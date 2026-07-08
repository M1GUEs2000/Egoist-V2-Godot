class_name WorldMembership extends Node
## Módulo componible (ex WorldMembership.cs): SOLO decide en qué mundo está activo el dueño
## (dónde aparece / es golpeable), desacoplado de qué le hace al mundo de los demás
## (eso es WorldSwitchTrigger). Nodo hijo del objeto/enemigo; absorbe las 4 subclases de v1.
##
##  - FIXED:   activo solo en su mundo (afiliación fija).           [enemigo por defecto]
##  - BOTH:    activo siempre, en ambos mundos.
##  - TIMED:   voltea su afiliación cada shift_interval segundos.
##  - FOLLOWS: su afiliación sigue al mundo actual (siempre activo).
##
## hide_when_inactive: si true, apaga visible + colisión del padre al quedar inactivo.
## Si false no toca visuales — solo emite changed y el dueño decide (el enemigo usa
## su propio ghost al 50%, así que lo pone en false).

signal changed(active: bool)

enum Mode { FIXED, BOTH, TIMED, FOLLOWS }

@export var mode := Mode.FIXED
@export var affiliation := World.Kind.LIVING
@export var hide_when_inactive := true
@export var shift_interval := 3.0  # solo Mode.TIMED

var is_active := true

var _shift_left := 0.0

@onready var _target := get_parent() as Node3D

func _ready() -> void:
	WorldManager.world_changed.connect(_on_world_changed)
	_shift_left = shift_interval
	_on_world_changed(WorldManager.current)

## Re-evalúa la afiliación contra el mundo actual y vuelve a emitir `changed`. Lo llama
## el dueño cuando setea `affiliation` por código: su `_ready` corre DESPUÉS del de este
## módulo, así que sin esto el módulo se quedaría con la afiliación vieja (ver SpikeWall).
func refresh() -> void:
	_on_world_changed(WorldManager.current)

func _process(delta: float) -> void:
	if mode != Mode.TIMED or shift_interval <= 0.0:
		return
	_shift_left -= delta
	if _shift_left > 0.0:
		return
	_shift_left = shift_interval
	affiliation = World.Kind.DEAD if affiliation == World.Kind.LIVING else World.Kind.LIVING
	_on_world_changed(WorldManager.current)

func _on_world_changed(world: World.Kind) -> void:
	if mode == Mode.FOLLOWS:
		affiliation = world
	is_active = mode == Mode.BOTH or world == affiliation
	if hide_when_inactive:
		_apply_visibility()
	changed.emit(is_active)

func _apply_visibility() -> void:
	if _target == null:
		return
	_target.visible = is_active
	# ponytail: no tocamos la colisión de un CharacterBody3D — perdería el movimiento
	# (mismo guard que con el CharacterController en v1). Los que se ocultan no son agentes.
	if _target is CharacterBody3D:
		return
	for shape in _target.find_children("*", "CollisionShape3D", false):
		shape.set_deferred("disabled", not is_active)
