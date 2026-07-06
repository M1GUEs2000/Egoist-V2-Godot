class_name StunSettings extends Resource
## Duración de stun de un golpe, distinta si el objetivo está en el aire o en el suelo
## (ex StunSettings.cs). La define QUIEN ataca (arma, dash, enemigo), no el enemigo —
## así cada fuente de daño tiene su propio stun. Instancias .tres viven en data/.

@export var grounded := 1.0
@export var airborne := 1.0

func duration_for(is_airborne: bool) -> float:
	return airborne if is_airborne else grounded
