class_name Player extends CharacterBody3D
## GLUE (ex PlayerController.cs) + motor físico (ex PlayerMotor.cs): CharacterBody3D ES el
## motor, así que el estado compartido que todos los bloques tocan (velocidad vertical,
## bump/momentum, aire/suelo) vive aquí. No implementa comportamiento de bloques: los
## orquesta en el orden correcto cada physics frame y coordina las cancelaciones cruzadas.
## El salto, por ser trivial, vive aquí. (Swing de cadenas llega en batch 6.)

enum AirState { GROUNDED, AIRBORNE }

signal double_jump_changed(available: bool)

@export var tuning: PlayerTuning

var air_state := AirState.GROUNDED
var vertical_velocity := 0.0
var bump_velocity := Vector3.ZERO
var poise := Poise.new()

var _can_double_jump := true
var _dodge_queued := false  # dodge pedido tarde en un golpe: sale al terminarlo

@onready var locomotion: PlayerLocomotion = $Locomotion
@onready var dash: PlayerDash = $Dash
@onready var launcher: PlayerLauncher = $Launcher
@onready var wall_slide: PlayerWallSlide = $WallSlide
@onready var floor_slide: PlayerFloorSlide = $FloorSlide
@onready var enemy_bounce: PlayerEnemyBounce = $EnemyBounce
@onready var air_kill_reset: PlayerAirKillReset = $AirKillReset
@onready var stun: PlayerStun = $Stun
@onready var meter: PlayerMeter = $Meter
@onready var health: Health = $Health
@onready var player_health: PlayerHealth = $PlayerHealth
@onready var combat: PlayerCombat = $Combat
@onready var action_world_switch: ActionWorldSwitchModifier = $ActionWorldSwitchModifier
@onready var lock_on: LockOn = $LockOn
@onready var arm: PlayerArm = $Arm
@onready var _run_dust: GPUParticles3D = get_node_or_null("RunDust") as GPUParticles3D
@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D

var _stun_material: StandardMaterial3D
var _stun_feedback_color := Color.WHITE
var _chip_material: StandardMaterial3D
var _chip_tween: Tween

func _ready() -> void:
	add_to_group("player")  # la cámara y los enemigos me encuentran por grupo
	if tuning == null:
		tuning = PlayerTuning.new()
	collision_layer = World.LAYER_PLAYER
	collision_mask = World.LAYER_WORLD | World.LAYER_ENEMY
	setup_poise()
	player_health.setup(self)
	meter.setup(self)
	lock_on.setup(self, get_viewport().get_camera_3d())
	locomotion.setup(self, get_viewport().get_camera_3d())
	launcher.setup(self)
	wall_slide.setup(self)
	floor_slide.setup(self)
	enemy_bounce.setup(self)
	air_kill_reset.setup(self)
	dash.setup(self, locomotion, launcher.register_air_hit_stall, launcher.cancel)
	combat.setup(self)
	arm.setup(self)
	stun.stunned_started.connect(_on_stunned_started)
	stun.stunned_ended.connect(_on_stunned_ended)

func is_grounded() -> bool:
	return air_state == AirState.GROUNDED

func is_airborne() -> bool:
	return air_state == AirState.AIRBORNE

func is_stunned() -> bool:
	return stun != null and stun.is_stunned()

func is_armored() -> bool:
	return false

## Duck typing que consulta Hurtbox.can_receive_hit(): i-frames del dodge de esquiva.
func can_receive_hit() -> bool:
	return not dash.is_invulnerable()

func forward() -> Vector3:
	return -global_basis.z

## Poise que inflige un parry del jugador ahora mismo (por arma y tipo de ataque). Lo consulta el
## enemigo parriado (EnemyBase.resolve_parry) por duck typing.
func current_parry_poise() -> float:
	return combat.current_parry_poise() if combat != null else 0.0

func _unhandled_input(event: InputEvent) -> void:
	if is_stunned():
		return
	if event.is_action_pressed("jump"):
		_on_jump()
	elif event.is_action_pressed("dodge"):
		_on_dodge()
	elif event.is_action_pressed("lock_on"):
		lock_on.toggle_lock()
	elif lock_on.is_locked and event.is_action_pressed("camera_left"):
		lock_on.cycle_target(-1)
	elif lock_on.is_locked and event.is_action_pressed("camera_right"):
		lock_on.cycle_target(1)

