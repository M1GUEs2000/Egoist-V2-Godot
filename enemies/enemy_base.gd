class_name EnemyBase extends CharacterBody3D
## Identidad comun de enemigo (ex EnemyBase.cs, sin contratos C#):
## compone Health + WorldMembership + Hurtbox y expone verbos de combate por duck typing.

enum Hostility { PASSIVE, REACTIVE, AGGRESSIVE, ULTRA_AGGRESSIVE }
enum CombatState { NORMAL, STUNNED, ARMORED }
enum AirState { GROUNDED, AIRBORNE }

@export var hostility := Hostility.AGGRESSIVE
@export var alert_radius := 8.0
@export var initial_combat_state := CombatState.NORMAL
@export var armored := false
@export var armor_hits_to_break := 3

# --- Poise (stagger) ---
# El stun no entra golpe a golpe: cada ataque come poise y el stun llega cuando el acumulado
# supera la reserva. Ver combat/poise.gd. La armadura SUMA reserva (no es un umbral aparte):
# al romperse, el bonus se pierde solo.
## Reserva de poise a romper para stunear a este enemigo.
@export var poise_max := 6.0
## Poise extra mientras esta armado. Se pierde al romperse la armadura.
@export var armor_poise_bonus := 6.0
## Drenaje del poise acumulado, en puntos por segundo. Alto = hay que encadenar golpes rapido.
@export var poise_decay_per_second := 1.5
## Escalera de degradacion: multiplicador de la reserva tras cada quiebre. Cada stun lo deja mas
## fragil; en el ultimo escalon (0.0) cualquier golpe lo stunea. Se reinicia solo (ver abajo).
@export var poise_break_levels: Array[float] = [1.0, 0.8, 0.6, 0.4, 0.2, 0.0]
## Segundos sin recibir golpes tras los que su reserva vuelve al 100%. Silencioso: no se muestra.
@export var poise_recovery_time := 20.0

# Fogonazo BLANCO del golpe que come poise sin quebrarlo: "te di, pero aguanto". Es el tercer
# color del lenguaje de impacto — amarillo = stuneado, rojo = hazard (SpikeWall), blanco = absorbido.
# Solo emision, sin tocar el albedo: el enemigo no cambia de color, se enciende un instante.
## Color del fogonazo del golpe absorbido.
@export var poise_chip_color := Color(1.0, 1.0, 1.0, 1.0)
## Emision del fogonazo absorbido. Requiere el glow del WorldEnvironment para el bloom.
@export var poise_chip_energy := 2.0
## Segundos que tarda en apagarse el fogonazo. Corto: es un destello, no un estado.
@export var poise_chip_time := 0.12

@export var airborne_gravity := -20.0
@export var airborne_max_time := 4.0
@export var death_destroy_delay := 0.4
@export var normal_color := Color(0.9, 0.2, 0.2, 1.0)
@export var inactive_color := Color(0.55, 0.55, 0.55, 1.0)
## Velocidad horizontal inicial del retroceso al entrar en stun, en m/s.
@export var stun_knockback_speed := 4.0
## Frenado del retroceso durante stun, en m/s². Mas alto = se detiene antes.
@export var stun_knockback_decay := 20.0
## Angulo maximo de inclinacion visual durante stun, en grados.
@export var stun_tilt_angle := 12.0
## Tiempo del tween de inclinacion al entrar/salir de stun, en segundos. Subirlo hace visible
## el recorrido hacia el angulo; bajarlo lo vuelve un salto instantaneo.
@export var stun_tilt_time := 0.15
## Escala a la que se encoge el enemigo en el golpe (1.0 = sin squash).
@export var stun_squash_scale := 0.8

# El rebote ocupa solo el arranque del stun; el resto el enemigo se queda grande. Los tiempos
# son absolutos, no fracciones: retunear la duracion del stun no deforma el gesto del impacto.
# Si el stun es mas corto que estos tiempos, el rebote se recorta para caber.
## Segundos desde el golpe en los que termina de encogerse.
@export var stun_squash_in_time := 0.05
## Segundos desde el golpe en los que ya recupero su tamaño normal. Mayor que in_time.
@export var stun_squash_out_time := 0.09
## Energia de emision del material durante stun. Sin bloom, solo enciende la superficie.
@export var stun_emission_energy := 1.8
## Energia de la luz amarilla durante stun.
@export var stun_light_energy := 1.6
## Alcance de la luz amarilla durante stun, en metros.
@export var stun_light_range := 3.0
## Altura sobre los pies a la que nacen las chispas de impacto, en metros.
@export var hit_sparks_height := 1.0
## Cuanto se adelantan las chispas desde el eje del enemigo hacia su atacante, en metros:
## nacen en la superficie golpeada, no en el centro del cuerpo.
@export var hit_sparks_offset := 0.45
## Velocidad horizontal minima (m/s) a partir de la cual el enemigo levanta polvo al moverse.
## Solo en el suelo, activo y sin stun. El look del polvo vive en el emisor RunDust de la escena.
@export var run_dust_min_speed := 1.0

# --- Enemigo de world switch ---
# Un enemigo con un WorldSwitchTrigger hijo (when = ON_DEATH) voltea el mundo de todos al morir.
# Se lee distinto del resto: en vez del rojo normal lleva el color del mundo OPUESTO (el mundo al
# que te va a mandar, igual criterio que los bloques de world switch) y su cuerpo LATE — la
# emision pulsa sola. Del bloque comparte solo el color; el gesto es propio.
## Emision minima del latido (el valle del pulso).
@export var world_switch_pulse_min_energy := 0.3
## Emision maxima del latido (la cresta del pulso).
@export var world_switch_pulse_max_energy := 2.0
## Velocidad del latido, en pulsos por segundo.
@export var world_switch_pulse_speed := 1.2
## Emision del fogonazo al morir (el golpe de luz que acompaña al cambio de mundo).
@export var world_switch_death_flash_energy := 6.0
## Segundos que tarda el fogonazo de muerte en apagarse.
@export var world_switch_death_flash_time := 0.3

