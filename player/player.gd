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
## Air-hit-stall + whiff del combo aereo (ex PlayerLauncher, que ya no lanzaba nada). El hang lo
## sostiene el Floater; aca queda solo la contabilidad del combo (para escalar la duracion de ese
## Floater) y la ventana de whiff: atacar en el aire SIN conectar agrava la caida hasta este instante.
var _aerial_attack_until := 0.0
var _air_stall_count := 0
var _last_air_stall_time := -999.0

@onready var locomotion: PlayerLocomotion = $Locomotion
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
## Mover (primitiva vertical): recorrido por trayectoria; hoy lleva el launcher ascendente (antes
## PlayerLauncher.start_launch/tick_launch). Se instancia por codigo en _ready. Ver combat/mover.gd.
var mover: Mover
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
	mover.mover_finished.connect(_on_launch_mover_ended)
	mover.mover_cancelled.connect(_on_launch_mover_ended)
	dash.setup(self, locomotion, register_air_hit_stall, cancel_launch)
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

	# Mover EXCLUSIVO: se adueña del frame entero (launcher ascendente, dash cargado). El
	# no-exclusivo (plunge) NO retorna acá: cae por el camino normal y solo aporta su eje vertical.
	if mover.is_moving() and mover.is_exclusive():
		_set_run_dust(false)
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

	# Politica vertical, en orden de prioridad: (1) un Mover NO-EXCLUSIVO manda su eje —hoy el plunge,
	# caida recta constante que pisa gravedad/floater pero deja vivo el resto del cuerpo—; (2) el
	# Floater sostiene el hang (sweet spot, air-hit-stall del combo aereo, freeze del Brazo: los tres
	# son lo mismo, una ventana con su escala de caida); (3) gravedad, agravada por el whiff.
	if mover.is_moving():
		vertical_velocity = mover.non_exclusive_tick(delta)
	elif floater.is_floating():
		vertical_velocity = floater.apply_fall(vertical_velocity, tuning.gravity, delta)
	else:
		# Whiff del combo aereo (ex PlayerLauncher.gravity_scale): atacar en el aire SIN conectar
		# agrava la caida. Conectando, el hang lo sostiene el Floater de la rama de arriba.
		var whiff_scale := tuning.aerial_whiff_fall_gravity if World.now() < _aerial_attack_until else 1.0
		vertical_velocity += tuning.gravity * whiff_scale * delta

	var horizontal_with_momentum := wall_slide.apply_slide_velocity(horizontal + bump_velocity, input_dir, delta)
	horizontal_with_momentum = floor_slide.apply_slide_velocity(horizontal_with_momentum, input_dir, delta)
	velocity = horizontal_with_momentum + Vector3(0.0, vertical_velocity, 0.0)
	move_and_slide()
	wall_slide.update_after_move(horizontal + bump_velocity, input_dir)
	floor_slide.update_after_move(horizontal + bump_velocity, input_dir)
	enemy_bounce.update_after_move(horizontal + bump_velocity)
	# Plunge no-exclusivo: recién ahora (tras el move) se sabe si tocó piso/pared o gastó la distancia.
	if mover.is_moving():
		mover.non_exclusive_after_move()

	if is_on_floor():
		vertical_velocity = -1.0
		air_state = AirState.GROUNDED
		dash.restore_airdash()
		_set_double_jump_available(true)
		_reset_air_stall()
		floater.cancel_float()  # aterrizar corta el hang del Floater igual que el air stall viejo
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
		cancel_plunge()  # el rebote en enemigo ES la cancelación del plunge
		air_state = AirState.AIRBORNE
	elif _can_double_jump and not is_plunging():
		_set_double_jump_available(false)
		# El doble salto sale SIEMPRE con gravedad normal: cierra la ventana de caida lenta
		# (air-hit-stall y hover de un move) antes de aplicar second_jump_force. Sin esto, saltar dentro
		# de esa ventana subia con air_stall_float_gravity (0.1 = -4 m/s^2 contra -40) y el mismo
		# second_jump_force llegaba diez veces mas alto. air_stall_max_rise no alcanzaba: capea la
		# velocidad al REGISTRAR el stall, no la de un salto posterior.
		_reset_air_stall()
		floater.cancel_float()  # el doble salto sale con gravedad normal: cierra el hang del Floater
		vertical_velocity = tuning.second_jump_force
		air_state = AirState.AIRBORNE

