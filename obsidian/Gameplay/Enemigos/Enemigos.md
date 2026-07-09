---
title: Enemigos
tags:
  - egoist
  - gameplay
  - enemigos
  - sistema
status: active
system_status: E2
hito: H1
---

# Enemigos

> [!info] Frontera con [[IA]]
> **Enemigos = que son**: identidad, roster, mascara/cordura, afiliacion de mundo, estados de combate, muerte, objetos golpeables. **IA = como piensan y se mueven**: percepcion, persecucion, roam, busqueda, seleccion de ataque.

Los enemigos de Egoist no son solo unidades de combate. Son portadores de mascaras rotas, actores del ecosistema vivo y piezas del world switch/traversal.

## Navegacion

| Nota | Contenido |
|---|---|
| [[Modelo de Enemigo]] | Arquitectura Godot: `EnemyBase`, `GroundedEnemy`, `Health`, `Hurtbox`, ataques. |
| [[Mascaras y Cordura]] | Sane, Not so sane, Insane; relacion con lore y hostilidad. |
| [[Hostilidad]] | Passive, Reactive, Aggressive, UltraAggressive — resumen; detalle por nivel en [[Pasivo]], [[Reactivo]], [[Agresivo]], [[Ultra Agresivo]]. |
| [[Afiliacion de Mundo]] | Fixed, Both, Timed, Follows y OnDeath. |
| [[Estados de Combate Enemigo]] | Normal, Armored, Stunned, Airborne, Parry vulnerable, muerte. |
| [[Stun]] | Umbral de stun, resistencia por armadura y juggle en el aire. |
| [[Ataques Enemigos]] | Melee, ranged, hibridos y seleccion por distancia. |
| [[Ecosistema Vivo]] | Enemigos que se atacan entre si, aggro grupal, objetivos no jugador. |
| [[Objetos Golpeables]] | Pickups, bloques, paredes y objetos con `Health` sin IA. |
| [[Roster Enemigos]] | Roster por area y por hito. |
| [[Melee Living]] | Enemigo melee H1. |
| [[Ranged Dead]] | Enemigo ranged H1. |
| [[Armored Enemy]] | Enemigo armored H1. |
| [[Jefes]] | Jefes por area. |

## Reglas compartidas

- Todos los enemigos reales componen `Health`, `Hurtbox` y `WorldMembership`.
- La vida del enemigo se configura en `Health.max_health`.
- Las armas golpean via `Hurtbox`; los verbos opcionales (`launch`, `slam`, `push`, `try_parry`) se llaman con duck typing.
- Un enemigo tambien puede ser terreno de traversal: `PlayerEnemyBounce` permite rebotar manualmente desde su colision fisica. Es una decision de diseno, no un accidente de la fisica.
- Un enemigo puede existir en un mundo, ambos mundos, seguir el mundo actual o alternar por tiempo.
- `UltraAggressive` puede atacar a otros enemigos; el mundo no existe solo para servir al jugador.
- Los objetos golpeables no son enemigos: comparten `Health`/`Hurtbox`, pero no IA ni lock-on.

## Estado Godot

| Sistema | Modulos | Estado |
|---|---|---|
| Enemigo base | `EnemyBase` | E2 |
| Enemigo de suelo | `GroundedEnemy` | E2 |
| Percepcion/locomocion | `Perception`, `GroundLocomotion` | E2 |
| Ataques | `MeleeAttack`, `RangedAttack`, `Projectile` | E2 |
| Mundo | `WorldMembership`, `WorldSwitchTrigger` | E2 |
| Roster H1 | Melee, ranged, armored | Diseno/prefab pendiente |

## Pendiente H1

- Convertir los tres tipos H1 en prefabs/escenas claras.
- Tunear rangos, dano, vida, stun, armadura y homing.
- Validar fantasma fuera de mundo cuando exista [[World Switch]] visual.
- Definir si golpe normal hace knockback.

## Relacionado

- [[IA]]
- [[Combate]]
- [[Traversal]]
- [[Historia]]
