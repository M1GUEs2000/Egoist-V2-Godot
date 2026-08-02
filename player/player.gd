class_name Player extends CharacterBody3D
## GLUE (ex PlayerController.cs) + motor físico (ex PlayerMotor.cs): CharacterBody3D ES el
## motor, así que el estado compartido que todos los bloques tocan (velocidad vertical,
## bump/momentum, aire/suelo) vive aquí. No implementa comportamiento de bloques: los
## orquesta en el orden correcto cada physics frame y coordina las cancelaciones cruzadas.
## El salto, por ser trivial, vive aquí. (Swing de cadenas llega en batch 6.)

enum AirState { GROUNDED, AIRBORNE }
enum JumpControl { NONE, LOCKED, RELEASED }

signal double_jump_changed(available: bool)

@export var tuning: PlayerTuning

var air_state := AirState.GROUNDED
var vertical_velocity := 0.0
var bump_velocity := Vector3.ZERO
var poise := Poise.new()

var _can_double_jump := true
var _dodge_queued := false  # dodge pedido tarde en un golpe: sale al terminarlo
var _jump_control := JumpControl.NONE
var _jump_direction := Vector3.ZERO
var _jump_hold_time := 0.0
var _jump_hold_finished := false
var _jump_elapsed := 0.0
var _jump_gravity := 0.0
var _jump_apex_height := 0.0
var _jump_horizontal_velocity := Vector3.ZERO
var _spawn_transform := Transform3D.IDENTITY

@onready var locomotion: PlayerLocomotion = $Locomotion
@onready var sprint: PlayerSprint = $Sprint
@onready var dash: PlayerDash = $Dash
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
## Floater (primitiva vertical): politica de caida temporal. Se instancia por codigo en _ready, no
## es nodo de escena. Ver combat/floater.gd y obsidian/Plan Autoridad Vertical.
var floater: Floater
## Mover (primitiva vertical): recorrido por trayectoria. Se instancia por codigo en _ready.
## Ver combat/mover.gd.
var mover: Mover
@onready var _run_smoke: SmokeStylizedVFX = get_node_or_null("RunSmoke") as SmokeStylizedVFX
@onready var _sprint_trail: SprintTrail = get_node_or_null("SprintTrail") as SprintTrail
@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D

# Launch de bloque: mientras dura, el bloque es DUEÑO del arco. Impone su propia gravedad (igual
# que el salto impone la suya) para que distancia, altura y duración del inspector se cumplan
# exactas, y bloquea el stick por `_launch_lock_until` para que el input no estire el tramo.
var _launch_gravity := 0.0
var _launch_until := -999.0
var _launch_lock_until := -999.0

var _stun_material: StandardMaterial3D
var _stun_feedback_color := Color.WHITE
var _chip_material: StandardMaterial3D
var _chip_tween: Tween
var _combat_flash_meshes: Array[MeshInstance3D] = []
var _combat_flash_material: StandardMaterial3D
var _combat_flash_tween: Tween

func _ready() -> void:
	add_to_group("player")  # la cámara y los enemigos me encuentran por grupo
	# Cada escena define el spawn con el transform inicial de esta instancia.
	_spawn_transform = global_transform
	if tuning == null:
		tuning = PlayerTuning.new()
	collision_layer = World.LAYER_PLAYER
	collision_mask = World.LAYER_WORLD | World.LAYER_ENEMY
	setup_poise()
	player_health.setup(self)
	meter.setup(self)
	lock_on.setup(self, get_viewport().get_camera_3d())
	locomotion.setup(self, get_viewport().get_camera_3d())
	sprint.setup(self)
	_collect_combat_flash_meshes(get_node_or_null("Visual"))
	if _combat_flash_meshes.is_empty() and _mesh != null:
		_combat_flash_meshes.append(_mesh)
	wall_slide.setup(self)
	floor_slide.setup(self)
	enemy_bounce.setup(self)
	air_kill_reset.setup(self)
	floater = Floater.new()
	floater.name = "Floater"
	add_child(floater)
	floater.setup(self)
	mover = Mover.new()
	mover.name = "Mover"
	add_child(mover)
	mover.setup(self, floater)
	dash.setup(self, locomotion, _cancel_controlled_movement)
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

