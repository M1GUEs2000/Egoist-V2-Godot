---
title: Comportamientos
tags:
  - egoist
  - gameplay
  - ia
status: active
system_status: E3
hito: H1
---

# Comportamientos

Catalogo general de los 15 estados del enum `AIState` (`GroundedEnemy`), que hacen **en general**. Como cambia la intencion de cada uno segun el nivel de hostilidad vive en [[Hostilidad]] y en las notas por nivel ([[Pasivo]], [[Reactivo]], [[Agresivo]], [[Ultra Agresivo]]). *(2026-07-08)*

> [!warning] No todos estan implementados
> De los 15 estados del enum, 12 tienen comportamiento real. `ATTACK_GROUP`, `DEFEND` y `CALL_HELP` existen como valor de enum y como flag en `allowed_state_flags`, pero **ninguna hoja del arbol los produce ni los maneja** — hoy son catalogo sin comportamiento, no un stub jugable. Ver tabla abajo.

> [!info] Capa de IA
> Cada estado vive en una de tres capas (game-ai): **decide** (que hacer), **steer** (como moverse — `GroundLocomotion`), **coord** (multi-agente). El spec con la hoja LimboAI de cada estado esta en el codigo, en `enemies/ai_spec/ai_states.yaml`.

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
| `EVADE` | steer | Reposiciona (orbita al target esperando su ventana de ataque) y esquiva reactivamente el telegraph del player. | `_process_engage` · `_on_player_attack_telegraphed` · `GroundLocomotion.strafe` |

## Estados sin implementar (solo catalogo)

Ya no son huecos "a ciegas": cada uno tiene su capa y diseno destino en `enemies/ai_spec/`. *(2026-07-08)*

| Estado | Capa | Intencion | Diseno destino / que falta | Hito |
|---|---|---|---|---|
| `CALL_HELP` | coord | Pide refuerzos. | Coordinacion **ligera**: generaliza `_provoke_nearby` via señal a grupo (`blackboard.coordination`). Godot-native, sin director. | H2 |
| `DEFEND` | decide | Postura defensiva. | Rama de alta prioridad. La condicion `IncomingAttack` ya esta servida: el receptor del telegraph escribe `combat.incoming_attack_until`. Falta la hoja que la consume. | H2 |
| `ATTACK_GROUP` | coord | Ataque coordinado en grupo. | Coordinacion **fuerte**: NO es estado por-enemigo, pide un **director de equipo** (autoload con tokens de ataque). Reusa el target scoring por utility. | H3+ |

Mientras no se implementen, dejarlos fuera de `allowed_state_flags` en las escenas no cambia nada — nunca se llegan a producir de todas formas.

## EVADE

El enemigo no se planta enfrente entre golpe y golpe: en rango de ataque **se espacia** y comete el golpe solo en su ventana, y ademas **esquiva reactivamente** el telegraph del player. Estado **E3**: aprobado jugando; faltan juice y edge cases.

**Parte proactiva (engage)** — `GroundedEnemy._process_engage`. El **melee tiene espaciado**: entra, pega, **sale retrocediendo de cara** al target (`BACKPEDAL`, nunca de espaldas) hasta `attack_range * melee_ring_fraction` — un ring **fuera** de su alcance —, ahi **orbita** esperando que la cadencia (`attack_pause_min..max`, sorteada al cerrar cada combo) o el cooldown del arma le habiliten el golpe, y entonces **vuelve a entrar** (`MOVE_TO` con parada en `attack_range * strike_distance_fraction`). Ya no se queda encima del jugador entre combo y combo.

El **ranged no retrocede**: orbita dentro de su alcance a `ranged_ring_fraction`. Por eso el ring se mide contra el rango del ataque que va a usar, no contra el mayor — un hibrido con ranged largo no se espacia como si su melee alcanzara 10 m.

El radio que activa el engage (`_engage_radius`) incluye el ring, no solo el alcance: si no, el melee saldria del engage apenas retrocede y volveria a perseguir, entrando y saliendo. Sin `EVADE` en `allowed_state_flags` no hay reposicionamiento: espera quieto mirando al target. La cadencia se trackea en el tick (`_update_attack_cadence`), fuera de la logica de decision.

**El combo compromete la direccion.** Mientras ataca, el enemigo ya no encara libre cada frame: gira como mucho `combo_turn_speed` (°/s) **entre golpes** y `combo_swing_turn_speed` **durante el swing** (`face_target_committed` → `GroundLocomotion.face_target_clamped`). El golpe sale hacia donde apunto al lanzarlo, asi que esquivarlo de costado sirve.

