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
> Un golpe que aplica stun mientras el enemigo esta `AIRBORNE` (por `launch` o `push`) cancela el impulso previo, aplica un retroceso corto propio del stun y extiende `_airborne_until` hasta que termine el stun (`maxf(_airborne_until, _stunned_until)`) — queda suspendido en el aire, no cae hasta que el stun expira. `airborne_max_time` sigue siendo solo el tope de seguridad de caida, no compite con esta extension.

## Direccion del golpe

`_last_hit_direction` es la direccion que **aleja al enemigo de su atacante**, no la de la hitbox que lo toco. La calcula `_remember_hit_direction()` desde la posicion de quien golpea; la direccion de la hitbox (`hitbox → hurtbox`) solo entra como fallback cuando no hay atacante posicionable.

> [!important]
> La hoja de un arma orbita alrededor del jugador (ver [[Combate]]): a mitad de un swing esta a un costado del enemigo, o mas alla. Su posicion no sirve como origen del golpe.

Tanto el retroceso como la inclinacion del stun leen esta direccion. *(2026-07-09)*

## Reaccion visual

Mientras `combat_state == STUNNED`, `EnemyBase` activa tres capas de feedback:

- Color amarillo + emision en los meshes bajo el pivote `Visual`.
- `StunLight` (`OmniLight3D`) amarilla, apagada por default y encendida solo durante el stun.
- Inclinacion del pivote `Visual` hacia atras, pivoteando desde los pies: el origen del enemigo esta a ras del piso, asi que `Visual` rota sobre el eje horizontal perpendicular al golpe. Tween de ida y vuelta.

El retroceso desplaza al enemigo alejandolo del atacante, reemplaza cualquier push previo y decae durante el stun.

El mesh del arma (`MeleeAttack/Weapon`) no se pinta con el estado del enemigo: queda fuera del pivote `Visual` a proposito para no mezclar el feedback de stun con posibles telegraphs/colores propios del ataque.

Los valores son exports por escena en `EnemyBase`, siguiendo la excepcion actual de enemigos: `stun_knockback_speed`, `stun_knockback_decay`, `stun_tilt_angle`, `stun_tilt_time`, `stun_emission_energy`, `stun_light_energy` y `stun_light_range`. *(2026-07-09, pendiente de tunear jugando)*

## Duraciones actuales de fuentes del jugador

La duracion la define la fuente via `StunSettings`; el enemigo solo decide si entra por threshold. En tierra el stun es corto — el enemigo se recupera rapido; en el aire dura mas para sostener el juggle.

- Espada normal y dash cargado: `grounded = 0.35`, `airborne = 1.0`.
- Dash del player: `grounded = 0.35`, `airborne = 1.0`.
- Mazo base: `grounded = 0.35`, `airborne = 0.9`.
- Freezes del sweet spot del Mazo: largos a proposito (`Resource_macefreeze = 1.4`, `Resource_maceairfreeze = 1.2`) para mantener enemigos congelados hasta la ultima vuelta.
- Parry del enemigo (`MeleeAttack.parry_stun_duration = 1.2`) no pasa por `StunSettings`; entra por `apply_stun()` directo.

## Relacionado

- [[Estados de Combate Enemigo]]
- [[Combate]]
- [[Armored Enemy]]