func _physics_process(delta: float) -> void:
	stun.tick()
	if is_stunned():
		_set_run_dust(false)
		_tick_stunned(delta)
		return

	if launcher.is_launched:
		_set_run_dust(false)
		wall_slide.cancel()
		floor_slide.cancel()
		enemy_bounce.cancel()
		launcher.tick_launch(delta)  # el launcher controla el movimiento
		return

	# Dodge bufferizado (pedido pasado el umbral del golpe): sale apenas el golpe termina.
	if _dodge_queued and not dash.is_dashing and not locomotion.is_attacking():
		_dodge_queued = false
		dash.dodge()

	if dash.is_dashing:
		_set_run_dust(false)
		wall_slide.cancel()
		floor_slide.cancel()
		enemy_bounce.cancel()
		dash.tick(delta)
		_bleed_momentum(delta)
		return

	var input_dir := locomotion.camera_relative(locomotion.read_move_input())
	var horizontal := locomotion.tick(delta) + locomotion.lunge_velocity()
	if wall_slide.blocks_move_input() or enemy_bounce.blocks_move_input():
		horizontal = Vector3.ZERO
		# El impulso del wall jump/rebote vive en bump_velocity: la inercia aérea del input
		# se borra para que al soltarse el lock no reaparezca el rumbo previo al salto.
		locomotion.set_air_velocity(Vector3.ZERO)

	# Freeze de caida del Brazo (solo la vertical): mientras dure, la caida se congela en 0 sin
	# tocar el horizontal; al soltar, launcher restaura el momentum de caida previo (ver
	# PlayerLauncher.consume_air_freeze).
	if launcher.consume_air_freeze():
		vertical_velocity = 0.0
	else:
		vertical_velocity += tuning.gravity * launcher.gravity_scale() * delta

	var horizontal_with_momentum := wall_slide.apply_slide_velocity(horizontal + bump_velocity, input_dir, delta)
	horizontal_with_momentum = floor_slide.apply_slide_velocity(horizontal_with_momentum, input_dir, delta)
	velocity = horizontal_with_momentum + Vector3(0.0, vertical_velocity, 0.0)
	move_and_slide()
	wall_slide.update_after_move(horizontal + bump_velocity, input_dir)
	floor_slide.update_after_move(horizontal + bump_velocity, input_dir)
	enemy_bounce.update_after_move(horizontal + bump_velocity)

	if is_on_floor():
		vertical_velocity = -1.0
		air_state = AirState.GROUNDED
		dash.restore_airdash()
		_set_double_jump_available(true)
		launcher.reset_air_stall()
		air_kill_reset.reset_air_charge_fall_control()
		wall_slide.cancel()
	else:
		air_state = AirState.AIRBORNE

	# Polvo al correr: solo en el suelo y por encima del umbral de velocidad horizontal.
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	_set_run_dust(is_on_floor() and planar_speed >= tuning.run_dust_min_speed)

	_bleed_momentum(delta)

func _on_jump() -> void:
	_dodge_queued = false  # saltar descarta un dodge bufferizado pendiente
	# (swing release / begin — batch 6)
	if is_on_floor():
		# Saltar desde un floor slide conserva jump_momentum_keep del slide como momentum aereo.
		if floor_slide.is_sliding:
			floor_slide.launch_into_jump()
		vertical_velocity = tuning.jump_force
		air_state = AirState.AIRBORNE
	elif wall_slide.try_wall_jump(locomotion.camera_relative(locomotion.read_move_input())):
		# Contra una pared el salto SIEMPRE es rebote hacia afuera (aunque el slide se
		# haya cortado este frame): no consume ni recarga el doble salto.
		air_state = AirState.AIRBORNE
	elif enemy_bounce.try_bounce(locomotion.camera_relative(locomotion.read_move_input())):
		air_state = AirState.AIRBORNE
	elif _can_double_jump:
		_set_double_jump_available(false)
		# El doble salto sale SIEMPRE con gravedad normal: cierra la ventana de caida lenta
		# (air-hit-stall y hover de un move) antes de aplicar jump_force. Sin esto, saltar dentro
		# de esa ventana subia con air_stall_float_gravity (0.1 = -4 m/s^2 contra -40) y el mismo
		# jump_force llegaba diez veces mas alto. air_stall_max_rise no alcanzaba: capea la
		# velocidad al REGISTRAR el stall, no la de un salto posterior.
		launcher.reset_air_stall()
		vertical_velocity = tuning.jump_force
		air_state = AirState.AIRBORNE

