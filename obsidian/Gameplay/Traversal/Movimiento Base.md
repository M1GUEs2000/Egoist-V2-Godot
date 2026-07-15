---
title: Movimiento Base
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
status: active
system_status: E3
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

## Polvo al correr

El jugador levanta polvo en el suelo por encima de `run_dust_min_speed` (`PlayerTuning`, grupo *Dust FX*): emisor `RunDust` (`GPUParticles3D`) a los pies, que `Player._set_run_dust` prende/apaga cada frame segun `is_on_floor()` + velocidad horizontal. Se apaga en stun, launch y dash. Los enemigos de suelo tienen el mismo polvo: `EnemyBase` lo maneja en `tick_base` con el export `run_dust_min_speed` (excepcion de tuning por escena de enemigos). Look tuneable en el `ParticleProcessMaterial` de cada emisor. *(2026-07-10)*

## Tuning

Los valores de feel viven en `PlayerTuning`. Cualquier cambio de aceleracion, velocidad, friccion o control debe hacerse ahi si el knob ya existe; si no existe, primero se crea como tuning.

## Relacionado

- [[Dash y Airdash]]
- [[Launcher y Aire]]
- [[Wall Slide y Wall Jump]]
- [[Traversal]]