func _on_dodge() -> void:
	# Golpe casi completo (pasado el umbral): no lo cortamos, se buferea y sale al terminar.
	# Golpe temprano o sin golpe: dashea ya (cancela el ataque).
	if locomotion.is_attacking() and locomotion.attack_progress() >= tuning.dodge_cancel_attack_threshold:
		_dodge_queued = true
		return
	_dodge_queued = false
	cancel_plunge()
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
	floater.start_float(tuning.air_charge_float_duration, tuning.air_charge_float_fall_scale)

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
	cancel_plunge()
	locomotion.cancel_lunge()
	wall_slide.cancel()
	floor_slide.cancel()
	enemy_bounce.cancel()
	_reset_air_stall()
	mover.cancel_mover(Mover.CancelReason.STUN)  # el stun corta un launch en curso
	floater.cancel_float()  # el stun corta cualquier hang del Floater
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

## Golpe aereo conectado (ex PlayerLauncher): sostiene la caida con un Floater cuya duracion escala
## con el combo, y (si el golpe no es cargado) come el momentum horizontal para anclar al jugador.
## `cuts_momentum` false = cargado: frena la caida como cualquiera, pero dueña su desplazamiento.
func register_air_hit_stall(scale := 1.0, cuts_momentum := true) -> void:
	if is_on_floor():
		return
	# Corte de momentum horizontal (contraparte del hang vertical): el golpe come momentum en las dos
	# fuentes (inercia del input y bump), asi conectar en el aire ancla al jugador en vez de dejarlo
	# viajando. Es horizontal, por eso no es asunto del Floater.
	if cuts_momentum:
		var keep := clampf(tuning.air_stall_momentum_keep, 0.0, 1.0)
		bump_velocity *= keep
		locomotion.scale_air_velocity(keep)
	if World.now() - _last_air_stall_time > tuning.air_stall_combo_window:
		_air_stall_count = 0
	_air_stall_count += 1
	_last_air_stall_time = World.now()
	var duration := minf(tuning.air_stall_base + tuning.air_stall_per_hit * (_air_stall_count - 1),
			tuning.air_stall_max) * scale
	# El hang lo sostiene el Floater (F3): misma duracion escalada por combo, misma escala de caida.
	floater.start_float(duration, tuning.air_stall_float_gravity)
	# Congela la caida pero preserva una subida chica (ej. el hop del primer spin de la rama espera);
	# el cap evita amplificar un salto reciente con la gravedad baja del stall.
	vertical_velocity = clampf(vertical_velocity, 0.0, tuning.air_stall_max_rise)
	air_state = AirState.AIRBORNE

## Golpe aereo del Brazo. VERTICAL: un Floater de hold total (`fall_scale` 0) por `duration` seg —
## el mismo primitivo que el resto de los ataques, sin sistema propio. A diferencia del freeze viejo
## que reemplaza, al terminar la ventana la caida arranca de 0 en vez de retomar la velocidad previa.
## HORIZONTAL: decelera el momentum (bump) por `horizontal_keep` (0-1) en el acto; no es una pausa,
## es un freno que decrece con cada golpe, y por eso no es asunto del Floater.
func register_arm_air_hit(duration: float, horizontal_keep: float) -> void:
	if is_on_floor():
		return
	bump_velocity *= clampf(horizontal_keep, 0.0, 1.0)
	floater.start_float(duration, 0.0)

