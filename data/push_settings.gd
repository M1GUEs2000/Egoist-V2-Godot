class_name PushSettings extends Resource
## Parametros de un empujon aereo en arco (rama espera del combo aereo). Lo define QUIEN
## ataca, no el enemigo (igual que StunSettings): cada fuente de push lleva su propio arco,
## asi cada arma/ataque puede empujar distinto. Instancias .tres/embebidas viven en data/.
##
## MODELO GEOMETRICO (no de fuerzas): no se tunea "cuanta velocidad", se tunea DONDE CAE.
## El arco sale con `angle_degrees` de inclinacion y tiene que pasar por el punto
## (distance, -fall_height) relativo al impacto. Con el angulo y ese punto fijos la velocidad
## inicial queda determinada por una sola ecuacion, asi que la calcula solve_speeds():
##
##     v0^2 = g * D^2 / (2 * cos(t)^2 * (D * tan(t) + H))
##
## Gastada la altura, el arco termina: muere el horizontal y el cuerpo cae a plomo.

## Metros que avanza en horizontal antes de caer recto. Es el knob principal: "este golpe
## manda al enemigo a 20 metros". Verificable mirando la pantalla.
@export var distance := 15.0
## Inclinacion inicial del arco, en grados sobre la horizontal. NO cambia donde cae (eso lo
## fija `distance`): cambia la FORMA del recorrido. Bajo = rasante y se comba tarde; alto =
## sube mas y cae picado. Ojo con angulos altos en distancias cortas: el cuerpo puede gastar
## `fall_height` antes de llegar, y ahi cae recto a mitad de camino sin cumplir la distancia.
@export_range(1.0, 80.0) var angle_degrees := 25.0
## Metros que el cuerpo termina POR DEBAJO del punto de impacto. No es un techo: es el
## presupuesto de caida. Al agotarlo se corta el horizontal y baja a plomo. 0 = aterriza a la
## misma altura desde la que salio.
## Con 5 el arco pica al final (baja mas empinado de lo que subio) y, si el enemigo estaba
## parado en el piso, aterriza antes de completar `distance`: no le sobran 5 m para caer.
@export var fall_height := 5.0
## Cierre del arco, en m/s^2 (negativo). No mueve el punto de caida —ya lo fija `distance`—
## sino el TIEMPO de vuelo: mas negativo = mismo recorrido pero mas rapido y seco.
@export var gravity := -20.0
## Metros que la pared lo devuelve si choca a mitad del arco, reflejando contra la normal.
## Reusa este mismo modelo (mismo angulo, misma altura). El rebote NO vuelve a rebotar: sin
## ese tope, un pasillo angosto deja al enemigo en ping-pong eterno. 0 lo apaga.
@export var wall_bounce_distance := 2.0

## Resuelve el arco: devuelve (velocidad horizontal, velocidad vertical inicial) en m/s para que
## el tiro salga a `angle_degrees` y pase por (target_distance, -fall_height). Unica fuente de la
## formula: la usan EnemyBase.push, el rebote de pared y los dummies de test.
## `target_distance` < 0 usa `distance` (el rebote de pared pasa la suya).
func solve_speeds(target_distance := -1.0) -> Vector2:
	var t := deg_to_rad(clampf(angle_degrees, 1.0, 80.0))
	var g := absf(gravity)
	var d := maxf(0.01, target_distance if target_distance >= 0.0 else distance)
	var h := maxf(0.0, fall_height)
	# Denominador siempre > 0 con t en (0, 80] y h >= 0: el tiro cruza la vertical del destino.
	var v0 := sqrt(g * d * d / (2.0 * pow(cos(t), 2.0) * (d * tan(t) + h)))
	return Vector2(v0 * cos(t), v0 * sin(t))
