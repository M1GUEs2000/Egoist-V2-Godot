---
title: Camara
tags:
  - egoist
  - gameplay
  - sistema
  - camara
status: active
system_status: E3
hito: H1
---

# Camara

Camara isometrica que sigue al jugador con damping, mas rotacion horizontal controlada por
stick dentro de un rango acotado. No incluye el occlusion fade (vive aparte, ver
[[Occlusion Fade de Camara]] en Traversal) ni el lock-on (ver [[Lock On]] en Combate).

## Implementado en Godot

| Pieza | Modulos | Estado | Nota |
|---|---|---|---|
| Follow isometrico + rotacion por stick | `CameraRig` (`visual/camera_rig.gd`) | E3 | Esta nota |
| Tuning | `CameraTuning` (`data/camera_tuning.gd`, instancia `data/camera_tuning.tres`) | E3 | Esta nota |

## Comportamiento

- **Follow**: la camara persigue al `target` (fallback al grupo `"player"` si el export
  llega null) a una posicion calculada por `pitch`/`center_yaw`/`distance` sobre el target,
  con lerp suavizado por `damping`. Igual que antes, la proyeccion (orto/perspectiva) la
  decide la `Camera3D` hija, `CameraRig` no la pisa.
- **Rotacion horizontal**: el jugador mueve la camara a izquierda/derecha con el stick
  derecho (acciones `camera_left`/`camera_right`, con fallback de teclado Q/E). El yaw real
  usado en el follow es `center_yaw + offset`; `offset` gira libre (360°, sin clamp) a
  `yaw_speed` grados/seg mientras el input supera `input_deadzone`, y se queda donde el
  jugador la dejo — no hay recentrado automatico.
- **Centro por area**: `center_yaw` hoy es un valor fijo del tuning (45°, igual que antes de
  esta tarea). "La posicion central varia por area" queda pendiente — falta un mecanismo
  (marcador de zona que le escriba `center_yaw` a `CameraRig` al entrar el jugador). Ver
  Pendiente mas abajo.
- **Encuadre de wall slide**: mientras el jugador esta pegado a una pared (ver
  [[Wall Slide y Wall Jump]]) el stick deja de rotar la camara y el yaw se calcula desde la
  normal del muro, corrido `wall_slide_yaw_offset` grados hacia el lado que el jugador va
  dejando atras — la pared queda en diagonal y se ve a lo largo del carril en vez de tenerla
  plana de frente. El angulo se abre solo hacia `wall_slide_vertical_yaw_offset` (90° =
  camara sobre la linea de la pared, encuadre 2D) segun cuan vertical sea el movimiento sobre
  el muro: recorrido lateral usa el angulo base, caida seca el vertical, y entre medio mezcla
  continua. El lado sale de la velocidad a lo largo de la pared; sin rumbo todavia (caida seca
  recien enganchada) se elige el que exige menos giro desde donde ya estaba la camara. Por
  debajo de `wall_slide_motion_min_speed` el encuadre se sostiene quieto. En paredes curvas el
  yaw sigue la normal frame a frame. Al soltarse la camara queda donde quedo y el stick vuelve
  a mandar. El lock-on tiene prioridad: lockeado manda el encuadre de combate. *(2026-07-19)*
- **Seguimiento vertical con tope**: la camara sigue al target en Y solo dentro de
  `vertical_follow_limit` metros desde la ultima altura "asentada" (`CameraRig._vertical_anchor`,
  que se re-ancla mientras el target esta dentro del tope). Pasado el tope se congela: el jugador
  sale de cuadro en vertical (sube/baja) en vez de que la camara lo persiga sin fin — pensado para
  tramos donde se sube mucho de golpe (Brazo, launcher). `vertical_follow_limit <= 0` desactiva el
  tope (sigue siempre, comportamiento previo al rework). `CameraVerticalZone` (`visual/camera_vertical_zone.gd`,
  Area3D en capa jugador) apila un tope distinto por area via `CameraRig.push_vertical_limit`/
  `pop_vertical_limit` (grupo `"camera_rig"`); zonas anidadas usan la mas reciente.

## Input

Acciones nuevas en `project.godot`:

| Accion | Gamepad | Teclado (fallback para probar sin control) |
|---|---|---|
| `camera_left` | Stick derecho, eje X negativo | Q |
| `camera_right` | Stick derecho, eje X positivo | E |

## Tuneables (`camera_tuning.tres`)

| Campo | Rol |
|---|---|
| `pitch` | Inclinacion isometrica fija |
| `center_yaw` | Yaw de reposo (centro de la rotacion libre) |
| `distance` | Distancia camara-target en modo libre |
| `damping` | Suavizado del follow de posicion |
| `yaw_speed` | Velocidad de giro mientras se sostiene el stick (grados/seg), libre y sin recentrado |
| `input_deadzone` | Zona muerta del eje del stick |
| `lock_focus_weight` | Con lock activo, cuanto se corre el punto de mira del jugador hacia el target (0=jugador, 1=target) |
| `lock_zoom_min_distance` / `lock_zoom_max_distance` | Con lock activo, rango de distancia de la camara (zoom in/out) segun separacion jugador-target (ver [[Lock On]]) |
| `lock_zoom_near_separation` / `lock_zoom_far_separation` | Separacion (metros) que mapea a `lock_zoom_min_distance`/`lock_zoom_max_distance` |
| `vertical_follow_limit` | Tope en metros del seguimiento vertical antes de congelarse (<=0 = sin tope). Default 10 |
| `wall_slide_frame_enabled` | Interruptor del encuadre de wall slide; false deja el yaw como lo dejo el jugador |
| `wall_slide_yaw_offset` | Grados desde la normal con recorrido lateral. 0 = detras del jugador con la pared de frente; 90 = pared de canto. Default 45 |
| `wall_slide_vertical_yaw_offset` | Grados desde la normal con movimiento vertical seco (90 = vista 2D). Igualarlo a `wall_slide_yaw_offset` desactiva la apertura. Default 90 |
| `wall_slide_motion_min_speed` | Rapidez (m/s) sobre la pared por debajo de la cual el encuadre se sostiene quieto. Default 1 |
| `wall_slide_yaw_damping` | Suavizado con que la camara se acomoda al encuadre de pared. Default 4 |

## Pendiente

- Tunear jugando: `yaw_speed` de la rotacion libre y si la falta de recentrado se siente bien.
- Tunear jugando el encuadre de pared: `wall_slide_yaw_damping` (transicion lateral↔2D) y si el
  90° pleno aplana demasiado la lectura de profundidad. *(pendiente de probar)*
- Centro por area: definir el mecanismo (zona/trigger) que varie `center_yaw` segun donde
  este el jugador.

## Relacionado

- [[Wall Slide y Wall Jump]]
- [[Occlusion Fade de Camara]]
- [[Lock On]]
- [[Traversal]]
- [[Combate]]
