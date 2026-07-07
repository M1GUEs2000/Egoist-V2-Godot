---
title: Traversal
tags:
  - egoist
  - gameplay
  - sistema
status: active
system_status: E2
hito: H1
---

# Traversal

Traversal cubre movimiento, salto, airdash, momentum, cadenas, bloques y world switch como herramienta de exploracion/plataforming.

## Implementado en Godot

| Pieza | Modulos | Estado |
|---|---|---|
| Movimiento base | `Player`, `PlayerLocomotion` | E2 |
| Dash / airdash | `PlayerDash` | E2 |
| Launcher / aire | `PlayerLauncher` | E2 |
| Momentum por bump | `Player.bump()` | E2 |
| Tomato block | `TomatoLaunchBlock` | E2 |
| Purple dash block | `PurpleDashBlock` | E2 |
| Breakable wall | `BreakOnDeath`, escena de pared | E2 |
| Cadenas | `PlayerSwing` | E0 |
| Landing indicator | `LandingIndicator` | E2 |

## Dash

- **Dodge (esquivar):** choca con enemigos y objetos, no los traspasa. *(2026-07-06)*
- Si hay barra, el dodge puede hacer daño, pero no aplica stun; el stun del dash normal es 0 en suelo y aire. *(2026-07-07)*
- **Dash ofensivo** (`PlayerDash.force_dash`, ej. el X cargado de la espada): atraviesa enemigos y choca con objetos.
- La diferencia es el flag `pass_through_enemies` en `_start_dash`: solo el ofensivo quita la capa `enemy` del `collision_mask`.

## World switch

El switch de mundo se gana por:

- `WorldSwitchTrigger` en modo OnHit.
- `WorldSwitchTrigger` en modo OnDeath.
- `ActionWorldSwitchModifier`, que cambia el mundo con la proxima accion.
- Boton/HUD o especiales futuros.

> [!important]
> Dodge no cambia mundo automaticamente. Dodge puede disparar switch solo si una maldicion/bonus lo modifico.

## Landing indicator

Circulo (anillo) azul que aparece en el suelo, bajo el jugador, cuando esta en el aire por encima de `min_air_height` (0.5 m por defecto). *(2026-07-06)*

- `LandingIndicator` es un `Node3D` hijo del Player con `top_level = true` (se posiciona en coordenadas globales propias, no hereda el transform del jugador).
- Cada frame lanza un raycast hacia abajo contra `LAYER_WORLD`, se coloca en el punto de impacto y se orienta segun la normal del suelo (sirve para rampas/plataformas). Solo se muestra si el jugador esta a mas de `min_air_height` del suelo.
- Malla (`TorusMesh`) y material (azul unshaded, emisivo, sin sombra) se generan por codigo: no hay `.tres`. Todo tuneable via `@export` en el nodo: `min_air_height`, `max_ray_distance`, `radius`, `thickness`, `surface_offset`, `color`.
- No detecta enemigos (raycast solo contra `LAYER_WORLD`): el circulo siempre marca suelo/plataforma real.

## Pendiente H1

- Implementar `PlayerSwing` con agarre, subir/bajar, impulso de salida y cooldown de reagarre.
- Construir un greybox de Playa con loop salto + airdash + switch + bloques.
- Probar que no haya softlocks si el jugador consume mal un switch.

## Relacionado

- [[Combate]]
- [[Areas]]
- [[H1 - Vertical Slice]]