## Multiplicador del sprint para un canal (ver PlayerSprint). Único punto de acceso: los módulos
## de movimiento lo llaman sobre su propio valor de tuning en vez de leer el nivel a mano, y la
## guarda de null deja que un Player armado por código corra sin el nodo Sprint.
func sprint_scale(channel: StringName) -> float:
	return sprint.scale(channel) if sprint != null else 1.0

## Nivel crudo del sprint (0-1). Para escalar valores usar sprint_scale(); esto es para el feedback
## visual, que interpola contra el nivel y no contra el multiplicador de ningún canal.
func sprint_level() -> float:
	return sprint.level if sprint != null else 0.0

## Poise que inflige un parry del jugador ahora mismo (por arma y tipo de ataque). Lo consulta el
## enemigo parriado (EnemyBase.resolve_parry) por duck typing.
func current_parry_poise() -> float:
	return combat.current_parry_poise() if combat != null else 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_spawn"):
		return_to_spawn()
		return
	if is_stunned():
		return
	if event.is_action_pressed("jump"):
		_on_jump()
	elif event.is_action_pressed("dodge"):
		_on_dodge()
	elif event.is_action_pressed("wall_slide"):
		wall_slide.request_slide()
	elif event.is_action_pressed("lock_on"):
		lock_on.toggle_lock()
	elif lock_on.is_locked and event.is_action_pressed("camera_left"):
		lock_on.cycle_target(-1)
	elif lock_on.is_locked and event.is_action_pressed("camera_right"):
		lock_on.cycle_target(1)

## Regreso de depuración al punto donde esta instancia apareció en la escena actual.
func return_to_spawn() -> void:
	_dodge_queued = false
	stun.cancel()
	dash.cancel()
	wall_slide.cancel()
	floor_slide.cancel()
	enemy_bounce.cancel()
	mover.cancel_mover(Mover.CancelReason.SUPERSEDED)
	floater.cancel_float()
	_cancel_jump_impulse()
	_cancel_launch_arc()
	locomotion.cancel_lunge()
	combat.cancel_input()
	bump_velocity = Vector3.ZERO
	vertical_velocity = 0.0
	velocity = Vector3.ZERO
	global_transform = _spawn_transform

func _physics_process(delta: float) -> void:
	stun.tick()
	if is_stunned():
		_stop_movement_fx()
		_tick_stunned(delta)
		return

	# El nivel de sprint se actualiza antes que cualquier consumidor, y sigue corriendo durante
	# dash/mover: cortarlo ahí haría que un dodge a mitad de carrera reiniciara la carga.
	sprint.tick(delta)

	if mover.is_moving() and mover.is_total():
		_stop_movement_fx()
		wall_slide.cancel()
		floor_slide.cancel()
		enemy_bounce.cancel()
		mover.tick(delta)
		return

	# Dodge bufferizado (pedido pasado el umbral del golpe): sale apenas el golpe termina.
	if _dodge_queued and not dash.is_dashing and not locomotion.is_attacking():
		_dodge_queued = false
		dash.dodge()

	if dash.is_dashing:
		_stop_movement_fx()
		wall_slide.cancel()
		floor_slide.cancel()
		enemy_bounce.cancel()
		dash.tick(delta)
		_bleed_momentum(delta)
		return

	var input_dir := locomotion.camera_relative(locomotion.read_move_input())
	var jump_locked := _tick_jump_impulse(delta)
	var horizontal := Vector3.ZERO
	if jump_locked:
		horizontal = _jump_horizontal_velocity
	else:
		var air_control_scale := tuning.jump_post_release_air_control_scale \
				if _jump_control == JumpControl.RELEASED else 1.0
		var air_idle_velocity := _jump_horizontal_velocity \
				if _jump_control == JumpControl.RELEASED else Vector3.ZERO
		horizontal = locomotion.tick(delta, air_control_scale, air_idle_velocity) \
				+ locomotion.lunge_velocity()
	if wall_slide.blocks_move_input() or enemy_bounce.blocks_move_input() \
			or launch_blocks_move_input():
		horizontal = Vector3.ZERO
		# El impulso del wall jump/rebote vive en bump_velocity: la inercia aérea del input
		# se borra para que al soltarse el lock no reaparezca el rumbo previo al salto.
		locomotion.set_air_velocity(Vector3.ZERO)

	# Politica vertical de los ataques: UNA sola, el Floater. Sostiene el hang del sweet spot, el
	# air-hit-stall del combo aereo y el freeze del Brazo — los tres son lo mismo (una ventana con
	# su escala de caida), asi que ninguno tiene sistema propio.
	if floater.is_floating():
		vertical_velocity = floater.apply_fall(vertical_velocity, _active_gravity(), delta)
	else:
		vertical_velocity += _active_gravity() * delta
	if mover.is_partial():
		vertical_velocity = mover.apply_partial_vertical(delta, vertical_velocity)

	var horizontal_with_momentum := wall_slide.apply_slide_velocity(horizontal + bump_velocity, input_dir, delta)
	horizontal_with_momentum = floor_slide.apply_slide_velocity(horizontal_with_momentum, input_dir, delta)
	var unstack := World.character_unstack_velocity(self, World.CHARACTER_UNSTACK_SPEED)
	velocity = horizontal_with_momentum + unstack + Vector3(0.0, vertical_velocity, 0.0)
	var before_move := global_position
	move_and_slide()
	mover.finish_partial_vertical(before_move)
	wall_slide.update_after_move(horizontal + bump_velocity, input_dir)
	floor_slide.update_after_move(horizontal + bump_velocity, input_dir)

	if World.on_solid_floor(self):
		vertical_velocity = -1.0
		air_state = AirState.GROUNDED
		dash.restore_airdash()
		_set_double_jump_available(true)
		floater.cancel_float()  # aterrizar corta el hang del Floater igual que el air stall viejo
		wall_slide.cancel()
		_cancel_jump_impulse()  # corta también el arco del bloque: aterrizar lo termina
	else:
		air_state = AirState.AIRBORNE

	# Humo al correr: solo en el suelo y por encima del umbral de velocidad horizontal.
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	_set_run_smoke(World.on_solid_floor(self) and planar_speed >= tuning.run_dust_min_speed)
	_set_sprint_trail()

	_bleed_momentum(delta)

