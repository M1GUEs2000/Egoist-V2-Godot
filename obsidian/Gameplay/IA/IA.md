---
title: IA
tags:
  - egoist
  - gameplay
  - sistema
status: active
system_status: E2
hito: H1
---

# IA

IA cubre percepcion, decision, movimiento enemigo y seleccion de ataque.

## Decision V2

> [!important]
> No se porta Unity Behavior Tree. Godot V2 usa FSM simple en `GroundedEnemy`; LimboAI solo entra si la FSM deja de alcanzar.

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

`test_scene` es un greybox amplio (piso, muros y plataformas de prueba) con grupos por hostilidad: 4 pasivos en circulo, 2 reactivos mas lejos, 2 agresivos todavia mas lejos y 1 ultra agresivo en el mundo muerto (con `FLEE`, `HIDE`, `GUARD` y `ATTACK_GROUP` desactivados via `allowed_state_flags`). *(2026-07-07)*

## Pendiente H1

- Tuning por escena de rangos, cooldowns, vision y homing.
- Validar seleccion melee/ranged por distancia.
- Probar en engine la FSM ampliada por hostilidad (los valores son de primer pase). *(pendiente de probar)*
- Decidir si H1 necesita dodge/reposicionamiento enemigo o se difiere a H2.
- Implementar (o borrar del enum si se descartan) `ATTACK_GROUP`, `EVADE`, `DEFEND` y `CALL_HELP` — hoy son catalogo sin comportamiento real. Ver [[Comportamientos]]. *(2026-07-08)*

## Relacionado

- [[Enemigos]]
- [[Hostilidad]]
- [[Comportamientos]]
- [[H1 - Vertical Slice]]

