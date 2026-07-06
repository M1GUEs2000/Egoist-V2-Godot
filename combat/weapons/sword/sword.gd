class_name Sword extends WeaponBase
## Espada (bóveda: Armas/Espada): combo X de 4 + rama espera + sweet spot;
## Y = launcher / Y cargada aérea. X cargado = dash ofensivo (gasta 1 barra).
## Swings 100% procedurales (tweens de quaternion sobre el Pivot), SIN AnimationPlayer.
# ponytail: personalidades X/Y como funcs aquí; extraer strategy cuando exista la 2ª arma.

const STEP_COUNT := 4
const STRIKE_ANGLE := 150.0
## Rama "espera": tardar al menos esto (dentro de la ventana) en encadenar el 3er golpe
## convierte los golpes 3-4 de estocadas a vueltas completas.
const WAIT_BRANCH_THRESHOLD := 0.3

var _step := 0
var _combo_playing := false
var _window_open := false
var _queued := false
var _queued_time := 0.0
var _window_expiry := 0.0
var _spin_branch := false
var _launcher_id := 0
var _swing_tween: Tween

@onready var _launcher_hitbox: Hitbox = $LauncherHitbox

func setup(player: Player) -> void:
	super.setup(player)
	_launcher_hitbox.source = player
	_launcher_hitbox.damage = 1.0 if _t().launcher_deals_damage else 0.0
	_launcher_hitbox.stun = tuning.stun
	_launcher_hitbox.landed.connect(_on_launcher_hit)

func tap(slot: World.Slot) -> void:
	if slot == World.Slot.X:
		_tap_x()
	else:
		_tap_y()

func hold(slot: World.Slot, _level: int) -> void:
	if slot == World.Slot.X:
		_hold_x()
	else:
		_hold_y()

# ---- Personalidad X: combo de 4 + cargado (dash sweet spot) ----

func _tap_x() -> void:
	# En el aire: combo aéreo (motor genérico en WeaponBase), no el terrestre.
	if _player.is_airborne():
		play_aerial_combo()
		return

	if _combo_playing:
		if _window_open:
			_queued = true
			_queued_time = World.now()
		return

	if World.now() > _window_expiry:
		_step = 0
	_run_ground_combo()

## Combo terrestre (bóveda Armas): X X X X → swing, swing, estocada, estocada.
## X X (espera) X X → los golpes 3-4 pasan a vueltas completas.
func _run_ground_combo() -> void:
	_combo_playing = true
	_spin_branch = false
	_routine_id += 1
	var id := _routine_id

	while true:
		_queued = false
		_window_open = false
		_step = (_step % STEP_COUNT) + 1

		_play_combo_step(_step, _spin_branch)
		_player.attack_step(tuning.swing_time)  # avanza hacia el lockeado / al frente
		_player.hold_airborne_for_attack()
		begin_damage_window(tuning.swing_time)
		ComboTracker.register_hit()

		await wait_seconds(tuning.swing_time)
		if id != _routine_id:
			return
		var last_step_end := World.now()

		if _step >= STEP_COUNT:
			_step = 0
			break

		# Ventana de encadene: esperar el siguiente tap o cortar el combo.
		_window_open = true
		_window_expiry = World.now() + _t().combo_window
		while World.now() < _window_expiry and not _queued:
			await get_tree().process_frame
			if id != _routine_id:
				return
		_window_open = false

		if not _queued:
			_step = 0
			break

		# Al pasar del 2º al 3er golpe: si hubo "espera", rama de vueltas.
		if _step == 2:
			_spin_branch = (_queued_time - last_step_end) >= WAIT_BRANCH_THRESHOLD

	_combo_playing = false
	_window_open = false

## X cargado: dash ofensivo (sweet spot). Gasta 1 barra; el daño lo pone el hitbox del
## dash (PlayerDash) → un kill en la ventana del cargado devuelve la barra completa.
func _hold_x() -> void:
	# Move de compromiso: interrumpe el combo en curso y dashea.
	cancel_routines()
	_combo_playing = false
	_window_open = false
	_step = 0

	if _player.meter.spend_charged():
		_player.force_dash(_player.forward(), _t().charged_dash_distance, _t().charged_dash_duration, true)
	else:
		# ponytail: sin barra no hay dash — cae a un swing cargado normal.
		# "sweet spot degradado sin meter" es diseño futuro, ver bóveda Combate.
		swing(130.0)
		_player.hold_airborne_for_attack()
		begin_damage_window(tuning.swing_time)
	ComboTracker.register_hit()

# ---- Personalidad Y: golpe simple + launcher / cargada aérea ----

func _tap_y() -> void:
	swing(STRIKE_ANGLE)
	_player.attack_step(tuning.swing_time)  # encara y avanza hacia el enemigo lockeado
	_player.hold_airborne_for_attack()
	begin_damage_window(tuning.swing_time)
	ComboTracker.register_hit()

func _hold_y() -> void:
	# En el aire: Y cargada aérea (auto-launch + spike/rebote), no el launcher terrestre.
	if _player.is_airborne():
		_aerial_charged_y()
		return
	# Launcher terrestre (ex AttackLauncher: solo desde el suelo — ya garantizado acá).
	swing_up(STRIKE_ANGLE)
	_run_launcher()

func _run_launcher() -> void:
	_launcher_id += 1
	var id := _launcher_id
	await wait_seconds(0.05)
	if id != _launcher_id:
		return
	_player.launch(_t().launcher_height, _t().launcher_hang_time)
	_launcher_hitbox.begin_swing()
	ComboTracker.register_hit()
	await wait_seconds(_t().launcher_hitbox_duration)
	if id != _launcher_id:
		return
	_launcher_hitbox.end_swing()

