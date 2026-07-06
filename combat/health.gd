class_name Health extends Node
## Módulo de vida compartido por TODO lo golpeable (ex Health.cs): jugador (HP), enemigos
## (golpes) y objetos (1 golpe). Solo lleva la cuenta y avisa por señales; NO decide qué
## pasa al morir (física de muerte, HUD, cambio de mundo) — eso lo enganchan los dueños.

signal damaged(amount: float)
signal died

@export var max_health := 1.0

var current := 0.0

var _initialized := false

func _ready() -> void:
	_ensure_init()

func is_dead() -> bool:
	return _initialized and current <= 0.0

## Para dueños que exponen la vida con otro nombre en SU inspector y la empujan acá
## (PlayerHealth, objetos con hits_to_break). Los enemigos configuran max_health directo.
## Funciona sin importar el orden de _ready entre dueño y módulo.
func set_max(new_max: float, refill := true) -> void:
	max_health = maxf(1.0, new_max)
	if refill or not _initialized:
		current = max_health
	_initialized = true

## Devuelve true si este golpe lo mató (para que el dueño decida recompensas, etc).
func take_damage(amount: float) -> bool:
	_ensure_init()
	if is_dead() or amount <= 0.0:
		return false
	current = maxf(0.0, current - amount)
	damaged.emit(amount)
	if current <= 0.0:
		died.emit()
		return true
	return false

func kill() -> void:
	_ensure_init()
	if is_dead():
		return
	current = 0.0
	died.emit()

func refill() -> void:
	_ensure_init()
	current = max_health

func _ensure_init() -> void:
	if _initialized:
		return
	current = max_health
	_initialized = true
