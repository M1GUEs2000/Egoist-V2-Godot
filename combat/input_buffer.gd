class_name InputBuffer extends Node
## Las 3 reglas de feel (ex InputBuffer.cs — NO negociables, ver bóveda Arquitectura):
## 1. Tap ejecuta al PRESS. Si sigue presionado > hold_threshold → hold.
## 2. Input durante animación se guarda buffer_time y dispara en el primer frame libre.
## 3. Las ventanas de cancel las decide quien setea is_actionable.

## Perillas de feel. Los valores canónicos viven en PlayerTuning (regla v2: tuning en
## .tres); PlayerCombat los inyecta en setup. Los defaults cubren usos standalone (tests).
var buffer_time := 0.15
var hold_threshold := 0.18

var is_actionable := true

var _buffered := Callable()
var _buffer_expiry := 0.0
var _press_time := 0.0
var _hold_fired := false
var _execute_on_release := false
var _charge_then_release := false
var _tap_action := Callable()
var _hold_action := Callable()

## Segundos crudos desde el press (sin saturar en hold_threshold). Lo usa el arma
## para resolver niveles de carga más allá del primer umbral (ver Mazo).
func held_duration() -> float:
	return World.now() - _press_time

## 0→1 mientras carga, se queda en 1 tras disparar hold, vuelve a 0 al soltar.
func charge_progress() -> float:
	if _hold_fired:
		return 1.0
	if _hold_action.is_valid():
		return clampf((World.now() - _press_time) / hold_threshold, 0.0, 1.0)
	return 0.0

## Llamar en el pressed de la acción de input.
func press(tap_action: Callable, hold_action: Callable) -> void:
	_press_time = World.now()
	_hold_fired = false
	_execute_on_release = false
	_charge_then_release = false
	_try_execute(tap_action)
	# ponytail: hold detection por polling en _process; cambiar a señal si el feel lo pide
	_hold_action = hold_action
	_tap_action = tap_action

## Nada al press; al soltar decide tap o hold según cuánto se mantuvo.
func press_on_release(tap_action: Callable, hold_action: Callable) -> void:
	_press_time = World.now()
	_hold_fired = false
	_execute_on_release = true
	_charge_then_release = false
	_hold_action = hold_action
	_tap_action = tap_action

## Tap inmediato en press; si se mantiene > threshold carga (charge_progress) y
## al soltar dispara el hold (cargado). El tap ya ocurrió, no se repite.
func press_then_charge(tap_action: Callable, hold_action: Callable) -> void:
	_press_time = World.now()
	_hold_fired = false
	_execute_on_release = false
	_charge_then_release = true
	_hold_action = hold_action
	_tap_action = tap_action
	_try_execute(tap_action)

## Llamar en el released de la acción de input.
func release() -> void:
	if _execute_on_release:
		var charged := World.now() - _press_time >= hold_threshold
		_try_execute(_hold_action if charged else _tap_action)
	elif _charge_then_release and World.now() - _press_time >= hold_threshold:
		_try_execute(_hold_action)  # tap ya salió en press; al soltar tras cargar, el cargado

	_hold_action = Callable()
	_tap_action = Callable()
	_hold_fired = false
	_execute_on_release = false
	_charge_then_release = false

func _process(_delta: float) -> void:
	# Flush del buffer
	if _buffered.is_valid() and is_actionable and World.now() <= _buffer_expiry:
		var action := _buffered
		_buffered = Callable()
		action.call()
	elif _buffered.is_valid() and World.now() > _buffer_expiry:
		_buffered = Callable()

	# Hold detection (auto-fire). En charge-then-release el hold sale al soltar, no aquí.
	if not _execute_on_release and not _charge_then_release and not _hold_fired \
			and _hold_action.is_valid() and World.now() - _press_time >= hold_threshold:
		_hold_fired = true
		_buffered = Callable()  # cancela el tap bufferizado si no ejecutó aún
		_try_execute(_hold_action)

func _try_execute(action: Callable) -> void:
	if not action.is_valid():
		return
	if is_actionable:
		action.call()
	else:
		_buffered = action
		_buffer_expiry = World.now() + buffer_time
