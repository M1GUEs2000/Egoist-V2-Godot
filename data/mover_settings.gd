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
## EXCLUSIVO (true): el Mover se adueña del cuerpo — fija velocity y hace move_and_slide el mismo,
## cortando gravedad, horizontal y contactos durante el recorrido (launcher UP, dash cargado).
## NO-EXCLUSIVO (false): el Mover solo aporta la velocidad de su eje vertical y deja que el glue
## mueva el cuerpo con el resto vivo (horizontal, contactos, rebote en enemigo). Es el caso del
## plunge: cae recto pero seguis pudiendo cancelarlo rebotando en un enemigo.
@export var exclusive := true
## --- Extras de dash (ex PlayerDash.force_dash, portados al Mover). Solo aplican al dueño que los
## sepa aplicar por hooks; un launcher/plunge/spike los deja en false. ---
## Atraviesa enemigos durante el recorrido: el Mover quita LAYER_ENEMY del collision_mask del cuerpo
## al arrancar y lo restaura al terminar (dash ofensivo). El hitbox de daño es aparte, no se afecta.
@export var pass_through_enemies := false
## Al arrancar, empuja el bump del cuerpo en la dirección del recorrido (boost de momentum del dash).
## Lo aplica el dueño por hook (Player.on_mover_started); un cuerpo que no lo implemente lo ignora.
@export var boost_momentum := false
## Al terminar, deja inercia aérea en la dirección del recorrido a move_speed (continuidad post-dash).
## Lo aplica el dueño por hook (Player.on_mover_ended).
@export var keep_exit_inertia := false
## Prende las partículas de dash del dueño mientras dura el recorrido (visual del dash). Hook.
@export var emit_dash_particles := false

## Segundos de Floater que este cuerpo pide al TERMINAR el recorrido. 0 = no detona Floater.
@export var float_duration := 0.0
## fall_scale del Floater que se pide al terminar: 0.0 = hold total, 1.0 = gravedad normal,
## intermedio = deriva lenta (ver combat/floater.gd). Solo aplica si float_duration > 0.
@export_range(0.0, 1.0) var float_fall_scale := 0.0
