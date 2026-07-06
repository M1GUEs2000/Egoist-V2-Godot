extends Node
## Estado global del juego (ex GameManager.cs). Autoload: GameManager.

enum State { PLAYING, PAUSED, DEAD, TRANSITIONING }

var state := State.PLAYING
