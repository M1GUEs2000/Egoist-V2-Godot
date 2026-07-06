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
@export var airborne_gravity := -20.0
@export var airborne_max_time := 4.0
@export var death_destroy_delay := 0.4
@export var normal_color := Color(0.9, 0.2, 0.2, 1.0)
@export var inactive_color := Color(0.55, 0.55, 0.55, 1.0)

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

@onready var health: Health = get_node_or_null("Health") as Health
@onready var membership: WorldMembership = get_node_or_null("WorldMembership") as WorldMembership
@onready var hurtbox: Hurtbox = get_node_or_null("Hurtbox") as Hurtbox

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = World.LAYER_ENEMY
	collision_mask = World.LAYER_WORLD | World.LAYER_PLAYER | World.LAYER_ENEMY

	if health != null and not health.died.is_connected(_die):
		health.died.connect(_die)
	if hurtbox != null:
		hurtbox.triggers_air_hit_stall = true
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
		velocity = velocity.move_toward(Vector3.ZERO, 20.0 * delta)
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
	if duration <= 0.0 or is_armored() or _dead:
		return
	combat_state = CombatState.STUNNED
	_stunned_until = maxf(_stunned_until, World.now() + duration)
	if is_airborne():
		_airborne_until = maxf(_airborne_until, _stunned_until + airborne_max_time)
	_refresh_visual_state()

func apply_armor(duration: float) -> void:
	if not armored or duration <= 0.0:
		return
	combat_state = CombatState.ARMORED
	_armor_hits_taken = 0
	_stunned_until = -999.0
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
	_refresh_visual_state()

func launch(height: float, hang_time: float) -> bool:
	if not can_receive_hit() or is_armored():
		return false
	_begin_airborne()
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

func push(direction: Vector3, horizontal_speed: float, up_speed: float) -> void:
	if not can_receive_hit() or is_armored():
		return
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	_begin_airborne()
	_airborne_until = World.now() + airborne_max_time
	velocity = direction.normalized() * horizontal_speed
	velocity.y = absf(up_speed)

func try_parry(_player: Player, _hit_direction: Vector3 = Vector3.ZERO) -> bool:
	return false

func apply_parry_stun(duration: float) -> void:
	apply_stun(duration)

func _on_membership_changed(active_now: bool) -> void:
	_is_active = active_now
	collision_layer = World.LAYER_ENEMY if _is_active else 0
	if hurtbox != null:
		hurtbox.monitorable = _is_active
	_refresh_visual_state()
	on_world_changed()

func on_world_changed() -> void:
	pass

func on_hurtbox_hit(from: Node, damage: float, hit_direction: Vector3, stun: StunSettings) -> void:
	if not can_receive_hit():
		return
	if hit_direction.length_squared() > 0.0001:
		_last_hit_direction = hit_direction.normalized()
	elif from != null and from is Node3D:
		var dir := global_position - (from as Node3D).global_position
		dir.y = 0.0
		if dir.length_squared() > 0.0001:
			_last_hit_direction = dir.normalized()
	if hostility == Hostility.PASSIVE:
		_provoke_nearby()
	if is_armored():
		_damage_armor(int(ceil(damage)))
	_apply_stun_from_settings(stun)

func _apply_stun_from_settings(stun: StunSettings) -> void:
	if stun == null:
		apply_stun(1.0)
	else:
		apply_stun(stun.duration_for(is_airborne()))

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
		_refresh_visual_state()

func _begin_airborne() -> void:
	if air_state == AirState.AIRBORNE:
		return
	air_state = AirState.AIRBORNE
	_airborne_ground_y = global_position.y

func _update_airborne(delta: float) -> void:
	if World.now() < _airborne_until and velocity.y <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y += airborne_gravity * delta
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
	for mesh in find_children("*", "MeshInstance3D", false):
		var mesh_instance := mesh as MeshInstance3D
		var material := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if material == null:
			material = StandardMaterial3D.new()
			mesh_instance.set_surface_override_material(0, material)
		material.albedo_color = color