## El arma avisa que hay un golpe aereo en curso (ex PlayerLauncher): si NO conecta, la caida se
## agrava (whiff) hasta que venza la ventana. Si conecta, el hitbox llama register_air_hit_stall y el
## Floater gana prioridad sobre esta agravante.
func notify_aerial_attack(duration: float) -> void:
	if is_on_floor():
		return
	_aerial_attack_until = maxf(_aerial_attack_until, World.now() + duration)

## Cierra la ventana de whiff y el contador del air-hit-stall (ex PlayerLauncher.reset_air_stall/
## cancel). El hang en si ya lo apaga el Floater en los mismos puntos (piso, doble salto, stun, bump).
func _reset_air_stall() -> void:
	_aerial_attack_until = 0.0
	_air_stall_count = 0

## Pide un Floater para el propio jugador (lo usa un ataque que quiere colgarlo en el aire). Frena
## la caída como el viejo hover: no actúa en piso ni pisa una subida, y snapea la vertical a 0 para
## que el hang se lea como una pausa real. `fall_scale` 0 = hold total; 0.15 = deriva lenta (como el
## air stall). No gasta el doble salto: la ventana existe para que el jugador lo use. La duración y el
## fall_scale los define el ataque (por arma/ataque, en su tuning). Ver combat/floater.gd.
func request_float(duration: float, fall_scale: float) -> void:
	if is_on_floor() or vertical_velocity > 0.0:
		return
	vertical_velocity = 0.0
	air_state = AirState.AIRBORNE
	floater.start_float(duration, fall_scale)

func attack_step(duration: float) -> void:
	locomotion.attack_step(duration)

func hold_airborne_for_attack() -> void:
	if not is_on_floor():
		air_state = AirState.AIRBORNE

## Plunge REUTILIZABLE (hoy lo usa el finisher aéreo X X espera X de la Espada): clava la caída con el
## perfil `settings` (un Mover DOWN NO-EXCLUSIVO: cae recto pero deja vivo el horizontal y el rebote en
## enemigo que lo cancela). Lo cancelan el rebote, el dodge, el stun, un launch o un bump (todos superan
## o cancelan el Mover); el doble salto NO sale durante el plunge (y no se gasta). El perfil lo define el
## ataque en su tuning (la Espada: plunge_player_mover); acá solo se dispara.
func plunge(settings: MoverSettings) -> void:
	if is_on_floor() or settings == null or settings.speed <= 0.0:
		return
	air_state = AirState.AIRBORNE
	mover.start_mover(settings)

func is_plunging() -> bool:
	return mover.is_moving() and not mover.is_exclusive()

func cancel_plunge() -> void:
	if is_plunging():
		mover.cancel_mover(Mover.CancelReason.ATTACK_RULE)

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
	cancel_plunge()
	wall_slide.cancel()
	floor_slide.cancel()
	enemy_bounce.cancel()
	_reset_air_stall()
	mover.cancel_mover(Mover.CancelReason.SUPERSEDED)  # un bump corta un launch en curso
	floater.cancel_float()  # un bump (knockback/rebote) corta el hang del Floater
	dash.cancel()
	var horizontal := Vector3(dir.x, 0.0, dir.z)
	if horizontal.length_squared() > 0.0001:
		add_momentum(horizontal.normalized() * h_speed)
	vertical_velocity = v_speed
	air_state = AirState.AIRBORNE

func force_dash(dir: Vector3, distance: float, duration: float, boost_bump_momentum := false,
		deals_damage := false) -> void:
	_dodge_queued = false
	cancel_plunge()
	wall_slide.cancel()
	floor_slide.cancel()
	enemy_bounce.cancel()
	dash.force_dash(dir, distance, duration, boost_bump_momentum, deals_damage)

## Programa un impulso que PlayerDash aplica solo al terminar naturalmente el dash actual.
func set_dash_exit_bop(dir: Vector3, forward_speed: float, vertical_speed: float) -> void:
	dash.set_exit_bop(dir, forward_speed, vertical_speed)

