---
title: Player (Animacion)
tags:
  - egoist
  - gameplay
  - animacion
  - sistema
status: active
system_status: E0
hito: H1
---

# Player (Animacion)

Plan de animaciones reales para el player, hoy 100% procedural (quaternions/tilts en `Hand`/`Pivot`, sin `AnimationPlayer`). El player actual con ese swing procedural queda resguardado en `player_legacy/` (scripts y `player_legacy.tscn`, con todos los `class_name` renombrados para no chocar con `player/`) por si hace falta volver a él.

Este nodo cubre locomoción, salto y slide. Los combos de arma tienen nota propia: [[Animacion Espada]] y [[Animacion Mazo]].

Los clips salen del mismo maniqui UAL de 67 huesos que ya usa [[Animacion|el piloto de enemigos]]: **UAL2** (`assets/animations/Universal Animation Library 2[Standard]/.../Unreal-Godot/UAL2_Standard.glb`) aporta ninja jump y slide; **UAL1** (`.../Universal Animation Library[Standard]/.../UAL1_Standard.glb`) aporta la locomoción base (walk/sprint). Nombres de clip verificados leyendo el JSON del `.glb` (no inventados) — usar estos nombres tal cual en el codigo.

## Clips usados (nombre técnico + duración real)

| Clip | Biblioteca | Duración |
|---|---|---|
| `Idle_No_Loop` | UAL2 | 2.50 s |
| `Walk_Loop` | UAL1 | — |
| `Sprint_Loop` | UAL1 | — |
| `NinjaJump_Start` | UAL2 | 0.967 s |
| `NinjaJump_Idle_Loop` | UAL2 | 2.00 s |
| `NinjaJump_Land` | UAL2 | 1.267 s |
| `Slide_Start` | UAL2 | 0.833 s |
| `Slide_Loop` | UAL2 | 2.00 s |
| `Slide_Exit` | UAL2 | 0.50 s |

## Locomoción (blend por velocidad)

Igual patrón que `EnemyAnimationController._update_locomotion_animation`: un solo `AnimationTree`/blend continuo por velocidad horizontal, no un salto discreto entre clips.

| Velocidad horizontal | Clip |
|---|---|
| ~0 | `Idle_No_Loop` |
| Caminando | `Walk_Loop` |
| Corriendo (por encima del umbral de sprint) | `Sprint_Loop` |

## Salto (Ninja Jump)

Blend con la locomoción, no un one-shot aislado: sale del suelo, sostiene en el aire y aterriza.

| Momento | Clip |
|---|---|
| Despegue | `NinjaJump_Start` |
| Sostenido en el aire | `NinjaJump_Idle_Loop` |
| Aterrizaje | `NinjaJump_Land` |

## Slide (Wall Slide)

[[Wall Slide y Wall Jump]]: el maniqui tiene que rotar según la dirección de la pared, no quedar fijo al forward del player.

| Momento | Clip |
|---|---|
| Entrada al slide | `Slide_Start` |
| Sostenido deslizando | `Slide_Loop` |
| Salida del slide | `Slide_Exit` |

## Relacionado

- [[Animacion]]
- [[Animacion Espada]]
- [[Animacion Mazo]]
- [[Combate]]
- [[Traversal]]
