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
	if when == When.ON_HIT:
		var hurtbox := World.find_sibling(self, Hurtbox) as Hurtbox
		if hurtbox != null:
			hurtbox.hit.connect(_on_hit)
	else:
		var health := World.find_sibling(self, Health) as Health
		if health != null:
			health.died.connect(_on_death)

func _on_hit(_from: Node, _damage: float) -> void:
	WorldManager.switch_world(_origin())

func _on_death() -> void:
	WorldManager.switch_world(_origin())

## De dónde sale la onda del scan: de este objeto (el bloque golpeado, el enemigo que murió). Si el
## dueño no es un Node3D, sin origen: WorldManager cae al jugador.
func _origin() -> Vector3:
	var owner_3d := get_parent() as Node3D
	return owner_3d.global_position if owner_3d != null else WorldManager.NO_ORIGIN