func _on_jump() -> void:
	_dodge_queued = false  # saltar descarta un dodge bufferizado pendiente
	# (swing release / begin — batch 6)
	if World.on_solid_floor(self):
		# Saltar desde un floor slide conserva jump_momentum_keep del slide como momentum aereo.
		if floor_slide.is_sliding:
			floor_slide.launch_into_jump()
		_start_jump_impulse(_jump_direction_from_input())
		air_state = AirState.AIRBORNE
	elif wall_slide.try_wall_jump(locomotion.camera_relative(locomotion.read_move_input())):
		# Contra una pared el salto SIEMPRE es rebote hacia afuera (aunque el slide se
		# haya cortado este frame): no consume ni recarga el doble salto.
		_cancel_jump_impulse()
		floater.cancel_float()  # el rebote impone su propia vertical: el hang la re-pisaria a 0
		air_state = AirState.AIRBORNE
	elif enemy_bounce.try_bounce(locomotion.camera_relative(locomotion.read_move_input())):
		_cancel_jump_impulse()
		mover.cancel_mover(Mover.CancelReason.ATTACK_RULE)
		floater.cancel_float()  # el rebote impone su propia vertical: el hang la re-pisaria a 0
		air_state = AirState.AIRBORNE
	elif _can_double_jump and not mover.blocks_jump():
		_set_double_jump_available(false)
		_start_jump_impulse(_jump_direction_from_input())
		air_state = AirState.AIRBORNE
		_burst_double_jump()

## Salto base y doble salto comparten una parabola dirigida definida por altura, distancia y
## duracion. La fuerza vertical y la gravedad se calculan: no son knobs de tuning.
func _start_jump_impulse(direction: Vector3) -> void:
	# Todo salto propulsado arranca con gravedad normal: si un Floater siguiera activo su fall_scale
	# escalaria la subida (o con 0.0 la anularia pisando vertical_velocity a 0), asi que el hang muere
	# al saltar. Vale para el salto de piso y el doble salto (ambos entran por aca).
	floater.cancel_float()
	_cancel_launch_arc()  # saltar es una salida del arco: le devuelve la vertical al player
	_jump_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	_jump_control = JumpControl.LOCKED
	_jump_hold_time = 0.0
	_jump_hold_finished = false
	_jump_elapsed = 0.0
	var duration := maxf(0.001, tuning.jump_duration)
	_jump_apex_height = 0.0
	vertical_velocity = 0.0
	_refresh_jump_vertical_trajectory()
	_refresh_jump_horizontal_velocity()
	locomotion.set_air_velocity(Vector3.ZERO)

