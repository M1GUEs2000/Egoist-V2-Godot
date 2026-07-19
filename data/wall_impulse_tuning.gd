class_name WallImpulseTuning extends Resource
## Tuning por pared de Wall Impulse. La direccion sale del primer input tangencial del
## jugador; este Resource solo define cuanto acelera y cual es su techo horizontal.

## Aceleracion horizontal constante mientras el jugador permanece enganchado a la pared.
@export var acceleration := 18.0
## Rapidez horizontal al capturar el rumbo. Evita arrancar quieto antes de acelerar.
@export var initial_speed := 5.0
## Inclinacion del carril respecto a la horizontal: 0 = recto, negativo = baja, positivo = sube.
@export_range(-89.0, 89.0, 1.0) var angle_degrees := 0.0
## Rapidez maxima del carril.
@export var max_speed := 16.0
