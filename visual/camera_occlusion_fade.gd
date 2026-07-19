class_name CameraOcclusionFade extends Node
## Hace semitransparentes los muros del mundo que quedan entre la camara y el jugador:
## raycast camara -> jugador cada frame de fisica; lo que estorba se desvanece (se sigue
## viendo que esta ahi) y recupera su material original apenas deja de tapar.

## Opacidad del muro mientras tapa (0 = casi invisible, 1 = solido).
@export_range(0.05, 1.0) var fade_alpha := 0.35
## El rayo apunta a esta altura sobre el pivote del jugador (centro de masa).
@export var target_height_offset := 1.0
## Cuantos obstaculos en fila se pueden desvanecer a la vez.
@export var max_occluders := 4
## Tras dejar de tapar, el muro espera esto (s) antes de volver a solido: evita titileo
## cuando la camara esta justo en el borde o dentro de la pared.
@export var restore_delay := 0.2

var _rig: CameraRig
var _cam: Camera3D
var _faded := {}  # MeshInstance3D -> {"override": Material, "surfaces": Array} para restaurar
var _last_occluding := {}  # MeshInstance3D -> World.now() de la ultima vez que tapaba

func _ready() -> void:
	_rig = get_parent() as CameraRig
	if _rig != null:
		for child in _rig.get_children():
			if child is Camera3D:
				_cam = child
				break

func _physics_process(_delta: float) -> void:
	if _rig == null or _cam == null or _rig.target == null:
		_restore_all()
		return
	var space := _cam.get_world_3d().direct_space_state
	var from := _cam.global_position
	var to: Vector3 = _rig.target.global_position + Vector3.UP * target_height_offset
	var occluding := {}
	var exclude: Array[RID] = []
	for i in range(max_occluders):
		var query := PhysicsRayQueryParameters3D.create(from, to, World.LAYER_WORLD, exclude)
		# Si la camara queda DENTRO del muro, el rayo nace adentro del colisionador:
		# sin esto no lo reporta y el fade titila segun el vaiven del follow.
		query.hit_from_inside = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		exclude.append(hit["rid"])
		var collider := hit["collider"] as Node
		if collider == null:
			continue
		for mesh in _meshes_of(collider):
			occluding[mesh] = true
			_last_occluding[mesh] = World.now()
			_fade_mesh(mesh)
	for mesh in _faded.keys():
		if occluding.has(mesh):
			continue
		# Gracia antes de restaurar: en el borde de la pared el rayo entra y sale
		# frame a frame; sin esta espera el muro parpadea solido/transparente.
		if World.now() - (_last_occluding.get(mesh, 0.0) as float) < restore_delay:
			continue
		_restore_mesh(mesh)
		_last_occluding.erase(mesh)

## Mallas que le corresponden a un collider golpeado por el rayo.
## Hay dos jerarquias segun de donde venga la pared:
##   - armada a mano: StaticBody3D padre, MeshInstance3D hijo -> se busca hacia abajo;
##   - importada de .blend (sufijo -col): MeshInstance3D padre, StaticBody3D hijo -> hacia arriba.
## Sin el caso "hacia arriba" las paredes de assets/models/walls nunca se desvanecian.
func _meshes_of(collider: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for mesh in collider.find_children("*", "MeshInstance3D", true, false):
		found.append(mesh as MeshInstance3D)
	if not found.is_empty():
		return found
	var ancestor := collider.get_parent()
	while ancestor != null:
		if ancestor is MeshInstance3D:
			found.append(ancestor as MeshInstance3D)
			break
		ancestor = ancestor.get_parent()
	return found

func _fade_mesh(mesh: MeshInstance3D) -> void:
	if _faded.has(mesh):
		return
	var entry := {"override": mesh.material_override, "surfaces": []}
	if mesh.material_override != null:
		mesh.material_override = _transparent_version(mesh.material_override)
	else:
		for s in range(mesh.get_surface_override_material_count()):
			var original := mesh.get_surface_override_material(s)
			(entry["surfaces"] as Array).append(original)
			var base := original
			if base == null and mesh.mesh != null:
				base = mesh.mesh.surface_get_material(s)
			mesh.set_surface_override_material(s, _transparent_version(base))
	_faded[mesh] = entry

func _restore_mesh(mesh: MeshInstance3D) -> void:
	var entry: Dictionary = _faded[mesh]
	_faded.erase(mesh)
	if not is_instance_valid(mesh):
		return
	if entry["override"] != null:
		mesh.material_override = entry["override"]
	else:
		var surfaces: Array = entry["surfaces"]
		for s in range(surfaces.size()):
			mesh.set_surface_override_material(s, surfaces[s])

func _restore_all() -> void:
	for mesh in _faded.keys():
		_restore_mesh(mesh)

## Duplica el material del muro en version transparente (conserva color/aspecto).
func _transparent_version(base: Material) -> BaseMaterial3D:
	var mat: BaseMaterial3D
	if base is BaseMaterial3D:
		mat = (base as BaseMaterial3D).duplicate() as BaseMaterial3D
	else:
		mat = StandardMaterial3D.new()
	# Depth pre-pass, no alpha puro: la profundidad se dibuja como opaco, asi el muro
	# conserva su sombra y sus caras no se pelean por el orden de dibujado (titileo).
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	mat.albedo_color.a = fade_alpha
	return mat