## Estela verde a los pies al gastar el doble salto (mismo verde de traversal que el
## bloque/dodge). World.spawn_trail_burst emite motas continuamente en los pies del jugador
## mientras dura, y las deja atras en el mundo (no pegadas) para que se vean como una estela
## que lo sigue, cada una desvaneciendose sola.
func _burst_double_jump() -> void:
	if not tuning.double_jump_burst_enabled:
		return
	World.spawn_trail_burst(self, Vector3(0.0, 0.1, 0.0),
			World.COLOR_TRAVERSAL_DASH, World.COLOR_TRAVERSAL_DASH_EMISSION,
			tuning.double_jump_burst_amount, tuning.double_jump_burst_speed,
			tuning.double_jump_burst_gravity, tuning.double_jump_burst_lifetime,
			tuning.double_jump_burst_size)

func _jump_direction_from_input() -> Vector3:
	var input := locomotion.read_move_input()
	var camera_dir := locomotion.camera_relative(input)
	return locomotion.movement_direction(input, camera_dir)

func _tick_jump_impulse(delta: float) -> bool:
	if _jump_control == JumpControl.NONE:
		return false
	if not _jump_hold_finished:
		if Input.is_action_pressed("jump"):
			_jump_hold_time += delta
		else:
			_jump_hold_finished = true
	_jump_elapsed += delta
	_refresh_jump_vertical_trajectory()
	_refresh_jump_horizontal_velocity()
	if _jump_control == JumpControl.RELEASED:
		return false
	var release_ratio := clampf(tuning.jump_control_release_percent / 100.0, 0.0, 1.0)
	if _jump_elapsed / maxf(0.001, tuning.jump_duration) >= release_ratio:
		_jump_control = JumpControl.RELEASED
		locomotion.set_air_velocity(_jump_horizontal_velocity)
		return false
	return true

func _refresh_jump_horizontal_velocity() -> void:
	var base_speed := _jump_launch_vertical_speed() * tuning.jump_forward_impulse_ratio
	_jump_horizontal_velocity = _jump_direction * base_speed * _jump_apex_speed_multiplier() \
			* sprint_scale(PlayerSprint.JUMP_FORWARD)

## El hold cambia solo la altura. Cada incremento agrega la parte vertical que falta y actualiza
## la gravedad del arco; la velocidad horizontal nunca depende del boton de salto.
func _refresh_jump_vertical_trajectory() -> void:
	var hold_ratio := 1.0 if tuning.jump_hold_time <= 0.0 else clampf(
			_jump_hold_time / tuning.jump_hold_time, 0.0, 1.0)
	# El sprint escala la altura de cúspide, no la duración: el arco sube más en el mismo tiempo
	# (la gravedad del salto se recalcula abajo a partir de esta altura, así que sigue cerrando).
	var target_height := lerpf(tuning.jump_min_apex_height, tuning.jump_max_apex_height, hold_ratio) \
			* sprint_scale(PlayerSprint.JUMP_HEIGHT)
	var duration := maxf(0.001, tuning.jump_duration)
	vertical_velocity += 4.0 * (target_height - _jump_apex_height) / duration
	_jump_apex_height = target_height
	_jump_gravity = -8.0 * target_height / (duration * duration)

func _jump_launch_vertical_speed() -> float:
	return 4.0 * _jump_apex_height / maxf(0.001, tuning.jump_duration)

## Curva cosenoidal centrada en la cuspide: frena sin esquinas y compensa antes/despues para
## que el area bajo la velocidad siga siendo uno; sin input, distancia y duracion no cambian.
func _jump_apex_speed_multiplier() -> float:
	var half_window := clampf(tuning.jump_apex_slowdown_window_percent / 200.0, 0.0, 0.5)
	if half_window <= 0.0:
		return 1.0
	var normalized_time := clampf(_jump_elapsed / maxf(0.001, tuning.jump_duration), 0.0, 1.0)
	var distance_from_apex := absf(normalized_time - 0.5)
	var shape := 0.0
	if distance_from_apex < half_window:
		var phase := distance_from_apex / half_window
		shape = 0.5 + 0.5 * cos(PI * phase)
	var strength := clampf(tuning.jump_apex_slowdown_strength, 0.0, 1.0)
	var average_multiplier := 1.0 - strength * half_window
	return (1.0 - strength * shape) / maxf(0.001, average_multiplier)

