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

## Direccion del recorrido (se normaliza al usarse). UP es el caso tipico del launcher; un dash
## cargado usa el forward del atacante; un spike usa DOWN.
@export var direction := Vector3.UP
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
