class_name World
## Enums y constantes base (ex WorldState.cs) + capas de física del proyecto.

enum Kind { LIVING, DEAD }
enum Slot { X, Y }

# Capas de física 3D (bits). Los scripts las setean por código en _ready —
# nada de configurarlas a mano en el editor (menos cosas que se desconfiguran).
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_HURTBOX := 8

## Tiempo que tarda en subir un launch (jugador y enemigos comparten el mismo feel).
const LAUNCH_RISE_TIME := 0.15

# ---- Convención de color de los mundos (greybox, hasta que haya arte) ----
## NARANJA = vivo, MORADO = muerto. Regla del proyecto: toda pieza que exista en los dos
## mundos se tiñe desde acá y NO hardcodea el color en su .tscn — el día que cambie la
## paleta, cambia en un solo lugar. Ver bóveda Gameplay/Traversal.
## Los colores de MUNDO y los de FEATURE de traversal son independientes: una feature nunca
## reusa un color de mundo, o choca con el bloque de world switch que apunta a ese mundo.
const COLOR_LIVING := Color(1.0, 0.55, 0.05)
const COLOR_LIVING_EMISSION := Color(0.9, 0.4, 0.03)
const COLOR_DEAD := Color(0.55, 0.15, 0.9)
const COLOR_DEAD_EMISSION := Color(0.35, 0.05, 0.8)
## Launch/bump tiene color PROPIO (rojo), NO el del mundo vivo. Si usara COLOR_LIVING
## chocaría con el bloque de world switch al vivo (que ya usa el color del mundo destino).
const COLOR_TRAVERSAL_LAUNCH := Color(0.9, 0.1, 0.08)
const COLOR_TRAVERSAL_LAUNCH_EMISSION := Color(0.7, 0.05, 0.03)
const COLOR_TRAVERSAL_DASH := Color(0.1, 0.85, 0.25)
const COLOR_TRAVERSAL_DASH_EMISSION := Color(0.05, 0.65, 0.14)
const COLOR_TRAVERSAL_METER := Color(0.15, 0.85, 1.0)
const COLOR_TRAVERSAL_METER_EMISSION := Color(0.05, 0.55, 0.85)
const COLOR_TRAVERSAL_CURSE := Color(1.0, 0.85, 0.1)
const COLOR_TRAVERSAL_CURSE_EMISSION := Color(1.0, 0.65, 0.05)

# ---- Texturas prototipo por afiliacion (greybox de Structures, pack CC0 Kenney) ----
## Mismo pack que el resto del greybox: cambia el archivo aca y cambia para toda pieza
## que use WorldMembership.paint_prototype_material o PrototypeDefaultPaint. NARANJA = vivo,
## MORADO = muerto (ver COLOR_LIVING/COLOR_DEAD arriba); LIGHT = pieza en ambos mundos;
## VERDE = pieza sin WorldMembership (no tiene afiliacion).
# texture_09 = relleno sólido del color + líneas de grilla. Las variantes _01/_02/_11 son
# "contorno de color con relleno BLANCO": sobre una cara grande se ven casi blancas.
const PROTOTYPE_TEXTURE_LIVING: Texture2D = preload("res://assets/textures/kenney_prototype-textures/PNG/Orange/texture_09.png")
const PROTOTYPE_TEXTURE_DEAD: Texture2D = preload("res://assets/textures/kenney_prototype-textures/PNG/Purple/texture_09.png")
# Light no sigue la numeracion de los colores: su _09 es relleno BLANCO (se ve casi sin
# pintar). _07 es el gris solido claro con grilla, el que lee como pieza neutra de "ambos".
const PROTOTYPE_TEXTURE_BOTH: Texture2D = preload("res://assets/textures/kenney_prototype-textures/PNG/Light/texture_07.png")
const PROTOTYPE_TEXTURE_NONE: Texture2D = preload("res://assets/textures/kenney_prototype-textures/PNG/Green/texture_09.png")

## Material greybox para una pieza de Structures a partir de una textura prototipo de arriba.
## Triplanar porque las piezas del pack modular no traen UVs pensadas para esta grilla.
static func prototype_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.uv1_triplanar = true
	return material