**Parte reactiva (esquive)** — los cinco principios de esquive humana:

1. **Leer el mundo fisico, no el control.** El sensor NO es un raycast a la hoja: la mano orbita al player y a mitad de swing la hoja esta a un costado del enemigo — su posicion no representa el ataque (misma regla que la direccion del golpe, ver [[Stun]]). El estimulo fisico es `PlayerCombat.attack_telegraphed(origin, direction)`, emitido al press, filtrado por `Perception` (cono + LOS): **solo se esquiva lo que se percibe** — por la espalda o fuera del cono no hay evade. Con `origin`/`direction` se chequea ademas que el enemigo este en rango y en la trayectoria real del golpe.
2. **Retraso humano simulado.** El telegraph escribe `blackboard.combat_incoming_attack_until`; el evade se ejecuta recien pasado `evade_reaction_time` (~0.2 s). Los swings procedurales tardan en llegar, asi que la ventana es real sin tocar el feel del player.
3. **Cooldown estricto.** `evade_cooldown` (3–5 s) bloquea el comportamiento tras un esquive. La **estamina invisible queda diferida** (regla de 2): si jugando el cooldown no alcanza, se agrega.
4. **Dado invisible.** `evade_chance` (~0.3), un roll por telegraph recibido. Es ademas el knob por-enemigo: 0.0 = nunca esquiva (off natural del pasivo), mas alto para enemigos agiles futuros.
5. **Ventanas de estado.** Solo puede rolear si: no esta atacando (`combat_attacking`), no esta stuneado/ragdoll, no esta en FLEE/HIDE y `EVADE` esta en sus `allowed_state_flags`. En recovery de su propio ataque tiene prohibido esquivar — ataca en la ventana correcta y el golpe entra.

Tuberia: `GroundedEnemy._on_player_attack_telegraphed` (conectado en `_ready` a `PlayerCombat.attack_telegraphed`) → gates en orden barato→caro (flags, cooldown, estado, percepcion, rango/trayectoria, dado) → escribe `combat_incoming_attack_until` y agenda la ventana → pasado `evade_reaction_time`, la hoja `limbo_evade_window` (prioridad alta, despues de FLEE) produce `AIState.EVADE` con intent `STRAFE` sin ring → `GroundLocomotion.strafe()` perpendicular al origen del telegraph durante `evade_duration`.

- El esquive **siempre retrocede**: nunca es un paso de puro costado (contra un arco ancho no sacaba de la trayectoria). Al agendarlo, `GroundLocomotion.begin_evade` sortea una de tres formas — retroceso recto, diagonal atras-izquierda o diagonal atras-derecha — y la sostiene toda la ventana. `evade_diagonal_bias` decide cuanto abre la diagonal; en 0 es siempre retroceso recto.
- **Cuanto se despega es un knob directo**: `evade_distance` (metros). La velocidad no se tunea, sale de `evade_distance / evade_duration` y viaja en el intent. Con la misma distancia, una duracion mas corta lo vuelve mas explosivo.
- Exports por escena (excepcion de enemigos): `evade_chance` (0.3), `evade_reaction_time` (0.2), `evade_cooldown` (4.0), `evade_distance` (3.0), `evade_duration` (0.45), `evade_range` (3.5) en `GroundedEnemy`; `evade_diagonal_bias` (0.7) en `GroundLocomotion`.
- El cono de trayectoria es una const (`EVADE_TRAJECTORY_DOT` 0.25, generoso porque la mano orbital barre arcos anchos), no un export. Los extremos del dado son deterministas: 0 nunca esquiva, 1 siempre.
- **Sin i-frames para el enemigo**: su esquive es moverse fuera de la trayectoria, no invulnerabilidad. Si jugando la hoja lo alcanza igual y se siente injusto, el gate `EnemyBase.can_receive_hit` es el lugar (mismo patron que los i-frames del dodge del player, ver [[Stun]]).
- El receptor del telegraph deja servida la condicion `IncomingAttack` que `DEFEND` tambien consume.
- Hojas del arbol: `limbo_engage_target` y `limbo_evade_window` en `EnemyLimboTreeBuilder`.
- Contratos en `combat_smoke_test`: dado 0 nunca agenda, dado 1 agenda, cooldown bloquea, fuera de trayectoria/percepcion/rango no agenda, en FLEE no rolea, y la ventana activa produce `EVADE` + intent `STRAFE`.

## Relacionado

- [[IA]]
- [[Hostilidad]]
- [[Enemigos]]
