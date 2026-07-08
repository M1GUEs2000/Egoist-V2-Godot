---
title: Modelo de Enemigo
tags:
  - egoist
  - enemigo
  - sistema
status: active
system_status: E2
hito: H1
---

# Modelo de Enemigo

En Godot V2 no hay una subclase por cada comportamiento de mundo o ataque. Hay un modelo componible.

## Estructura

| Pieza | Responsabilidad |
|---|---|
| `EnemyBase` | Salud, estados, armadura, mundo, verbos aereos, muerte. |
| `GroundedEnemy` | Glue de enemigo de suelo: FSM, target, locomocion y ataques. |
| `Health` | Vida compartida. |
| `Hurtbox` | Entrada de dano y senal `hit`. |
| `WorldMembership` | Decide si el enemigo esta activo en el mundo actual. |
| `Perception` | Sensor de vision/proximidad/memoria. |
| `GroundLocomotion` | Movimiento de suelo, chase, roam y search. |
| `MeleeAttack` / `RangedAttack` | Ataques componibles. |

## Contratos por duck typing

| Verbo | Uso |
|---|---|
| `launch(height, hang_time)` | Lo sube al aire. |
| `slam(down_speed)` | Lo azota al piso. |
| `push(direction, PushSettings)` | Lo empuja en arco; el arco lo define quien ataca (inyectable). |
| `slam_bounce(down_speed, target_world_y, hang_time)` | Spike + rebote hasta altura objetivo. |
| `try_parry(player, hit_direction)` | Parry si el ataque enemigo esta en ventana. |
| `receive_stun` / `try_apply_stun` | Entrada normal de stun: solo entra si la potencia supera `_effective_stun_threshold()` (`stun_threshold` o `armor_stun_threshold` si esta armado). Mismo criterio que el player. *(2026-07-07)* |

## Regla

> [!important]
> Crear variedad configurando composicion y datos antes de crear clases nuevas. Nueva clase solo si aparece un comportamiento que no encaja en `GroundedEnemy`.

## Relacionado

- [[Enemigos]]
- [[IA]]
- [[Ataques Enemigos]]