func _on_dodge() -> void:
	# Golpe casi completo (pasado el umbral): no lo cortamos, se buferea y sale al terminar.
	# Golpe temprano o sin golpe: dashea ya (cancela el ataque).
	if locomotion.is_attacking() and locomotion.attack_progress() >= tuning.dodge_cancel_attack_threshold:
		_dodge_queued = true
		return
	_dodge_queued = false
	dash.dodge()

# ---- API pública (armas, pickups, combate, traversal) ----

func restore_double_jump() -> void:
	_set_double_jump_available(true)

func has_double_jump() -> bool:
	return _can_double_jump

func restore_airdash() -> void:
	dash.restore_airdash()

func apply_air_charge_fall_control() -> void:
	air_kill_reset.apply_air_charge_fall_control()

func reset_air_charge_fall_control() -> void:
	air_kill_reset.reset_air_charge_fall_control()

func apply_air_kill_reset() -> void:
	air_kill_reset.apply_air_kill_reset()

func activate_action_world_switch() -> void:
	action_world_switch.activate()

func take_damage(amount: float) -> bool:
	return player_health.take_damage(amount)

func receive_stun(stun_settings: StunSettings, mode := PlayerStun.Mode.STILL,
		push_direction := Vector3.ZERO, horizontal_speed := 0.0, vertical_speed := 0.0) -> bool:
	if stun_settings == null:
		return false
	return try_apply_stun(
			stun_settings.duration_for(is_airborne()),
			stun_settings.poise_damage,
			mode,
			push_direction,
			horizontal_speed,
			vertical_speed)

## Gate del stun: el golpe come poise y solo stunea si quiebra la reserva. Ya stuneado no hay
## poise que romper (está quebrado): el golpe entra directo y extiende.
## Único embudo de stun del player (melee/ranged enemigo y spike_wall llaman esto o receive_stun,
## que redirige aquí) — por eso los i-frames del dodge se cortan ACÁ, no en Hurtbox.can_receive_hit:
## el stun de los ataques enemigos llega directo por este método, sin pasar por el Hurtbox.
func try_apply_stun(duration: float, poise_damage: float, mode := PlayerStun.Mode.STILL,
		push_direction := Vector3.ZERO, horizontal_speed := 0.0, vertical_speed := 0.0,
		feedback_color := Color.TRANSPARENT) -> bool:
	if dash.is_invulnerable():
		return false
	if not is_stunned() and not poise.take_poise_damage(poise_damage, is_armored()):
		_play_poise_chip_flash()  # aguanté: fogonazo blanco, sin stun
		return false
	apply_stun(duration, mode, push_direction, horizontal_speed, vertical_speed, feedback_color)
	return true

func apply_stun(duration: float = -1.0, mode := PlayerStun.Mode.STILL,
		push_direction := Vector3.ZERO, horizontal_speed := 0.0, vertical_speed := 0.0,
		feedback_color := Color.TRANSPARENT) -> void:
	var stun_duration := tuning.default_stun_duration if duration < 0.0 else duration
	_stun_feedback_color = feedback_color if feedback_color.a > 0.0 else tuning.stun_color
	_dodge_queued = false
	locomotion.cancel_lunge()
	wall_slide.cancel()
	floor_slide.cancel()
	enemy_bounce.cancel()
	launcher.cancel()
	dash.cancel()
	if combat != null:
		combat.cancel_input()
	match mode:
		PlayerStun.Mode.PUSH:
			push_direction.y = 0.0
			if push_direction.length_squared() > 0.0001:
				set_momentum(push_direction.normalized() * horizontal_speed)
			else:
				bump_velocity = Vector3.ZERO
			vertical_velocity = vertical_speed
			air_state = AirState.AIRBORNE
		_:
			bump_velocity = Vector3.ZERO
			if is_on_floor():
				vertical_velocity = -1.0
	stun.apply(stun_duration, mode)

