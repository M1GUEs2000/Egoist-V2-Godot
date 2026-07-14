---
title: IA
tags:
  - egoist
  - gameplay
  - sistema
  - ia
status: active
system_status: E2
hito: H1
---

# IA

IA cubre percepcion, decision, movimiento enemigo y seleccion de ataque.

## Motor de decision: LimboAI

> [!important] Backend unico
> El motor de decision es [[Integraciones|LimboAI]] (BT + HSM), validado en engine el 2026-07-13. **Todo trabajo nuevo de IA se hace sobre el arbol de LimboAI**: hojas `BTAction` / `BTCondition` en `enemies/ai/tasks/`, blackboard en `EnemyAIBlackboard` y forma del arbol en `EnemyLimboTreeBuilder`. La FSM manual de `GroundedEnemy` (`use_simple_fsm`) queda solo como red de seguridad si el GDExtension no carga: no se le agregan comportamientos nuevos.

El backend se elige con `ai_backend` (`LIMBO` por default). El arbol corre en un `BTPlayer` en modo manual, tickeado desde `_physics_process`. `GroundedEnemy` sigue siendo el glue: percepcion, target, cadencia de ataque y los gates del evade viven ahi, y el arbol los consume via los metodos `limbo_*`.

## Arquitectura y spec

El plano construible vive **en el codigo**, en `enemies/ai_spec/*.yaml` (no en la boveda: la boveda documenta, el codigo es la fuente).

| Archivo (`enemies/ai_spec/`) | Que define |
|---|---|
| `ai_states.yaml` | Los 15 estados, su capa (decide/steer/coord) y su hoja LimboAI. |
| `fsm_decision_tree.yaml` | La forma del arbol de decision y la frontera decision/ejecucion. |
| `hostility_profiles.yaml` | Los 4 perfiles como UN arbol compartido parametrizado por blackboard. |
| `blackboard.yaml` | Schema del blackboard seccionado (el decouple: percepcion escribe, decision emite intent, locomocion ejecuta). |
| `leaf_tasks.yaml` | Catalogo de hojas reutilizables, target scoring por utility y contrato de locomocion + stuck-check + enganche navmesh. |

**Tres capas** (game-ai): `decide` (que hacer), `steer` (como moverse — `GroundLocomotion`, incluye EVADE), `coord` (multi-agente — CALL_HELP, ATTACK_GROUP). Regla del decouple: la decision **emite intent**, nunca llama locomocion directo. Asi enchufar navmesh no toca la decision.

## Telegraph del ataque del player

`PlayerCombat.attack_telegraphed(origin, direction)` se emite al arrancar un ataque (en el press). **Emisor implementado** (2026-07-08); no agrega delay al ataque (los swings son procedurales, la hoja tarda en barrer). **Receptor implementado** (2026-07-13): `GroundedEnemy._on_player_attack_telegraphed` corre los gates de EVADE, escribe `combat.incoming_attack_until` y agenda el esquive — ver [[Comportamientos]]. El estado DEFEND que reusa esa condicion sigue pendiente. Ver `enemies/ai_spec/leaf_tasks.yaml` (condicion `IncomingAttack`).

## Estados

El enum `AIState` de `GroundedEnemy` es un catalogo comun a todos los enemigos. Cada enemigo activa o desactiva estados con `allowed_state_flags`; si un estado no esta permitido, se cae al fallback mas cercano (`_fallback_state`). La intencion de cada estado cambia segun [[Hostilidad]].

Catalogo completo, que hace cada uno en general y cuales tienen logica real implementada: [[Comportamientos]]. *(2026-07-08)*

> [!warning]
> `ATTACK_GROUP`, `DEFEND` y `CALL_HELP` son solo enum/flag hoy — ninguna hoja del arbol los produce ni los maneja. Ver detalle en [[Comportamientos]].

## Percepcion y memoria

Ningun enemigo es omnisciente (los agresivos y ultra agresivos ya no detectan por magia). Toda deteccion pasa por `Perception`: rango de vision + angulo de vision + raycast contra el mundo. Guarda la ultima posicion conocida; la persecucion se corta cuando pierde linea de vision y se agota la memoria. *(2026-07-07)*

Memoria por hostilidad (default): pasivo `10s`, reactivo `20s`, agresivo `40s`, ultra agresivo `60s`.

## FLEE / HIDE

- `FLEE` se evalua **una sola vez** al cruzar `current / max_health <= 0.30`; si la tirada falla, no se reintenta para esa bajada de vida.
- Chance por hostilidad: pasivo `0.50`, reactivo `0.25`, agresivo `0.05`, ultra agresivo `0.0`.
- `HIDE` nunca se activa solo: solo puede venir despues de `FLEE`.
- El movimiento de huida vive en `GroundLocomotion.flee_from`.

## Bloques

| Bloque | Responsabilidad |
|---|---|
| `Perception` | Rango, angulo, raycast, ultima posicion conocida y memoria por hostilidad. |
| `GroundLocomotion` | Chase, roam, search, huida (`flee_from`), strafe (orbita/esquive, intent `STRAFE`) y `stop` para estados pasivos/guard/hide. |
| `MeleeAttack` | Combo melee y ventana de parry; aplica `receive_stun` si el ataque trae `StunSettings`. |
| `RangedAttack` | Windup, proyectil y homing. |

## Hostilidad

La intencion por nivel (`PASSIVE`, `REACTIVE`, `AGGRESSIVE`, `ULTRA_AGGRESSIVE`) vive en [[Hostilidad]]: quien inicia combate, que significa SEARCH para cada uno, chances de huida y estados vetados.

## Escena de prueba

`test_scene` es un greybox amplio (piso, muros y plataformas de prueba) con grupos por hostilidad: 4 pasivos en circulo, 2 reactivos mas lejos, 2 agresivos todavia mas lejos y 1 ultra agresivo (con `FLEE`, `HIDE`, `GUARD` y `ATTACK_GROUP` desactivados via `allowed_state_flags`). Todos, incluido el ultra agresivo, heredan afiliacion Dead: `grounded_enemy.tscn` trae `WorldMembership.affiliation = DEAD` por defecto y ninguna instancia en `test_scene` la overridea — ver [[Afiliacion de Mundo]]. *(2026-07-07, corregido 2026-07-09)*

## Pendiente H1

- Tuning por escena de rangos, cooldowns, vision y homing (los valores son de primer pase).
- Validar seleccion melee/ranged por distancia.
- Tunear jugando el engage y el esquive: cadencia entre combos, ring de orbita y `evade_*`. Ver [[Comportamientos]].
- **Retirar el fallback FSM** de `GroundedEnemy` (`use_simple_fsm` + las ramas `_update_fsm` / `_process_*`), dejando el arbol como unico camino.
- Implementar (o borrar del enum si se descartan) `ATTACK_GROUP` (coord/director, H3+), `DEFEND` (decide; el receptor del telegraph ya escribe `incoming_attack_until`, H2), `CALL_HELP` (coord ligera, H2). Ver [[Comportamientos]].

## Pendiente diferido

- **Navmesh** (`NavigationAgent3D` / `NavigationRegion3D`): diferido. El enganche esta disenado en `leaf_tasks.yaml#locomotion_contract` para que enchufarlo no toque la decision. Decidir sí/no segun la geometria real de Playa. *(2026-07-08)*

## Relacionado

- [[Enemigos]]
- [[Hostilidad]]
- [[Comportamientos]]
- [[hitos]]
