---
title: Momentum y Bump
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
status: active
system_status: E2
hito: H1
---

# Momentum y Bump

Impulsos externos aplicados al jugador para traversal, bloques o golpes.

## Implementado en Godot

- `Player.bump()`
- Consumidores como [[Bloques]]

## Responsabilidad

- Aplicar empujes horizontales y verticales sin mezclar la logica dentro del movimiento base.
- Permitir que bloques de traversal restauren habilidades aereas cuando el diseno lo pide.
- Servir de puente entre objetos golpeables, stun/push y movilidad.

## Casos actuales

- `TraversalBlock` con feature Launch: bump horizontal/vertical y restauracion de habilidades.
- `SpikeWall`: stun `PUSH` + rebote, restaura doble salto y airdash.

## Relacionado

- [[Bloques]]
- [[Launcher y Aire]]
- [[Combate]]
- [[Traversal]]
