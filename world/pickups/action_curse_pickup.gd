class_name ActionCursePickup extends Node
## Pickup amarillo: al romperse activa "la próxima acción cambia mundo" en el player.

@onready var _owner_node := get_parent()

func _ready() -> void:
	for sibling in _owner_node.get_children():
		var health := sibling as Health
		if health != null:
			health.died.connect(_on_died)
			return

func _on_died() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.activate_action_world_switch()
