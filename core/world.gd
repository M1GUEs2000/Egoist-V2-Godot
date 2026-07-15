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
