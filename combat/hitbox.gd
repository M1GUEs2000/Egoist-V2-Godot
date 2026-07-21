class_name Hitbox extends Area3D
## Lo que golpea (unifica WeaponTraceHitbox / ConeLauncherHitbox / AirDiscHitbox de v1).
## Tonto a propósito: detecta Hurtboxes, deduplica por swing y entrega el golpe.
## Quién lo prende/apaga y qué pasa al conectar lo decide el dueño (arma/ataque) vía landed.

signal landed(hurtbox: Hurtbox, died: bool)
## Se emite ANTES de aplicar el daño de un golpe que sí va a conectar (no parriado). El dueño
## engancha reacciones que deben ocurrir primero: p.ej. el launcher lanza al enemigo aquí, así
## receive_hit ya lo ve en el aire y usa el stun aéreo (ex ConeLauncherHitbox: lanza y luego TakeHit).
signal about_to_hit(hurtbox: Hurtbox)
## El dueño del hurtbox parrió este golpe (melee mid-swing): no hubo daño (ex gizmo cyan de v1).
signal parried(hurtbox: Hurtbox)

@export var damage := 1.0
@export var stun: StunSettings
## Si el objetivo puede parriar (has_method try_parry) se le da la chance antes del daño.
## El launcher lo apaga: en v1 el cono nunca preguntaba parry (ver ConeLauncherHitbox).
@export var can_be_parried := true

## Quien ataca: su propia hurtbox se ignora (se setea al crear el arma/ataque).
var source: Node

var _already_hit: Array[Hurtbox] = []

## Gizmo de debug: dibuja el shape de la CollisionShape3D hija solo mientras el hitbox esta
## activo (begin_swing/end_swing), en vez de depender del "Visible Collision Shapes" del motor
## (ese es todo-o-nada, siempre prendido). Solo existe en builds de debug.
var _debug_gizmo: MeshInstance3D
## El dueño (arma) lo apaga con set_debug_enabled(false) si quiere ocultar sus gizmos sin
## tocar el resto de hitboxes. true por default: se ve mientras haya build de debug.
var _debug_enabled := true

func _ready() -> void:
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = World.LAYER_HURTBOX  # solo detecto hurtboxes
	area_entered.connect(_on_area_entered)
	if OS.is_debug_build():
		_build_debug_gizmo()

## Varios hitboxes de la misma arma (hoja + disco aéreo) comparten el dedup:
## un enemigo cuenta una sola vez por swing aunque lo toquen los dos.
func share_already_hit(shared: Array[Hurtbox]) -> void:
	_already_hit = shared

## Prende/apaga el gizmo de este hitbox especifico. Si se apaga a mitad de un swing activo,
## se oculta al toque (no espera al end_swing).
func set_debug_enabled(enabled: bool) -> void:
	_debug_enabled = enabled
	if _debug_gizmo != null and not enabled:
		_debug_gizmo.visible = false

## El dueño llama esto al iniciar un swing: limpia dedup y prende detección.
func begin_swing() -> void:
	_already_hit.clear()
	monitoring = true
	if _debug_gizmo != null and _debug_enabled:
		_debug_gizmo.visible = true

func end_swing() -> void:
	monitoring = false
	if _debug_gizmo != null:
		_debug_gizmo.visible = false

func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or hurtbox in _already_hit:
		return
	if source != null and hurtbox.owner_node == source:
		return
	var direction := (hurtbox.global_position - global_position).normalized()
	var target := hurtbox.owner_node
	var attacker_enemy := source as EnemyBase
	var target_enemy := target as EnemyBase
	if attacker_enemy != null and target_enemy != null \
			and not EnemyBase.can_damage_enemy(attacker_enemy, target_enemy):
		return
	_already_hit.append(hurtbox)
	# Parry: si el dueño puede parriar ESTE golpe ahora mismo (melee mid-swing en su ventana),
	# se auto-stunea y el golpe NO hace daño (ex WeaponTraceHitbox: TryParry antes de TakeHit).
	if can_be_parried and target != null and target.has_method("try_parry") \
			and target.call("try_parry", source, direction):
		parried.emit(hurtbox)
		return
	about_to_hit.emit(hurtbox)  # reacciones pre-daño (ej: el launcher lanza primero)
	var died := hurtbox.receive_hit(source, damage, direction, stun)
	landed.emit(hurtbox, died)

