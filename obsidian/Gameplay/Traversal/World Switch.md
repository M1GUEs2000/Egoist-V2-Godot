---
title: World Switch
tags:
  - egoist
  - gameplay
  - sistema
status: active
system_status: E2
hito: H1
---

# World Switch

Mecanica central de los dos mundos.

## Decision V2

Switch por triggers ganados, no dodge gratis.

## Modulos

- `WorldManager`
- `WorldMembership`
- `WorldSwitchTrigger` (modulo componible ON_HIT/ON_DEATH; lo usa `world_switch_enemy.tscn`. El switch de los bloques no pasa por el: corre inline en `TraversalBlock.enable_world_switch`)
- `ActionWorldSwitchModifier`

## Triggers

- `TraversalBlock` con world switch OnHit: brilla con el color del mundo destino. Implementacion inline en `traversal_block.gd`, no usa `WorldSwitchTrigger`.
- Enemigo OnDeath: `world_switch_enemy.tscn` voltea el mundo al morir y late con el color del mundo destino (ver [[Afiliacion de Mundo]]). Es el switch que se gana peleando.
- Maldicion amarilla + proxima accion.
- Boton/HUD o especiales futuros.

## Pendiente

El scanner de cambio de mundo, todavia sin diseñar, vive en el board de tareas ([[tareas]]).

## Relacionado

- [[Traversal]]
- [[Decisiones Congeladas]]
