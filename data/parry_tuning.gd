class_name ParryTuning extends Resource
## Resultado de un parry correcto, compartido por TODOS los enemigos (instancia unica en
## data/parry_tuning.tres). El poise que INFLIGE el parry es por arma/ataque (WeaponTuning);
## esto define que le pasa al enemigo cuando ese poise le quiebra la reserva: entra en el estado
## VULNERABLE cian (recibe daño multiplicado) y queda stuneado. Ver EnemyBase.resolve_parry.
##
## Un enemigo puede sobreescribirlo con su propio @export var parry_tuning si algun dia necesita
## un parry distinto; por default todos comparten este .tres.

## Segundos que el enemigo queda stuneado tras un parry correcto (IA congelada).
@export var stun_duration := 1.5
## Segundos que dura la ventana VULNERABLE (daño multiplicado). Por default = stun; separarlos si
## se quiere que el enemigo siga recibiendo daño extra un rato despues de reaccionar.
@export var vulnerable_duration := 1.5
## Multiplicador del daño que recibe mientras esta VULNERABLE. 2.0 = doble.
@export var damage_multiplier := 2.0
## Color celeste del estado vulnerable (albedo + emision + luz), en vez del amarillo del stun comun.
@export var cyan_color := Color(0.3, 0.85, 1.0, 1.0)
## Energia de emision del cuerpo mientras esta vulnerable. Alto = "celeste brilloso" con el bloom.
@export var cyan_emission_energy := 3.0