## Un salto en curso gana sobre el arco del bloque (saltar cancela el launch, es una de las salidas
## que el jugador tiene), y el arco gana sobre la gravedad normal mientras dure.
func _active_gravity() -> float:
	if _jump_control != JumpControl.NONE:
		return _jump_gravity
	if World.now() < _launch_until and _launch_gravity < 0.0:
		return _launch_gravity
	return tuning.gravity

## Suelta la autoridad vertical del player. Cancela también el arco de un launch de bloque: salto y
## arco son la MISMA autoridad (los dos imponen su gravedad), así que todo lo que corta uno corta el
## otro — aterrizar, ser golpeado, dashear, un Mover o un bump nuevo. Unificarlo acá evita tener que
## acordarse de cancelar el arco en cada uno de esos puntos por separado.
func _cancel_jump_impulse() -> void:
	_cancel_launch_arc()
	_jump_control = JumpControl.NONE
	_jump_direction = Vector3.ZERO
	_jump_hold_time = 0.0
	_jump_hold_finished = false
	_jump_elapsed = 0.0
	_jump_gravity = 0.0
	_jump_apex_height = 0.0
	_jump_horizontal_velocity = Vector3.ZERO

func _on_dodge() -> void:
	# Golpe casi completo (pasado el umbral): no lo cortamos, se buferea y sale al terminar.
	# Golpe temprano o sin golpe: dashea ya (cancela el ataque).
	if locomotion.is_attacking() and locomotion.attack_progress() >= tuning.dodge_cancel_attack_threshold:
		_dodge_queued = true
		return
	_dodge_queued = false
	combat.cancel_attack_routines()
	mover.cancel_mover(Mover.CancelReason.ATTACK_RULE)
	dash.dodge()

# ---- API pública (armas, pickups, combate, traversal) ----

func restore_double_jump() -> void:
	_set_double_jump_available(true)

func has_double_jump() -> bool:
	return _can_double_jump

func restore_airdash() -> void:
	dash.restore_airdash()

## Empezar una carga en el aire cuelga al jugador con un Floater, igual que cualquier otro ataque
## que sostiene. Antes era un freno de caida propio con desgaste por uso (air_charge_fall_control);
## ahora es el mismo primitivo que todo lo demas y sin escalado.
func apply_air_charge_float() -> void:
	if is_on_floor():
		return
	var f := tuning.air_charge_floater
	if f != null:
		floater.start_float(f.duration, f.fall_scale)

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
	mover.cancel_mover(Mover.CancelReason.STUN)  # el stun corta un launch en curso
	floater.cancel_float()  # el stun corta cualquier hang del Floater
	dash.cancel()
	_cancel_jump_impulse()
	sprint.cancel()  # comerse un golpe apaga la carrera: el sprint se vuelve a ganar corriendo
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

## Golpe aereo del Brazo. VERTICAL: un Floater por `duration` seg con `fall_scale` propio (el ataque
## trae ambos en su FloaterSettings) — el mismo primitivo que el resto de los ataques, sin sistema
## propio. A diferencia del freeze viejo que reemplaza, al terminar la ventana la caida arranca de 0
## en vez de retomar la velocidad previa. HORIZONTAL: decelera el momentum (bump) por `horizontal_keep`
## (0-1) en el acto; no es una pausa, es un freno que decrece con cada golpe, y por eso no es del Floater.
func register_arm_air_hit(duration: float, fall_scale: float, horizontal_keep: float) -> void:
	if is_on_floor():
		return
	bump_velocity *= clampf(horizontal_keep, 0.0, 1.0)
	floater.start_float(duration, fall_scale)

