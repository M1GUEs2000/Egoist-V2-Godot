class_name AttackSequence extends Resource
## Una cadena de golpes declarada como datos: los pasos, cuanto dura cada uno, la ventana para
## encadenar el siguiente y las ramas por espera. Reemplaza a WeaponBase.run_combo_chain, que recibia
## la forma de la cadena como seis parametros sueltos mas dos Callables de coreografia.
##
## Lo que esto habilita y el runner viejo no podia:
##
##   - Un paso puede tener su propia duracion, su propio clip y su propio dano. Antes todos los
##     golpes de una cadena median swing_time y el clip lo elegia un match hardcodeado por indice.
##   - Cada paso abre su propia ventana de dano, asi que N golpes son N impactos (ver AttackStep).
##   - Un paso puede llevar su AttackMovementProfile, o sea "el Mover sale en el tercer golpe" es
##     tuning. Ese era el motivo por el que los combos no podian ser datos.
##   - La cadena es un ARBOL, no una linea con una desviacion. Cada paso declara su propia rama por
##     espera (AttackStep.wait_threshold / wait_steps), asi que se puede ramificar tantas veces como
##     golpes tenga: `X X espera X espera X X X` es un paso con rama cuyo primer paso tiene otra.
##
## Los hooks del AttackMovementProfile que dependen del cierre de la ventana (EnemyTravelAt.
## WINDOW_END y player_travel_at_window_end) los cobra el ULTIMO paso y ademas cualquier paso que
## traiga perfil propio. Un paso sin perfil no cobra nada: el perfil del paso anterior ya se limpio.

## Los golpes en orden. El ultimo es el finisher: es el que cobra el recovery post-cadena y el que
## dispara los hooks de cierre del perfil.
@export var steps: Array[AttackStep] = []

## Segundos que dura un paso que no declara duracion propia (AttackClip.duration en 0). 0 = usa
## WeaponTuning.swing_time. Es el default de la cadena, no un techo: un paso con clip propio manda.
@export var step_time := 0.0

## Segundos para encadenar el golpe siguiente una vez terminado el actual. Dejar pasar la ventana
## corta la cadena sin cobrar recovery. Se ignora con `auto_chain` prendido.
@export var chain_window := 0.3

## Los pasos salen uno tras otro SIN pedir input. Es lo unico que separa un COMBO de un GESTO de
## varios tramos: el combo se gana golpe a golpe con un tap dentro de `chain_window`, el gesto ya se
## decidio cuando se disparo (un cargado, una secuencia de RT) y se corre entero solo.
##
## Es lo que permite que un cargado sean tres animaciones con tres ventanas de dano en vez de un
## clip suelto con una ventana estirada. Sin esto el runner cortaba el gesto despues del primer paso,
## porque se quedaba esperando un tap que en un cargado no llega nunca.
##
## No alcanzaba con poner `chain_window` en 0: eso ya significa "no se puede encadenar, corta al
## toque", que es un caso legitimo y distinto.
@export var auto_chain := false

## Segundos de recovery al terminar el ultimo paso, durante los cuales no arranca otra secuencia.
## -1 = usa WeaponTuning.combo_recovery, que es el recovery del combo del arma. Existe para que un
## gesto pueda tener el suyo: un cargado de compromiso suele querer pagar mas que un combo, y un
## tramo de RT que encadena con otra cosa suele querer 0.
@export var recovery := -1.0

## Segundos de recovery reales de esta cadena.
func recovery_seconds(weapon_default: float) -> float:
	return weapon_default if recovery < 0.0 else recovery

# Las ramas por espera NO viven aca: cuelgan del paso que las dispara (AttackStep.wait_threshold /
# wait_steps). Vivieron aca hasta el 2026-07-30 como un Array[AttackBranch] con un `after_step`
# absoluto, y eso forzaba a ramificar una sola vez por corrida: al reemplazar la cola, el contador de
# pasos seguia corriendo y la rama declarada mas adelante secuestraba a la que acababa de entrar.
