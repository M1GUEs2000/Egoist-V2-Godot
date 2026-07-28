class_name PlayerSprint extends Node
## Bloque componible: mantiene el NIVEL de sprint (0-1) y devuelve el multiplicador que cada
## sistema de movimiento le aplica a su propio tuning. No mueve al jugador ni pisa velocidades:
## solo escala. Con nivel 0 todos los canales devuelven 1.0 y el juego se comporta exactamente
## como si el modulo no existiera — el "base" sigue siendo el de siempre.
##
## Carga: boton `sprint` sostenido (sube a `sprint_charge_seconds`), en tierra y en el aire por
## igual. Soltar lo apaga siempre: el nivel ya no queda congelado al despegar, asi que sostener el
## boton es lo unico que mantiene el sprint durante el salto y la cadena de paredes.
##
## Tener el sprint activo CUESTA meter (`sprint_meter_drain_per_second` barras por segundo). Sin
## meter no se puede cargar y el nivel cae solo: la carrera compite con el gasto de combate.
##
## El multiplicador se aplica SIEMPRE en el consumidor, nunca escribiendo sobre PlayerTuning: asi
## `tuning.move_speed` sigue siendo la referencia base para los calculos que la usan como UNIDAD
## de medida y no como velocidad. Caso concreto: el angulo del wall jump mide tu velocidad tangente
## contra `move_speed` — si el sprint escalara el Resource, correr te sacaria mas perpendicular de
## la pared a igual velocidad real, que es lo contrario de lo que el sprint deberia hacer.

## Canales de escalado. Cada uno tiene su porcentaje propio en PlayerTuning (grupo Sprint), asi se
## puede decidir por separado cuanto le entra el sprint a cada pieza del movimiento.
const MOVE_SPEED := &"move_speed"
const JUMP_HEIGHT := &"jump_height"
const JUMP_FORWARD := &"jump_forward"
const WALL_SLIDE_INITIAL := &"wall_slide_initial"
const WALL_SLIDE_FINAL := &"wall_slide_final"
const WALL_SLIDE_ACCEL := &"wall_slide_accel"
const WALL_JUMP_H := &"wall_jump_h"
const WALL_JUMP_V := &"wall_jump_v"
const WALL_IMPULSE := &"wall_impulse"
const MOMENTUM_MAX := &"momentum_max"

signal level_changed(level: float)

## Nivel actual del sprint: 0 = valores base, 1 = sprint pleno (todos los bonos al maximo).
var level := 0.0

var _body: Player

func setup(body: Player) -> void:
	_body = body

func tick(delta: float) -> void:
	if _body == null:
		return
	var t := _body.tuning
	var previous := level
	if _is_charging():
		level = minf(1.0, level + delta / maxf(0.001, t.sprint_charge_seconds))
	else:
		level = maxf(0.0, level - delta / maxf(0.001, t.sprint_decay_seconds))
	# El sprint se cobra mientras este encendido, no solo mientras lo cargues: el tramo de decay
	# todavia te esta dando bono, asi que todavia paga. El costo es fraccion del meter completo,
	# asi que subir las barras maximas no abarata la carrera.
	if level > 0.0 and _body.meter != null:
		var drain := t.sprint_meter_drain_per_second * float(_body.meter.bars()) * delta
		_body.meter.gain_bars(-drain)
	if not is_equal_approx(level, previous):
		level_changed.emit(level)

## Multiplicador del canal para el nivel actual: 1.0 sin sprint, 1 + bono a sprint pleno.
func scale(channel: StringName) -> float:
	if _body == null or level <= 0.0:
		return 1.0
	return 1.0 + _bonus_percent(channel) * 0.01 * level

## Tira el sprint a cero de golpe. Lo llama el stun: comerse un golpe te apaga la carrera.
func cancel() -> void:
	if level == 0.0:
		return
	level = 0.0
	level_changed.emit(level)

func _is_charging() -> bool:
	if not Input.is_action_pressed("sprint"):
		return false
	# Sin meter no hay carrera: el nivel se cae solo aunque sigas apretando.
	if _body.meter != null and _body.meter.meter() <= 0.0:
		return false
	if not _body.tuning.sprint_requires_move_input:
		return true
	if _body.locomotion == null:
		return false
	return _body.locomotion.has_move_input(_body.locomotion.read_move_input())

func _bonus_percent(channel: StringName) -> float:
	var t := _body.tuning
	match channel:
		MOVE_SPEED:
			return t.sprint_move_speed_bonus
		JUMP_HEIGHT:
			return t.sprint_jump_height_bonus
		JUMP_FORWARD:
			return t.sprint_jump_forward_bonus
		WALL_SLIDE_INITIAL:
			return t.sprint_wall_slide_initial_speed_bonus
		WALL_SLIDE_FINAL:
			return t.sprint_wall_slide_final_speed_bonus
		WALL_SLIDE_ACCEL:
			return t.sprint_wall_slide_acceleration_bonus
		WALL_JUMP_H:
			return t.sprint_wall_jump_h_bonus
		WALL_JUMP_V:
			return t.sprint_wall_jump_v_bonus
		WALL_IMPULSE:
			return t.sprint_wall_impulse_bonus
		MOMENTUM_MAX:
			return t.sprint_momentum_max_bonus
	return 0.0