## Pide un Floater para el propio jugador (lo usa un ataque que quiere colgarlo en el aire). En el
## aire TOMA la autoridad vertical: cancela el salto en curso —suba o caiga— y snapea la vertical a 0
## para que el hang se lea como una pausa real. Es la contraparte simetrica de saltar, que a su vez
## cancela el Floater (ver _start_jump_impulse): salto y hang nunca coexisten, gana el ultimo pedido.
## No actúa en piso. `fall_scale` 0 = hold total; 0.15 = deriva lenta (como el air stall). No gasta el
## doble salto: la ventana existe para que el jugador lo use. La duración y el fall_scale los define el
## ataque (por arma/ataque, en su tuning). Ver combat/floater.gd.
func request_float(duration: float, fall_scale: float) -> void:
	# El dash es dueño de su propia vertical mientras corre (el glue hace return temprano y dash.tick
	# pisa velocity). Un float pedido durante el dash arrancaria un hang fantasma que deja al jugador
	# flotando a ras de piso con is_on_floor() en false (el bloque de piso nunca lo re-asienta ni le
	# devuelve el doble salto), y el impacto del cargado borraria un salto recien buffereado. El dash
	# termina y recien ahi el jugador vuelve a aceptar floats.
	if is_on_floor() or dash.is_dashing:
		return
	_cancel_jump_impulse()  # el golpe mata el salto en curso: la vertical pasa entera al Floater
	vertical_velocity = 0.0
	air_state = AirState.AIRBORNE
	floater.start_float(duration, fall_scale)

## Ejecuta un recorrido vertical ya decidido por un ataque. El Player solo prepara su estado fisico
## y entrega el perfil al Mover: distancia, velocidad, contactos y Float final viven en el arma.
func request_mover(settings: MoverSettings) -> void:
	if settings == null:
		return
	_dodge_queued = false
	if settings.mode == MoverSettings.Mode.TOTAL:
		wall_slide.cancel()
		floor_slide.cancel()
		enemy_bounce.cancel()
	stun.cancel()
	dash.cancel()
	floater.cancel_float()
	_cancel_jump_impulse()
	air_state = AirState.AIRBORNE
	vertical_velocity = 0.0
	mover.start_mover(settings)

func attack_step(duration: float) -> void:
	locomotion.attack_step(duration)

func hold_airborne_for_attack() -> void:
	if not is_on_floor():
		air_state = AirState.AIRBORNE

## Techo del momentum. `sprint_scaled` decide QUIÉN es dueño de la velocidad resultante:
## - false (default): la fuente es EXTERNA y manda ella — bloque de launch, knockback, spike wall.
##   Capea contra el techo base para que el impulso sea el mismo se venga corriendo o sprinteando:
##   un bloque que promete una distancia tiene que cumplirla siempre. (Los bloques suelen pedir MÁS
##   de lo que el techo permite, así que este recorte no es un detalle: ES la distancia que entregan.)
## - true: la velocidad la generó el propio jugador con su movimiento (wall jump, Wall Impulse), y
##   ahí el sprint sí tiene que poder empujar el techo o el recorte se come el bono en las cadenas.
func _momentum_max_speed(sprint_scaled: bool) -> float:
	if not sprint_scaled:
		return tuning.momentum_max_speed
	return tuning.momentum_max_speed * sprint_scale(PlayerSprint.MOMENTUM_MAX)

func add_momentum(v: Vector3, sprint_scaled := false) -> void:
	bump_velocity = (bump_velocity + v).limit_length(_momentum_max_speed(sprint_scaled))

func set_momentum(v: Vector3, sprint_scaled := false) -> void:
	bump_velocity = v.limit_length(_momentum_max_speed(sprint_scaled))

## Launch de un bloque: el bloque manda el arco completo. A diferencia de `bump`, trae su propia
## gravedad (derivada de altura + duración, igual que el salto del player) y un lock que apaga el
## stick, así la distancia que promete el inspector es la que se recorre. Salto y dash lo cancelan:
## el lock solo apaga el movimiento, no las acciones.
func launch_arc(dir: Vector3, h_speed: float, v_speed: float, arc_gravity: float,
		lock_time: float) -> void:
	bump(dir, h_speed, v_speed)
	if arc_gravity >= 0.0:
		return
	_launch_gravity = arc_gravity
	# La gravedad propia dura todo el vuelo; el lock del stick, solo el tramo pedido.
	_launch_until = World.now() + maxf(0.0, lock_time) + _launch_air_time(v_speed, arc_gravity)
	_launch_lock_until = World.now() + maxf(0.0, lock_time)

