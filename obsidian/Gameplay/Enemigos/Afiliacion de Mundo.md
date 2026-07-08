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

## Trigger global

`WorldSwitchTrigger` es ortogonal: un enemigo puede cambiar el mundo global al morir sin que eso cambie su propio modo de afiliacion.

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

