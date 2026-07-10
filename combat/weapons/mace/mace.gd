class_name Mace extends WeaponBase
## Mazo (boveda: Armas/Mazo): tap = combo de 3 + rama espera (2 smashes extra);
## X cargado = 3 niveles con sweet spot congelante; Y cargado = continuidad de combo:
## paso corto + launcher en tierra, caida diagonal + AOE que rebota (slam_bounce) en aire.
## Coreografia sobre el motor generico de WeaponBase; aca vive solo la personalidad.

const STEP_COUNT := 3
const WAIT_BRANCH_EXTRA_STEPS := 2
const AIR_STEP_COUNT := 2

var _air_y_meet_y := 0.0

@onready var _launcher_hitbox: Hitbox = $LauncherHitbox
@onready var _air_slam_hitbox: Hitbox = $AirSlamHitbox
@onready var _launcher_shape: CollisionShape3D = $LauncherHitbox/CollisionShape3D
@onready var _air_slam_shape: CollisionShape3D = $AirSlamHitbox/CollisionShape3D

func setup(player: Player) -> void:
	super.setup(player)
	var t := _t()
	(_launcher_shape.shape as BoxShape3D).size = t.ground_y_launcher_size
	var air_slam_cylinder := _air_slam_shape.shape as CylinderShape3D
	air_slam_cylinder.radius = t.air_y_aoe_radius
	air_slam_cylinder.height = t.air_y_aoe_height
	setup_launcher_hitbox(_launcher_hitbox, t.ground_y_launcher_deals_damage, tuning.stun)
	# El AOE aereo NO lancea hacia arriba: clava a los enemigos al suelo y los rebota hasta
	# la altura del jugador (verbo slam_bounce, igual que el Y cargado de la Espada).
	_air_slam_hitbox.source = player
	_air_slam_hitbox.damage = 1.0
	_air_slam_hitbox.stun = tuning.stun
	_air_slam_hitbox.can_be_parried = false
	_air_slam_hitbox.landed.connect(_on_air_slam_hit)

func tap(_slot: World.Slot) -> void:
	_tap_combo()

func hold(slot: World.Slot, level: int) -> void:
	if slot == World.Slot.X:
		_hold_x(level)
	else:
		_hold_y()

## Solo X usa niveles. Y cargado ignora el nivel de carga por diseno.
func charge_level(held_time: float) -> int:
	var t := _t()
	var hold_threshold := _player.tuning.input_hold_threshold if _player != null else 0.0
	var extra := held_time - hold_threshold
	var level := 1 + int(floor(maxf(0.0, extra) / t.charge_level_step))
	return clampi(level, 1, t.max_charge_level)

# ---- Tap: combo de 3 (+2 en rama espera) compartido por X/Y ----

func _tap_combo() -> void:
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

func _play_smash() -> void:
	var half := _t().smash_angle
	_play_swing(Quaternion(Vector3.RIGHT, deg_to_rad(-half)), Quaternion(Vector3.RIGHT, deg_to_rad(half)))

# ---- Personalidad X: cargado (vueltas, 3 niveles) ----

func _hold_x(level: int) -> void:
	cancel_routines()
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

# ---- Personalidad Y: continuidad de combo ----

func _hold_y() -> void:
	var id := begin_routine()
	reset_hit_profile()
	if _player.is_airborne():
		_aerial_hold_y(id)
		return
	var t := _t()
	_player.force_dash(_player.forward(), t.ground_y_dash_distance, t.ground_y_dash_duration, false)
	await wait_seconds(t.ground_y_dash_duration)
	if not is_routine_current(id):
		return
	swing_up(t.strike_angle)
	run_launcher_window(_launcher_hitbox, t.ground_y_launcher_height, t.ground_y_launcher_hang_time,
			t.ground_y_launcher_duration, t.ground_y_launcher_delay, false)

# ---- Aereo ----

## Combo aereo X de 2 golpes (un tap por golpe, mismo motor que el terrestre): corre a
## swing_time porque el Mazo es pesado (el air_step_time generico es para armas rapidas).
func _aerial_tap() -> void:
	if try_queue_combo(&"air"):
		return
	reset_hit_profile()
	run_combo_chain(&"air", AIR_STEP_COUNT, tuning.swing_time, _t().combo_window,
			0, 0.0, _begin_air_step)

