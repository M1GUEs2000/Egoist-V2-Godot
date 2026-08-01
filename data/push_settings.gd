class_name PushSettings extends Resource
## Parametros de un empujon aereo en arco. Lo define QUIEN ataca, no el enemigo: cada
## fuente de push lleva su propio arco. Las instancias .tres/embebidas viven en data/.
##
## MODELO CINEMATICO: `initial_speed` lanza el cuerpo en `angle_degrees` y `acceleration`
## modifica su velocidad vertical durante el vuelo. `distance` y `fall_height` son limites
## de seguridad: al gastar cualquiera, se corta el impulso horizontal y el cuerpo cae a plomo.

## Condiciones que detienen el impulso. Coinciden con MoverSettings para que ambos inspectores
## expresen la misma intencion.
const STOP_ON_DISTANCE := 1
const STOP_ON_FLOOR := 2
const STOP_ON_WALL := 4
const STOP_ON_HIT := 8

## Metros maximos que avanza en horizontal antes de caer recto. 0 desactiva este limite.
@export var distance := 15.0
## Inclinacion inicial respecto de la horizontal. Negativo empuja hacia abajo; positivo levanta.
## +/-80 evita una direccion casi vertical sin componente horizontal.
@export_range(-80.0, 80.0) var angle_degrees := 25.0
## Metros que puede bajar desde el impacto antes de cortar el impulso horizontal. 0 = corta al
## volver a la altura de salida.
@export var fall_height := 5.0
## Magnitud del impulso inicial, en m/s. El angulo reparte esta velocidad entre horizontal y Y.
@export var initial_speed := 15.112016
## Cambio de velocidad vertical, en m/s^2. Negativo curva hacia abajo; positivo hacia arriba.
@export var acceleration := -20.0
## Condiciones de fin combinables. Por defecto distancia, piso y golpe nuevo cortan el push;
## WALL queda apagado para permitir `wall_bounce_distance`.
@export_flags("Distance:1", "Floor:2", "Wall:4", "Hit:8") var stop_on := \
		STOP_ON_DISTANCE | STOP_ON_FLOOR | STOP_ON_HIT
## Metros que la pared lo devuelve si choca a mitad del arco, reflejando contra la normal.
## El rebote no vuelve a rebotar; 0 lo apaga.
@export var wall_bounce_distance := 2.0

## Devuelve (velocidad horizontal, velocidad vertical inicial) en m/s. El rebote conserva este
## mismo impulso y solo cambia la direccion horizontal contra la pared.
func initial_velocity() -> Vector2:
	var angle := deg_to_rad(clampf(angle_degrees, -80.0, 80.0))
	var speed := maxf(0.0, initial_speed)
	return Vector2(speed * cos(angle), speed * sin(angle))

func stops_on(condition: int) -> bool:
	return (stop_on & condition) != 0
