extends Node
## Dueño del mundo actual (ex WorldManager.cs). Autoload: WorldManager.

signal world_changed(world: World.Kind)

var current := World.Kind.LIVING

func switch_world() -> void:
	current = World.Kind.DEAD if current == World.Kind.LIVING else World.Kind.LIVING
	world_changed.emit(current)
