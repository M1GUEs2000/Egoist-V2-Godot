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

func affordable_bars() -> int:
	return int(floor(_meter / _body.tuning.meter_charged_cost))

## Cuánto da un golpe lo decide la FUENTE, no el player: cada arma trae su
## `WeaponTuning.meter_gain_on_hit`, y el Brazo o un bloque traen el suyo.
func gain_on_hit(bars_amount: float) -> void:
	_add(bars_amount)

func gain_bars(amount: float) -> void:
	_add(amount)

## Gasto puntual de una mecanica que no es dash ni cargado. Acepta fracciones de barra para que
## cada arma pueda cobrar su propio gesto sin abrir la ventana de kill de los cargados.
func spend_bars(amount: float) -> bool:
	if amount <= 0.0 or _meter < amount:
		return false
	_add(-amount)
	return true

## Al matar: si venimos de un cargado (ventana abierta), recuperás 1 barra completa
## (habilidad especial de la Espada) y la ganancia por arma no aplica. Si no, la que
## traiga la fuente.
func gain_on_kill(bars_amount: float) -> void:
	if World.now() <= _charged_kill_expiry:
		_charged_kill_expiry = -999.0
		_add(1.0)
	else:
		_add(bars_amount)

## Gasta el coste del dodge. Devuelve si había suficiente (para el futuro dodge
## degradado sin meter). Hoy el dodge no se bloquea: gasta lo que haya hasta 0.
func spend_dash() -> bool:
	var enough := _meter >= _body.tuning.meter_dash_cost
	_add(-_body.tuning.meter_dash_cost)
	return enough

## Cargado: pide barras completas. Si hay suficientes, las gasta. La ventana de kill
## especial queda activa por defecto para la Espada; otras armas pueden desactivarla.
## cost_scale abarata el cargado sin tocar cuantas barras pide (1.0 = precio de lista;
## el sweet spot pasa 0.7 = 30% menos, ver WeaponTuning.meter_cost_scale).
func spend_charged(bars_to_spend: int = 1, opens_kill_window: bool = true,
		cost_scale: float = 1.0) -> bool:
	var cost := _body.tuning.meter_charged_cost * float(bars_to_spend) * maxf(0.0, cost_scale)
	if bars_to_spend <= 0 or _meter < cost:
		return false
	_add(-cost)
	if opens_kill_window:
		_charged_kill_expiry = World.now() + _body.tuning.meter_charged_kill_window
	return true

func _add(bars_delta: float) -> void:
	_meter = clampf(_meter + bars_delta, 0.0, float(bars()))
	bars_changed.emit(_meter, bars())
