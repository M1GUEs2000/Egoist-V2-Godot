class_name PlayerLegacyHealth extends Node
## Adaptador de vida del jugador: configura el Health generico y traduce la muerte
## al estado global. El dano sigue entrando por Hurtbox para compartir el pipeline.

@export var max_health := 100.0

var _body: PlayerLegacy

func setup(body: PlayerLegacy) -> void:
	_body = body
	_body.health.set_max(max_health)
	if not _body.health.died.is_connected(_on_died):
		_body.health.died.connect(_on_died)

func take_damage(amount: float) -> bool:
	if _body == null:
		return false
	return _body.health.take_damage(amount)

func refill() -> void:
	if _body == null:
		return
	_body.health.refill()

func _on_died() -> void:
	GameManager.set_state(GameManager.State.DEAD)
