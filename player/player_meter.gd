class_name PlayerMeter extends Node
## Recurso de combate en BARRAS: gana al pegar/matar, gasta al dashear/cargar (ex PlayerMeter.cs).

signal bars_changed(current: float, max_bars: int)

@export var max_bars := 2  # mejora a 5 con upgrades (bóveda: Combate)
