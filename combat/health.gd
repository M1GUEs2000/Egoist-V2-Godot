class_name Health extends Node
## Vida COMPARTIDA de todo el juego: jugador, enemigos y objetos (lección v1:
## un solo módulo, sin hits_to_kill duplicado). Solo cuenta y avisa; no decide qué pasa al morir.

signal damaged(amount: float)
signal died

@export var max_health := 3.0

@onready var current := max_health

func take_damage(amount: float) -> bool:
	# TODO: restar, emitir señales. Devuelve true si murió.
	return false