func launch(height: float, hang_time: float, rise_time: float = World.LAUNCH_RISE_TIME) -> void:
	_dodge_queued = false
	cancel_plunge()
	wall_slide.cancel()
	floor_slide.cancel()
	enemy_bounce.cancel()
	stun.cancel()
	dash.cancel()
	floater.cancel_float()  # un launch nuevo reemplaza cualquier hang del Floater en curso
	# Mover ascendente (ex launcher.start_launch/tick_launch): sube `height` a velocidad constante en
	# `rise_time` y al terminar detona su Floater (el hang del launcher). `hang_time` es para el
	# ENEMIGO; el jugador flota con sus propios knobs, igual que el launcher viejo lo ignoraba.
	var s := MoverSettings.new()
	s.direction = Vector3.UP
	s.distance = height
	s.speed = height / maxf(0.01, rise_time)
	s.acceleration = 0.0
	s.stop_on = MoverSettings.STOP_ON_DISTANCE
	# Float del jugador tras la subida: el launcher viejo tenia dos fases (float 0.15@0.30, fall
	# 0.30@0.85). F2 las colapsa en un Floater unico (duracion total al fall_scale de la fase float).
	# Mapeo feel-sensible: retunear launcher_float_duration/gravity/fall_duration si hace falta.
	s.float_duration = tuning.launcher_float_duration + tuning.launcher_fall_duration
	s.float_fall_scale = tuning.launcher_float_gravity
	air_state = AirState.AIRBORNE
	vertical_velocity = 0.0
	mover.start_mover(s)

## Dash EXCLUSIVO por Mover (hoy el X cargado de la Espada, ex force_dash). El ataque arma el perfil
## (direction/distance/speed + flags pass_through/boost/particulas/inercia) y esto hace las
## cancelaciones cruzadas y lo arranca. El daño lo pone el hitbox propio del arma, aparte del Mover.
func dash_mover(settings: MoverSettings) -> void:
	_dodge_queued = false
	wall_slide.cancel()
	floor_slide.cancel()
	enemy_bounce.cancel()
	dash.cancel()
	floater.cancel_float()
	vertical_velocity = 0.0  # el dash borra la caída acumulada (igual que force_dash)
	air_state = AirState.AIRBORNE
	mover.start_mover(settings)

## Hooks que el Mover llama al arrancar/terminar para los extras de dash que son propios del Player
## (ver MoverSettings y PlayerDash). Un cuerpo sin estos metodos (EnemyBase) los ignora.
func on_mover_started(settings: MoverSettings, dir: Vector3, speed: float) -> void:
	if settings.emit_dash_particles:
		dash.show_dash_particles(true)
	if settings.boost_momentum:
		dash.boost_momentum_along(dir, speed)

func on_mover_ended(settings: MoverSettings, dir: Vector3) -> void:
	if settings.emit_dash_particles:
		dash.show_dash_particles(false)
	if settings.keep_exit_inertia:
		# Continuidad post-dash: la inercia aérea del input queda apuntando a la salida a velocidad
		# de carrera (el exceso, si lo hubo, ya vive en bump). Igual que PlayerDash._end_dash.
		locomotion.set_air_velocity(dir * tuning.move_speed)

## Un Mover del player terminó o se canceló. Solo el EXCLUSIVO (launcher/dash: manejaba velocity
## directo) necesita sincronizar la vertical del glue a 0, así el Floater del hang —que el propio
## Mover ya detonó— y la gravedad arrancan limpios. Un Mover NO-EXCLUSIVO (plunge) NO la pisa: su
## cancelador (rebote en enemigo, bump) ya fijó la vertical que quiere y borrarla mataría el rebote.
func _on_launch_mover_ended(_reason: int) -> void:
	if mover.is_exclusive():
		vertical_velocity = 0.0

## Cancela un launch en curso (Mover ascendente) y cierra el air-hit-stall/whiff del combo aereo.
## Lo usan el dash (via callback en dash.setup), el bump y los resets de estado.
func cancel_launch() -> void:
	mover.cancel_mover(Mover.CancelReason.SUPERSEDED)
	_reset_air_stall()

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
