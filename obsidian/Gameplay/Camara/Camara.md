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

## Pendiente

- Verificacion headless (`--import` + `--quit-after 2`) — no corrida todavia. *(pendiente de probar)*
- Tunear jugando: `yaw_speed` de la rotacion libre y si la falta de recentrado se siente bien.
- Centro por area: definir el mecanismo (zona/trigger) que varie `center_yaw` segun donde
  este el jugador.

## Relacionado

- [[Occlusion Fade de Camara]]
- [[Lock On]]
- [[Traversal]]
- [[Combate]]
