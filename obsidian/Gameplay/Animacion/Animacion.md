---
title: Animacion
tags:
  - egoist
  - gameplay
  - animacion
  - sistema
status: draft
system_status: E0
hito: H3
---

# Animacion

La animacion de combate no bloquea H1. La espada es procedural hasta H3.

## Migracion desde Unity

| Unity V1 | Godot V2 |
|---|---|
| Humanoid Avatar | BoneMap/import Godot. |
| Animator Controller | AnimationTree o AnimationPlayer. |
| Blend Tree Speed | BlendSpace o script puente. |
| Root Motion off | Movimiento por `CharacterBody3D`. |
| Animation Events | Senales/metodos desde AnimationPlayer si hace falta. |

## H1

- Placeholders visuales.
- Prioridad absoluta al feel mecanico.
- No reintentar combo animado sobre placeholder.

## H3

- Personaje final.
- Locomotion Mixamo retarget.
- Ataques de Espada hechos en Blender.

## Relacionado

- [[Combate]]
- [[Blender Pipeline]]

