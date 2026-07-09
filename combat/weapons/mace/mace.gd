class_name Mace extends WeaponBase
## Mazo (bóveda: Armas/Mazo): tap = combo de 3 + rama espera (2 smashes extra);
## X cargado = 3 niveles con sweet spot congelante; Y = launcher omnidireccional con sweet
## spot de 2 golpes. Aéreo: tap empuja / X cargado cae con AOE / cae+vuelta congelante, Y gira
## empujando o congela con más hang time. Arma lenta, más daño y knockback que la
## Espada. Coreografía sobre el motor genérico de WeaponBase (run_combo_chain,
## swing/spin/run_launcher_window); acá vive solo la personalidad del Mazo.
# ponytail: número mágico de golpes/niveles hardcodeado en la coreografía (no en un
# enum) — si sale una 3ra arma con combo terrestre distinto, recién ahí generalizar.

const STEP_COUNT := 3
const WAIT_BRANCH_EXTRA_STEPS := 2  # rama espera: 3 smashes en vez de 1 (steps 3-4-5)

## Rutina dueña de la ventana de sweet spot del launcher (0 = ninguna abierta). Es el
## id de rutina, no un bool: así cualquier otro ataque la invalida al arrancar y el
## launcher degradado no se dispara solo en medio del combo siguiente.
var _launcher_window_id := 0

@onready var _launcher_hitbox: Hitbox = $LauncherHitbox

func setup(player: Player) -> void:
	super.setup(player)
	setup_launcher_hitbox(_launcher_hitbox, _t().launcher_deals_damage, tuning.stun)

func tap(_slot: World.Slot) -> void:
	_tap_combo()

func hold(slot: World.Slot, level: int) -> void:
	if slot == World.Slot.X:
		_hold_x(level)
	else:
		_hold_y(level)

## Niveles de carga del X (bóveda: "1 carga = 1 vuelta, 2 cargas = 2 vueltas, 3
## cargas = 3 vueltas"). El primer nivel sale al cruzar hold_threshold (ya cargado,
## nivel 1); cada charge_level_step extra suma un nivel, hasta max_charge_level.
## Y reusa la misma escala: aguantar hasta el nivel máximo confirma su sweet spot aéreo.
func charge_level(held_time: float) -> int:
	var t := _t()
	var hold_threshold := _player.tuning.input_hold_threshold if _player != null else 0.0
	var extra := held_time - hold_threshold  # hold() ya garantiza held_time >= hold_threshold
	var level := 1 + int(floor(maxf(0.0, extra) / t.charge_level_step))
	return clampi(level, 1, t.max_charge_level)

# ---- Tap: combo de 3 (+2 en rama espera) compartido por X/Y ----

## Combo terrestre (bóveda): tap tap tap → swing, swing, smash vertical AOE.
## tap tap (espera) tap tap → swing, swing, tres smashes verticales AOE (steps 3-4-5).
## Si hay un launcher terrestre esperando confirmación, este tap confirma su segundo golpe.
func _tap_combo() -> void:
	if _launcher_window_is_open():
		_confirm_launcher_second_hit()
		return
	if _player.is_airborne():
		_aerial_tap()
		return
	if try_queue_combo(&"ground"):
		return
	reset_hit_profile()
	run_combo_chain(&"ground", STEP_COUNT, tuning.swing_time, _t().combo_window,
			2, _t().ground_wait_branch_threshold, _begin_ground_step, Callable(),
			WAIT_BRANCH_EXTRA_STEPS)

func _begin_ground_step(step: int, _finisher: bool, _wait_branch: bool) -> void:
	match step:
		1:
			var half := _t().combo_swing_angle
			_play_swing(Quaternion(Vector3.UP, deg_to_rad(-half)), Quaternion(Vector3.UP, deg_to_rad(half)))
		2:
			var half := _t().combo_swing_angle
			_play_swing(Quaternion(Vector3.UP, deg_to_rad(half)), Quaternion(Vector3.UP, deg_to_rad(-half)))
		_:
			_play_smash()
	_player.attack_step(tuning.swing_time)
	_player.hold_airborne_for_attack()
	# NO begin_damage_window aqui: run_combo_chain ya lo llama despues de begin_step.
	# Ver Sword._begin_ground_step como referencia. Llamarlo aqui duplicaba la ventana
	# e inmediatamente limpiaba _window_hits antes de que el motor arrancara la real.