## Segundos hasta que el arco vuelve a la altura de salida, con la gravedad del propio launch.
func _launch_air_time(v_speed: float, arc_gravity: float) -> float:
	return 2.0 * v_speed / -arc_gravity if arc_gravity < 0.0 else 0.0

## El launch bloquea SOLO el input de movimiento (mismo criterio que el wall jump). Saltar o
## dashear siguen disponibles y cancelan el arco por su cuenta.
func launch_blocks_move_input() -> bool:
	return World.now() < _launch_lock_until and not is_on_floor()

func _cancel_launch_arc() -> void:
	_launch_gravity = 0.0
	_launch_until = -999.0
	_launch_lock_until = -999.0

func bump(dir: Vector3, h_speed: float, v_speed: float) -> void:
	_dodge_queued = false
	wall_slide.cancel()
	floor_slide.cancel()
	enemy_bounce.cancel()
	mover.cancel_mover(Mover.CancelReason.SUPERSEDED)  # un bump corta un launch en curso
	floater.cancel_float()  # un bump (knockback/rebote) corta el hang del Floater
	dash.cancel()
	_cancel_jump_impulse()
	# La fuente PISA tu momentum, no se le suma: un bloque que promete una distancia tiene que
	# entregarla igual vengas parado, corriendo o encadenando paredes. (Antes sumaba, y por eso la
	# distancia real dependía de con cuánto llegabas y del recorte del techo global.)
	var horizontal := Vector3(dir.x, 0.0, dir.z)
	if horizontal.length_squared() > 0.0001:
		set_momentum(horizontal.normalized() * h_speed)
	else:
		bump_velocity = Vector3.ZERO
	vertical_velocity = v_speed
	air_state = AirState.AIRBORNE

func force_dash(dir: Vector3, distance: float, duration: float, boost_bump_momentum := false,
		deals_damage := false) -> void:
	_dodge_queued = false
	mover.cancel_mover(Mover.CancelReason.SUPERSEDED)
	wall_slide.cancel()
	floor_slide.cancel()
	enemy_bounce.cancel()
	dash.force_dash(dir, distance, duration, boost_bump_momentum, deals_damage)

## Programa un impulso que PlayerDash aplica solo al terminar naturalmente el dash actual.
func set_dash_exit_bop(dir: Vector3, forward_speed: float, vertical_speed: float) -> void:
	dash.set_exit_bop(dir, forward_speed, vertical_speed)

## Cualquier movimiento dirigido por locomocion cancela el control vertical de combate en curso.
func _cancel_controlled_movement() -> void:
	mover.cancel_mover(Mover.CancelReason.SUPERSEDED)
	floater.cancel_float()
	_cancel_jump_impulse()

func _tick_stunned(delta: float) -> void:
	wall_slide.cancel()
	floor_slide.cancel()
	enemy_bounce.cancel()
	locomotion.set_air_velocity(Vector3.ZERO)  # el golpe pisa la inercia del input; el knockback vive en bump
	vertical_velocity += tuning.gravity * tuning.stun_gravity_scale * delta
	# Aunque esté stuneado, un cuerpo apilado sobre otro debe despegarse (el stun no lo debe dejar
	# clavado en la cabeza del otro): el knockback vive en bump, el desapilado se suma aparte.
	var unstack := World.character_unstack_velocity(self, World.CHARACTER_UNSTACK_SPEED)
	velocity = bump_velocity + unstack + Vector3(0.0, vertical_velocity, 0.0)
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

func _set_run_smoke(active: bool) -> void:
	if _run_smoke == null:
		return
	if active:
		# Igual que PushSmoke: el look se aplica antes de reiniciar y las nubes se emiten en mundo.
		# SmokeStylizedVFX duplica el material por instancia, asi otro player no recibe este tinte.
		_run_smoke.tint_color = Color.WHITE.lerp(_run_smoke_sprint_color(), sprint_level())
		if not _run_smoke.emitting:
			_run_smoke.restart()
			_run_smoke.emitting = true
	elif _run_smoke.emitting:
		# Cortar emision deja que las nubes vivas terminen su lifetime y dissolve, como el push.
		_run_smoke.emitting = false

