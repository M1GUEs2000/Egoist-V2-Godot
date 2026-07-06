extends Node3D
## Escena de pruebas (reemplaza al TestSceneBuilder.cs de v1: acá el "builder" es el propio
## .tscn, que Claude edita como texto). Tecla T: cambia de mundo — debug temporal hasta que
## existan armas y pickups (batches 4 y 6).

func _ready() -> void:
	WorldManager.world_changed.connect(func(world: World.Kind) -> void:
		print("[Egoist] Mundo -> ", World.Kind.keys()[world]))

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_T:
		WorldManager.switch_world()
