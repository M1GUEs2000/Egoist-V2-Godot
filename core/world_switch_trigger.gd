class_name WorldSwitchTrigger extends Node
## Módulo componible (ex WorldSwitchTrigger.cs): qué le hace este objeto/enemigo al mundo
## de TODOS cuando pasa algo. Eje ortogonal a WorldMembership (dónde vivo yo).
##
##  - ON_HIT:   voltea el mundo global en CADA golpe (escucha Hurtbox.hit del hermano).
##               Combinar con Health: 1 golpe de vida → pickup que se gasta;
##               sin Health / indestructible → palanca permanente.
##  - ON_DEATH: voltea el mundo global al morir (escucha Health.died del hermano).
##
## No exige las piezas: según el modo depende de hermanos distintos; el objeto ya trae la suya.

enum When { ON_HIT, ON_DEATH }

@export var when := When.ON_HIT

func _ready() -> void:
	for sibling in get_parent().get_children():
		if when == When.ON_HIT and sibling is Hurtbox:
			sibling.hit.connect(_on_hit)
			return
		if when == When.ON_DEATH and sibling is Health:
			sibling.died.connect(WorldManager.switch_world)
			return

func _on_hit(_from: Node, _damage: float) -> void:
	WorldManager.switch_world()