## Color del humo a sprint pleno, ya empujado a HDR. Multiplica solo el RGB: subir también el alpha
## saturaría la transparencia y se perdería el dissolve del emisor.
func _run_smoke_sprint_color() -> Color:
	var c := tuning.run_dust_sprint_color
	var boost := tuning.run_dust_sprint_emission_energy
	return Color(c.r * boost, c.g * boost, c.b * boost, c.a)

## Corta los FX de movimiento de una. Lo usan los cortes tempranos del frame (stun, Mover total,
## dash): ahí el player no se mueve por locomoción y el cálculo normal de la estela nunca llega a
## correr, así que sin esto quedaría emitiendo colgada.
func _stop_movement_fx() -> void:
	_set_run_smoke(false)
	if _sprint_trail != null:
		_sprint_trail.stop()

## Cinta del sprint: dos markers laterales del Player se muestrean en mundo y dibujan el recorrido
## real como una tira continua. No pide suelo: también acompaña saltos y cadenas de paredes.
func _set_sprint_trail() -> void:
	if _sprint_trail == null:
		return
	var level := sprint_level()
	var active := level >= tuning.sprint_trail_min_level
	if active:
		# El color arranca en el umbral y sube hasta sprint pleno, así la cinta nace tenue.
		var ramp := inverse_lerp(tuning.sprint_trail_min_level, 1.0, level)
		_sprint_trail.set_tint(_sprint_trail_color(clampf(ramp, 0.0, 1.0)))
		if not _sprint_trail.is_emitting():
			_sprint_trail.emit()
	elif _sprint_trail.is_emitting():
		_sprint_trail.stop()

## Color de la estela a una fracción dada, empujado a HDR igual que el polvo: el emisor es unshaded,
## así que el brillo sale de pasar el RGB de 1.0 para que lo agarre el glow. Solo escala el RGB para
## no romper el fade de alpha del color_ramp.
func _sprint_trail_color(ramp: float) -> Color:
	var c := tuning.sprint_trail_color
	var boost := lerpf(1.0, tuning.sprint_trail_emission_energy, ramp)
	return Color(c.r * boost, c.g * boost, c.b * boost, c.a)

func _set_double_jump_available(available: bool) -> void:
	if _can_double_jump == available:
		return
	_can_double_jump = available
	double_jump_changed.emit(_can_double_jump)

## Carga el medidor de poise desde el tuning. Publico: cambiar el .tres en caliente
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

## Igual que el wall slide, el flash recorre las mallas reales bajo Visual. El nodo Mesh es solo
## la capsula placeholder y queda invisible cuando el modelo esta activo.
func _collect_combat_flash_meshes(root: Node) -> void:
	if root == null:
		return
	var mesh := root as MeshInstance3D
	if mesh != null:
		_combat_flash_meshes.append(mesh)
	for child in root.get_children():
		_collect_combat_flash_meshes(child)

## Fogonazo aditivo de un ataque que gasto meter. Usa el mismo material_overlay HDR del wall slide:
## conserva el material original del personaje y multiplica el RGB para que el Environment haga bloom.
func play_combat_flash(color: Color, energy: float, duration: float) -> void:
	if _combat_flash_meshes.is_empty() or is_stunned() or duration <= 0.0:
		return
	if _combat_flash_tween != null and _combat_flash_tween.is_valid():
		_combat_flash_tween.kill()
	if _combat_flash_material == null:
		_combat_flash_material = StandardMaterial3D.new()
		_combat_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_combat_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_combat_flash_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_combat_flash_material.albedo_color = Color(color.r * energy, color.g * energy,
			color.b * energy, color.a)
	for mesh in _combat_flash_meshes:
		mesh.material_overlay = _combat_flash_material
	_combat_flash_tween = create_tween()
	_combat_flash_tween.tween_property(_combat_flash_material, "albedo_color:a", 0.0, duration)
	_combat_flash_tween.tween_callback(_clear_combat_flash)

func _clear_combat_flash() -> void:
	for mesh in _combat_flash_meshes:
		if mesh.material_overlay == _combat_flash_material:
			mesh.material_overlay = null

func _on_stunned_started(_duration: float, _mode: PlayerStun.Mode) -> void:
	if _mesh == null:
		return
	if _combat_flash_tween != null and _combat_flash_tween.is_valid():
		_combat_flash_tween.kill()
	_clear_combat_flash()
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
