class_name MoverSettings extends Resource
## Perfil de un recorrido para un Mover (ver combat/mover.gd y obsidian/Plan Autoridad Vertical).
## Lo define QUIEN ataca (arma/ataque/enemigo), no el receptor: cada golpe lleva su propio perfil,
## asi un mismo ataque puede pedir un recorrido distinto al Player y al Enemy. Instancias .tres o
## subresources embebidas viven en data/ dentro de SwordTuning, MaceTuning, ArmTuning, etc.
##
## Un Mover SOLO mueve a su dueno. "Mover a ambos" = el ataque emite DOS MoverSettings, uno por
## cuerpo; no hay fisica compartida ni un target=BOTH dentro del componente.

## Bits de `stop_on`. DISTANCE es el limite de seguridad y siempre deberia estar prendido; FLOOR,
## WALL y ENEMY permiten que una coreografia termine antes por contacto.
const STOP_ON_DISTANCE := 1
const STOP_ON_FLOOR := 2
const STOP_ON_WALL := 4
const STOP_ON_ENEMY := 8

enum Mode {
	TOTAL,
	PARTIAL,
}

## Las cuatro direcciones que un recorrido puede tomar. Reemplazan al Vector3 crudo (2026-07-30):
## un vector obliga a pensar en ejes del mundo para decir algo tan simple como "hacia atras", y
## acepta valores que no significan nada — `(0,0,0)` mandaba el recorrido hacia arriba por el
## fallback del Mover, que fue exactamente el bug del empujon que no empujaba.
##
## FORWARD y BACK se resuelven SIEMPRE contra el facing del Player, tambien cuando el que se mueve
## es el enemigo. O sea que empujar a un enemigo lejos tuyo es FORWARD: "su atras" es "tu adelante",
## y asi el mismo perfil vale mires a donde mires.
enum Direction {
	UP,       ## Vertical del mundo, hacia arriba. Es el launcher.
	DOWN,     ## Vertical del mundo, hacia abajo. Es el spike y el plunge.
	FORWARD,  ## Horizontal, hacia donde mira el Player. Avances y empujones.
	BACK,     ## Horizontal, opuesto al facing del Player. Retrocesos.
}

## Hacia donde va el recorrido. La inclinacion sale aparte, en `pitch_degrees`.
@export var direction := Direction.UP
## Inclinacion del recorrido en grados sobre la horizontal: positivo sube, negativo baja. SOLO
## aplica a FORWARD y BACK — UP y DOWN ya son verticales puras y lo ignoran.
##
## Es lo que permite un remate en diagonal sin volver a los vectores: el knock de la Y cargada aerea
## era `(0, -0.5, 0.866)`, que hay que resolver con trigonometria para saber que son 30 grados hacia
## abajo. Aca es `-30`.
@export_range(-89.0, 89.0, 1.0) var pitch_degrees := 0.0

## Vector ya resuelto contra el facing, escrito en runtime por quien dispara el ataque
## (WeaponBase clona el perfil antes de escribirlo, nunca toca el .tres). NO es @export: no es
## tuning, es el resultado de resolver `direction` cuando existe un Player al que mirar.
var aimed_direction := Vector3.ZERO

## Traduce `direction` + `pitch_degrees` a un vector unitario. `player_forward` solo se usa para
## FORWARD y BACK; UP y DOWN no lo miran, asi que un cuerpo sin facing puede pasar Vector3.ZERO.
## Un facing degenerado cae a UP, que es el mismo fallback historico del Mover.
func direction_vector(player_forward: Vector3) -> Vector3:
	if direction == Direction.UP:
		return Vector3.UP
	if direction == Direction.DOWN:
		return Vector3.DOWN
	var flat := Vector3(player_forward.x, 0.0, player_forward.z)
	if flat.length_squared() < 0.0001:
		return Vector3.UP
	flat = flat.normalized()
	if direction == Direction.BACK:
		flat = -flat
	var pitch := deg_to_rad(pitch_degrees)
	return (flat * cos(pitch) + Vector3.UP * sin(pitch)).normalized()
## Metros maximos del recorrido. Tope duro: aunque no se cumpla ninguna condicion de contacto, el
## Mover termina al recorrer esta distancia (razon DISTANCE).
@export var distance := 4.0
## Velocidad inicial del recorrido, en m/s.
@export var speed := 12.0
## Aceleracion en m/s^2: positiva acelera, negativa frena, 0 mantiene la velocidad constante.
@export var acceleration := 0.0
## Condiciones de fin combinables (flags). DISTANCE siempre actua como tope; FLOOR/WALL/ENEMY
## cortan antes por contacto. Ej.: un dash cargado usa DISTANCE|WALL (atraviesa enemigos, frena en
## pared); un launcher usa solo DISTANCE.
@export_flags("Distance:1", "Floor:2", "Wall:4", "Enemy:8") var stop_on := STOP_ON_DISTANCE
## TOTAL ejecuta `move_and_slide` por su cuenta y toma el movimiento completo. PARTIAL solo controla
## Y dentro del tick normal del Player, para conservar contactos y movimiento horizontal.
@export var mode := Mode.TOTAL
## Segundos de Floater que este cuerpo pide al TERMINAR el recorrido. 0 = no detona Floater.
@export var float_duration := 0.0
## fall_scale del Floater que se pide al terminar: 0.0 = hold total, 1.0 = gravedad normal,
## intermedio = deriva lenta (ver combat/floater.gd). Solo aplica si float_duration > 0.
@export_range(0.0, 1.0) var float_fall_scale := 0.0
