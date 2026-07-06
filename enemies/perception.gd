class_name Perception extends Node
## Sensor REUTILIZABLE (ex Perception.cs): cono de visión, proximidad, línea de vista,
## alerta/búsqueda. El objetivo se lo pasa el dueño. Sirve para NPC o animal, no solo enemigos.

@export var vision_range := 12.0
@export var vision_angle := 70.0
@export var proximity_radius := 2.5
