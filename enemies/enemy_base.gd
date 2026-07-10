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
@export var stun_threshold := 1.0
@export var armor_stun_threshold := 2.0
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
## Tiempo del tween de inclinacion al entrar/salir de stun, en segundos.
@export var stun_tilt_time := 0.08
## Escala a la que se encoge el enemigo en el instante del golpe (1.0 = sin squash).
## Vuelve a 1.0 a lo largo del stun; cada golpe reinicia el rebote.
@export var stun_squash_scale := 0.8
## Poses discretas del rebote de squash, incluyendo la inicial y la normal. El crecimiento
## salta entre ellas en vez de interpolar: es la animacion "a frames cortados". 2 = pop seco.
@export_range(2, 12, 1) var stun_squash_steps := 3
## Energia de emision del material durante stun. Sin bloom, solo enciende la superficie.
@export var stun_emission_energy := 1.8
## Energia de la luz amarilla durante stun.
@export var stun_light_energy := 1.6
## Alcance de la luz amarilla durante stun, en metros.
@export var stun_light_range := 3.0

var air_state := AirState.GROUNDED
var combat_state := CombatState.NORMAL

var _armor_hits_taken := 0
var _dead := false
var _is_active := true
var _last_hit_direction := Vector3.FORWARD
var _stunned_until := -999.0
var _airborne_until := -999.0
var _airborne_ground_y := 0.0
var _slam_bounce := false
var _bounce_target_y := Callable()
var _bounce_hang_time := 0.0
var _launch_id := 0
var _air_gravity := 0.0  # gravedad del vuelo actual; el push la override con su propio arco
var _stun_tween: Tween

@onready var health: Health = get_node_or_null("Health") as Health
@onready var membership: WorldMembership = get_node_or_null("WorldMembership") as WorldMembership
@onready var hurtbox: Hurtbox = get_node_or_null("Hurtbox") as Hurtbox
@onready var visual: Node3D = get_node_or_null("Visual") as Node3D
@onready var stun_light: OmniLight3D = get_node_or_null("StunLight") as OmniLight3D

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = World.LAYER_ENEMY
	collision_mask = World.LAYER_WORLD | World.LAYER_PLAYER | World.LAYER_ENEMY
	_air_gravity = airborne_gravity

	if health != null and not health.died.is_connected(_die):
		health.died.connect(_die)
	if hurtbox != null:
		hurtbox.triggers_air_hit_stall = true
	if stun_light != null:
		stun_light.visible = false
		stun_light.light_energy = stun_light_energy
		stun_light.omni_range = stun_light_range
	if membership != null:
		membership.hide_when_inactive = false
		if not membership.changed.is_connected(_on_membership_changed):
			membership.changed.connect(_on_membership_changed)
		_on_membership_changed(membership.is_active)

	combat_state = CombatState.ARMORED if armored else initial_combat_state
	_refresh_visual_state()

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

func can_attack() -> bool:
	return _is_active and not _dead and not is_stunned() and not is_airborne()

func can_receive_hit() -> bool:
	return _is_active and not _dead

func tick_base(delta: float) -> bool:
	if _dead:
		return false
	_update_combat_state()
	if is_airborne():
		_update_airborne(delta)
		return false
	if is_stunned():
		_tick_stun_knockback(delta)
		move_and_slide()
		return false
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

func apply_stun(duration: float) -> void:
	if duration <= 0.0 or _dead:
		return
	combat_state = CombatState.STUNNED
	_stunned_until = maxf(_stunned_until, World.now() + duration)
	# El golpe cancela el push (u otro impulso) en curso y lo reemplaza por un retroceso
	# corto propio del stun, sin acumular momentum previo.
	_apply_stun_knockback()
	if is_airborne():
		# Suspendido mientras dure el stun (juggle): cae cuando el stun termina.
		# airborne_max_time NO va aca; es solo el tope de seguridad en _update_airborne.
		_airborne_until = maxf(_airborne_until, _stunned_until)
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

func launch(height: float, hang_time: float) -> bool:
	if not can_receive_hit() or is_armored():
		return false
	_begin_airborne()
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
	if not can_receive_hit() or is_armored() or not is_airborne():
		return
	_airborne_until = World.now()
	velocity.y = -absf(down_speed)

func slam_bounce(down_speed: float, target_world_y: Callable, hang_time: float) -> void:
	if not can_receive_hit() or is_armored():
		return
	_bounce_target_y = target_world_y
	_bounce_hang_time = hang_time
	_slam_bounce = true
	if not is_airborne():
		_do_bounce()
	else:
		slam(down_speed)

## Empujon en arco. El arco (velocidad + altura + cierre) lo define quien ataca via
## PushSettings, no el enemigo: asi cada arma/ataque empuja distinto (inyectable).
func push(direction: Vector3, settings: PushSettings) -> void:
	if not can_receive_hit() or is_armored():
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