# --- Acostado + ragdoll de aterrizaje ---
# Un enemigo empujado (push) o stuneado EN EL AIRE cae ACOSTADO (pose horizontal), siguiendo su
# trayectoria scripteada normal (arco del push o hang del stun). El rigid body NO existe en el
# aire: solo al tocar el piso. Una esfera de proximidad (GroundSense) detecta el suelo justo
# antes del contacto real y ahi arranca el ragdoll (RigidBody capsula) para que se vea natural.
# Tras rodar `ragdoll_getup_delay` segundos el cuerpo se para. Greybox: ragdoll de cuerpo unico
# (la capsula rueda), no por huesos — el ragdoll por PhysicalBone es upgrade de H3.
## Angulo de la pose acostada durante el vuelo, en grados. 90 = horizontal pleno.
@export var lie_angle := 90.0
## Segundos que el cuerpo rueda como RigidBody en el piso antes de pararse. Es el "se para en X".
@export var ragdoll_getup_delay := 0.5
## Segundos del tween de pararse (de acostado a vertical) al terminar el ragdoll.
@export var ragdoll_stand_time := 0.25
## Escala de gravedad del RigidBody del ragdoll. La gravedad global de fisica es mas suave que la
## del juego; subir esto acerca el peso de la caida al feel del resto.
@export var ragdoll_gravity_scale := 3.0
## Giro inicial del ragdoll al aterrizar, en rad/s: da el volteo del cuerpo al rodar.
@export var ragdoll_spin := 6.0

var air_state := AirState.GROUNDED
var combat_state := CombatState.NORMAL
var poise := Poise.new()

var _armor_hits_taken := 0
var _dead := false
var _is_active := true
var _last_hit_direction := Vector3.FORWARD
var _stunned_until := -999.0
var _stun_feedback_color := Color(1.0, 0.9, 0.15, 1.0)
var _airborne_until := -999.0
var _airborne_ground_y := 0.0
var _slam_bounce := false
var _bounce_ballistic := false
var _bounce_target_y := Callable()
var _bounce_hang_time := 0.0
var _bouncing := false
var _bounce_dir := Vector3.ZERO
var _bounce_up_speed := 0.0
var _bounce_forward_speed := 0.0
var _bounce_gravity := -30.0
var _launch_id := 0
var _air_gravity := 0.0  # gravedad del vuelo actual; el push la override con su propio arco
var _stun_tween: Tween
var _squash_tween: Tween
var _lying := false          # cae acostado (push o stun aereo); la pose horizontal esta activa
var _ragdolling := false     # el RigidBody tomo la posta en el piso; el CharacterBody espera
var _left_ground_once := false  # dejo el rango de GroundSense una vez: recien ahi vale re-tocar
var _ragdoll_until := -999.0
var _world_switch: WorldSwitchTrigger  # null = enemigo normal; presente = voltea el mundo al morir
var _death_flash_tween: Tween
var _chip_tween: Tween
var _announced_color := Color.WHITE  # ultimo color de mundo que mostro; lo hereda el fogonazo
# Los materiales de la escena son SubResources: Godot los comparte entre instancias, asi que
# pintarlos directo tine a TODOS los enemigos. Cada instancia se queda con su copia propia.
var _own_materials: Dictionary[MeshInstance3D, StandardMaterial3D] = {}

@onready var health: Health = get_node_or_null("Health") as Health
@onready var membership: WorldMembership = get_node_or_null("WorldMembership") as WorldMembership
@onready var hurtbox: Hurtbox = get_node_or_null("Hurtbox") as Hurtbox
@onready var visual: Node3D = get_node_or_null("Visual") as Node3D
@onready var stun_light: OmniLight3D = get_node_or_null("StunLight") as OmniLight3D
@onready var hit_sparks: GPUParticles3D = get_node_or_null("HitSparks") as GPUParticles3D
@onready var run_dust: GPUParticles3D = get_node_or_null("RunDust") as GPUParticles3D
@onready var ground_sense: Area3D = get_node_or_null("GroundSense") as Area3D
@onready var ragdoll_body: RigidBody3D = get_node_or_null("Ragdoll") as RigidBody3D
@onready var _body_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = World.LAYER_ENEMY
	collision_mask = World.LAYER_WORLD | World.LAYER_PLAYER | World.LAYER_ENEMY
	_air_gravity = airborne_gravity
	poise.poise_max = poise_max
	poise.armor_bonus = armor_poise_bonus
	poise.decay_per_second = poise_decay_per_second
	poise.break_levels = poise_break_levels
	poise.recovery_time = poise_recovery_time
	poise.reset()

	if health != null and not health.died.is_connected(_die):
		health.died.connect(_die)
	if hurtbox != null:
		hurtbox.triggers_air_hit_stall = true
	if stun_light != null:
		stun_light.visible = false
		stun_light.light_energy = stun_light_energy
		stun_light.omni_range = stun_light_range
	if ground_sense != null:
		# Solo siente el suelo/paredes; capas por codigo (regla del proyecto, ver World.LAYER_*).
		ground_sense.collision_layer = 0
		ground_sense.collision_mask = World.LAYER_WORLD
		ground_sense.monitoring = true
		ground_sense.monitorable = false
	if ragdoll_body != null:
		# El ragdoll vive en el mundo (top_level), rueda contra el suelo y nadie lo detecta a el.
		ragdoll_body.top_level = true
		ragdoll_body.collision_layer = 0
		ragdoll_body.collision_mask = World.LAYER_WORLD
		ragdoll_body.gravity_scale = ragdoll_gravity_scale
		ragdoll_body.freeze = true
		ragdoll_body.visible = false
	if membership != null:
		membership.hide_when_inactive = false
		if not membership.changed.is_connected(_on_membership_changed):
			membership.changed.connect(_on_membership_changed)
		_on_membership_changed(membership.is_active)

	for child in get_children():
		if child is WorldSwitchTrigger:
			_world_switch = child as WorldSwitchTrigger
			break
	if is_world_switch():
		# Su color es el del mundo OPUESTO: al voltear el mundo, el color que anuncia cambia.
		WorldManager.world_changed.connect(_on_world_switched)

	combat_state = CombatState.ARMORED if armored else initial_combat_state
	_refresh_visual_state()

