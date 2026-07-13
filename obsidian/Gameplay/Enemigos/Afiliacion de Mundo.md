---
title: Afiliacion de Mundo
tags:
  - egoist
  - enemigo
  - world-switch
status: active
system_status: E2
hito: H1
---

# Afiliacion de Mundo

La afiliacion de mundo define donde existe y actua un enemigo.

## Modos

| Modo | Funcion |
|---|---|
| `FIXED` | Activo solo en Living o Dead. |
| `BOTH` | Activo en ambos mundos. No se le escapa cambiando. |
| `TIMED` | Alterna su afiliacion cada `shift_interval`. |
| `FOLLOWS` | Sigue el mundo actual del jugador, con posible delay de persecucion. |

## Eco del otro mundo

Todo dueño de `WorldMembership` (enemigo, plataforma, bloque o estructura) deja una lectura abstracta cuando esta inactivo por pertenecer al otro mundo: humo sobre su contorno y una luz tenue con el color de su afiliacion. La emision crece con el movimiento, pero no revela su mesh ni una silueta exacta. El eco vive como hermano de la estructura en la escena para seguir visible aunque `hide_when_inactive` oculte el objeto real. `BOTH` y `FOLLOWS` no lo muestran porque nunca estan fuera del mundo actual.

## Trigger global

`WorldSwitchTrigger` es ortogonal a la afiliacion: dice que le hace este enemigo al mundo de TODOS, no donde vive el. Como nodo hijo, con `when = ON_HIT` (voltea el mundo en cada golpe) o `ON_DEATH` (al morir).

## Enemigo de world switch

`world_switch_enemy.tscn` (hereda `grounded_enemy.tscn`, con un `WorldSwitchTrigger` hijo en `ON_DEATH`): matarlo voltea el mundo de todos. Es la fuente de world switch que se gana peleando, ver [[World Switch]]. Aguanta mas que el enemigo comun (`Health.max_health = 25`) y cuesta mas de stunear (`stun_threshold = 2.0`): el cambio de mundo se paga.

Se lee distinto del resto sin necesidad de HUD:

- **Color del mundo opuesto**: no usa el rojo de `normal_color`, sino `World.world_color(World.opposite_world(...))` — anuncia el mundo al que te va a mandar, y se repinta solo cuando el mundo cambia. Es el mismo criterio de color de los bloques de world switch (ver [[Bloques]]); el gesto, en cambio, es propio.
- **Latido**: su emision pulsa sola mientras esta vivo y entero.
- **Fogonazo al morir**: el cuerpo se enciende de golpe con el color que venia anunciando y se apaga. Es el acuse de recibo del cambio de mundo.
- El stun manda por encima: mientras dura, gana el amarillo de [[Stun]].

Tuneables (exports de `EnemyBase`, excepcion de enemigos): `world_switch_pulse_min_energy` (0.3), `world_switch_pulse_max_energy` (2.0), `world_switch_pulse_speed` (1.2 pulsos/s), `world_switch_death_flash_energy` (6.0), `world_switch_death_flash_time` (0.3 s). *(2026-07-12, pendiente de probar jugando)*

## Activarse / desactivarse al cambiar de mundo

Cuando `WorldMembership` emite `changed`, `EnemyBase._on_membership_changed` sincroniza tres cosas segun el enemigo este activo o no: `collision_layer` (ENEMY o 0), la visual, y `hurtbox.monitorable` (si otros hitbox pueden detectar su hurtbox).

> [!bug] Trampa Godot 4.7: monitorable durante el flush
> El switch de mundo suele dispararse desde un golpe/pickup, o sea desde un callback de `area_entered`, que corre **durante el flush de queries de fisica**. Ahi el motor BLOQUEA `area.monitorable = ...` (error `Function blocked during in/out signal`). Si el seteo se bloquea, la hurtbox del enemigo queda desincronizada: el cuerpo pasa a activo (te ve y te ataca) pero **ningun hitbox lo detecta, es intocable**. Se arregla con `hurtbox.set_deferred("monitorable", _is_active)`, que aplica el valor al terminar el flush. *(2026-07-06)*

## Triggers hijos se apagan a mano

`WorldMembership` sincroniza las colisiones directas del nodo padre, pero **no** apaga `Area3D` triggers que vivan como nodos hijos separados: cada dueno debe escuchar `WorldMembership.changed` y apagar su trigger manualmente. Ejemplo: `SpikeWall` apaga su `Trigger` ademas de visual y colision (ver [[Bloques]]). *(2026-07-07)*

## Equivalencias Unity viejas

| Unity V1 | Godot V2 |
|---|---|
| `DualWorldEnemy` | `WorldMembership.BOTH` |
| `TimedWorldShiftEnemy` | `WorldMembership.TIMED` |
| `FatWorldFollowerEnemy` | `WorldMembership.FOLLOWS` |
| `WorldSwitchOnDeathEnemy` | `WorldSwitchTrigger.ON_DEATH` |

## Relacionado

- [[World Switch]]
- [[Enemigos]]
