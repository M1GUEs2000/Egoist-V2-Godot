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

## Control aereo (inercia)

En el suelo el input tiene autoridad instantanea: la velocidad horizontal es `dir * move_speed` en el mismo frame. En el aire manda la inercia: la velocidad de input se conserva y el stick solo la empuja hacia donde apunta a `air_acceleration` (m/s², `PlayerTuning`); no se puede invertir el rumbo a velocidad plena en un frame. Saltar o caer conserva la velocidad de carrera del despegue. Referencia de tuning: `move_speed / air_acceleration` = segundos de quieto a velocidad plena en el aire (invertir tarda el doble); un valor muy alto (>= 1000) equivale a control instantaneo. *(2026-07-16, pendiente de probar jugando)*

Cuando otro modulo toma el control del movimiento la inercia del input se resetea via `PlayerLocomotion.set_air_velocity()`: al terminar un dash queda apuntando a la salida del dash a velocidad de carrera; el lock post wall jump/rebote y el stun la borran (el impulso real de esas mecanicas vive en `bump_velocity`, ver [[Momentum y Bump]]).

## Polvo al correr

El jugador levanta polvo en el suelo por encima de `run_dust_min_speed` (`PlayerTuning`, grupo *Dust FX*): emisor `RunDust` (`GPUParticles3D`) a los pies, que `Player._set_run_dust` prende/apaga cada frame segun `is_on_floor()` + velocidad horizontal. Se apaga en stun, launch y dash. Los enemigos de suelo tienen el mismo polvo: `EnemyBase` lo maneja en `tick_base` con el export `run_dust_min_speed` (excepcion de tuning por escena de enemigos). Look tuneable en el `ParticleProcessMaterial` de cada emisor. *(2026-07-10)*

## Tuning

Los valores de feel viven en `PlayerTuning`. Cualquier cambio de aceleracion, velocidad, friccion o control debe hacerse ahi si el knob ya existe; si no existe, primero se crea como tuning.

## Relacionado

- [[Dash y Airdash]]
- [[Launcher y Aire]]
- [[Wall Slide y Wall Jump]]
- [[Traversal]]