## Este enemigo voltea el mundo de todos al morir (lleva un WorldSwitchTrigger hijo).
func is_world_switch() -> bool:
	return _world_switch != null

func _on_world_switched(_world: World.Kind) -> void:
	_refresh_visual_state()

## Color que este enemigo anuncia: el del mundo al que manda al jugador (el opuesto al actual),
## el mismo criterio que los bloques de world switch. Es lo unico que comparte con ellos.
func _world_switch_color() -> Color:
	return World.world_color(World.opposite_world(WorldManager.current))

## El latido: la emision del cuerpo sube y baja sola mientras el enemigo esta vivo y entero.
## Se corta durante el stun (ahi manda el amarillo) y al morir (ahi manda el fogonazo).
func _process(_delta: float) -> void:
	if not is_world_switch() or _dead or not _is_active or is_stunned():
		return
	var wave := 0.5 + 0.5 * sin(World.now() * world_switch_pulse_speed * TAU)
	var energy := lerpf(world_switch_pulse_min_energy, world_switch_pulse_max_energy, wave)
	for material in _own_materials.values():
		material.emission_energy_multiplier = energy

## Fogonazo de muerte: el cuerpo se enciende de golpe con el color que el enemigo venia
## anunciando y se apaga. Es el acuse de recibo del cambio de mundo.
##
## Usa el color GUARDADO, no `_world_switch_color()`: el WorldSwitchTrigger es hijo, asi que su
## _ready conecta a `Health.died` antes que el nuestro y para cuando corre `_die` el mundo YA
## cambio — recalcular daria el color del mundo viejo, justo el que no queremos.
func _play_death_flash() -> void:
	var color := _announced_color
	if _chip_tween != null and _chip_tween.is_valid():
		_chip_tween.kill()
	if _death_flash_tween != null and _death_flash_tween.is_valid():
		_death_flash_tween.kill()
	_death_flash_tween = create_tween().set_parallel(true)
	for material in _own_materials.values():
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = world_switch_death_flash_energy
		_death_flash_tween.tween_property(material, "emission_energy_multiplier", 0.0,
				world_switch_death_flash_time)

## Fogonazo blanco del golpe que comio poise sin quebrarlo. Solo enciende la emision y la apaga:
## el albedo no se toca, asi que no compite con el amarillo del stun ni con el color del enemigo.
## Si el golpe SI quiebra, nunca se llama — manda el stun.
func _play_poise_chip_flash() -> void:
	if _dead or not _is_active or is_stunned() or _own_materials.is_empty():
		return
	if _chip_tween != null and _chip_tween.is_valid():
		_chip_tween.kill()
	_chip_tween = create_tween().set_parallel(true)
	for material in _own_materials.values():
		material.emission_enabled = true
		material.emission = poise_chip_color
		material.emission_energy_multiplier = poise_chip_energy
		_chip_tween.tween_property(material, "emission_energy_multiplier", 0.0, poise_chip_time)
	# Devuelve el material al estado que corresponda (apaga la emision, o la deja si el de world
	# switch esta latiendo). Sin esto el enemigo queda con emission_enabled y energia 0.
	_chip_tween.chain().tween_callback(_refresh_visual_state)

func is_dead() -> bool:
	return _dead

func is_active_in_current_world() -> bool:
	return _is_active

func is_airborne() -> bool:
	return air_state == AirState.AIRBORNE

func is_stunned() -> bool:
	return combat_state == CombatState.STUNNED

func is_armored() -> bool:
	return combat_state == CombatState.ARMORED

func is_ragdolling() -> bool:
	return _ragdolling

## GATE UNIVERSAL DE DESPLAZAMIENTO: mientras al enemigo le quede poise NO se lo mueve de ninguna
## forma (launch, push, slam, bounce). Solo entra si la reserva ya esta quebrada (STUNNED) o si el
## golpe que trae el desplazamiento la va a quebrar ahora mismo.
##
## La armadura NO es un caso aparte: es reserva extra (ver Poise.effective_max), asi que un armado
## aguanta mas golpes, pero uno que le quiebre la reserva (el sweet spot del Mazo) lo mueve igual.
## Resistencia, nunca inmunidad.
##
## `stun` solo se pasa desde los desplazamientos que corren ANTES de que el golpe cobre el poise
## (el launcher, en about_to_hit): ahi la reserva se CONSULTA (would_break, no consume) porque el
## golpe la va a cobrar despues en on_hurtbox_hit. Los que corren DESPUES del golpe (push, slam,
## slam_arc, en landed) no lo pasan: para entonces el stun ya entro y alcanza con is_stunned().
func _breaks_poise(stun: StunSettings = null) -> bool:
	if is_stunned():
		return true  # la reserva ya esta quebrada: el juggle y los combos entran directo
	if stun == null or poise == null:
		return false
	return poise.would_break(stun.poise_damage, is_armored())

func can_attack() -> bool:
	return _is_active and not _dead and not is_stunned() and not is_airborne() and not _ragdolling

func can_receive_hit() -> bool:
	return _is_active and not _dead

func tick_base(delta: float) -> bool:
	if _dead:
		return false
	if _ragdolling:
		_update_combat_state()
		_set_run_dust(false)
		_update_ragdoll()
		return false
	_update_combat_state()
	if is_airborne():
		_set_run_dust(false)
		_update_airborne(delta)
		return false
	if is_stunned():
		_set_run_dust(false)
		_tick_stun_knockback(delta)
		move_and_slide()
		return false
	# Polvo al correr: activo en el mundo, en el suelo y por encima del umbral. La velocidad es
	# la del move_and_slide del frame anterior (la locomocion corre despues de tick_base).
	_set_run_dust(_is_active and is_on_floor()
			and Vector2(velocity.x, velocity.z).length() >= run_dust_min_speed)
	return _is_active