## Pinta TODAS las superficies de cada MeshInstance3D bajo `root` con `material`. OJO:
## `surface_override_material` es indexada, no una propiedad asignable directo — se escribe
## con set_surface_override_material(idx, mat). `owned=false` para que tambien encuentre los
## meshes de cuerpos instanciados por codigo (sin owner), no solo los guardados en el .tscn.
static func paint_all_surfaces(root: Node, material: Material) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(surface, material)

## Estallido one-shot de motas de un color, en `position` global. Se cuelga de `host` (que debe
## estar en el arbol) y se libera solo al terminar. Motas unshaded + billboard + additive: puro
## color que suma luz. Lo usan el bloque de traversal al golpearlo y el bop de salida del dash
## verde (ver TraversalBlock y PlayerDash).
static func spawn_color_burst(host: Node, position: Vector3, color: Color, emission: Color,
		amount: int, speed: float, gravity: float, lifetime: float, size: float) -> void:
	if host == null or amount <= 0:
		return
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0  # todas las motas salen en el mismo frame = estallido
	particles.amount = amount
	particles.lifetime = lifetime
	particles.local_coords = false

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.4
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 180.0  # esfera completa: sale para todos lados
	process.initial_velocity_min = speed * 0.4
	process.initial_velocity_max = speed
	process.gravity = Vector3(0.0, -gravity, 0.0)
	process.scale_min = 0.6
	process.scale_max = 1.0
	particles.process_material = process

	particles.draw_pass_1 = make_mote_mesh(color, emission, size)

	host.add_child(particles)
	particles.global_position = position
	particles.emitting = true
	particles.finished.connect(particles.queue_free)  # one_shot no se libera solo

## Emisor CONTINUO de las MISMAS motas que el estallido, para colgar de cualquier nodo y
## prender/apagar con `emitting` (no se libera solo: es del nodo que lo cuelga). Las motas
## nacen en una esfera de `radius` y suben flotando a `rise_speed` m/s, sin gravedad.
## Lo usa el aura de la ventana de sweet spot en la hoja (ver WeaponBase).
static func make_color_motes(color: Color, emission: Color, amount: int, lifetime: float,
		size: float, radius: float, rise_speed: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.amount = maxi(1, amount)
	particles.lifetime = lifetime
	particles.local_coords = false  # las motas quedan atras: la hoja deja estela al moverse

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = radius
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 25.0
	process.initial_velocity_min = rise_speed * 0.3
	process.initial_velocity_max = rise_speed
	process.gravity = Vector3.ZERO
	process.scale_min = 0.6
	process.scale_max = 1.0
	particles.process_material = process

	particles.draw_pass_1 = make_mote_mesh(color, emission, size)
	return particles

## Una mota: quad unshaded + billboard + additive, puro color que suma luz. Es la receta
## visual compartida por el estallido de los bloques de traversal y los emisores continuos.
static func make_mote_mesh(color: Color, emission: Color, size: float) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.emission_enabled = true
	material.emission = emission
	material.albedo_color = color
	mesh.material = material
	return mesh

## Color base de una pieza segun el mundo al que pertenece.
static func world_color(kind: Kind) -> Color:
	return COLOR_LIVING if kind == Kind.LIVING else COLOR_DEAD

## Color de emision (glow) para el mismo mundo.
static func world_emission(kind: Kind) -> Color:
	return COLOR_LIVING_EMISSION if kind == Kind.LIVING else COLOR_DEAD_EMISSION

static func opposite_world(kind: Kind) -> Kind:
	return Kind.DEAD if kind == Kind.LIVING else Kind.LIVING

## Reloj del juego en segundos (equivale a Time.time de Unity).
static func now() -> float:
	return Time.get_ticks_msec() / 1000.0

## Primer hermano de `node` que sea instancia de `type` (class_name o clase nativa),
## o null. Único punto para el cableado "módulo hijo busca a su módulo hermano".
static func find_sibling(node: Node, type: Variant) -> Node:
	for sibling in node.get_parent().get_children():
		if sibling != node and is_instance_of(sibling, type):
			return sibling
	return null
