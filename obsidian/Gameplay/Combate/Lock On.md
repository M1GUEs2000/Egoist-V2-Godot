---
title: Lock On
tags:
  - egoist
  - gameplay
  - sistema
  - combate
status: active
system_status: E3
hito: H1
---

# Lock On

Sistema tipo Hades. No reemplaza movimiento: solo ajusta target, orientacion y snap si coincide con la direccion del input.

## Referencia Unity

`LockOnTargeting.cs`

## Godot

`player/lock_on.gd` implementado: adquisicion de target por direccion cuantizada a 16 direcciones (`_find_best_target`/`_quantize`), reticle sobre el AABB combinado de las mallas del target (`_reticle_position`), visibilidad condicionada a armas afuera (`has_visible_target`/`_is_weapons_out`), e integracion con `PlayerLocomotion.tick` (`set_aim_direction`). Cobertura en `world/smoke_test.gd`.

## Rango/angulo vertical (enemigos aereos)

La mira sigue cuantizada en el plano XZ (16 direcciones), pero `_find_best_target` ahora filtra
tambien por elevacion: usa el rango 3D real (`lock_max_range` contra la distancia completa, no
solo horizontal) y un cono vertical propio (`lock_vertical_half_angle`, grados sobre/bajo el
plano horizontal). Antes, un enemigo aereo directamente arriba del jugador se lockeaba a
cualquier altura porque el calculo ignoraba `to.y`. Pensado para `FlyingEnemy`.

## Dona que se vacia con la vida del target

El `Reticle` dejo de usar `StandardMaterial3D`: ahora tiene un `ShaderMaterial`
(`player/reticle_fill.gdshader`) con un uniform `fill` (0-1). El `TorusMesh` mapea su UV.x
dando toda la vuelta al anillo mayor, asi que el shader recorta por `UV.x > fill` — un pie
chart sin reconstruir geometria. Cada `_process`, `LockOn._target_health_ratio` calcula
`target.health.current / target.health.max_health` y lo empuja al shader: la dona se va
vaciando en tiempo real mientras se le pega al target lockeado, y desaparece (fill 0) justo
antes de que muera.

## Indicador de aterrizaje del target

`LockOn` tiene un `TargetLandingIndicator` (mismo script que [[Landing Indicator]], reusado via
`source`/`enabled`) que sigue al `current_target` y solo se enciende junto con el reticle
(mismo gate que `has_visible_target`). El propio `LandingIndicator` filtra si el target no esta
lo bastante alto sobre el suelo (`min_air_height`).

## Ultimos detalles

- Tunear jugando `lock_max_range`/`lock_half_angle`/`lock_vertical_half_angle`/altura del reticle,
  idealmente con [[Flying Enemy]] en escena para validar el cono vertical.
- Revisar si el ring del target de `TargetLandingIndicator` necesita su propio radio/color
  (hoy hereda los defaults de `LandingIndicator`) una vez se vea jugando.
- Ver jugando el color/emision de la dona (`shader_parameter/color`, `emission_energy` en
  `player.tscn`) y si conviene que cambie de color en tramos de vida baja.

## Relacionado

- [[Combate]]
- [[Input Feel]]
