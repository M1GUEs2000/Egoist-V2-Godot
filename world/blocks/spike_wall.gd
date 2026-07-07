class_name SpikeWall extends StaticBody3D
## Pared de pinchos: al tocarla stunea, rebota perpendicularmente y restaura recursos aereos.

@export var stun_duration := 0.45
@export var stun_power := 2.0
@export var push_horizontal_speed := 9.0
@export var push_vertical_speed := 5.5
@export var hit_cooldown := 0.35

var _last_hit_time := -999.0

@onready var _trigger: Area3D = $Trigger
@onready var _membership: WorldMembership = $WorldMembership

func _ready() -> void:
	collision_layer = World.LAYER_WORLD
	collision_mask = 0
	_trigger.collision_layer = 0
	_trigger.collision_mask = World.LAYER_PLAYER
	_trigger.body_entered.connect(_on_body_entered)
	if _membership != null:
		_membership.changed.connect(_on_membership_changed)
		_on_membership_changed(_membership.is_active)

func _on_body_entered(body: Node3D) -> void:
	if _membership != null and not _membership.is_active:
		return
	var player := body as Player
	if player == null:
		return
	if World.now() - _last_hit_time < hit_cooldown:
		return
	_last_hit_time = World.now()

	var push_dir := _normal_away_from(player.global_position)
	if player.has_method("try_apply_stun"):
		player.try_apply_stun(
				stun_duration,
				stun_power,
				PlayerStun.Mode.PUSH,
				push_dir,
				push_horizontal_speed,
				push_vertical_speed)
	else:
		player.apply_stun(stun_duration, PlayerStun.Mode.PUSH, push_dir, push_horizontal_speed, push_vertical_speed)
	player.restore_double_jump()
	player.restore_airdash()

func _normal_away_from(world_position: Vector3) -> Vector3:
	var normal := global_basis.z.normalized()
	var to_player := world_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.0001:
		return normal
	return normal if normal.dot(to_player) >= 0.0 else -normal

func _on_membership_changed(active: bool) -> void:
	_trigger.monitoring = active
	_trigger.monitorable = active
	for shape in _trigger.find_children("*", "CollisionShape3D"):
		(shape as CollisionShape3D).set_deferred("disabled", not active)
