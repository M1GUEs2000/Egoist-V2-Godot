class_name Player extends CharacterBody3D
## GLUE (ex PlayerController.cs) + motor físico (ex PlayerMotor.cs): CharacterBody3D ES el
## motor, así que el estado compartido que todos los bloques tocan (velocidad vertical,
## bump/momentum, aire/suelo) vive aquí. No implementa comportamiento de bloques: los
## orquesta en el orden correcto cada physics frame y coordina las cancelaciones cruzadas.
## El salto, por ser trivial, vive aquí. (Swing de cadenas llega en batch 6.)

enum AirState { GROUNDED, AIRBORNE }

@export var tuning: PlayerTuning

var air_state := AirState.GROUNDED
var vertical_velocity := 0.0
var bump_velocity := Vector3.ZERO
var lock_on: Node3D = null  # LockOn (batch 6); los bloques lo tratan como opcional

var _can_double_jump := true
var _dodge_queued := false  # dodge pedido tarde en un golpe: sale al terminarlo
var _grounded_grace_until := 0.0

@onready var locomotion: PlayerLocomotion = $Locomotion
@onready var dash: PlayerDash = $Dash
@onready var launcher: PlayerLauncher = $Launcher
@onready var meter: PlayerMeter = $Meter
@onready var health: Health = $Health
@onready var player_health: PlayerHealth = $PlayerHealth
@onready var combat: PlayerCombat = $Combat
@onready var action_world_switch: ActionWorldSwitchModifier = $ActionWorldSwitchModifier

func _ready() -> void:
	add_to_group("player")  # la cámara y los enemigos me encuentran por grupo
	if tuning == null:
		tuning = PlayerTuning.new()
	collision_layer = World.LAYER_PLAYER
	collision_mask = World.LAYER_WORLD | World.LAYER_ENEMY
	player_health.setup(self)
	meter.setup(self)
	locomotion.setup(self, get_viewport().get_camera_3d())
	launcher.setup(self)
	dash.setup(self, locomotion, launcher.register_air_hit_stall, launcher.cancel)
	combat.setup(self)

func is_grounded() -> bool:
	return air_state == AirState.GROUNDED

func is_airborne() -> bool:
	return air_state == AirState.AIRBORNE

func forward() -> Vector3:
	return -global_basis.z

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_on_jump()
	elif event.is_action_pressed("dodge"):
		_on_dodge()

func _physics_process(delta: float) -> void:
	if launcher.is_launched:
		launcher.tick_launch(delta)  # el launcher controla el movimiento
		return

	# Dodge bufferizado (pedido pasado el umbral del golpe): sale apenas el golpe termina.
	if _dodge_queued and not dash.is_dashing and not locomotion.is_attacking():
		_dodge_queued = false
		dash.dodge()

	if dash.is_dashing:
		dash.tick(delta)
		_decay_bump(delta)
		return

	var horizontal := locomotion.tick(delta) + locomotion.lunge_velocity()

	vertical_velocity += tuning.gravity * launcher.gravity_scale() * delta

	velocity = horizontal + bump_velocity + Vector3(0.0, vertical_velocity, 0.0)
	move_and_slide()

	if is_on_floor():
		if air_state != AirState.GROUNDED:
			_grounded_grace_until = World.now() + tuning.landing_momentum_grace
		vertical_velocity = -1.0
		air_state = AirState.GROUNDED
		dash.restore_airdash()
		_can_double_jump = true
		launcher.reset_air_stall()
	else:
		air_state = AirState.AIRBORNE

	_decay_bump(delta)

func _on_jump() -> void:
	_dodge_queued = false  # saltar descarta un dodge bufferizado pendiente
	# (swing release / begin — batch 6)
	if is_on_floor():
		vertical_velocity = tuning.jump_force
		air_state = AirState.AIRBORNE
	elif _can_double_jump:
		_can_double_jump = false
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
	_can_double_jump = true

func restore_airdash() -> void:
	dash.restore_airdash()

func activate_action_world_switch() -> void:
	action_world_switch.activate()

func take_damage(amount: float) -> bool:
	return player_health.take_damage(amount)

func fire_action_world_switch() -> void:
	action_world_switch.fire_action()

func register_air_hit_stall() -> void:
	launcher.register_air_hit_stall()

func notify_aerial_attack(duration: float) -> void:
	launcher.notify_aerial_attack(duration)

func attack_step(duration: float) -> void:
	locomotion.attack_step(duration)

func hold_airborne_for_attack() -> void:
	if not is_on_floor():
		air_state = AirState.AIRBORNE

func bump(dir: Vector3, h_speed: float, v_speed: float) -> void:
	_dodge_queued = false
	launcher.cancel()
	dash.cancel()
	bump_velocity = Vector3(dir.x, 0.0, dir.z).normalized() * h_speed
	vertical_velocity = v_speed
	air_state = AirState.AIRBORNE

func force_dash(dir: Vector3, distance: float, duration: float, boost_bump_momentum := false) -> void:
	_dodge_queued = false
	dash.force_dash(dir, distance, duration, boost_bump_momentum)

func launch(height: float, hang_time: float, rise_time: float = World.LAUNCH_RISE_TIME) -> void:
	_dodge_queued = false
	dash.cancel()
	launcher.start_launch(height, hang_time, rise_time)

func _decay_bump(delta: float) -> void:
	if bump_velocity.length_squared() < 0.01:
		bump_velocity = Vector3.ZERO
		return
	var decay := tuning.bump_decay
	if is_on_floor():
		decay = 0.0 if World.now() < _grounded_grace_until else tuning.grounded_bump_decay
	bump_velocity = bump_velocity.move_toward(Vector3.ZERO, decay * delta)