# ---- Personalidad X: cargado (vueltas, 3 niveles) ----

func _play_smash() -> void:
	var half := _t().smash_angle
	_play_swing(Quaternion(Vector3.RIGHT, deg_to_rad(-half)), Quaternion(Vector3.RIGHT, deg_to_rad(half)))

## X cargado: `level` vueltas completas (bóveda: 1/2/3 cargas = 1/2/3 vueltas). En
## tierra gasta 1 barra por vuelta real; en el aire gasta 1 barra fija y cae con AOE.
## Move de compromiso (igual que Sword._hold_x): cancela el combo tap que arrancó
## en el press antes de ejecutar el cargado, sea en tierra o en el aire.
func _hold_x(level: int) -> void:
	cancel_routines()  # interrumpe el tap combo del press antes de ejecutar el cargado
	if _player.is_airborne():
		if _player.meter.spend_charged(1, false):
			_aerial_charged_x(level >= _t().max_charge_level)
		else:
			_tap_combo()
		return
	var actual_level := mini(level, _player.meter.affordable_bars())
	if actual_level <= 0:
		_tap_combo()
	elif _player.meter.spend_charged(actual_level, false):
		_run_charged_spins(actual_level)
	else:
		_tap_combo()

## El golpe final de la secuencia de vueltas es el que hace daño/knockback real. Si
## llegó al nivel máximo (sweet spot), las vueltas intermedias congelan en vez de
## empujar — bóveda: "los enemigos que pega quedan congelados hasta la última vuelta".
## No restaura el hitbox al salir: si otra rutina la invalidó, ella ya es la dueña; el
## perfil lo resetea la entrada del ataque siguiente (reset_hit_profile).
func _run_charged_spins(level: int) -> void:
	var t := _t()
	var id := begin_routine()
	reset_hit_profile()
	var sweet_spot := level >= t.max_charge_level
	_player.hold_airborne_for_attack()
	for spin in range(1, level + 1):
		_play_spin(t.charged_spin_time)
		var finisher := spin == level
		_set_hitbox_stun(t.charged_freeze_stun if (sweet_spot and not finisher) else t.charged_final_stun)
		_blade_hitbox.damage = t.charged_hit_damage if finisher else (0.0 if sweet_spot else 1.0)
		if finisher:
			arm_push(t.charged_final_push, t.charged_spin_time * tuning.push_at)
		begin_damage_window(t.charged_spin_time)
		ComboTracker.register_hit()
		await wait_seconds(t.charged_spin_time)
		if not is_routine_current(id):
			return
	reset_hit_profile()

# ---- Personalidad Y: launcher omnidireccional + sweet spot de 2 golpes ----

## Launcher terrestre (área grande, omnidireccional) o Y cargado aéreo (giro que
## empuja / congela) según el estado del player. `level` decide el sweet spot aéreo.
func _hold_y(level: int) -> void:
	if _player.is_airborne():
		_aerial_hold_y(level >= _t().max_charge_level)
		return
	var id := begin_routine()
	reset_hit_profile()
	swing_up(_t().strike_angle)
	begin_damage_window(tuning.swing_time)
	ComboTracker.register_hit()
	_open_launcher_second_hit_window(id)

## Sweet spot (bóveda: "hace dos golpes para subirlos al aire"): un segundo tap Y
## dentro de esta ventana confirma y lanza ya; si expira sin confirmar, lanza igual
## con un solo golpe (degradado, mismo criterio que usan los cargados sin meter).
## Si otro ataque arrancó mientras tanto, la ventana muere con su rutina: nada de
## lanzar al jugador medio segundo después, en medio del combo que la interrumpió.
func _open_launcher_second_hit_window(id: int) -> void:
	_launcher_window_id = id
	await wait_seconds(_t().launcher_second_hit_window)
	if _launcher_window_id != id or not is_routine_current(id):
		return  # ya lo confirmó un segundo tap, u otro ataque invalidó la rutina
	_launcher_window_id = 0
	_run_launcher()