func try_parry(_player: Player, _hit_direction: Vector3 = Vector3.ZERO) -> bool:
	return false

func apply_parry_stun(duration: float) -> void:
	apply_stun(duration)

func receive_stun(stun: StunSettings) -> bool:
	if stun == null:
		return false
	return try_apply_stun(stun.duration_for(is_airborne()), stun.power)

func try_apply_stun(duration: float, power: float) -> bool:
	if power < _effective_stun_threshold():
		return false
	apply_stun(duration)
	return true

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

func _effective_stun_threshold() -> float:
	if is_armored():
		return armor_stun_threshold
	return stun_threshold

func _begin_airborne() -> void:
	if air_state == AirState.AIRBORNE:
		return
	air_state = AirState.AIRBORNE
	_airborne_ground_y = global_position.y

func _update_airborne(delta: float) -> void:
	if is_stunned():
		_tick_stun_knockback(delta)
	if World.now() < _airborne_until and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y += _air_gravity * delta
	move_and_slide()
	if is_on_floor() or World.now() >= _airborne_until + airborne_max_time:
		if _slam_bounce:
			_do_bounce()
		else:
			_land()

func _do_bounce() -> void:
	_slam_bounce = false
	var target_y := global_position.y
	if _bounce_target_y.is_valid():
		target_y = _bounce_target_y.call()
	var height := target_y - global_position.y
	if height <= 0.1:
		_land()
		return
	launch(height, _bounce_hang_time)

func _land() -> void:
	air_state = AirState.GROUNDED
	velocity = Vector3.ZERO
	_air_gravity = airborne_gravity  # limpia el override del push para el proximo vuelo

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
	if _stun_tween != null:
		_stun_tween.kill()
	_set_squash_progress(0.0)
	_stun_tween = create_tween()
	_stun_tween.set_parallel(true)
	_stun_tween.tween_property(visual, "rotation", _stun_tilt_rotation(), stun_tilt_time)
	_stun_tween.tween_method(_set_squash_progress, 0.0, 1.0, maxf(0.01, duration))

## El rebote no interpola: cuantiza el progreso en `stun_squash_steps` poses y salta entre
## ellas. Da la lectura de una animacion a frames cortados en vez de un crecimiento fluido.
func _set_squash_progress(progress: float) -> void:
	if visual == null:
		return
	var steps := maxi(2, stun_squash_steps)
	var index := clampi(int(progress * steps), 0, steps - 1)
	var stepped := float(index) / float(steps - 1)
	visual.scale = Vector3.ONE * lerpf(stun_squash_scale, 1.0, stepped)

func _reset_stun_reaction() -> void:
	if visual == null:
		return
	if _stun_tween != null:
		_stun_tween.kill()
	visual.scale = Vector3.ONE
	_stun_tween = create_tween()
	_stun_tween.tween_property(visual, "rotation", Vector3.ZERO, stun_tilt_time)

func _stun_tilt_rotation() -> Vector3:
	var direction := Vector3(_last_hit_direction.x, 0.0, _last_hit_direction.z)
	if direction.length_squared() < 0.0001:
		direction = Vector3.FORWARD
	var axis := Vector3.UP.cross(direction.normalized())
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT
	return axis.normalized() * deg_to_rad(stun_tilt_angle)

func _die() -> void:
	_dead = true
	remove_from_group("enemy")  # los vivos ya no lo ven (targeting/provocación)
	collision_layer = 0
	collision_mask = 0
	if hurtbox != null:
		hurtbox.monitorable = false
	_refresh_visual_state()
	await get_tree().create_timer(death_destroy_delay).timeout
	if is_instance_valid(self):
		queue_free()

func _refresh_visual_state() -> void:
	var color := normal_color
	if _dead:
		color = Color(0.2, 0.2, 0.2, 1.0)
	elif not _is_active:
		color = inactive_color
	elif is_armored():
		color = Color(0.6, 0.2, 0.9, 1.0)
	elif is_stunned():
		color = Color(1.0, 0.9, 0.15, 1.0)
	var stunned := is_stunned() and not _dead and _is_active
	if stun_light != null:
		stun_light.visible = stunned
		stun_light.light_energy = stun_light_energy if stunned else 0.0
		stun_light.omni_range = stun_light_range
	var mesh_root := visual if visual != null else self
	var recursive := visual != null
	for mesh in mesh_root.find_children("*", "MeshInstance3D", recursive):
		var mesh_instance := mesh as MeshInstance3D
		var material := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if material == null:
			material = StandardMaterial3D.new()
			mesh_instance.set_surface_override_material(0, material)
		material.albedo_color = color
		material.emission_enabled = stunned
		if stunned:
			material.emission = color
			material.emission_energy_multiplier = stun_emission_energy
