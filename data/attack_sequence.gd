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
## WINDOW_END y player_travel_at_window_end) se cobran al cerrar el ULTIMO paso, no cada paso: el
## perfil describe el gesto completo, no el golpe suelto.

## Los golpes en orden. El ultimo es el finisher: es el que cobra el recovery post-cadena y el que
## dispara los hooks de cierre del perfil.
@export var steps: Array[AttackStep] = []

## Segundos que dura un paso que no declara duracion propia (AttackClip.duration en 0). 0 = usa
## WeaponTuning.swing_time. Es el default de la cadena, no un techo: un paso con clip propio manda.
@export var step_time := 0.0

## Segundos para encadenar el golpe siguiente una vez terminado el actual. Dejar pasar la ventana
## corta la cadena sin cobrar recovery.
@export var chain_window := 0.3

# Las ramas por espera NO viven aca: cuelgan del paso que las dispara (AttackStep.wait_threshold /
# wait_steps). Vivieron aca hasta el 2026-07-30 como un Array[AttackBranch] con un `after_step`
# absoluto, y eso forzaba a ramificar una sola vez por corrida: al reemplazar la cola, el contador de
# pasos seguia corriendo y la rama declarada mas adelante secuestraba a la que acababa de entrar.
