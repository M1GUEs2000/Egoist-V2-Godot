class_name Perception extends Node
## Sensor reutilizable (ex Perception.cs): cono de vision, proximidad, alerta y busqueda.

@export var vision_range := 12.0
@export var vision_half_angle := 70.0
@export var sight_origin_height := 1.2
@export var proximity_radius := 3.0
@export var lose_sight_memory := 4.0
@export var alert_duration := 0.6
@export_flags_3d_physics var sight_block_mask := World.LAYER_WORLD

var can_see_target := false
var last_known_position := Vector3.ZERO
var target: Node3D

var _owner: Node3D
var _alert_until := -999.0
var _search_until := -999.0

func setup(owner: Node3D) -> void:
	_owner = owner

func tick(new_target: Node3D, hostility: int, can_chase: bool) -> void:
	target = new_target
	var sees := _compute(hostility, can_chase)
	if sees and not can_see_target:
		_alert_until = World.now() + alert_duration
	can_see_target = sees
	if sees and target != null:
		last_known_position = target.global_position
		_search_until = World.now() + lose_sight_memory

func is_alerted() -> bool:
	return can_see_target and World.now() < _alert_until

func is_searching() -> bool:
	return not can_see_target and World.now() < _search_until

func within(range: float) -> bool:
	if _owner == null or target == null:
		return false
	var to := target.global_position - _owner.global_position
	to.y = 0.0
	return to.length() <= range

func _compute(hostility: int, can_chase: bool) -> bool:
	if _owner == null or target == null or not can_chase:
		return false
	if hostility == EnemyBase.Hostility.PASSIVE:
		return false
	if hostility == EnemyBase.Hostility.AGGRESSIVE or hostility == EnemyBase.Hostility.ULTRA_AGGRESSIVE:
		return true
	if within(proximity_radius):
		return true

	var eye := _owner.global_position + Vector3.UP * sight_origin_height
	var target_eye := target.global_position + Vector3.UP * 0.8
	var to := target_eye - eye
	if to.length() > vision_range:
		return false
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length_squared() < 0.0001:
		return true
	var forward := -_owner.global_basis.z
	forward.y = 0.0
	if rad_to_deg(forward.normalized().angle_to(flat.normalized())) > vision_half_angle:
		return false

	var space := _owner.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(eye, target_eye, sight_block_mask)
	if _owner is CollisionObject3D:
		query.exclude = [(_owner as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	if collider == null:
		return false
	return collider == target or target.is_ancestor_of(collider)
