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
- `WorldSwitchTrigger` (modulo componible ON_HIT/ON_DEATH; no se usa en ninguna escena hoy, solo en `world/smoke_test.gd`. El switch real de `test_scene` corre inline en `TraversalBlock.enable_world_switch`)
- `ActionWorldSwitchModifier`

## Triggers

- `TraversalBlock` con world switch OnHit: brilla con el color del mundo destino. Implementacion inline en `traversal_block.gd`, no usa `WorldSwitchTrigger`.
- Enemigo/objeto OnDeath: planeado via `WorldSwitchTrigger.ON_DEATH`, sin instancia real todavia.
- Maldicion amarilla + proxima accion.
- Boton/HUD o especiales futuros.

## Relacionado

- [[Traversal]]
- [[Decisiones Congeladas]]
