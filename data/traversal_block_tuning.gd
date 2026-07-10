class_name TraversalBlockTuning extends Resource
## Tuning visual compartido por los bloques de traversal componibles.

## Radio a partir del cual el glow empieza a subir por proximidad al jugador.
@export var proximity_radius := 7.0
## Emision de reposo cuando el jugador esta lejos: casi apagado, solo se distingue el color.
@export_range(0.0, 4.0, 0.05) var glow_min_energy := 0.2
## Emision al estar encima del bloque: bien encendido. Con albedo apagado, este es el
## que hace que "prenda" al acercarse; subilo si el glow se ve debil.
@export_range(0.0, 4.0, 0.05) var glow_max_energy := 0.8
## Alcance en metros de la luz real que emite el bloque hacia el entorno (piso, paredes).
@export var light_range := 4.0
## Energia maxima de esa luz cuando el jugador esta encima. 0 = el bloque no ilumina nada
## (solo brilla su superficie por emision). Subilo si queres que tiña mas fuerte el entorno.
@export_range(0.0, 8.0, 0.1) var light_energy_max := 2.5
