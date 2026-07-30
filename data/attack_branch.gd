class_name AttackBranch extends Resource
## Rama de espera de una secuencia: si el jugador tarda en encadenar despues de cierto golpe, el
## resto de la cadena se reemplaza por otros pasos. Es la mecanica de "X X espera X" de la Espada,
## que hasta ahora vivia como dos parametros del runner (branch_step / branch_threshold) mas un
## bool que cada arma interpretaba dentro de su coreografia.
##
## POR QUE ES UN RESOURCE APARTE Y NO UN CAMPO DE AttackStep: si la rama colgara del paso, AttackStep
## tendria que referenciar a AttackSequence y AttackSequence a AttackStep — un ciclo entre dos
## class_name, que GDScript resuelve mal. Colgando de la secuencia el grafo queda en un solo sentido.

## Despues de que golpe se evalua la espera (1-based). El combo terrestre de la Espada ramifica
## despues del golpe 2 (los golpes 3 y 4 pasan de estocadas a vueltas); el aereo ramifica despues
## del 1 (vueltas) y tambien despues del 2 (plunge).
@export var after_step := 1

## Segundos que hay que tardar en encadenar para que la rama entre. Se mide entre el fin del golpe
## `after_step` y el tap que pide el siguiente, siempre DENTRO de la ventana de encadene: pasarse de
## la ventana no ramifica, corta la cadena.
@export var threshold := 0.2

## Los pasos que reemplazan a todo lo que venia despues de `after_step`. No se agregan: sustituyen.
## Pueden ser mas o menos que los originales, asi que una rama puede alargar o acortar el combo.
@export var steps: Array[AttackStep] = []
