class_name AttackLoadout extends Node
## Modulo componible: decide QUE familias de ataque puede usar su dueño (melee, ranged o ambas).
## Es el reemplazo de la subclase-por-enemigo: antes, "este enemigo no pega de cerca" pedia
## escribir un script propio que vaciara `_attacks` a mano (el viejo `RangedDead`). Ahora es una
## casilla en el inspector, y funciona sobre CUALQUIER enemigo que componga ataques.
##
## No hace falta borrar el nodo del ataque que no se usa: un ataque que la IA no registra nunca
## recibe `try_attack`, y sin `try_attack` no hay `begin_swing`, asi que su `Hitbox` jamas prende
## el monitoring (ver Hitbox._ready). Queda inerte, no invisible-pero-peligroso.
##
## Es politica pura: responde "¿este ataque esta equipado?" y nada mas. Quien recorre los hijos,
## los registra y les apaga la malla es el dueño (`GroundedEnemy._collect_attacks`).
##
## Sin este nodo, el enemigo usa TODOS sus ataques (comportamiento historico). Es opt-in.

## Familias de ataque. Los valores son los bits de `enabled_kinds`.
enum Kind {
	MELEE = 1,
	RANGED = 2,
}

## Que familias tiene equipadas este enemigo. Solo melee, solo ranged, o ambas (el hibrido: la
## IA elige por distancia, ver `GroundedEnemy._best_attack_state_for_range`). Ninguna marcada =
## no ataca — util para presa/ambiente que existe para ser golpeado.
@export_flags("Melee", "Ranged") var enabled_kinds := Kind.MELEE | Kind.RANGED

## ¿Esta equipada la familia de este ataque? Una familia que este modulo no conoce se deja pasar:
## no vetamos lo que no entendemos, y la regla de 2 dice que no se generaliza hasta el 2º caso.
func allows(attack: Node) -> bool:
	if attack is MeleeAttack:
		return (enabled_kinds & Kind.MELEE) != 0
	if attack is RangedAttack:
		return (enabled_kinds & Kind.RANGED) != 0
	return true