## Y cargada en el aire: gasta 1 barra (como la X cargada). El jugador se auto-launcha
## (mismos valores que el launcher Y) y los golpeados spikean al suelo y rebotan hasta
## la altura del jugador leída al aterrizar. Sin barra → golpe Y normal.
func _aerial_charged_y() -> void:
	if not _player.meter.spend_charged():
		# ponytail: sin barra no hay move de compromiso — cae a un golpe Y aéreo normal.
		_tap_y()
		return
	_run_aerial_charged_y()

func _run_aerial_charged_y() -> void:
	var t := _t()
	_player.launch(t.launcher_height, t.launcher_hang_time)  # auto-empuje hacia arriba
	swing_up(STRIKE_ANGLE)
	begin_damage_window(tuning.swing_time)
	ComboTracker.register_hit()
	await wait_seconds(tuning.swing_time)
	for hurtbox in _window_hits.duplicate():
		var target := hurtbox.owner_node
		if target.has_method("slam_bounce"):
			target.call("slam_bounce", t.aerial_charged_down_speed,
					func() -> float: return _player.global_position.y,
					t.launcher_hang_time)

func _on_launcher_hit(hurtbox: Hurtbox, died: bool) -> void:
	_on_hit(hurtbox, died)  # meter / air-hit-stall, igual que la hoja
	# Solo lanza lo lanzable: una pared o un pickup no salen volando.
	# (v1 lanzaba ANTES del daño para que el golpe viera el stun aéreo; acá el Hitbox
	# ya aplicó el daño — revisar el orden en batch 5 cuando existan enemigos.)
	var target := hurtbox.owner_node
	if target.has_method("launch"):
		target.call("launch", _t().launcher_height, _t().launcher_hang_time)

# ---- Swings visuales (procedurales, quaternions sobre el Pivot) ----

## Swing horizontal (eje Y local): barrido de un lado al otro. Corte por defecto.
func swing(angle: float) -> void:
	_swing_axis(angle, Vector3.UP)

## Swing vertical ascendente (eje X local): corte de abajo hacia arriba (uppercut del launcher).
func swing_up(angle: float) -> void:
	_swing_axis(angle, Vector3.RIGHT)

## Combo terrestre: swing, swing, estocada, estocada (o vueltas en la rama espera).
func _play_combo_step(step: int, spin: bool) -> void:
	match step:
		1:  # izquierda → derecha
			_play_swing(Quaternion(Vector3.UP, deg_to_rad(-70.0)), Quaternion(Vector3.UP, deg_to_rad(70.0)))
		2:  # derecha → izquierda
			_play_swing(Quaternion(Vector3.UP, deg_to_rad(70.0)), Quaternion(Vector3.UP, deg_to_rad(-70.0)))
		3, 4:
			if spin:
				_play_spin()  # vuelta completa
			else:
				_play_thrust()  # estocada

## Combo AÉREO (bóveda Armas): golpe 1 siempre diagonal; según la espera antes del 2:
##   X X X          → diagonal, diagonal, hachazo vertical (spikea al suelo)
##   X (espera) X X → diagonal, vuelta, vuelta (empuja hacia adelante)
func air_steps() -> int:
	return 3

func play_air_step(step: int, finisher: bool, wait_branch: bool) -> void:
	if step == 1:
		_play_air_diagonal(-1.0)  # arriba-izq → abajo-der
		return
	if wait_branch:
		_play_spin()  # vuelta completa (golpe 2 y finisher)
		return
	if finisher:  # hachazo vertical
		_play_swing(Quaternion(Vector3.RIGHT, deg_to_rad(-95.0)), Quaternion(Vector3.RIGHT, deg_to_rad(95.0)))
	else:
		_play_air_diagonal(1.0)  # arriba-der → abajo-izq

## Diagonal descendente: combina giro horizontal (Y) con inclinación vertical (X).
func _play_air_diagonal(side: float) -> void:
	_play_swing(
		Quaternion(Vector3.UP, deg_to_rad(-55.0 * side)) * Quaternion(Vector3.RIGHT, deg_to_rad(-45.0)),
		Quaternion(Vector3.UP, deg_to_rad(55.0 * side)) * Quaternion(Vector3.RIGHT, deg_to_rad(45.0))
	)

## Estocada: la hoja apunta al frente y vuelve. El avance real lo da attack_step del jugador.
func _play_thrust() -> void:
	_play_swing(Quaternion.IDENTITY, Quaternion(Vector3.RIGHT, deg_to_rad(80.0)))

func _swing_axis(angle: float, axis: Vector3) -> void:
	var half := deg_to_rad(angle * 0.5)
	_play_swing(Quaternion(axis, -half), Quaternion(axis, half))

func _play_swing(from: Quaternion, to: Quaternion) -> void:
	_kill_swing_tween()
	_pivot.quaternion = from
	_swing_tween = create_tween()
	_swing_tween.tween_property(_pivot, "quaternion", to, tuning.swing_time)
	_swing_tween.tween_callback(_reset_pivot)

func _play_spin() -> void:
	_kill_swing_tween()
	_swing_tween = create_tween()
	_swing_tween.tween_method(_set_spin_angle, 0.0, TAU, tuning.swing_time)
	_swing_tween.tween_callback(_reset_pivot)

func _set_spin_angle(angle: float) -> void:
	_pivot.quaternion = Quaternion(Vector3.UP, angle)

func _reset_pivot() -> void:
	_pivot.quaternion = Quaternion.IDENTITY

func _kill_swing_tween() -> void:
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()

func _t() -> SwordTuning:
	return tuning as SwordTuning

func _default_tuning() -> WeaponTuning:
	return SwordTuning.new()
