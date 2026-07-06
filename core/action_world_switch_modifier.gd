class_name ActionWorldSwitchModifier extends Node
## Maldición amarilla (ex ActionWorldSwitchModifier.cs): si está activa, la próxima
## acción del jugador (ataque o dodge) cambia el mundo y consume la maldición.

var _active := false

func activate() -> void:
	_active = true

func fire_action() -> void:
	if not _active:
		return
	_active = false
	WorldManager.switch_world()
