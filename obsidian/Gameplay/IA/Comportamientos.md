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

## EVADE — diseño acordado (pendiente de implementar)

Plan cerrado en sesion, **se implementa despues** (H2). Cinco principios de IA de esquive humana, mapeados a los sistemas que ya existen. *(2026-07-13)*

1. **Leer el mundo fisico, no el control.** El sensor NO es un raycast a la hoja: la mano orbita al player y a mitad de swing la hoja esta a un costado del enemigo — su posicion no representa el ataque (misma regla que la direccion del golpe, ver [[Stun]]). El estimulo fisico es `PlayerCombat.attack_telegraphed(origin, direction)` (ya existe, emitido al press, **sin receptor**), filtrado por `Perception` (cono + LOS, ya existe): **solo se esquiva lo que se percibe** — por la espalda o fuera del cono no hay evade. Con `origin`/`direction` se chequea ademas que el enemigo este en rango y en la trayectoria real del golpe.
2. **Retraso humano simulado.** El telegraph escribe `blackboard.combat_incoming_attack_until`; el evade se ejecuta recien pasado `evade_reaction_time` (~0.2 s). Los swings procedurales tardan en llegar, asi que la ventana es real sin tocar el feel del player.
3. **Cooldown estricto.** `evade_cooldown` (3–5 s) bloquea el comportamiento tras un esquive. La **estamina invisible queda diferida** (regla de 2): si jugando el cooldown no alcanza, se agrega.
4. **Dado invisible.** `evade_chance` (~0.3), un roll por telegraph recibido. Es ademas el knob por-enemigo: 0.0 = nunca esquiva (off natural del pasivo), mas alto para enemigos agiles futuros.
5. **Ventanas de estado.** Solo puede rolear si: no esta atacando (`combat_attacking`), no esta stuneado/ragdoll, no esta en FLEE/HIDE y `EVADE` esta en sus `allowed_state_flags`. En recovery de su propio ataque tiene prohibido esquivar — ataca en la ventana correcta y el golpe entra.

Tuberia: receptor del telegraph en `GroundedEnemy` → gates (percepcion, rango/trayectoria, estado, cooldown, dado) → `combat_incoming_attack_until` + evade agendado → pasado el delay, `AIState.EVADE` emite un intent `STRAFE` nuevo en `EnemyAIBlackboard` → `GroundLocomotion.strafe()` perpendicular al atacante durante `evade_duration`.

- Exports por escena (excepcion de enemigos): `evade_chance`, `evade_reaction_time`, `evade_cooldown`, `evade_speed`, `evade_duration`, `evade_range`.
- **Sin i-frames para el enemigo** en el primer pase: su esquive es moverse fuera de la trayectoria, no invulnerabilidad. Si jugando la hoja lo alcanza igual y se siente injusto, el gate `EnemyBase.can_receive_hit` ya quedo facil de extender (mismo patron que los i-frames del dodge del player, ver [[Stun]]).
- Gatillo **solo reactivo** al telegraph por ahora; el reposicionamiento proactivo (en rango + cooldown propio) es otra feature y se evalua despues.
- Al implementarse nace en **E1** y el receptor del telegraph deja servida la condicion `IncomingAttack` que `DEFEND` tambien consume.

## Relacionado

- [[IA]]
- [[Hostilidad]]
- [[Enemigos]]