func _launcher_window_is_open() -> bool:
	return _launcher_window_id != 0 and is_routine_current(_launcher_window_id)

func _confirm_launcher_second_hit() -> void:
	_launcher_window_id = 0
	swing_up(_t().strike_angle)
	begin_damage_window(tuning.swing_time)
	ComboTracker.register_hit()
	_run_launcher()

func _run_launcher() -> void:
	run_launcher_window(_launcher_hitbox, _t().launcher_height, _t().launcher_hang_time,
			_t().launcher_hitbox_duration)

# ---- Aéreo (moves puntuales, no son combo encadenado: ver Combate/Mazo) ----

## Tap aéreo sin carga: golpe con empuje hacia adelante.
func _aerial_tap() -> void:
	begin_routine()
	reset_hit_profile()
	swing(_t().combo_swing_angle)
	arm_push(tuning.push, tuning.swing_time * tuning.push_at)
	_player.notify_aerial_attack(tuning.swing_time)
	begin_damage_window(tuning.swing_time)
	ComboTracker.register_hit()

## X cargado: caída forzada con AOE ("ground pound"); sweet spot con vuelta final
## que congela y mantiene al jugador (y a los golpeados) en el aire.
func _aerial_charged_x(sweet_spot: bool) -> void:
	var t := _t()
	var id := begin_routine()
	reset_hit_profile()
	_player.notify_aerial_attack(tuning.swing_time)
	_player.vertical_velocity = -absf(t.air_smash_fall_speed)
	_set_hitbox_damage(t.charged_hit_damage)
	begin_damage_window(tuning.swing_time)
	ComboTracker.register_hit()
	await wait_seconds(tuning.swing_time)
	if not is_routine_current(id):
		return
	if sweet_spot:
		_play_spin(t.charged_spin_time)
		_set_hitbox_stun(t.air_freeze_stun)
		begin_damage_window(t.charged_spin_time)
		ComboTracker.register_hit()
		_player.notify_aerial_attack(t.air_freeze_extra_hang_time)
		await wait_seconds(t.charged_spin_time)
		if not is_routine_current(id):
			return
	reset_hit_profile()

## Y cargado aéreo: vueltas que empujan a los lados; sweet spot congela y da más
## tiempo airborne (bóveda: "a ti también te da más tiempo airborne").
func _aerial_hold_y(sweet_spot: bool) -> void:
	var t := _t()
	var id := begin_routine()
	reset_hit_profile()
	_player.notify_aerial_attack(t.charged_spin_time)
	_play_spin(t.charged_spin_time)
	_set_hitbox_stun(t.air_freeze_stun if sweet_spot else tuning.stun)
	if not sweet_spot:
		arm_push(tuning.push, t.charged_spin_time * tuning.push_at)
	begin_damage_window(t.charged_spin_time)
	ComboTracker.register_hit()
	await wait_seconds(t.charged_spin_time)
	if not is_routine_current(id):
		return
	if sweet_spot:
		_player.notify_aerial_attack(t.air_freeze_extra_hang_time)
	reset_hit_profile()

## Sincroniza el stun de la hoja y el disco aéreo (ambos activos en el aire): así un
## golpe congelante congela sin importar cuál de los dos conecta.
func _set_hitbox_stun(s: StunSettings) -> void:
	_blade_hitbox.stun = s
	if _air_disc_hitbox != null:
		_air_disc_hitbox.stun = s

func _set_hitbox_damage(damage: float) -> void:
	_blade_hitbox.damage = damage
	if _air_disc_hitbox != null:
		_air_disc_hitbox.damage = damage

func _t() -> MaceTuning:
	return tuning as MaceTuning

func _default_tuning() -> WeaponTuning:
	return MaceTuning.new()