func take_hit_from_enemy(hits: float = 1.0, hit_direction: Vector3 = Vector3.ZERO, stun: StunSettings = null) -> bool:
	if not can_receive_hit() or health == null:
		return false
	if hit_direction.length_squared() > 0.0001:
		_last_hit_direction = hit_direction.normalized()
	var died := health.take_damage(hits)
	if not died:
		if is_armored():
			_damage_armor(int(ceil(hits)))
		_apply_stun_from_settings(stun)
	return died

func apply_stun(duration: float, feedback_color := Color.TRANSPARENT) -> void:
	# El ragdoll conserva la representacion fisica, pero el stun sigue siendo la autoridad de
	# combate: un impacto al cuerpo caido lo puede congelar y extender su recuperacion.
	if duration <= 0.0 or _dead:
		return
	# Un golpe anterior pudo dejar el fogonazo blanco a medio apagar: si sigue corriendo, le
	# pelearia la emision al amarillo del stun. Manda el stun.
	if _chip_tween != null and _chip_tween.is_valid():
		_chip_tween.kill()
	_stun_feedback_color = feedback_color if feedback_color.a > 0.0 else Color(1.0, 0.9, 0.15, 1.0)
	combat_state = CombatState.STUNNED
	_stunned_until = maxf(_stunned_until, World.now() + duration)
	if _ragdolling:
		_freeze_ragdoll_for_stun()
		_refresh_visual_state()
		return
	# El golpe cancela el push (u otro impulso) en curso y lo reemplaza por un retroceso
	# corto propio del stun, sin acumular momentum previo.
	_apply_stun_knockback()
	if is_airborne():
		# Suspendido mientras dure el stun (juggle): cae cuando el stun termina.
		# airborne_max_time NO va aca; es solo el tope de seguridad en _update_airborne.
		_airborne_until = maxf(_airborne_until, _stunned_until)
		# Golpeado en el aire = queda acostado (el hang no se toca, solo la pose).
		_lying = true
	_play_stun_reaction(duration)
	_refresh_visual_state()

func apply_armor(duration: float) -> void:
	if not armored or duration <= 0.0:
		return
	combat_state = CombatState.ARMORED
	_armor_hits_taken = 0
	_stunned_until = -999.0
	_reset_stun_reaction()
	_refresh_visual_state()
	await get_tree().create_timer(duration).timeout
	if not _dead and combat_state == CombatState.ARMORED:
		combat_state = CombatState.NORMAL
		_refresh_visual_state()

func set_armored(enabled: bool) -> void:
	if enabled and not armored:
		return
	combat_state = CombatState.ARMORED if enabled else CombatState.NORMAL
	_armor_hits_taken = 0
	_stunned_until = -999.0
	_reset_stun_reaction()
	_refresh_visual_state()

## Lanza al aire. Corre en about_to_hit (ANTES del daño) para que el stun del golpe lo vea ya
## airborne y le de la duracion aerea, asi que recibe el `stun` del golpe para consultar el poise:
## solo lanza si esa reserva se quiebra. Ver _breaks_poise.
func launch(height: float, hang_time: float, stun: StunSettings = null,
		starts_lying := false) -> bool:
	if not can_receive_hit() or _ragdolling or not _breaks_poise(stun):
		return false
	_begin_airborne()
	if starts_lying:
		_set_lying(true)
	_air_gravity = airborne_gravity  # el launcher cae con la gravedad propia del enemigo
	velocity = Vector3.ZERO
	_launch_id += 1
	_launch_routine(_launch_id, height, hang_time)
	return true

func _launch_routine(id: int, height: float, hang_time: float) -> void:
	var rise_time := World.LAUNCH_RISE_TIME
	var rise_speed := height / rise_time
	var rise_left := rise_time
	while rise_left > 0.0 and not _dead and id == _launch_id:
		var delta := get_physics_process_delta_time()
		global_position.y += rise_speed * delta
		rise_left -= delta
		await get_tree().physics_frame
	if id != _launch_id:
		return
	_airborne_until = World.now() + hang_time

func slam(down_speed: float) -> void:
	if not can_receive_hit() or not is_stunned() or not is_airborne() or _ragdolling:
		return
	_airborne_until = World.now()
	velocity.y = -absf(down_speed)

## Rebote VERTICAL: baja y, al tocar el piso, sube a una altura objetivo con hang. Lo usa el Y
## cargado aereo de la Espada (spike + rebote hasta tu altura).
func slam_bounce(down_speed: float, target_world_y: Callable, hang_time: float) -> void:
	if not can_receive_hit() or not is_stunned() or _ragdolling:
		return
	_bounce_target_y = target_world_y
	_bounce_hang_time = hang_time
	_bounce_ballistic = false
	_slam_bounce = true
	if not is_airborne():
		_do_bounce()
	else:
		slam(down_speed)

## Pique BALISTICO: baja y, al tocar el piso, pica en un arco propio (up + forward + su gravedad) en
## bounce_dir, sin atarse a una altura. Lo usa el Y cargado aereo del Mazo (rebote genuino).
func slam_arc(down_speed: float, bounce_dir: Vector3, bounce_up_speed: float,
		bounce_forward_speed: float, bounce_gravity: float) -> void:
	if not can_receive_hit() or not is_stunned() or _ragdolling:
		return
	_bounce_dir = Vector3(bounce_dir.x, 0.0, bounce_dir.z)
	if _bounce_dir.length_squared() > 0.0001:
		_bounce_dir = _bounce_dir.normalized()
	_bounce_up_speed = absf(bounce_up_speed)
	_bounce_forward_speed = maxf(0.0, bounce_forward_speed)
	_bounce_gravity = -absf(bounce_gravity)
	_bounce_ballistic = true
	_slam_bounce = true
	if not is_airborne():
		_do_bounce()
	else:
		slam(down_speed)

