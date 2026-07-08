---
title: Launcher y Aire
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
status: active
system_status: E2
hito: H1
---

# Launcher y Aire

Movimiento y control cuando el jugador entra en estado aereo por salto, launcher, bump o acciones de combate.

## Implementado en Godot

- `PlayerLauncher`
- Integracion desde `Player`
- Interacciones con `PlayerDash`, `PlayerWallSlide` y `LandingIndicator`

## Responsabilidad

- Aplicar impulsos verticales o direccionales del jugador.
- Coordinar restauraciones de habilidades aereas cuando otro sistema lo permite.
- Mantener el control aereo tuneable desde `PlayerTuning`.

## Interacciones importantes

- [[Dash y Airdash]] consume/restaura disponibilidad de airdash segun la accion.
- [[Wall Slide y Wall Jump]] no consume doble salto al rebotar de pared.
- [[Momentum y Bump]] puede lanzar al jugador desde bloques o impactos.
- [[Landing Indicator]] solo visualiza el punto de caida; no decide gameplay.

## Relacionado

- [[Movimiento Base]]
- [[Momentum y Bump]]
- [[Landing Indicator]]
- [[Traversal]]
