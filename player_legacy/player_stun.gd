class_name PlayerLegacyStun extends Node
## Estado de stun del jugador: suspende input/control, pero deja correr fisica externa.

enum Mode { STILL, PUSH }

signal stunned_started(duration: float, mode: Mode)
signal stunned_ended

var mode := Mode.STILL

var _stunned_until := -999.0
var _was_stunned := false

func apply(duration: float, stun_mode := Mode.STILL) -> void:
	if duration <= 0.0:
		return
	mode = stun_mode
	_stunned_until = maxf(_stunned_until, World.now() + duration)
	_was_stunned = true
	stunned_started.emit(duration, mode)

func is_stunned() -> bool:
	return World.now() < _stunned_until

func remaining() -> float:
	return maxf(0.0, _stunned_until - World.now())

func cancel() -> void:
	_stunned_until = -999.0
	mode = Mode.STILL
	if _was_stunned:
		_was_stunned = false
		stunned_ended.emit()

func tick() -> void:
	if _was_stunned and not is_stunned():
		_was_stunned = false
		stunned_ended.emit()