func fire_action_world_switch() -> void:
	action_world_switch.fire_action()

func register_air_hit_stall(scale := 1.0, cuts_momentum := true) -> void:
	launcher.register_air_hit_stall(scale, cuts_momentum)

## Golpe aereo del Brazo: pausa la caida `duration` seg y la retoma completa (vertical), y decelera
## el momentum horizontal por `horizontal_keep` (ver PlayerLauncher.register_arm_air_freeze).
func register_arm_air_freeze(duration: float, horizontal_keep: float) -> void:
	launcher.register_arm_air_freeze(duration, horizontal_keep)

func notify_aerial_attack(duration: float) -> void:
	launcher.notify_aerial_attack(duration)

## Hang propio de un move: frena la caída y sostiene al jugador, sin gastarle el doble salto.
func hover(duration: float) -> void:
	launcher.hover(duration)

func attack_step(duration: float) -> void:
	locomotion.attack_step(duration)

func hold_airborne_for_attack() -> void:
	if not is_on_floor():
		air_state = AirState.AIRBORNE

## Pequeño empujón vertical (juice del combo aéreo: la 1ra vuelta de la rama espera
## eleva un poco al jugador). No pisa una subida mayor ya en curso.
func air_hop(speed: float) -> void:
	vertical_velocity = maxf(vertical_velocity, speed)
	air_state = AirState.AIRBORNE

func add_momentum(v: Vector3) -> void:
	bump_velocity = (bump_velocity + v).limit_length(tuning.momentum_max_speed)

func set_momentum(v: Vector3) -> void:
	bump_velocity = v.limit_length(tuning.momentum_max_speed)

func bump(dir: Vector3, h_speed: float, v_speed: float) -> void:
	_dodge_queued = false
	wall_slide.cancel()
	floor_slide.cancel()
	enemy_bounce.cancel()
	launcher.cancel()
	dash.cancel()
	var horizontal := Vector3(dir.x, 0.0, dir.z)
	if horizontal.length_squared() > 0.0001:
		add_momentum(horizontal.normalized() * h_speed)
	vertical_velocity = v_speed
	air_state = AirState.AIRBORNE

func force_dash(dir: Vector3, distance: float, duration: float, boost_bump_momentum := false,
		deals_damage := false) -> void:
	_dodge_queued = false
	wall_slide.cancel()
	floor_slide.cancel()
	enemy_bounce.cancel()
	dash.force_dash(dir, distance, duration, boost_bump_momentum, deals_damage)

## Programa un impulso que PlayerDash aplica solo al terminar naturalmente el dash actual.
func set_dash_exit_bop(dir: Vector3, forward_speed: float, vertical_speed: float) -> void:
	dash.set_exit_bop(dir, forward_speed, vertical_speed)

func launch(height: float, hang_time: float, rise_time: float = World.LAUNCH_RISE_TIME) -> void:
	_dodge_queued = false
	wall_slide.cancel()
	floor_slide.cancel()
	enemy_bounce.cancel()
	stun.cancel()
	dash.cancel()
	launcher.start_launch(height, hang_time, rise_time)

func _tick_stunned(delta: float) -> void:
	wall_slide.cancel()
	floor_slide.cancel()
	enemy_bounce.cancel()
	locomotion.set_air_velocity(Vector3.ZERO)  # el golpe pisa la inercia del input; el knockback vive en bump
	vertical_velocity += tuning.gravity * tuning.stun_gravity_scale * delta
	velocity = bump_velocity + Vector3(0.0, vertical_velocity, 0.0)
	move_and_slide()
	if is_on_floor():
		vertical_velocity = -1.0
		air_state = AirState.GROUNDED
	else:
		air_state = AirState.AIRBORNE
	if stun.mode == PlayerStun.Mode.PUSH:
		_bleed_momentum(delta, tuning.stun_bump_decay)
	else:
		bump_velocity = Vector3.ZERO

