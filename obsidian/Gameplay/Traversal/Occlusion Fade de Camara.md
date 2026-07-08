---
title: Occlusion Fade de Camara
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
  - camara
status: active
system_status: E2
hito: H1
---

# Occlusion Fade de Camara

Visibilidad de traversal cuando un muro queda entre la camara y el jugador. *(2026-07-07, falta tunear)*

## Implementado en Godot

- `CameraOcclusionFade` (`visual/camera_occlusion_fade.gd`)
- Nodo `OcclusionFade` hijo del `CameraRig`

## Comportamiento

- Si un muro del mundo queda entre la camara y el jugador, se vuelve semitransparente.
- El muro sigue proyectando sombra y recupera su material original al dejar de tapar.
- Raycast camara -> jugador contra `LAYER_WORLD` cada frame de fisica, con `hit_from_inside` para funcionar aunque la camara quede dentro del muro.
- Puede desvanecer varios muros en fila (`max_occluders`).
- El material del mesh ocluyente se duplica en version `TRANSPARENCY_ALPHA_DEPTH_PRE_PASS`: conserva color, sombra y orden de dibujado estable.
- Al dejar de tapar espera `restore_delay` antes de volver a solido para evitar parpadeos en bordes.

## Tuneables

- `fade_alpha`
- `target_height_offset`
- `max_occluders`
- `restore_delay`

## Relacionado

- [[Movimiento Base]]
- [[Areas]]
- [[Traversal]]