## Empujon en arco. El arco (velocidad + altura + cierre) lo define quien ataca via
## PushSettings, no el enemigo: asi cada arma/ataque empuja distinto (inyectable).
##
## Todos los pushes corren DESPUES de que el golpe cobro el poise (en landed, o tras el
## try_apply_stun de apply_spike_hit), asi que alcanza con is_stunned(): si el enemigo aguanto la
## reserva, no se mueve. El rebote del jugador (PlayerEnemyBounce) no trae poise propio, asi que
## solo empuja a un enemigo ya stuneado.
func push(direction: Vector3, settings: PushSettings) -> void:
	if not can_receive_hit() or not is_stunned() or _ragdolling:
		return
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	if settings == null:
		settings = PushSettings.new()  # defaults seguros si el arma no configuro su push
	_begin_airborne()
	# Sin hang: el push es un arco balistico (sube por up_speed y cae por su gravedad).
	# airborne_max_time queda solo como tope de seguridad en _update_airborne.
	_air_gravity = settings.gravity
	_airborne_until = World.now()
	velocity = direction.normalized() * settings.horizontal_speed
	velocity.y = absf(settings.up_speed)
	# Empujado = cae acostado. Un push sobre un enemigo en el piso tambien lo acuesta: entra igual
	# a AIRBORNE (arco bajo), sigue su trayectoria y el ragdoll arranca al tocar el suelo.
	_set_lying(true)

func try_parry(_player: Player, _hit_direction: Vector3 = Vector3.ZERO) -> bool:
	return false

func apply_parry_stun(duration: float) -> void:
	apply_stun(duration)

func receive_stun(stun: StunSettings, feedback_color := Color.TRANSPARENT) -> bool:
	if stun == null:
		return false
	return try_apply_stun(stun.duration_for(is_airborne()), stun.poise_damage, feedback_color)

## Gate del stun: el golpe come poise y solo stunea si quiebra la reserva. Ya stuneado no hay
## poise que romper (esta quebrado): el golpe entra directo y extiende — eso sostiene el juggle.
func try_apply_stun(duration: float, poise_damage: float,
		feedback_color := Color.TRANSPARENT) -> bool:
	if not is_stunned() and not poise.take_poise_damage(poise_damage, is_armored()):
		_play_poise_chip_flash()  # aguanto: fogonazo blanco, sin stun
		return false
	apply_stun(duration, feedback_color)
	return true

## Impacto de hazard: daÃ±o, stun por poise y empuje en una sola reacciÃ³n.
func apply_spike_hit(damage: float, push_direction: Vector3, stun: StunSettings,
		push_settings: PushSettings, feedback_color: Color) -> bool:
	if not can_receive_hit() or health == null:
		return false
	push_direction.y = 0.0
	if push_direction.length_squared() > 0.0001:
		_last_hit_direction = push_direction.normalized()
	var died := health.take_damage(damage)
	if died:
		return true
	if is_armored():
		_damage_armor(int(ceil(damage)))
	# El stun corre ANTES del push a proposito: push() solo empuja si la reserva quedo quebrada
	# (ver su gate). Un enemigo que aguanta el hazard come el daño y el fogonazo blanco, y no se mueve.
	if stun != null:
		try_apply_stun(stun.duration_for(is_airborne()), stun.poise_damage, feedback_color)
	if push_settings != null:
		push(push_direction, push_settings)
	return false

func _on_membership_changed(active_now: bool) -> void:
	_is_active = active_now
	collision_layer = World.LAYER_ENEMY if _is_active else 0
	if hurtbox != null:
		# El switch puede venir desde un golpe/pickup (callback de area_entered), o sea
		# durante el flush de queries de fisica, donde el motor BLOQUEA set_monitorable.
		# set_deferred lo aplica al terminar el flush; si no, la hurtbox se desincroniza y
		# el enemigo queda activo pero intocable (no lo detecta ningun hitbox).
		hurtbox.set_deferred("monitorable", _is_active)
	_refresh_visual_state()
	on_world_changed()

func on_world_changed() -> void:
	pass

func on_hurtbox_hit(from: Node, damage: float, hit_direction: Vector3, stun: StunSettings) -> void:
	if not can_receive_hit():
		return
	_remember_hit_direction(from, hit_direction)
	_play_hit_sparks()
	if hostility == Hostility.PASSIVE:
		_on_passive_attacked(from)
	if is_armored():
		_damage_armor(int(ceil(damage)))
	_apply_stun_from_settings(stun)

func _on_passive_attacked(_from: Node) -> void:
	_provoke_nearby()

func _apply_stun_from_settings(stun: StunSettings) -> void:
	if stun == null:
		try_apply_stun(1.0, 1.0)
	else:
		receive_stun(stun)

func _damage_armor(hits: int) -> void:
	_armor_hits_taken += maxi(1, hits)
	if _armor_hits_taken < maxi(1, armor_hits_to_break):
		return
	combat_state = CombatState.NORMAL
	_armor_hits_taken = 0
	_refresh_visual_state()

func _provoke_nearby() -> void:
	hostility = Hostility.AGGRESSIVE
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as EnemyBase
		if enemy == null or enemy == self or enemy.is_dead():
			continue
		if enemy.hostility != Hostility.PASSIVE:
			continue
		if global_position.distance_to(enemy.global_position) <= alert_radius:
			enemy.hostility = Hostility.AGGRESSIVE

func _update_combat_state() -> void:
	if combat_state == CombatState.STUNNED and World.now() >= _stunned_until:
		combat_state = CombatState.NORMAL
		_reset_stun_reaction()
		_refresh_visual_state()

func _begin_airborne() -> void:
	if air_state == AirState.AIRBORNE:
		return
	air_state = AirState.AIRBORNE
	_airborne_ground_y = global_position.y
	_left_ground_once = false  # hasta que salga del rango de GroundSense no cuenta como "toco"

