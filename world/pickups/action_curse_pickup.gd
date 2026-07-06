class_name ActionCursePickup extends Node
## Pickup amarillo: al romperse activa "la próxima acción cambia mundo" en el player.

func _ready() -> void:
	var health := World.find_sibling(self, Health) as Health
	if health != null:
		health.died.connect(_on_died)

func _on_died() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.activate_action_world_switch()
