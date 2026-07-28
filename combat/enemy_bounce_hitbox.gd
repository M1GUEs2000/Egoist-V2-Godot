class_name EnemyBounceHitbox extends Area3D
## Area de rebote del enemigo. Su caja se deriva de la colision corporal, asi que el
## margen para pedir salto sigue el volumen de cada enemigo y no un radio global.

var _enemy: EnemyBase
var _shape_node: CollisionShape3D
var _half_size := Vector3.ONE * 0.5

func setup(enemy: EnemyBase, body_shape: CollisionShape3D) -> void:
	_enemy = enemy
	name = "BounceHitbox"
	collision_layer = 0
	collision_mask = World.LAYER_PLAYER
	monitorable = false
	monitoring = true
	_shape_node = CollisionShape3D.new()
	_shape_node.shape = _box_from(body_shape.shape)
	_shape_node.transform = body_shape.transform
	add_child(_shape_node)
	_half_size = (_shape_node.shape as BoxShape3D).size * 0.5
	body_entered.connect(_on_body_entered)

func set_active(active: bool) -> void:
	set_deferred("monitoring", active)

func _box_from(body_shape: Shape3D) -> BoxShape3D:
	var box := BoxShape3D.new()
	if body_shape is BoxShape3D:
		box.size = (body_shape as BoxShape3D).size
	elif body_shape is SphereShape3D:
		var diameter := (body_shape as SphereShape3D).radius * 2.0
		box.size = Vector3.ONE * diameter
	elif body_shape is CapsuleShape3D:
		var capsule := body_shape as CapsuleShape3D
		box.size = Vector3(capsule.radius * 2.0, capsule.height, capsule.radius * 2.0)
	elif body_shape is CylinderShape3D:
		var cylinder := body_shape as CylinderShape3D
		box.size = Vector3(cylinder.radius * 2.0, cylinder.height, cylinder.radius * 2.0)
	else:
		push_warning("EnemyBounceHitbox: shape corporal no soportado; usando caja de 1 m.")
		box.size = Vector3.ONE
	return box

func _on_body_entered(body: Node3D) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	var bounce := body.get_node_or_null("EnemyBounce") as PlayerEnemyBounce
	if bounce == null:
		return
	bounce.remember_hitbox_contact(_enemy, _normal_for(body.global_position))

func _normal_for(point: Vector3) -> Vector3:
	var local := _shape_node.global_transform.affine_inverse() * point
	var ratios := Vector3(
		absf(local.x) / maxf(_half_size.x, 0.001),
		absf(local.y) / maxf(_half_size.y, 0.001),
		absf(local.z) / maxf(_half_size.z, 0.001))
	var local_normal := Vector3.RIGHT * signf(local.x)
	if ratios.y > ratios.x and ratios.y >= ratios.z:
		local_normal = Vector3.UP * signf(local.y)
	elif ratios.z > ratios.x:
		local_normal = Vector3.FORWARD * signf(local.z)
	if local_normal == Vector3.ZERO:
		local_normal = Vector3.UP
	return (_shape_node.global_transform.basis * local_normal).normalized()
