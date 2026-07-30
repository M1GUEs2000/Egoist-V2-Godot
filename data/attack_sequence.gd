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
##   - Varias ramas por cadena, no una sola. El combo aereo de la Espada tiene dos puntos de espera
##     distintos (vueltas tras el golpe 1, plunge tras el golpe 2) y el runner viejo solo soportaba
##     uno, asi que el segundo estaba implementado a mano dentro de la coreografia del arma.
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

## Ramas por espera, evaluadas por `after_step`. Ver data/attack_branch.gd.
##
## Solo entra UNA por corrida: una vez que la cadena se fue por una rama, los pasos que siguen son
## los de esa rama y no se vuelve a evaluar nada. Es lo que hace el juego hoy — si esperaste tras el
## primer golpe aereo entras a las vueltas, y ahi la espera del plunge ya no aplica.
@export var branches: Array[AttackBranch] = []

## Los pasos que corren tras ramificar en `after_step`, o los originales si esa rama no entro.
func steps_after(after_step: int, waited: float) -> Array[AttackStep]:
	for branch in branches:
		if branch != null and branch.after_step == after_step and waited >= branch.threshold:
			return branch.steps
	return []

## True si algun paso de la cadena puede ramificar justo despues de `step_index`. Evita que el runner
## mida esperas en golpes donde ninguna rama las mira.
func branches_after(step_index: int) -> bool:
	for branch in branches:
		if branch != null and branch.after_step == step_index:
			return true
	return false