func _update_airborne(delta: float) -> void:
	# Durante el pique el arco es dueño del horizontal: el decay del stun lo frenaria y mataria el
	# rebote genuino. Por eso _bouncing lo saltea (sigue stuneado, pero sin comerse la velocidad).
	if is_stunned() and not _bouncing:
		_tick_stun_knockback(delta)
	if World.now() < _airborne_until and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y += _air_gravity * delta
	move_and_slide()
	# La esfera GroundSense siente el piso un pelo antes que los pies: el ragdoll de un cuerpo
	# acostado arranca justo antes del contacto real y se ve mas natural (anticipacion). Solo
	# cuenta despues de haber salido del rango una vez (si no, un push desde el piso dispararia
	# en el frame 0). Los pushes bajos que nunca salen del rango caen por is_on_floor().
	var sensed := ground_sense != null and ground_sense.has_overlapping_bodies()
	if not sensed:
		_left_ground_once = true
	var early_ground := _lying and _left_ground_once and sensed
	if is_on_floor() or early_ground or World.now() >= _airborne_until + airborne_max_time:
		if _slam_bounce:
			_do_bounce()
		elif _lying:
			_start_ragdoll()
		else:
			_land()

func _do_bounce() -> void:
	_slam_bounce = false
	if _bounce_ballistic:
		_do_bounce_arc()
	else:
		_do_bounce_vertical()

## Rebote vertical (Espada): sube a la altura objetivo con el launcher lineal.
func _do_bounce_vertical() -> void:
	var target_y := global_position.y
	if _bounce_target_y.is_valid():
		target_y = _bounce_target_y.call()
	var height := target_y - global_position.y
	if height <= 0.1:
		_land()
		return
	launch(height, _bounce_hang_time)

## Pique balistico (Mazo): arco propio (velocity + gravedad del pique), stuneado todo el arco. No se
## ata a una altura: la da la fisica. Al aterrizar, el cuerpo acostado (_set_lying) arranca el ragdoll,
## que hereda esta velocidad y rueda.
func _do_bounce_arc() -> void:
	if _bounce_up_speed <= 0.0 and _bounce_forward_speed <= 0.0:
		_land()
		return
	_begin_airborne()
	_left_ground_once = false  # recien toco el piso; que no dispare el ragdoll hasta despegar del pique
	_bouncing = true
	_air_gravity = _bounce_gravity  # el arco cae con la gravedad del pique
	_airborne_until = World.now()   # sin hang: arco balistico puro
	velocity = _bounce_dir * _bounce_forward_speed
	velocity.y = _bounce_up_speed
	_set_lying(true)
	# Stuneado todo el vuelo del pique (~2*up/gravedad): extiende el stun para cubrirlo.
	var airtime := 2.0 * _bounce_up_speed / maxf(0.1, absf(_bounce_gravity))
	combat_state = CombatState.STUNNED
	_stunned_until = maxf(_stunned_until, World.now() + airtime)

func _land() -> void:
	air_state = AirState.GROUNDED
	velocity = Vector3.ZERO
	_bouncing = false
	_air_gravity = airborne_gravity  # limpia el override del push para el proximo vuelo

## Acuesta al enemigo: la pose horizontal del vuelo (push o stun aereo). Reusa el mismo eje que
## la inclinacion del stun, pero al angulo pleno `lie_angle`. Solo cambia el gesto; la trayectoria
## (arco del push / hang del stun) no se toca. Ignora si ya esta el ragdoll fisico en el piso.
func _set_lying(on: bool) -> void:
	_lying = on
	if visual == null or _ragdolling:
		return
	var target := _tilt_quaternion(lie_angle) if on else Quaternion.IDENTITY
	var pivot := _lie_pivot() if on else Vector3.ZERO
	_rotate_visual_to(target, pivot, stun_tilt_time)

## Pivote de la pose acostada: la MITAD del modelo (centro de la capsula), no los pies. El cuerpo
## stuneado se tumba girando sobre su centro. En el piso (ragdoll) el pivote ya no importa: manda
## la fisica. La inclinacion corta del stun en tierra sigue pivotando desde los pies (pivot cero).
func _lie_pivot() -> Vector3:
	return Vector3.UP * _body_center_height()

## Rota el Visual alrededor de `pivot` (espacio local del enemigo), no de su origen (los pies):
## origin = pivot - R*pivot. Setea rotacion y posicion por separado para NO pisar la escala del
## squash, que corre en su propio tween en paralelo.
func _apply_visual_rotation(q: Quaternion, pivot: Vector3) -> void:
	visual.quaternion = q
	visual.position = pivot - Basis(q) * pivot

func _tween_visual_rotation(t: float, from_q: Quaternion, to_q: Quaternion, pivot: Vector3) -> void:
	_apply_visual_rotation(from_q.slerp(to_q, t), pivot)

func _rotate_visual_to(target: Quaternion, pivot: Vector3, duration: float) -> void:
	if _stun_tween != null:
		_stun_tween.kill()
	var from_q := visual.quaternion
	_stun_tween = create_tween()
	_stun_tween.tween_method(
			_tween_visual_rotation.bind(from_q, target, pivot), 0.0, 1.0, maxf(0.01, duration))

## Aterrizaje de un cuerpo acostado: el CharacterBody se apaga y un RigidBody capsula (el ragdoll)
## toma la posta con la velocidad y un giro para rodar. El rigid body SOLO existe aca, en el piso.
func _start_ragdoll() -> void:
	_bouncing = false
	if ragdoll_body == null:
		# Escena sin nodo Ragdoll: cae al comportamiento normal (fallback defensivo, como el resto
		# de modulos opcionales por get_node_or_null).
		_lying = false
		_land()
		return
	_ragdolling = true
	air_state = AirState.GROUNDED
	_airborne_until = -999.0
	_ragdoll_until = maxf(World.now() + ragdoll_getup_delay, _stunned_until)
	if _stun_tween != null:
		_stun_tween.kill()
	if _squash_tween != null:
		_squash_tween.kill()
	# El cuerpo deja de colisionar y de verse; el ragdoll es lo visible mientras rueda.
	if _body_shape != null:
		_body_shape.set_deferred("disabled", true)
	if visual != null:
		visual.visible = false
	# Arranca donde estaba el cuerpo (capsula centrada), ya acostado, heredando su velocidad.
	var center := global_position + Vector3.UP * _body_center_height()
	ragdoll_body.global_transform = Transform3D(Basis(_tilt_quaternion(lie_angle)), center)
	ragdoll_body.freeze = false
	ragdoll_body.visible = true
	ragdoll_body.linear_velocity = velocity
	ragdoll_body.angular_velocity = _ragdoll_spin_axis() * ragdoll_spin
	velocity = Vector3.ZERO
	_refresh_visual_state()

