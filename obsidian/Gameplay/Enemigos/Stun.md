---
title: Stun
tags:
  - egoist
  - enemigo
  - combate
status: active
system_status: E2
hito: H1
---

# Stun

Sistema de stun y armadura de `EnemyBase`. Vive separado de [[Estados de Combate Enemigo]] porque tiene su propio criterio de entrada, independiente del resto de `combat_state`. *(2026-07-08)*

## Umbral efectivo

El criterio es universal (igual que el player, ver [[Combate]]): la fuente manda `StunSettings` con un `power`; el receptor solo queda `STUNNED` si `power >= _effective_stun_threshold()`.

- `_effective_stun_threshold()` devuelve `armor_stun_threshold` si el enemigo esta `ARMORED`, o `stun_threshold` si no.
- La armadura es **resistencia** al stun, no inmunidad: un golpe suficientemente fuerte igual puede stunear a un enemigo armado.

## Entradas

| Metodo | Que hace |
|---|---|
| `receive_stun(stun: StunSettings)` | Entrada normal: llama `try_apply_stun` con `duration_for(is_airborne())` y `power` del `StunSettings`. |
| `try_apply_stun(duration, power)` | Compara `power` contra el threshold efectivo; si no alcanza, no hace nada. |
| `apply_stun(duration)` | Aplicacion directa que **ignora** la resistencia — solo para casos que ya decidieron que el stun aplica (ej. `apply_parry_stun`). |

`MeleeAttack` llama `receive_stun` en su target cuando el `StunSettings` del ataque no es null (`_deal_damage`); si el target no tiene `receive_stun` pero es otro `EnemyBase`, usa `take_hit_from_enemy` que aplica stun via `_apply_stun_from_settings`.

## Armadura

- `armored` (export) define si el enemigo inicia armado (`combat_state = ARMORED` en `_ready` si `armored` esta activo).
- `armor_hits_to_break` define cuantos golpes aguanta antes de romperse (`_damage_armor` cuenta hits, no dano bruto).
- Al romperse: `combat_state` vuelve a `NORMAL` y se resetea `_armor_hits_taken`.
- `apply_armor(duration)` reactiva la armadura por tiempo limitado (usado por ataques que la re-arman) y la revierte a `NORMAL` sola si nadie la cambio antes.

## Interaccion con el aire (juggle)

> [!important]
> Un golpe que aplica stun mientras el enemigo esta `AIRBORNE` (por `launch` o `push`) cancela su `velocity` y extiende `_airborne_until` hasta que termine el stun (`maxf(_airborne_until, _stunned_until)`) — queda suspendido en el aire, no cae hasta que el stun expira. `airborne_max_time` sigue siendo solo el tope de seguridad de caida, no compite con esta extension.

## Relacionado

- [[Estados de Combate Enemigo]]
- [[Combate]]
- [[Armored Enemy]]
