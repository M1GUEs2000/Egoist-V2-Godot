class_name DeflectTuning extends Resource
## Que le pasa a un proyectil cuando el player lo parria, compartido por TODOS los proyectiles
## (instancia unica en data/deflect_tuning.tres). El deflect es PURO: solo da vuelta el proyectil
## contra quien lo tiro. No toca el estado VULNERABLE cian del parry melee (ver ParryTuning) — el
## tirador se staggerea con su propio tiro, por el pipeline de poise normal del impacto.
##
## Un proyectil puede sobreescribirlo con su propio @export var deflect_tuning si algun dia necesita
## un deflect distinto; por default todos comparten este .tres.

## Multiplicador de la velocidad del proyectil al rebotar. >1 = el rebote sale mas rapido que el tiro.
@export var speed_multiplier := 1.0
## Multiplicador del daño (y de los hits de enemigo) del proyectil rebotado. 1.0 = pega igual que el
## tiro original; subirlo convierte el parry de proyectil en una recompensa, no solo en una defensa.
@export var damage_multiplier := 1.0
## Segundos de vida que se le devuelven al proyectil al rebotar. Corre desde el parry, y reemplaza
## lo que le quedaba del lifetime original: sin esto un tiro parriado tarde muere antes de volver.
@export var lifetime := 5.0
## Homing del rebote, en grados/segundo: cuanto corrige el proyectil para seguir al tirador que se
## mueve. Reemplaza al turn_rate del tiro original (0 = el rebote va recto adonde estaba el tirador).
@export var turn_rate := 120.0
## Radio de la esfera golpeable del proyectil, en metros. Es la ventana espacial del parry: cuanto
## mas grande, mas facil es que el arma del player lo alcance al pasar.
@export var hurtbox_radius := 0.45
