class_name WallImpulseSurface extends Node3D
## Marca un StaticBody3D como pared de impulso. PlayerWallSlide captura el primer input
## tangencial valido al engancharse y acelera en esa direccion hasta perder el contacto.

## Cada pared puede usar un .tres distinto para tunear movimiento y particulas.
@export var tuning: WallImpulseTuning

## Semilla fija: la siembra de puntos debe ser identica en cada corrida, si no la pared
## cambia de aspecto entre partidas y deja de poder tunearse.
const _SEED := 20260719

var _emit_particles: Array[GPUParticles3D] = []
var _contact_particles: GPUParticles3D
var _particle_light: OmniLight3D

func _ready() -> void:
	# Senal permanente: solo sobre las caras marcadas en Blender con el material emisor.
	# Cada punto guarda su normal, asi una pared curva expulsa perpendicular en cada tramo.
	_build_emit_particles()
	# Refuerzo movil: solo aparece en el contacto durante Wall Impulse.
	_contact_particles = _make_particles(true)
	if _contact_particles != null:
		add_child(_contact_particles)
	_particle_light = _make_particle_light()

## El efecto vive en el punto donde esta el player, no en el origen del mesh. Asi una pared
## curva o muy larga siempre brilla justo donde se esta usando el Wall Impulse.
func set_impulse_active(active: bool, player_position: Vector3 = Vector3.ZERO,
		wall_normal: Vector3 = Vector3.ZERO) -> void:
	if active:
		_update_effect_position(player_position, wall_normal)
	if _contact_particles != null and _contact_particles.emitting != active:
		if active:
			_contact_particles.restart()
		_contact_particles.emitting = active
	if _particle_light != null:
		_particle_light.visible = active

func _update_effect_position(player_position: Vector3, wall_normal: Vector3) -> void:
	if player_position == Vector3.ZERO:
		return
	var normal := wall_normal.normalized() if wall_normal.length_squared() > 0.0001 else Vector3.ZERO
	# La normal mira desde el muro hacia el jugador; retroceder medio radio acerca las motas a la cara.
	var effect_position := player_position - normal * 0.5
	if _contact_particles != null:
		_contact_particles.global_position = effect_position
	if _particle_light != null:
		_particle_light.global_position = effect_position + Vector3.UP * 0.35

## Igual que TraversalBlock: la feature inyecta su emisor por codigo. Cualquier pared solo
## necesita WallImpulseSurface + tuning; nunca se cablea un GPUParticles3D a mano.
## Una pared sin caras marcadas no emite ambiente: es la senal de que falta pintarle el
## material emisor en Blender.
func _build_emit_particles() -> void:
	if tuning == null or not tuning.particles_enabled:
		return
	# WallImpulseSurface cuelga del StaticBody; la malla importada es su abuelo o un hijo suyo.
	var visual_root := get_parent().get_parent() as Node3D
	if visual_root == null:
		visual_root = get_parent() as Node3D
	if visual_root == null:
		return
	# La malla importada suele ser el propio visual_root, y find_children no se incluye a si
	# mismo: sin esto una pared .blend nunca encontraria su superficie marcada.
	var candidates: Array[Node] = []
	if visual_root is MeshInstance3D:
		candidates.append(visual_root)
	candidates.append_array(visual_root.find_children("*", "MeshInstance3D", true, false))
	for node in candidates:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var surface := _find_emit_surface(mesh_instance)
		if surface < 0:
			continue
		var particles := _make_emit_particles(mesh_instance, surface)
		if particles == null:
			continue
		# Diferido: _ready corre mientras la malla padre todavia esta armando sus hijos,
		# y un add_child directo sobre ella se rechaza.
		mesh_instance.add_child.call_deferred(particles)
		_emit_particles.append(particles)
		if tuning.hide_emit_material:
			_hide_emit_material(mesh_instance, surface)

