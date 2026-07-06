class_name BreakOnDeath extends Node
## Reaccion reusable para objetos golpeables simples (ex HittableObject.OnBroken):
## escucha el Health hermano y elimina u oculta al dueño cuando muere.

@export var free_owner := true
@export var hide_owner := false

@onready var _owner_node := get_parent()

func _ready() -> void:
	for sibling in _owner_node.get_children():
		var health := sibling as Health
		if health != null:
			health.died.connect(_on_died)
			return

func _on_died() -> void:
	if not is_instance_valid(_owner_node):
		return
	if hide_owner and _owner_node is Node3D:
		(_owner_node as Node3D).visible = false
	if free_owner:
		_owner_node.call_deferred("queue_free")
