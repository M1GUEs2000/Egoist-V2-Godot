class_name TraversalBlockTuning extends Resource
## Tuning visual compartido por los bloques de traversal componibles.

## Radio a partir del cual el glow empieza a subir por proximidad al jugador.
@export var proximity_radius := 7.0
## Emision minima cuando el jugador esta lejos (0.1 = 10%).
@export_range(0.0, 2.0, 0.05) var glow_min_energy := 0.1
## Emision maxima cuando el jugador esta encima (0.6 = 60%).
@export_range(0.0, 2.0, 0.05) var glow_max_energy := 0.6