## Drena el exceso de velocidad a rate constante, escalado por la superficie actual.
func _bleed_momentum(delta: float, override_rate := -1.0) -> void:
	if bump_velocity.length_squared() < 0.01:
		bump_velocity = Vector3.ZERO
		return
	var rate := override_rate
	var surface_scale := 1.0
	if override_rate < 0.0:
		rate = tuning.move_speed / maxf(0.001, tuning.momentum_bleed_seconds_per_unit)
		surface_scale = _bleed_scale()
	_bleed_momentum_for_scale(delta, rate, surface_scale)

## En que esta apoyado el jugador ahora. El orden importa: el suelo gana sobre la pared.
func _bleed_scale() -> float:
	if is_on_floor():
		return tuning.momentum_bleed_ground
	if wall_slide.is_sliding:
		return tuning.momentum_bleed_wall
	return tuning.momentum_bleed_air

func _bleed_momentum_for_scale(delta: float, rate: float, surface_scale: float) -> void:
	bump_velocity = bump_velocity.move_toward(Vector3.ZERO, rate * surface_scale * delta)

func _set_run_dust(active: bool) -> void:
	if _run_dust != null and _run_dust.emitting != active:
		_run_dust.emitting = active

func _set_double_jump_available(available: bool) -> void:
	if _can_double_jump == available:
		return
	_can_double_jump = available
	double_jump_changed.emit(_can_double_jump)

## Carga el medidor de poise desde el tuning. Publico: cambiar el .tres en caliente (o el smoke)
## necesita re-aplicarlo, porque Poise guarda los valores, no lee el Resource cada golpe.
func setup_poise() -> void:
	poise.poise_max = tuning.poise_max
	poise.armor_bonus = tuning.armor_poise_bonus
	poise.decay_per_second = tuning.poise_decay_per_second
	poise.break_levels = tuning.poise_break_levels
	poise.recovery_time = tuning.poise_recovery_time
	poise.reset()

## Fogonazo blanco del golpe que comió poise sin quebrarme. Solo emisión: el material vuelve a
## null al apagarse, así que no deja rastro ni compite con el amarillo del stun.
func _play_poise_chip_flash() -> void:
	if _mesh == null or is_stunned():
		return
	if _chip_tween != null and _chip_tween.is_valid():
		_chip_tween.kill()
	if _chip_material == null:
		_chip_material = StandardMaterial3D.new()
		_chip_material.emission_enabled = true
	_chip_material.albedo_color = tuning.poise_chip_color
	_chip_material.emission = tuning.poise_chip_color
	_chip_material.emission_energy_multiplier = tuning.poise_chip_emission_energy
	_mesh.set_surface_override_material(0, _chip_material)
	_chip_tween = create_tween()
	_chip_tween.tween_property(_chip_material, "emission_energy_multiplier", 0.0,
			tuning.poise_chip_time)
	_chip_tween.tween_callback(_clear_poise_chip_flash)

# Si el stun entró durante el destello, el material amarillo ya está puesto: no lo pisamos.
func _clear_poise_chip_flash() -> void:
	if _mesh != null and not is_stunned():
		_mesh.set_surface_override_material(0, null)

func _on_stunned_started(_duration: float, _mode: PlayerStun.Mode) -> void:
	if _mesh == null:
		return
	if _chip_tween != null and _chip_tween.is_valid():
		_chip_tween.kill()  # manda el stun: el fogonazo blanco no le pelea la emisión al amarillo
	if _stun_material == null:
		_stun_material = StandardMaterial3D.new()
		_stun_material.emission_enabled = true
	_stun_material.albedo_color = _stun_feedback_color
	_stun_material.emission = _stun_feedback_color
	_stun_material.emission_energy_multiplier = tuning.stun_emission_energy
	_mesh.set_surface_override_material(0, _stun_material)

func _on_stunned_ended() -> void:
	if _mesh != null:
		_mesh.set_surface_override_material(0, null)
