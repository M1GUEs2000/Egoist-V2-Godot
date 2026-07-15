---
title: Lock On
tags:
  - egoist
  - gameplay
  - sistema
  - combate
status: active
system_status: E2
hito: H1
---

# Lock On

Reworkeado a boton dedicado tipo Dark Souls (ex sistema tipo Hades por direccion cuantizada).
`lock_on` (tecla `C`) ancla un target persistente que ya no se recalcula solo cada frame; se
suelta con el mismo boton o si el target muere/sale de rango. Con lock activo, `camera_left`/
`camera_right` (Q/E) dejan de rotar la camara libre y ciclan entre targets en rango en su lugar.

## Referencia Unity

`LockOnTargeting.cs`

## Godot

`player/lock_on.gd`: `toggle_lock()` ancla el enemigo mas centrado en camara (`_best_camera_target`,
dentro de `lock_half_angle`/`lock_vertical_half_angle`/`lock_max_range`) — ya no el mas cercano a
secas, y ya no cuantizado a 16 direcciones. `cycle_target(direction)` salta al vecino ordenado
izquierda-derecha respecto al forward de camara (`_screen_angle`). `nearest_in_cone(direction)`
queda aparte para el snap de ataque sin lock (usado por `PlayerLocomotion._attack_direction`, sin
tocar el lock persistente). Reticle sobre el AABB combinado de las mallas del target
(`_reticle_position`), visibilidad condicionada a lock activo + armas afuera
(`has_visible_target`/`_is_weapons_out`). Cobertura en `world/smoke_test.gd`.

`visual/camera_rig.gd`: mientras `player.lock_on.is_locked`, `CameraRig` deja el modo libre
(`_update_free`, con rotacion manual por stick) y entra a `_update_locked` — orbita un punto de
mira entre jugador y target (`CameraTuning.lock_focus_weight`, 0.5 = punto medio) parada del lado
opuesto al target respecto del jugador, encuadrando a los dos como en Dark Souls. Distancia/pitch
se reusan del modo libre (sin escalar todavia por separacion jugador-target).

## Rango/angulo vertical (enemigos aereos)

El filtro de adquisicion/ciclado es 3D: usa el rango real (`lock_max_range` contra la distancia
completa, no solo horizontal) y un cono vertical propio (`lock_vertical_half_angle`, grados
sobre/bajo el plano horizontal), ademas del cono horizontal (`lock_half_angle`) respecto al
forward de camara. Sin el filtro vertical, un enemigo aereo directamente arriba del jugador se
lockearia a cualquier altura porque el calculo ignoraria `to.y`. Pensado para `FlyingEnemy`.

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

- Tunear jugando `lock_focus_weight`, y si distancia/pitch necesitan escalar con la separacion
  jugador-target (hoy fijos, mismos valores que el modo libre).
- Ver jugando si el ciclado (Q/E) necesita orden mas inteligente que angulo puro respecto a camara
  (ej. priorizar el mas cercano en empate).
- Validar feel del snap de camara al entrar/salir de lock (hoy solo el damping existente, sin
  blend dedicado).
- Tunear jugando `lock_max_range`/`lock_half_angle`/`lock_vertical_half_angle`/altura del reticle,
  idealmente con [[Flying Enemy]] en escena para validar el cono vertical.
- Revisar si el ring del target de `TargetLandingIndicator` necesita su propio radio/color
  (hoy hereda los defaults de `LandingIndicator`) una vez se vea jugando.
- Ver jugando el color/emision de la dona (`shader_parameter/color`, `emission_energy` en
  `player.tscn`) y si conviene que cambie de color en tramos de vida baja.

## Relacionado

- [[Combate]]
- [[Input Feel]]