func _update_ragdoll() -> void:
	if ragdoll_body != null:
		# El cuerpo (Hurtbox, luz, chispas) sigue al ragdoll en el plano mientras rueda.
		global_position.x = ragdoll_body.global_position.x
		global_position.z = ragdoll_body.global_position.z
	if World.now() >= _ragdoll_until:
		_end_ragdoll()

func _freeze_ragdoll_for_stun() -> void:
	if ragdoll_body == null:
		return
	ragdoll_body.linear_velocity = Vector3.ZERO
	ragdoll_body.angular_velocity = Vector3.ZERO
	ragdoll_body.freeze = true
	_ragdoll_until = maxf(_ragdoll_until, _stunned_until)

## Se para: congela y esconde el ragdoll, reubica el cuerpo donde se asento y lo endereza.
func _end_ragdoll() -> void:
	var rest := ragdoll_body.global_position if ragdoll_body != null else global_position
	if ragdoll_body != null:
		ragdoll_body.freeze = true
		ragdoll_body.visible = false
		ragdoll_body.linear_velocity = Vector3.ZERO
		ragdoll_body.angular_velocity = Vector3.ZERO
	_ragdolling = false
	_lying = false
	air_state = AirState.GROUNDED
	velocity = Vector3.ZERO
	# Reubica el cuerpo donde rodo el ragdoll; los pies al piso. Greybox plano: usa la altura de
	# despegue. H3: raycast al piso real para terreno con desnivel.
	global_position.x = rest.x
	global_position.z = rest.z
	global_position.y = _airborne_ground_y
	if _body_shape != null:
		_body_shape.set_deferred("disabled", false)
	if visual != null:
		visual.visible = true
		visual.scale = Vector3.ONE
		# Arranca acostado (sobre la mitad) y se endereza. En el piso el pivote ya no importa,
		# pero mantenerlo evita un salto de posicion al pararse.
		_apply_visual_rotation(_tilt_quaternion(lie_angle), _lie_pivot())
		_rotate_visual_to(Quaternion.IDENTITY, _lie_pivot(), ragdoll_stand_time)
	_refresh_visual_state()

## Altura del centro de la capsula sobre los pies (el CollisionShape del cuerpo esta offset +Y).
func _body_center_height() -> float:
	return _body_shape.position.y if _body_shape != null else 0.9

## Eje horizontal, perpendicular a la direccion del golpe, sobre el que voltea el ragdoll al rodar.
func _ragdoll_spin_axis() -> Vector3:
	var dir := Vector3(_last_hit_direction.x, 0.0, _last_hit_direction.z)
	if dir.length_squared() < 0.0001:
		return Vector3.RIGHT
	var axis := Vector3.UP.cross(dir.normalized())
	return axis.normalized() if axis.length_squared() > 0.0001 else Vector3.RIGHT

## Dirección en la que este enemigo retrocede y se inclina al ser golpeado: SIEMPRE se aleja
## del atacante, nunca de la hitbox que lo tocó. La hoja del arma orbita alrededor del jugador
## (ver la Hand en WeaponBase), así que a mitad de un swing está a un costado del enemigo —
## usarla como origen mandaba el retroceso de lado, o de vuelta hacia el jugador.
## hit_direction (hitbox → hurtbox) queda solo de fallback: golpes sin atacante posicionable.
func _remember_hit_direction(from: Node, hit_direction: Vector3) -> void:
	var attacker := from as Node3D
	if attacker != null:
		var away := global_position - attacker.global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			_last_hit_direction = away.normalized()
			return
	if hit_direction.length_squared() > 0.0001:
		_last_hit_direction = hit_direction.normalized()

## Chispas del impacto: nacen en la superficie que mira al atacante, no en el centro del cuerpo.
## Salen en TODO golpe recibido, stunee o no. El emisor es `top_level`, asi que las particulas
## viven en el mundo: el squash, la inclinacion y el giro del enemigo no las deforman.
func _play_hit_sparks() -> void:
	if hit_sparks == null:
		return
	var toward_attacker := -_last_hit_direction  # _last_hit_direction se aleja del atacante
	hit_sparks.global_position = global_position \
			+ Vector3.UP * hit_sparks_height \
			+ toward_attacker * hit_sparks_offset
	hit_sparks.restart()
	hit_sparks.emitting = true

func _apply_stun_knockback() -> void:
	var direction := Vector3(_last_hit_direction.x, 0.0, _last_hit_direction.z)
	if direction.length_squared() < 0.0001:
		direction = Vector3.FORWARD
	var vertical := velocity.y if is_airborne() else 0.0
	velocity = direction.normalized() * stun_knockback_speed
	velocity.y = vertical

