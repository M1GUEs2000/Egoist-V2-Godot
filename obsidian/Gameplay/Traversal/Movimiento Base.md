---
title: Movimiento Base
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
status: active
system_status: E2
hito: H1
---

# Movimiento Base

Movimiento terrestre principal del jugador.

## Implementado en Godot

- `Player`
- `PlayerLocomotion`

## Responsabilidad

- Leer input direccional y convertirlo en velocidad sobre el plano del mundo.
- Mantener la locomocion base separada de acciones especiales como dash, launcher, stun o wall slide.
- Dejar que `Player` orqueste el estado general, mientras `PlayerLocomotion` resuelve la decision fina de movimiento.

## Tuning

Los valores de feel viven en `PlayerTuning`. Cualquier cambio de aceleracion, velocidad, friccion o control debe hacerse ahi si el knob ya existe; si no existe, primero se crea como tuning.

## Relacionado

- [[Dash y Airdash]]
- [[Launcher y Aire]]
- [[Wall Slide y Wall Jump]]
- [[Traversal]]
