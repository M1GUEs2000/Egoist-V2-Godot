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

Catalogo general de los 14 estados del enum `AIState` (`GroundedEnemy`), que hacen **en general**. Como cambia la intencion de cada uno segun el nivel de hostilidad vive en [[Hostilidad]] y en las notas por nivel ([[Pasivo]], [[Reactivo]], [[Agresivo]], [[Ultra Agresivo]]). *(2026-07-08)*

> [!warning] No todos estan implementados
> De los 14 estados del enum, solo 10 tienen logica real en `_update_fsm` / `_process_*`. `ATTACK_GROUP`, `EVADE`, `DEFEND` y `CALL_HELP` existen como valor de enum y como flag en `allowed_state_flags`, pero **ningun `_process_*` los produce ni los maneja** — hoy son catalogo sin comportamiento, no un stub jugable. Ver tabla abajo.

## Estados implementados

| Estado | Que hace | Modulo |
|---|---|---|
| `IDLE` | Quieto; fallback final si ningun otro estado es legal. | `_fallback_state` |
| `ROAM` | Patrulla alrededor del punto de spawn, radio y tiempos aleatorios. | `GroundLocomotion.roam` |
| `ACTIVITY` | Actividad idle propia (dormir, comer presas...); en la practica cae a `roam`/`stop` segun el estado previo. | `_process_no_target` |
| `ALERT` | Beat de reaccion: se activa un instante al pasar de no ver a ver al target (`alert_duration`), antes de perseguir. | `Perception.is_alerted` |
| `CHASE` | Persigue al target en linea recta. | `GroundLocomotion.move_toward` |
| `GUARD` | Se queda quieto en su posicion (fallback de [[Reactivo]] sin target). | `_process_no_target` |
| `SEARCH` | Va a la ultima posicion conocida del target mientras dure la memoria por hostilidad. | `GroundLocomotion.search_last_known` |
| `ATTACK_MELEE` | Ataque cuerpo a cuerpo: combo de swings con ventana de parry. | `MeleeAttack` |
| `ATTACK_RANGED` | Windup, dispara `Projectile` con homing. | `RangedAttack` |
| `FLEE` | Se aleja del target; tirada unica al cruzar 30% de vida. | `GroundLocomotion.flee_from` |
| `HIDE` | Se esconde quieto; solo puede venir despues de `FLEE` exitoso y con el target fuera de vista. | `_process_flee` |

## Estados sin implementar (solo catalogo)

| Estado | Intencion documentada | Que falta |
|---|---|---|
| `ATTACK_GROUP` | Ataque coordinado en grupo. | No hay logica de coordinacion entre enemigos ni un `_process_attack_group`; tampoco hay soporte en `GroundLocomotion` para posicionamiento de grupo. |
| `EVADE` | Se reposiciona/esquiva. | No hay `_process_evade`; `GroundLocomotion` no tiene un metodo de esquive (solo `move_toward`, `roam`, `search_last_known`, `flee_from`, `stop`). |
| `DEFEND` | Postura defensiva. | No hay `_process_defend` ni logica de bloqueo/parry proactivo fuera de la ventana de parry de `MeleeAttack`. |
| `CALL_HELP` | Pide refuerzos. | No hay `_process_call_help` ni señal que notifique a otros enemigos para que reaccionen. |

Mientras no se implementen, dejarlos fuera de `allowed_state_flags` en las escenas no cambia nada — nunca se llegan a producir de todas formas.

## Relacionado

- [[IA]]
- [[Hostilidad]]
- [[Enemigos]]
