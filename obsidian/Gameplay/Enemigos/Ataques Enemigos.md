---
title: Ataques Enemigos
tags:
  - egoist
  - enemigo
  - combate
status: active
system_status: E2
hito: H1
---

# Ataques Enemigos

Los ataques son componentes. Un enemigo puede no tener ataques, tener melee, ranged o ambos.

| Componente | Funcion |
|---|---|
| `MeleeAttack` | Combo de swings, dano, cooldown, ventana de parry. |
| `RangedAttack` | Windup, proyectil, homing, cadencia y dano. |
| `Projectile` | Viaja, gira hacia objetivo si hay homing, impacta y expira. |
| `AttackLoadout` | **Que familias tiene equipadas**: solo melee, solo ranged o ambas. |

## AttackLoadout — el modulo inyectable

`AttackLoadout` es un nodo hijo **opcional** que decide que familias de ataque puede usar su dueño (`@export_flags` Melee / Ranged). Se le enchufa a **cualquier** enemigo que componga ataques; sin el, el enemigo usa todos los suyos (comportamiento historico, retrocompatible). *(2026-07-13)*

Antes, "este enemigo no pega de cerca" pedia **escribir una subclase por enemigo** que vaciara `_attacks` a mano — asi funcionaba el viejo `RangedDead`. Esa subclase ya no existe: hoy es una casilla en el inspector.

> [!info] Un ataque no equipado queda INERTE, no invisible-pero-peligroso
> `GroundedEnemy._collect_attacks` no lo registra, asi que nunca recibe `try_attack`; sin `try_attack` no hay `begin_swing`, y sin `begin_swing` su `Hitbox` jamas prende el `monitoring` (arranca en `false`, ver `Hitbox._ready`). Ademas el dueño le apaga la malla: un solo-ranged no pasea con una espada colgando. Cubierto por asserts en el smoke de combate.

`AttackLoadout` es **politica pura**: solo contesta `allows(attack)`. Quien recorre los hijos, los registra y les apaga la malla es el dueño — el modulo no toca a sus hermanos.

## Melee fisico

`MeleeAttack` usa el mismo contrato de arma procedural que la Espada: `Hand` orbita el
enemigo, `Pivot` mantiene la hoja rigida y `BladeHitbox` barre con la trayectoria real.
El combo base es **swing, swing, estocada, estocada**. `attack_range` solo decide cuando
la IA inicia el ataque; nunca aplica dano a distancia. Dano, stun y empuje del player solo
ocurren cuando `BladeHitbox` toca su `Hurtbox`.

## Hibridos

Un hibrido es un enemigo con **las dos familias equipadas** (`AttackLoadout` con Melee + Ranged). No es un tipo especial ni una subclase: es la misma pieza con otra casilla marcada. `GroundedEnemy._best_attack_state_for_range` elige por distancia:

- Melee si el objetivo esta dentro del `attack_range` del `MeleeAttack`.
- Ranged si esta mas lejos pero dentro del `attack_range` del `RangedAttack`.

Prefab de ejemplo: `enemies/hybrid_enemy.tscn` — melee + ranged + un `WorldSwitchTrigger` en `ON_DEATH`, o sea que **matarlo voltea el mundo de todos**. Los dos ejes son ortogonales: el loadout dice con que pega, el trigger dice que le hace al mundo (ver [[Afiliacion de Mundo]]).

> [!warning] Un enemigo de world switch NO usa su `normal_color`
> `EnemyBase._refresh_visual_state` se lo pisa con el color del mundo OPUESTO (mas el latido): anuncia a donde te manda. Setear `normal_color` en un enemigo con `WorldSwitchTrigger` es letra muerta — su identidad visual tiene que salir de la silueta (mallas propias), no del color.

## Pendiente

- Tuning por enemigo (los knobs del hibrido son de primer pase).
- Validar jugando que la transicion melee↔ranged del hibrido no se sienta nerviosa en el borde entre ambos rangos (hoy no hay histeresis en la eleccion de ataque, a diferencia de la de target).
- Feedback de windup/proyectil.
- Decidir si H1 necesita evasiones o lanzamientos de objetos.

## Relacionado

- [[IA]]
- [[Melee Living]]
- [[Ranged Dead]]
