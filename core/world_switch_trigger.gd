class_name WorldSwitchTrigger extends Node
## "¿Qué le hago al mundo de TODOS?" (ex WorldSwitchTrigger.cs).
## Escucha señales del dueño (hit de Hurtbox / died de Health) y voltea el mundo global.

enum When { ON_HIT, ON_DEATH }

@export var when := When.ON_HIT
