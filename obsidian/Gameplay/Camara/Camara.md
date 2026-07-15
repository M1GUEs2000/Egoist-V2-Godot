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
| Follow isometrico + rotacion por stick | `CameraRig` (`visual/camera_rig.gd`) | E1 | Esta nota |
| Tuning | `CameraTuning` (`data/camera_tuning.gd`, instancia `data/camera_tuning.tres`) | E1 | Esta nota |

## Comportamiento

- **Follow**: la camara persigue al `target` (fallback al grupo `"player"` si el export
  llega null) a una posicion calculada por `pitch`/`center_yaw`/`distance` sobre el target,
  con lerp suavizado por `damping`. Igual que antes, la proyeccion (orto/perspectiva) la
  decide la `Camera3D` hija, `CameraRig` no la pisa.
- **Rotacion horizontal**: el jugador mueve la camara a izquierda/derecha con el stick
  derecho (acciones `camera_left`/`camera_right`, con fallback de teclado Q/E). El yaw real
  usado en el follow es `center_yaw + offset`, donde `offset` esta clamped a
  `±max_yaw_offset` (30° por defecto) — nunca permite colocarse completamente detras del
  personaje, solo desviacion lateral.
- **Recentrado**: si el stick esta en su zona muerta (`input_deadzone`) durante
  `recenter_delay` segundos (1.2s por defecto), el `offset` empieza a volver solo a 0 con
  velocidad `recenter_speed`. Se corta apenas el jugador vuelve a mover el stick.
- **Centro por area**: `center_yaw` hoy es un valor fijo del tuning (45°, igual que antes de
  esta tarea). "La posicion central varia por area" queda pendiente — falta un mecanismo
  (marcador de zona que le escriba `center_yaw` a `CameraRig` al entrar el jugador). Ver
  Pendiente mas abajo.

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
| `center_yaw` | Yaw de reposo (centro de la rotacion) |
| `distance` | Distancia camara-target |
| `damping` | Suavizado del follow de posicion |
| `max_yaw_offset` | Rango de desviacion lateral permitido (± grados) |
| `yaw_speed` | Velocidad de giro mientras se sostiene el stick (grados/seg) |
| `recenter_delay` | Segundos sin input antes de empezar a recentrar |
| `recenter_speed` | Suavizado del recentrado |
| `input_deadzone` | Zona muerta del eje del stick |

## Pendiente

- Verificacion headless (`--import` + `--quit-after 2`) — no disponible en este entorno,
  falta correrla.
- Tunear jugando: rango de ±30°, velocidad de giro, delay y velocidad de recentrado.
- Centro por area: definir el mecanismo (zona/trigger) que varie `center_yaw` segun donde
  este el jugador.

## Relacionado

- [[Occlusion Fade de Camara]]
- [[Lock On]]
- [[Traversal]]
- [[Combate]]
