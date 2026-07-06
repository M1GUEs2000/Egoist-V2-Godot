class_name PlayerMeter extends Node
## Recurso central del combate, medido en BARRAS, no HP (ex PlayerMeter.cs). Se gana al
## pegar y al matar (lo reportan el arma y el dash), se gasta al dashear y en los
## cargados. La vista se engancha a la señal bars_changed (v2: señales, no polling).
## Los números viven en PlayerTuning (grupo Meter).
# ponytail: sin implementar (bóveda Combate): mejora a 5 barras, esquive perfecto,
# dodge degradado sin meter, y la Habilidad Suprema al llenar todas las barras.

signal bars_changed(current: float, max_bars: int)

var _body: Player
var _meter := 0.0
var _charged_kill_expiry := -999.0

func setup(body: Player) -> void:
	_body = body
	_meter = clampf(body.tuning.meter_start_bars, 0.0, float(bars()))
	bars_changed.emit(_meter, bars())

func bars() -> int:
	return _body.tuning.meter_max_bars

func meter() -> float:
	return _meter

func fraction() -> float:
	return _meter / float(bars())

func gain_on_hit() -> void:
	_add(_body.tuning.meter_gain_on_hit)

## Al matar: si venimos de un cargado (ventana abierta), recuperás 1 barra completa
## (habilidad especial de la Espada). Si no, la ganancia normal de kill.
func gain_on_kill() -> void:
	if World.now() <= _charged_kill_expiry:
		_charged_kill_expiry = -999.0
		_add(1.0)
	else:
		_add(_body.tuning.meter_gain_on_kill)

## Gasta el coste del dodge. Devuelve si había suficiente (para el futuro dodge
## degradado sin meter). Hoy el dodge no se bloquea: gasta lo que haya hasta 0.
func spend_dash() -> bool:
	var enough := _meter >= _body.tuning.meter_dash_cost
	_add(-_body.tuning.meter_dash_cost)
	return enough

## Cargado (sweet spot): pide 1 barra completa. Si la hay, la gasta y abre la ventana
## de kill especial. Si no, false → el arma cae a su ataque sin dash.
func spend_charged() -> bool:
	if _meter < _body.tuning.meter_charged_cost:
		return false
	_add(-_body.tuning.meter_charged_cost)
	_charged_kill_expiry = World.now() + _body.tuning.meter_charged_kill_window
	return true

func _add(bars_delta: float) -> void:
	_meter = clampf(_meter + bars_delta, 0.0, float(bars()))
	bars_changed.emit(_meter, bars())
