---
title: Landing Indicator
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
status: active
system_status: E3
hito: H1
---

# Landing Indicator

Circulo (anillo) azul que aparece en el suelo, bajo el jugador, cuando esta en el aire por encima de `min_air_height` (0.5 m por defecto). *(2026-07-06)*

## Implementado en Godot

- `LandingIndicator`
- Nodo `Node3D` hijo del Player con `top_level = true`

## Comportamiento

- Se posiciona en coordenadas globales propias, no hereda el transform del jugador.
- Cada frame lanza un raycast hacia abajo contra `LAYER_WORLD`.
- Se coloca en el punto de impacto y se orienta segun la normal del suelo, incluyendo rampas/plataformas.
- Solo se muestra si el jugador esta a mas de `min_air_height` del suelo.
- No detecta enemigos: el raycast solo usa `LAYER_WORLD`, asi que siempre marca suelo o plataforma real.

## Visual

Malla (`TorusMesh`) y material (azul unshaded, emisivo, sin sombra) se generan por codigo: no hay `.tres`.

## Tuneables

- `min_air_height`
- `max_ray_distance`
- `radius`
- `thickness`
- `surface_offset`
- `color`

## Relacionado

- [[Launcher y Aire]]
- [[Movimiento Base]]
- [[Traversal]]