## Indice de la superficie cuyo material es el marcador. El importador ya separa la malla
## en una superficie por material, asi que la cara marcada llega sola y aislada.
func _find_emit_surface(mesh_instance: MeshInstance3D) -> int:
	var mesh := mesh_instance.mesh
	for i in mesh.get_surface_count():
		var material := mesh_instance.get_active_material(i)
		if material == null:
			continue
		if _material_name(material) == tuning.emit_material_name:
			return i
	return -1

func _material_name(material: Material) -> String:
	if not material.resource_name.is_empty():
		return material.resource_name
	return material.resource_path.get_file().get_basename()

## El marcador es dato, no arte: en juego la cara vuelve a verse como el resto de la pared.
func _hide_emit_material(mesh_instance: MeshInstance3D, emit_surface: int) -> void:
	var mesh := mesh_instance.mesh
	for i in mesh.get_surface_count():
		if i == emit_surface:
			continue
		var material := mesh_instance.get_active_material(i)
		if material != null:
			mesh_instance.set_surface_override_material(emit_surface, material)
			return
	# Malla dedicada solo a marcar (un PlaneMesh pegado a una pared hecha en Godot): no hay
	# material hermano que copiar. Se vuelve transparente en vez de ocultar el nodo, porque
	# el emisor cuelga de el y ocultarlo apagaria tambien las particulas.
	var invisible := StandardMaterial3D.new()
	invisible.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	invisible.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	invisible.albedo_color = Color(0.0, 0.0, 0.0, 0.0)
	mesh_instance.set_surface_override_material(emit_surface, invisible)

func _make_emit_particles(mesh_instance: MeshInstance3D, surface: int) -> GPUParticles3D:
	var particles := _make_particles(false)
	if particles == null:
		return null
	var sampled := _sample_surface(mesh_instance.mesh, surface, tuning.emit_point_count)
	var positions: PackedVector3Array = sampled[0]
	var normals: PackedVector3Array = sampled[1]
	if positions.is_empty():
		particles.queue_free()
		return null

	var process := particles.process_material as ParticleProcessMaterial
	# Puntos dirigidos: cada mota nace en un punto de la cara y sale por la normal de ese punto.
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_DIRECTED_POINTS
	process.emission_point_count = positions.size()
	process.emission_point_texture = _vector_texture(positions)
	process.emission_normal_texture = _vector_texture(normals)
	process.spread = tuning.emit_spread_degrees
	# Gravedad propia: el emisor de pared no hereda la caida del emisor de contacto, asi las
	# motas pueden salir perpendiculares y quedarse horizontales.
	process.gravity = Vector3(0.0, tuning.emit_gravity, 0.0)

	# Sin AABB explicito Godot puede cullear el emisor al mirar la pared de costado.
	particles.visibility_aabb = mesh_instance.get_aabb().grow(4.0)
	return particles

