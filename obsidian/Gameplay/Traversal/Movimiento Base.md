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

## Salto dirigido y control aereo

El salto normal y el doble salto son una parabola calculada, no una fuerza vertical manual. `jump_min_apex_height` / `jump_max_apex_height` definen la altura de toque a hold y `jump_duration` la velocidad de todo el recorrido. El impulso horizontal se deriva de esa misma fuerza vertical mediante `jump_forward_impulse_ratio`: mas hold significa mas altura y mas avance, sin una distancia horizontal fija. El avance solo existe si habia input direccional al despegar: sin input el salto es recto hacia arriba.

`jump_control_release_percent` decide cuando se libera el control sobre el tiempo total del arco: 0 = al despegar, 100 = al aterrizar. Desde ese punto el input puede frenar, girar o llevar al personaje a los lados con `jump_post_release_air_control_scale`, una fraccion de la aceleracion aerea normal. Sin input, conserva el avance base hacia el aterrizaje. La correccion del jugador puede cambiar ese aterrizaje previsto. *(2026-07-21, pendiente de probar jugando)*

El avance horizontal puede frenarse suavemente al pasar por la cuspide con `jump_apex_slowdown_strength` y `jump_apex_slowdown_window_percent`. La curva cosenoidal no tiene esquinas al entrar o salir del freno; el sistema compensa la velocidad antes y despues de esa ventana, por lo que sin input conserva tanto la distancia como la duracion configuradas.

## Control aereo (inercia)

En el suelo el input tiene autoridad instantanea: la velocidad horizontal es `dir * move_speed` en el mismo frame. En el aire manda la inercia: la velocidad de input se conserva y el stick solo la empuja hacia donde apunta a `air_acceleration` (m/s², `PlayerTuning`); no se puede invertir el rumbo a velocidad plena en un frame. Saltar o caer conserva la velocidad de carrera del despegue. Referencia de tuning: `move_speed / air_acceleration` = segundos de quieto a velocidad plena en el aire (invertir tarda el doble); un valor muy alto (>= 1000) equivale a control instantaneo. *(2026-07-16, pendiente de probar jugando)*

Cuando otro modulo toma el control del movimiento la inercia del input se resetea via `PlayerLocomotion.set_air_velocity()`: al terminar un dash queda apuntando a la salida del dash a velocidad de carrera; el lock post wall jump/rebote y el stun la borran (el impulso real de esas mecanicas vive en `bump_velocity`, ver [[Momentum y Bump]]).

## Polvo al correr

El jugador levanta polvo en el suelo por encima de `run_dust_min_speed` (`PlayerTuning`, grupo *Dust FX*): emisor `RunDust` (`GPUParticles3D`) a los pies, que `Player._set_run_dust` prende/apaga cada frame segun `is_on_floor()` + velocidad horizontal. Se apaga en stun, launch y dash. Los enemigos de suelo tienen el mismo polvo: `EnemyBase` lo maneja en `tick_base` con el export `run_dust_min_speed` (excepcion de tuning por escena de enemigos). Look tuneable en el `ParticleProcessMaterial` de cada emisor. *(2026-07-10)*

## Tuning

Los valores de feel viven en `PlayerTuning`. Para el salto: altura de cuspide, distancia minima/maxima de aterrizaje, duracion total, tiempo de hold, porcentaje de liberacion y escala de control posterior. Cualquier cambio de aceleracion, velocidad, friccion o control debe hacerse ahi si el knob ya existe; si no existe, primero se crea como tuning.

## Relacionado

- [[Dash y Airdash]]
- [[Launcher y Aire]]
- [[Wall Slide y Wall Jump]]
- [[Traversal]]