## Arma un wireframe rojo del shape de la primera CollisionShape3D hija (misma transform local:
## sigue al hitbox si este se mueve/orbita) y lo deja oculto hasta el primer begin_swing().
func _build_debug_gizmo() -> void:
	var col := _find_collision_shape()
	if col == null or col.shape == null:
		return
	var verts := PackedVector3Array()
	_append_shape_wireframe(col.shape, verts)
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.0, 0.0)
	mat.no_depth_test = true
	_debug_gizmo = MeshInstance3D.new()
	_debug_gizmo.mesh = mesh
	_debug_gizmo.transform = col.transform
	_debug_gizmo.visible = false
	add_child(_debug_gizmo)

func _find_collision_shape() -> CollisionShape3D:
	for child in get_children():
		if child is CollisionShape3D:
			return child
	return null

func _append_shape_wireframe(shape: Shape3D, verts: PackedVector3Array) -> void:
	if shape is BoxShape3D:
		_append_box_wireframe((shape as BoxShape3D).size * 0.5, verts)
	elif shape is SphereShape3D:
		_append_sphere_wireframe((shape as SphereShape3D).radius, verts)
	elif shape is CapsuleShape3D:
		_append_capsule_wireframe(shape as CapsuleShape3D, verts)
	# Otros Shape3D (no usados hoy por ninguna arma) quedan sin gizmo en vez de romper.

func _append_box_wireframe(half: Vector3, verts: PackedVector3Array) -> void:
	var c := [
		Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, half.z), Vector3(-half.x, -half.y, half.z),
		Vector3(-half.x, half.y, -half.z), Vector3(half.x, half.y, -half.z),
		Vector3(half.x, half.y, half.z), Vector3(-half.x, half.y, half.z),
	]
	var edges := [
		[0, 1], [1, 2], [2, 3], [3, 0],
		[4, 5], [5, 6], [6, 7], [7, 4],
		[0, 4], [1, 5], [2, 6], [3, 7],
	]
	for e in edges:
		verts.append(c[e[0]])
		verts.append(c[e[1]])

## axis 0 = circulo en YZ, 1 = XZ, 2 = XY.
func _append_circle(radius: float, axis: int, verts: PackedVector3Array, segments := 24) -> void:
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		verts.append(_circle_point(radius, axis, a0))
		verts.append(_circle_point(radius, axis, a1))

func _circle_point(radius: float, axis: int, angle: float) -> Vector3:
	var x := cos(angle) * radius
	var y := sin(angle) * radius
	match axis:
		0: return Vector3(0.0, x, y)
		1: return Vector3(x, 0.0, y)
		_: return Vector3(x, y, 0.0)

func _append_sphere_wireframe(radius: float, verts: PackedVector3Array) -> void:
	_append_circle(radius, 0, verts)
	_append_circle(radius, 1, verts)
	_append_circle(radius, 2, verts)

func _append_capsule_wireframe(shape: CapsuleShape3D, verts: PackedVector3Array) -> void:
	var half_seg := shape.height * 0.5 - shape.radius
	_append_circle(shape.radius, 0, verts)
	for v in verts.size():
		verts[v] += Vector3(0.0, half_seg, 0.0)
	var top_count := verts.size()
	_append_circle(shape.radius, 0, verts)
	for v in range(top_count, verts.size()):
		verts[v] += Vector3(0.0, -half_seg, 0.0)
	_append_circle(shape.radius, 2, verts)
