class_name EnemyBounceHitbox extends Area3D
## Volumen desde el que se puede pedir el rebote sobre un enemigo. Es una caja derivada de su
## colision corporal MAS un margen, y ese margen es lo que hace pedible el rebote: la caja cruda
## coincide con la pared solida del enemigo, que frena al jugador antes de que llegue a solaparla.
##
## No bloquea movimiento ni participa en daño: solo avisa contacto. La reaccion (impulso del
## jugador, stun y push del enemigo) la decide PlayerEnemyBounce.

var _enemy: EnemyBase
var _shape: CollisionShape3D
var _half := Vector3.ONE * 0.5
## Cuerpos del jugador dentro de la caja ahora mismo. El contacto se refresca cada frame mientras
## haya alguno: avisando solo en `body_entered` la gracia vencia con el jugador todavia adentro,
## que es justo el caso de caer pegado al enemigo.
var _inside: Array[Node3D] = []
var _debug_mesh: MeshInstance3D
var _debug_material: StandardMaterial3D

## Aristas de la caja como pares de esquinas. La esquina se codifica en bits: 1 = +x, 2 = +y, 4 = +z.
const _EDGES: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 3), Vector2i(3, 2), Vector2i(2, 0),
	Vector2i(4, 5), Vector2i(5, 7), Vector2i(7, 6), Vector2i(6, 4),
	Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)]
const _COLOR_IDLE := Color(0.15, 0.75, 1.0, 0.55)     # cian: la caja existe, nadie adentro
const _COLOR_CONTACT := Color(0.25, 1.0, 0.35, 0.95)  # verde: hay contacto, el rebote es pedible

func setup(enemy: EnemyBase, body_shape: CollisionShape3D, margin: float,
		debug_draw := false) -> void:
	_enemy = enemy
	name = "BounceHitbox"
	collision_layer = 0
	collision_mask = World.LAYER_PLAYER
	monitorable = false
	monitoring = true
	_shape = CollisionShape3D.new()
	_shape.shape = _box_from(body_shape.shape, margin)
	_shape.transform = body_shape.transform
	add_child(_shape)
	_half = (_shape.shape as BoxShape3D).size * 0.5
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if debug_draw:
		_build_debug_view()
	set_physics_process(false)

## Wireframe de la caja real (misma forma y mismo transform que el CollisionShape3D, no una copia
## aparte que pueda desincronizarse). Sin sombreado y sin depth test: se ve a traves del enemigo,
## que es justamente para lo que sirve. Es ayuda de tuning, no toca ninguna colision.
func _build_debug_view() -> void:
	_debug_material = StandardMaterial3D.new()
	_debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_debug_material.no_depth_test = true
	_debug_material.albedo_color = _COLOR_IDLE
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.name = "DebugBox"
	_debug_mesh.mesh = ImmediateMesh.new()
	_debug_mesh.material_override = _debug_material
	_debug_mesh.transform = _shape.transform
	_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_debug_mesh)
	var mesh := _debug_mesh.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for edge in _EDGES:
		mesh.surface_add_vertex(_corner(edge.x))
		mesh.surface_add_vertex(_corner(edge.y))
	mesh.surface_end()

func _corner(index: int) -> Vector3:
	return Vector3(
		_half.x if (index & 1) != 0 else -_half.x,
		_half.y if (index & 2) != 0 else -_half.y,
		_half.z if (index & 4) != 0 else -_half.z)

## Sigue la actividad por mundo y la muerte del enemigo: un enemigo apagado no es plataforma.
func set_active(active: bool) -> void:
	set_deferred("monitoring", active)
	if not active:
		_inside.clear()
		set_physics_process(false)
	# El wireframe sigue el estado REAL de la caja: si desaparece es porque el enemigo dejo de ser
	# plataforma (muerto o fuera del mundo activo), no porque el dibujo se haya perdido.
	if _debug_mesh != null:
		_debug_mesh.visible = active
		_paint_debug()

## Caja circunscrita al shape corporal, crecida `margin` a cada lado de cada eje.
func _box_from(body_shape: Shape3D, margin: float) -> BoxShape3D:
	var box := BoxShape3D.new()
	if body_shape is BoxShape3D:
		box.size = (body_shape as BoxShape3D).size
	elif body_shape is SphereShape3D:
		box.size = Vector3.ONE * (body_shape as SphereShape3D).radius * 2.0
	elif body_shape is CapsuleShape3D:
		var capsule := body_shape as CapsuleShape3D
		box.size = Vector3(capsule.radius * 2.0, capsule.height, capsule.radius * 2.0)
	elif body_shape is CylinderShape3D:
		var cylinder := body_shape as CylinderShape3D
		box.size = Vector3(cylinder.radius * 2.0, cylinder.height, cylinder.radius * 2.0)
	else:
		push_warning("EnemyBounceHitbox: shape corporal no soportado; usando caja de 1 m.")
		box.size = Vector3.ONE
	box.size += Vector3.ONE * maxf(0.0, margin) * 2.0
	return box

func _on_body_entered(body: Node3D) -> void:
	if _bounce_of(body) == null:
		return
	if not _inside.has(body):
		_inside.append(body)
	set_physics_process(true)
	_paint_debug()
	_report(body)

func _on_body_exited(body: Node3D) -> void:
	_inside.erase(body)
	if _inside.is_empty():
		set_physics_process(false)
	_paint_debug()

func _paint_debug() -> void:
	if _debug_material != null:
		_debug_material.albedo_color = _COLOR_CONTACT if not _inside.is_empty() else _COLOR_IDLE

func _physics_process(_delta: float) -> void:
	for body in _inside:
		if is_instance_valid(body):
			_report(body)

func _report(body: Node3D) -> void:
	if _enemy == null or not is_instance_valid(_enemy):
		return
	var bounce := _bounce_of(body)
	if bounce != null:
		bounce.remember_contact(_enemy, _normal_for(_center_of(body)))

func _bounce_of(body: Node3D) -> PlayerEnemyBounce:
	return body.get_node_or_null("EnemyBounce") as PlayerEnemyBounce

## El origen del Player esta en los pies. Medir desde ahi clasifica un contacto lateral bajo como
## cara inferior, y el rebote lateral se degrada a stomp (normal sin componente horizontal). La
## cara se decide desde el centro del cuerpo.
func _center_of(body: Node3D) -> Vector3:
	var shape := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	return shape.global_position if shape != null else body.global_position

## Cara de la caja mas cercana al punto, en coordenadas de mundo. Define hacia donde sale el
## jugador: horizontal = rebote lateral, vertical pura = stomp.
func _normal_for(point: Vector3) -> Vector3:
	var local := _shape.global_transform.affine_inverse() * point
	var ratios := Vector3(
		absf(local.x) / maxf(_half.x, 0.001),
		absf(local.y) / maxf(_half.y, 0.001),
		absf(local.z) / maxf(_half.z, 0.001))
	# Los tres ejes se arman con el vector POSITIVO (RIGHT/UP/BACK) por el signo de la coordenada
	# local: la normal tiene que apuntar del enemigo HACIA el punto. Ojo con Vector3.FORWARD, que en
	# Godot es (0,0,-1) y aca invertiria la cara Z entera.
	var normal := Vector3.RIGHT * signf(local.x)
	if ratios.y > ratios.x and ratios.y >= ratios.z:
		normal = Vector3.UP * signf(local.y)
	elif ratios.z > ratios.x:
		normal = Vector3.BACK * signf(local.z)
	if normal == Vector3.ZERO:
		normal = Vector3.UP
	return (_shape.global_transform.basis * normal).normalized()