func _tick_stun_knockback(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(Vector3.ZERO, stun_knockback_decay * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

## Golpe recibido: el enemigo se encoge de golpe y se inclina hacia atras. El squash rebota
## hasta su escala normal a lo largo del stun; la inclinacion entra con su propio tween.
## Cada golpe reinicia ambos, asi un combo se siente como una sucesion de impactos.
## El squash escala el pivote `Visual`, cuyo origen esta en los pies: se hunde contra el piso.
func _play_stun_reaction(duration: float) -> void:
	if visual == null:
		return
	# Acostado (stun aereo) gira al angulo pleno sobre la MITAD del modelo; en el piso, la
	# inclinacion corta de siempre sobre los pies (pivot cero).
	if _lying:
		_rotate_visual_to(_tilt_quaternion(lie_angle), _lie_pivot(), stun_tilt_time)
	else:
		_rotate_visual_to(_tilt_quaternion(stun_tilt_angle), Vector3.ZERO, stun_tilt_time)
	_play_squash(duration)

## El rebote arranca con el golpe y termina mucho antes que el stun: encoge en
## `stun_squash_in_time` y ya recupero su tamaño en `stun_squash_out_time`; el resto del stun
## se queda grande. Tween propio, para correr en paralelo con la inclinacion sin atarse a su
## ritmo. Un stun mas corto que el gesto lo recorta en vez de dejarlo encogido.
func _play_squash(duration: float) -> void:
	if _squash_tween != null:
		_squash_tween.kill()
	var total := maxf(0.01, duration)
	var in_time := minf(stun_squash_in_time, total)
	var out_time := maxf(0.01, minf(stun_squash_out_time, total) - in_time)
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual, "scale", Vector3.ONE * stun_squash_scale, maxf(0.01, in_time))
	_squash_tween.tween_property(visual, "scale", Vector3.ONE, out_time)

func _reset_stun_reaction() -> void:
	if visual == null:
		return
	if _squash_tween != null:
		_squash_tween.kill()
	visual.scale = Vector3.ONE  # el rebote ya termino a mitad del stun
	# Si sigue acostado (juggle terminado pero aun cayendo) NO se endereza: espera el ragdoll.
	if _lying:
		_rotate_visual_to(_tilt_quaternion(lie_angle), _lie_pivot(), stun_tilt_time)
	else:
		_rotate_visual_to(Quaternion.IDENTITY, Vector3.ZERO, stun_tilt_time)

## Inclinacion del golpe: el cuerpo cae en la direccion en que el golpe lo aleja del atacante,
## pivotando desde los pies. Se expresa como Quaternion (eje + angulo), no como Euler.
##
## `_last_hit_direction` es global, pero `visual.quaternion` es local al enemigo, que gira con
## `look_at` para encarar a su objetivo. Sin pasar la direccion a espacio local, la inclinacion
## depende de hacia donde este mirando: de frente al jugador, el cuerpo cae hacia adelante.
func _tilt_quaternion(angle_deg: float) -> Quaternion:
	var direction := Vector3(_last_hit_direction.x, 0.0, _last_hit_direction.z)
	if direction.length_squared() < 0.0001:
		return Quaternion.IDENTITY
	var basis_no_scale := global_transform.basis.orthonormalized()
	var local_dir := basis_no_scale.inverse() * direction.normalized()
	local_dir.y = 0.0
	if local_dir.length_squared() < 0.0001:
		return Quaternion.IDENTITY
	var axis := Vector3.UP.cross(local_dir.normalized())
	if axis.length_squared() < 0.0001:
		return Quaternion.IDENTITY
	return Quaternion(axis.normalized(), deg_to_rad(angle_deg))

func _set_run_dust(active: bool) -> void:
	if run_dust != null and run_dust.emitting != active:
		run_dust.emitting = active

func _die() -> void:
	_dead = true
	if _ragdolling:
		# Murio a mitad del ragdoll: apaga la fisica y devuelve el cuerpo a la vista para la
		# reaccion de muerte normal.
		_ragdolling = false
		if ragdoll_body != null:
			ragdoll_body.freeze = true
			ragdoll_body.visible = false
		if _body_shape != null:
			_body_shape.set_deferred("disabled", false)
		if visual != null:
			visual.visible = true
	_lying = false
	_set_run_dust(false)
	remove_from_group("enemy")  # los vivos ya no lo ven (targeting/provocación)
	collision_layer = 0
	collision_mask = 0
	if hurtbox != null:
		hurtbox.monitorable = false
	_refresh_visual_state()
	if is_world_switch():
		_play_death_flash()
	await get_tree().create_timer(death_destroy_delay).timeout
	if is_instance_valid(self):
		queue_free()

func _refresh_visual_state() -> void:
	var color := normal_color
	if is_world_switch():
		# El enemigo de world switch no usa el rojo comun: anuncia el mundo al que manda.
		_announced_color = _world_switch_color()
		color = _announced_color
	if _dead:
		color = Color(0.2, 0.2, 0.2, 1.0)
	elif not _is_active:
		color = inactive_color
	elif is_armored():
		color = Color(0.6, 0.2, 0.9, 1.0)
	elif is_stunned():
		color = _stun_feedback_color
	var stunned := is_stunned() and not _dead and _is_active
	# El de world switch late siempre que este vivo y entero: su emision queda prendida y la
	# energia la mueve _process. El stun sigue mandando (amarillo) mientras dura.
	var pulsing := is_world_switch() and not stunned and not _dead and _is_active
	if stun_light != null:
		stun_light.visible = stunned
		stun_light.light_color = _stun_feedback_color if stunned else Color.WHITE
		stun_light.light_energy = stun_light_energy if stunned else 0.0
		stun_light.omni_range = stun_light_range
	var mesh_roots: Array[Node] = []
	if visual != null:
		mesh_roots.append(visual)
	if ragdoll_body != null:
		mesh_roots.append(ragdoll_body)
	if mesh_roots.is_empty():
		mesh_roots.append(self)
	for mesh_root in mesh_roots:
		for mesh in mesh_root.find_children("*", "MeshInstance3D", true):
			var mesh_instance := mesh as MeshInstance3D
			var material := _own_material_for(mesh_instance)
			material.albedo_color = color
			material.emission_enabled = stunned or pulsing
			if stunned:
				material.emission = color
				material.emission_energy_multiplier = stun_emission_energy
			elif pulsing:
				material.emission = color

## Material exclusivo de ESTE enemigo. El de la escena es un SubResource compartido por todas
## las instancias: si se pinta directo, un solo stun tine a todo el roster. Se duplica una vez
## por mesh y se cachea; el original queda intacto como plantilla.
func _own_material_for(mesh_instance: MeshInstance3D) -> StandardMaterial3D:
	var cached: StandardMaterial3D = _own_materials.get(mesh_instance)
	if cached != null:
		return cached
	var scene_material := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	var material: StandardMaterial3D = scene_material.duplicate() if scene_material != null else StandardMaterial3D.new()
	mesh_instance.set_surface_override_material(0, material)
	_own_materials[mesh_instance] = material
	return material
