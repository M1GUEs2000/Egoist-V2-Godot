extends Node
## Estado global del juego (ex GameManager.cs). Autoload: GameManager.

enum State { PLAYING, PAUSED, DEAD, TRANSITIONING }

signal state_changed(state: int)

var state := State.PLAYING

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # debe poder des-pausar el arbol
	state_changed.emit(state)

func set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	get_tree().paused = new_state == State.PAUSED
	state_changed.emit(state)
