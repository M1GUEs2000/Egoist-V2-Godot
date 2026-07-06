extends Node
## Estado global del juego (ex GameManager.cs). Autoload: GameManager.

enum State { PLAYING, PAUSED, DEAD, TRANSITIONING }

var state := State.PLAYING

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # debe poder des-pausar el árbol

func set_state(new_state: State) -> void:
	state = new_state
	get_tree().paused = new_state == State.PAUSED