## Golpe 1: jab con el mango, sin push (golpe de preparacion). Golpe 2 (finisher): cabezazo
## horizontal que arma el push hacia adelante a mitad del swing.
func _begin_air_step(step: int, _finisher: bool, _wait_branch: bool) -> void:
	if step == 1:
		thrust(_t().air_handle_reach)
	else:
		swing(_t().combo_swing_angle)
		arm_push(tuning.push, tuning.swing_time * tuning.push_at)
	_player.attack_step(tuning.swing_time)
	_player.notify_aerial_attack(tuning.swing_time)

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

## Y aereo: cae en diagonal para interceptar. Al impactar (enemigo en el aire o suelo)
## estalla el cilindro UNA vez y clava/rebota a todos los de adentro (slam_bounce). Si el
## impacto fue contra un enemigo en el aire, el jugador rebota arriba-y-adelante segun la
## direccion de la caida ("grados de rebote"), sin gastar el doble salto.
func _aerial_hold_y(id: int) -> void:
	var t := _t()
	_set_air_y_fall_velocity()
	_player.notify_aerial_attack(t.air_y_max_fall_time)
	ComboTracker.register_hit()
	var end_at := World.now() + t.air_y_max_fall_time
	var hit_enemy_in_air := false
	while is_routine_current(id) and World.now() < end_at:
		if _player.is_on_floor():
			break
		if _airborne_enemy_contact():
			hit_enemy_in_air = true
			break
		await get_tree().physics_frame
	if not is_routine_current(id):
		return
	await _burst_air_slam(id, hit_enemy_in_air)

func _set_air_y_fall_velocity() -> void:
	var t := _t()
	var angle := deg_to_rad(t.air_y_fall_angle)
	var horizontal_speed := cos(angle) * t.air_y_fall_speed
	var vertical_speed := sin(angle) * t.air_y_fall_speed
	_player.set_momentum(_player.forward() * horizontal_speed)
	_player.vertical_velocity = -absf(vertical_speed)
	_player.air_state = Player.AirState.AIRBORNE

## Contacto fisico real con un enemigo durante la caida (mismas colisiones de CharacterBody3D
## que usa PlayerEnemyBounce): un collider en LAYER_ENEMY. Sin Area3D de deteccion aparte.
func _airborne_enemy_contact() -> bool:
	for index in range(_player.get_slide_collision_count()):
		var collision := _player.get_slide_collision(index)
		if collision == null:
			continue
		var collider := collision.get_collider() as CollisionObject3D
		if collider != null and (collider.collision_layer & World.LAYER_ENEMY) != 0:
			return true
	return false

## Estallido del cilindro: fija la altura de encuentro, rebota al jugador (solo si el impacto
## fue en el aire) y prende el hitbox una vez para golpear/rebotar a todos los de adentro.
func _burst_air_slam(id: int, hit_enemy_in_air: bool) -> void:
	var t := _t()
	_air_y_meet_y = _player.global_position.y + t.air_y_meet_height
	if hit_enemy_in_air:
		# La caida fue abajo+adelante; el rebote sale arriba+adelante. Los dos knobs fijan el
		# angulo ("grados de rebote"). No gasta el doble salto.
		_player.set_momentum(_player.forward() * t.air_y_bounce_forward_speed)
		_player.vertical_velocity = t.air_y_bounce_up_speed
		_player.air_state = Player.AirState.AIRBORNE
	_air_slam_hitbox.begin_swing()
	await wait_seconds(t.air_y_aoe_duration)
	if is_routine_current(id):
		_air_slam_hitbox.end_swing()

## Cada enemigo del estallido: alimenta meter/kills y lo clava al suelo -> rebota hasta la
## altura del jugador (slam_bounce), no un launch hacia arriba.
func _on_air_slam_hit(hurtbox: Hurtbox, died: bool) -> void:
	register_weapon_hit(hurtbox, died)
	var target: Node = hurtbox.owner_node
	if target.has_method("slam_bounce"):
		var meet_y := _air_y_meet_y
		target.call("slam_bounce", _t().air_y_down_speed,
				func() -> float: return meet_y,
				_t().air_y_launcher_hang_time)

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
