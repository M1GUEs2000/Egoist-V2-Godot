class_name StunSettings extends Resource
## Stun de un golpe: cuanto poise le come y cuanto dura si lo quiebra. Lo define QUIEN ataca
## (arma, ataque cargado, dash, enemigo), no el receptor — asi cada fuente pega distinto y un
## cargado puede tener su propio poise sin tocar codigo. Instancias .tres viven en data/.
##
## El poise_damage NO decide solo: se acumula en el Poise del receptor (combat/poise.gd) y el
## stun entra recien cuando ese acumulado supera su reserva.

## Poise que come este golpe. Alto = quiebra en pocos golpes (Mazo); bajo = hay que insistir
## (Espada). 0 = nunca staggerea, solo hace daño.
@export var poise_damage := 1.0
## Duracion del stun si quiebra al objetivo en el suelo, en segundos.
@export var grounded := 1.0
## Duracion del stun si quiebra al objetivo en el aire (mas larga: sostiene el juggle).
@export var airborne := 1.0

func duration_for(is_airborne: bool) -> float:
	return airborne if is_airborne else grounded
