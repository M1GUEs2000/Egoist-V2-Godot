---
title: Flying Enemy
tags:
  - egoist
  - enemigo
  - gameplay
status: active
system_status: E1
hito: H2
---

# Flying Enemy

Prototipo aereo de greybox. Patrulla de izquierda a derecha alrededor de su punto de aparicion, oscila en altura y usa alas procedurales.

## Base tecnica

- `FlyingEnemy` extiende `EnemyBase`: compone `Health`, `Hurtbox` y `WorldMembership` en Dead.
- No usa `GroundedEnemy`, `GroundLocomotion` ni la FSM/LimboAI: no es una variante del enemigo de suelo.
- Escena: `enemies/flying_enemy.tscn`; hay una instancia en `test_scene`.

## Movimiento

- `patrol_half_width` define los extremos sobre el eje X global.
- `patrol_speed` mueve entre extremos e invierte la direccion.
- `hover_height` y `hover_frequency` definen la oscilacion vertical.
- `wing_flap_frequency` y `wing_flap_angle` animan ambas alas en sentidos opuestos.
- Si un `push` lo derriba, al terminar la fisica terrestre vuelve volando de forma continua a su punto de aparicion y solo entonces retoma la patrulla. `return_speed` y `return_arrive_distance` controlan ese regreso.

## Stun aereo

El stun de suelo no se usa tal cual: inclina el `Visual` completo y detiene el loop propio, por lo que las alas quedaban laterales y congeladas. `FlyingEnemy` conserva el feedback de stun del `EnemyBase`, pero:

- queda suspendido en su posicion, sin retroceso terrestre;
- restaura el `Visual` vertical;
- sigue aleteando mientras dura el stun;
- reanuda la patrulla al terminar.

## Pendiente

- Definir ataque y cadencia.
- Decidir si reacciona a percepcion/hostilidad o sigue como patrulla simple.
- Tunear ampliamente jugando: amplitud, velocidad, altura, aleteo, feel del stun, `return_speed` y `return_arrive_distance`.

## Relacionado

- [[Enemigos]]
- [[IA]]
- [[Roster Enemigos]]
