class_name FloorSlideTuning extends Resource
## Tuning de una superficie de deslizamiento de suelo (hielo / rampa). Cada plataforma que
## desliza lleva su propio .tres a traves del nodo FloorSlideSurface, asi dos plataformas
## pueden ser mas o menos resbaladizas sin tocar codigo. Una sola formula cubre los dos casos:
## en plataforma plana la normal apunta hacia arriba y el termino de pendiente se anula solo
## (queda hielo puro); si la plataforma esta inclinada, empuja cuesta abajo como un tobogan.

## Velocidad horizontal minima (m/s) con la que hay que pisar la superficie para enganchar el
## slide. Por debajo de esto la plataforma se camina normal.
@export var min_enter_speed := 3.0
## Velocidad maxima que puede alcanzar el slide (m/s). Es el techo de lo que la pendiente y el
## momentum de entrada pueden acumular.
@export var max_speed := 22.0
## Aceleracion cuesta abajo segun la inclinacion de la plataforma (m/s^2). En plataforma plana
## no hace nada (la normal es vertical); solo actua en rampas. Mas alto = tobogan mas agresivo.
@export var slope_accel := 18.0
## Friccion residual mientras desliza (m/s^2): cuanto frena el slide por si solo. 0 = hielo puro
## (no frena nunca), alto = casi como pisar suelo normal.
@export var friction := 2.0
## Cuanto puede redirigir el input la direccion del slide (0-1). 0 = cero control (hielo puro,
## te llevan la velocidad y la pendiente), 1 = el input arrastra el slide hacia el como caminar.
@export_range(0.0, 1.0) var steer_control := 0.4
## Rapidez con la que el input reorienta el slide cuando steer_control > 0 (m/s^2). Junto con
## steer_control define que tan pegajoso se siente el volante.
@export var steer_accel := 30.0
## Fraccion de la velocidad del slide que se conserva como momentum al SALTAR desde el slide
## (0-1). 0 = el salto sale limpio sin arrastre; 1 = te llevas todo el slide al aire.
@export_range(0.0, 1.0) var jump_momentum_keep := 0.7
