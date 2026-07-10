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
