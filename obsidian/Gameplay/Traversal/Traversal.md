---
title: Traversal
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
status: active
system_status: E2
hito: H1
---

# Traversal

Traversal cubre movimiento, salto, airdash, momentum, cadenas, bloques y world switch como herramientas de exploracion y plataforming.

Esta nota es el indice del sistema. El detalle vive en una subnota por modulo o tipo de movimiento para que el nodo no se vuelva un cajon mezclado.

## Implementado en Godot

| Pieza | Modulos | Estado | Nota |
|---|---|---|---|
| Movimiento base | `Player`, `PlayerLocomotion` | E2 | [[Movimiento Base]] |
| Dash / airdash | `PlayerDash` | E2 | [[Dash y Airdash]] |
| Launcher / aire | `PlayerLauncher` | E2 | [[Launcher y Aire]] |
| Momentum por bump | `Player.bump()` | E1 | [[Momentum y Bump]] |
| Wall slide / wall jump | `PlayerWallSlide` | E1 | [[Wall Slide y Wall Jump]] |
| Floor slide por plataforma | `PlayerFloorSlide`, `FloorSlideSurface`, `FloorSlideTuning` | E0 | [[Floor Slide]] |
| Rebote en enemigos | `PlayerEnemyBounce` | E1 | [[Rebote en Enemigos]] |
| Reset aereo por kill / carga | `PlayerAirKillReset` | E1 | [[Reset Aereo por Kill]] |
| World switch | `WorldManager`, `WorldMembership`, `WorldSwitchTrigger`, `ActionWorldSwitchModifier` | E2 | [[World Switch]] |
| Grieta | `WorldRift`, `WorldRiftTuning`, `RiftSpawner` | E0 | [[Grieta]] |
| Bloques traversal | `TraversalBlock`, `BreakOnDeath`, `SpikeWall` | E2 | [[Bloques]] |
| Cadenas | `PlayerSwing` | E0 | [[Cadenas]] |
| Occlusion fade de camara | `CameraOcclusionFade` | E2 | [[Occlusion Fade de Camara]] |
| Landing indicator | `LandingIndicator` | E3 | [[Landing Indicator]] |
| Colores de mundo | `World.world_color()` | E2 | [[Colores de mundo]] |

## Reglas madre del nodo

> [!important]
> Dodge no cambia mundo automaticamente. Dodge puede disparar switch solo si una maldicion/bonus lo modifico.

> [!important]
> Ninguna pieza hardcodea color en su `.tscn`: todo se tiñe desde `World`. La convencion de
> mundo y de feature vive en [[Colores de mundo]], que es su unica fuente de verdad.

- El feel de traversal se valida jugando; headless solo confirma que no este roto.
- Los valores de movimiento viven en tuning (`PlayerTuning` o exports del nodo cuando corresponda), no como constantes nuevas de paso.
- H1 prioriza lectura mecanica y greybox: nada de arte final antes de H3.

## Pendiente H1

- Implementar [[Cadenas]] con agarre, subir/bajar, impulso de salida y cooldown de reagarre.
- Construir un greybox de [[Playa]] con loop salto + airdash + switch + bloques.
- Probar que no haya softlocks si el jugador consume mal un switch.

Lo que todavia no existe vive en el kanban ([[tareas]]) o, si no esta comprometido, en [[ideas]].

## Relacionado

- [[Combate]]
- [[Areas]]
- [[hitos]]
