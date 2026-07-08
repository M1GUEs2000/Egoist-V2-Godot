---
title: Comportamientos
tags:
  - egoist
  - gameplay
  - ia
status: active
system_status: E2
hito: H1
---

# Comportamientos

Catalogo general de los 15 estados del enum `AIState` (`GroundedEnemy`), que hacen **en general**. Como cambia la intencion de cada uno segun el nivel de hostilidad vive en [[Hostilidad]] y en las notas por nivel ([[Pasivo]], [[Reactivo]], [[Agresivo]], [[Ultra Agresivo]]). *(2026-07-08)*

> [!warning] No todos estan implementados
> De los 15 estados del enum, solo 11 tienen logica real en `_update_fsm` / `_process_*`. `ATTACK_GROUP`, `EVADE`, `DEFEND` y `CALL_HELP` existen como valor de enum y como flag en `allowed_state_flags`, pero **ningun `_process_*` los produce ni los maneja** — hoy son catalogo sin comportamiento, no un stub jugable. Ver tabla abajo.

> [!info] Capa de IA
> Cada estado vive en una de tres capas (game-ai): **decide** (que hacer), **steer** (como moverse — `GroundLocomotion`), **coord** (multi-agente). El spec construible con la hoja LimboAI de cada estado esta en el codigo, en `enemies/ai_spec/ai_states.yaml`. *(2026-07-08)*

## Estados implementados

| Estado | Capa | Que hace | Modulo |
|---|---|---|---|
| `IDLE` | decide | Quieto; fallback final si ningun otro estado es legal. | `_fallback_state` |
| `ROAM` | steer | Patrulla alrededor del punto de spawn, radio y tiempos aleatorios. | `GroundLocomotion.roam` |
| `ACTIVITY` | decide | Actividad idle propia (dormir, comer presas...); en la practica cae a `roam`/`stop` segun el estado previo. | `_process_no_target` |
| `ALERT` | decide | Beat de reaccion: se activa un instante al pasar de no ver a ver al target (`alert_duration`), antes de perseguir. | `Perception.is_alerted` |
| `CHASE` | steer | Persigue al target en linea recta. | `GroundLocomotion.move_toward` |
| `GUARD` | decide | Se queda quieto en su posicion (fallback de [[Reactivo]] sin target). | `_process_no_target` |
| `SEARCH` | steer | Va a la ultima posicion conocida del target mientras dure la memoria por hostilidad. | `GroundLocomotion.search_last_known` |
| `ATTACK_MELEE` | decide | Ataque cuerpo a cuerpo: combo de swings con ventana de parry. | `MeleeAttack` |
| `ATTACK_RANGED` | decide | Windup, dispara `Projectile` con homing. | `RangedAttack` |
| `FLEE` | steer | Se aleja del target; tirada unica al cruzar 30% de vida. | `GroundLocomotion.flee_from` |
| `HIDE` | decide | Se esconde quieto; solo puede venir despues de `FLEE` exitoso y con el target fuera de vista. | `_process_flee` |

## Estados sin implementar (solo catalogo)

Ya no son huecos "a ciegas": cada uno tiene su capa y diseno destino en `enemies/ai_spec/`. *(2026-07-08)*

| Estado | Capa | Intencion | Diseno destino / que falta | Hito |
|---|---|---|---|---|
| `EVADE` | steer | Reposiciona/esquiva. | Es un **modo de movimiento**, no peer de CHASE: steering de strafe en `GroundLocomotion` + condicion que lo selecciona. El mas barato. | H2 |
| `CALL_HELP` | coord | Pide refuerzos. | Coordinacion **ligera**: generaliza `_provoke_nearby` via señal a grupo (`blackboard.coordination`). Godot-native, sin director. | H2 |
| `DEFEND` | decide | Postura defensiva. | Rama de alta prioridad. La condicion `IncomingAttack` ya es escribible (el **telegraph del player existe**); falta el receptor que escribe `combat.incoming_attack_until` y el `_process_defend`. | H2 |
| `ATTACK_GROUP` | coord | Ataque coordinado en grupo. | Coordinacion **fuerte**: NO es estado por-enemigo, pide un **director de equipo** (autoload con tokens de ataque). Reusa el target scoring por utility. | H3+ |

Mientras no se implementen, dejarlos fuera de `allowed_state_flags` en las escenas no cambia nada — nunca se llegan a producir de todas formas.

## Relacionado

- [[IA]]
- [[Hostilidad]]
- [[Enemigos]]
