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

## Decision V2

> [!important]
> No se porta Unity Behavior Tree. Hoy `GroundedEnemy` corre una FSM (priority-selector escrito a mano). **Decision tomada (2026-07-08): se adopta [[Integraciones|LimboAI]] (BT + HSM) desde el inicio, no "migrar despues"** — al ser GDExtension drop-in (no fork del engine), el costo de integracion que antes lo desaconsejaba ya no existe, y el roster futuro + coordinacion de grupo la piden. La FSM actual ya ES un priority-selector, asi que el port es cambiar el selector, no reescribir.

> [!info] Port code-only (2026-07-10)
> `GroundedEnemy` tiene backend dual `FSM / LIMBO`. El default sigue en FSM hasta
> validacion en Godot. El port a LimboAI esta armado en codigo con `BTPlayer` manual,
> `EnemyAIBlackboard`, `EnemyLimboTreeBuilder` y hojas `BTAction` / `BTCondition` en
> `enemies/ai/tasks/`. Sin Godot local, queda pendiente validar import, carga del
> GDExtension y comportamiento en `test_scene`.

## Arquitectura destino y spec

El plano construible vive **en el codigo**, en `enemies/ai_spec/*.yaml` (no en la boveda: la boveda documenta, el codigo es la fuente). *(2026-07-08)*

| Archivo (`enemies/ai_spec/`) | Que define |
|---|---|
| `ai_states.yaml` | Los 15 estados, su capa (decide/steer/coord) y su hoja LimboAI. |
| `fsm_decision_tree.yaml` | El selector actual + la forma destino como BT de LimboAI y la frontera decision/ejecucion. |
| `hostility_profiles.yaml` | Los 4 perfiles como UN arbol compartido parametrizado por blackboard. |
| `blackboard.yaml` | Schema del blackboard seccionado (el decouple: percepcion escribe, decision emite intent, locomocion ejecuta). |
| `leaf_tasks.yaml` | Catalogo de hojas reutilizables, target scoring por utility y contrato de locomocion + stuck-check + enganche navmesh. |

**Tres capas** (game-ai): `decide` (que hacer), `steer` (como moverse — `GroundLocomotion`, incluye EVADE), `coord` (multi-agente — CALL_HELP, ATTACK_GROUP). Regla del decouple: la decision **emite intent**, nunca llama locomocion directo. Asi enchufar navmesh o portar a LimboAI no toca la decision.

## Telegraph del ataque del player

`PlayerCombat.attack_telegraphed(origin, direction)` se emite al arrancar un ataque (en el press). Es el estimulo que DEFEND/EVADE percibiran. **Implementado el emisor** (2026-07-08); no agrega delay al ataque (los swings son procedurales, la hoja tarda en barrer). El receptor enemigo que escribe `combat.incoming_attack_until` y el estado DEFEND que lo consume estan pendientes. Ver `enemies/ai_spec/leaf_tasks.yaml` (condicion `IncomingAttack`).

## Estados FSM

El enum `AIState` de `GroundedEnemy` es un catalogo comun a todos los enemigos. Cada enemigo activa o desactiva estados con `allowed_state_flags`; si un estado no esta permitido, la FSM cae al fallback mas cercano. La intencion de cada estado cambia segun [[Hostilidad]]. *(2026-07-07)*

Catalogo completo, que hace cada uno en general y cuales tienen logica real implementada: [[Comportamientos]]. *(2026-07-08)*

> [!warning]
> `ATTACK_GROUP`, `EVADE`, `DEFEND` y `CALL_HELP` son solo enum/flag hoy — ningun `_process_*` los produce ni los maneja. Ver detalle y que falta en [[Comportamientos]]. *(2026-07-08)*

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
| `GroundLocomotion` | Chase, roam, search, huida (`flee_from`) y `stop` para estados pasivos/guard/hide. |
| `MeleeAttack` | Combo melee y ventana de parry; aplica `receive_stun` si el ataque trae `StunSettings`. |
| `RangedAttack` | Windup, proyectil y homing. |

## Hostilidad

La intencion por nivel (`PASSIVE`, `REACTIVE`, `AGGRESSIVE`, `ULTRA_AGGRESSIVE`) vive en [[Hostilidad]]: quien inicia combate, que significa SEARCH para cada uno, chances de huida y estados vetados.

## Escena de prueba

`test_scene` es un greybox amplio (piso, muros y plataformas de prueba) con grupos por hostilidad: 4 pasivos en circulo, 2 reactivos mas lejos, 2 agresivos todavia mas lejos y 1 ultra agresivo (con `FLEE`, `HIDE`, `GUARD` y `ATTACK_GROUP` desactivados via `allowed_state_flags`). Todos, incluido el ultra agresivo, heredan afiliacion Dead: `grounded_enemy.tscn` trae `WorldMembership.affiliation = DEAD` por defecto y ninguna instancia en `test_scene` la overridea — ver [[Afiliacion de Mundo]]. *(2026-07-07, corregido 2026-07-09)*

## Pendiente H1

- Tuning por escena de rangos, cooldowns, vision y homing.
- Validar seleccion melee/ranged por distancia.
- Probar en engine la FSM ampliada por hostilidad (los valores son de primer pase). *(pendiente de probar)*
- **Validar backend LimboAI en Godot**: import, carga de `BTPlayer`, tareas custom y equivalencia de comportamiento contra FSM en `test_scene`. *(2026-07-10)*
- **Retirar fallback FSM** solo despues de validacion runtime jugando/headless. *(2026-07-10)*
- **Validar LimboAI en Godot editor/headless** tras import: confirmar que `addons/limboai/bin/limboai.gdextension` carga sin errores en Windows y que no hay DLL temporal abierta antes de commitear. *(2026-07-09)*
- **Target scoring por utility** (proximidad + compromiso) para arreglar el flip-flop de target de [[Ultra Agresivo]]. Ver `leaf_tasks.yaml#target_selection`. *(2026-07-08)*
- **Stuck-check** en `GroundLocomotion` (no-negociable): sin esto los enemigos muelen contra muros del greybox. *(2026-07-08)*
- Implementar (o borrar del enum si se descartan) `ATTACK_GROUP` (coord/director, H3+), `EVADE` (steer, H2), `DEFEND` (decide + receptor del telegraph, H2), `CALL_HELP` (coord ligera, H2). Ver [[Comportamientos]]. *(2026-07-08)*

## Pendiente diferido

- **Navmesh** (`NavigationAgent3D` / `NavigationRegion3D`): diferido. El enganche esta disenado en `leaf_tasks.yaml#locomotion_contract` para que enchufarlo no toque la decision. Decidir sí/no segun la geometria real de Playa. *(2026-07-08)*

## Relacionado

- [[Enemigos]]
- [[Hostilidad]]
- [[Comportamientos]]
- [[hitos]]