## Reparte puntos sobre los triangulos de una superficie, ponderando por area para que los
## triangulos grandes reciban proporcionalmente mas motas. Devuelve [posiciones, normales].
func _sample_surface(mesh: Mesh, surface: int, count: int) -> Array:
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var arrays := mesh.surface_get_arrays(surface)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var vertex_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	if vertices.is_empty():
		return [positions, normals]

	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for i in vertices.size():
			indices.append(i)

	@warning_ignore("integer_division")
	var triangle_count := indices.size() / 3
	if triangle_count <= 0:
		return [positions, normals]

	# Areas acumuladas: elegir triangulo es una busqueda binaria sobre este arreglo.
	var cumulative := PackedFloat32Array()
	cumulative.resize(triangle_count)
	var total := 0.0
	for t in triangle_count:
		var a := vertices[indices[t * 3]]
		var b := vertices[indices[t * 3 + 1]]
		var c := vertices[indices[t * 3 + 2]]
		total += (b - a).cross(c - a).length() * 0.5
		cumulative[t] = total
	if total <= 0.0:
		return [positions, normals]

	var rng := RandomNumberGenerator.new()
	rng.seed = _SEED
	for _i in count:
		var t: int = mini(cumulative.bsearch(rng.randf() * total), triangle_count - 1)
		var i0 := indices[t * 3]
		var i1 := indices[t * 3 + 1]
		var i2 := indices[t * 3 + 2]
		# Baricentricas uniformes: plegar la esquina sobrante mantiene el reparto parejo.
		var u := rng.randf()
		var v := rng.randf()
		if u + v > 1.0:
			u = 1.0 - u
			v = 1.0 - v
		var a := vertices[i0]
		positions.append(a + (vertices[i1] - a) * u + (vertices[i2] - a) * v)
		if vertex_normals.size() > i2:
			var n := vertex_normals[i0] * (1.0 - u - v) \
					+ vertex_normals[i1] * u + vertex_normals[i2] * v
			normals.append(n.normalized() if n.length_squared() > 0.0001 else Vector3.UP)
		else:
			var face_normal := (vertices[i1] - a).cross(vertices[i2] - a)
			normals.append(face_normal.normalized() if face_normal.length_squared() > 0.0001
					else Vector3.UP)
	return [positions, normals]

## Empaqueta vectores en una textura de una fila: es el formato en el que
## ParticleProcessMaterial lee posiciones y normales de emision desde la GPU.
func _vector_texture(values: PackedVector3Array) -> ImageTexture:
	var image := Image.create_empty(values.size(), 1, false, Image.FORMAT_RGBF)
	for i in values.size():
		var v := values[i]
		image.set_pixel(i, 0, Color(v.x, v.y, v.z))
	return ImageTexture.create_from_image(image)

func _make_particles(follows_player: bool) -> GPUParticles3D:
	if tuning == null or not tuning.particles_enabled:
		return null
	var particles := GPUParticles3D.new()
	particles.name = "WallImpulseContactParticles" if follows_player else "WallImpulseEmitParticles"
	particles.emitting = not follows_player
	particles.amount = tuning.particle_amount
	particles.lifetime = tuning.particle_lifetime
	# Las motas caen en espacio de mundo: asi la gravedad no depende de como este rotada la malla.
	particles.local_coords = false
	particles.top_level = follows_player
	if follows_player:
		particles.visibility_aabb = AABB(Vector3(-6.0, -6.0, -6.0), Vector3(12.0, 12.0, 12.0))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# El emisor de pared reemplaza esta forma por puntos dirigidos en _make_emit_particles.
	process.emission_box_extents = Vector3(1.5, 2.0, 0.08)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 12.0 if not follows_player else 35.0
	process.gravity = Vector3(0.0, -tuning.particle_speed, 0.0)
	process.initial_velocity_min = tuning.particle_speed * 0.25
	process.initial_velocity_max = tuning.particle_speed
	process.scale_min = 0.55
	process.scale_max = 1.0
	particles.process_material = process

	var mesh := QuadMesh.new()
	mesh.size = Vector2(tuning.particle_size, tuning.particle_size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.emission_enabled = true
	material.albedo_color = World.COLOR_TRAVERSAL_DASH
	material.emission = World.COLOR_TRAVERSAL_DASH_EMISSION
	material.emission_energy_multiplier = (tuning.particle_emission_energy if follows_player
			else tuning.particle_idle_emission_energy)
	mesh.material = material
	particles.draw_pass_1 = mesh
	return particles

func _make_particle_light() -> OmniLight3D:
	if tuning == null or not tuning.particles_enabled or tuning.particle_light_energy <= 0.0:
		return null
	var light := OmniLight3D.new()
	light.name = "WallImpulseGlow"
	light.top_level = true
	light.visible = false
	light.shadow_enabled = false
	light.light_color = World.COLOR_TRAVERSAL_DASH
	light.light_energy = tuning.particle_light_energy
	light.omni_range = tuning.particle_light_range
	add_child(light)
	return light
