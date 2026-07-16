---
title: Player (Animacion)
tags:
  - egoist
  - gameplay
  - animacion
  - sistema
status: active
system_status: E1
hito: H1
---

# Player (Animacion)

Animaciones reales del player sobre el maniqui UAL. Implementado en `player/player_animation_controller.gd` (`AnimationController`, hijo de `Player` en `player.tscn`, con el maniqui `UAL2_Standard` bajo `Visual/`): capa SOLO visual, mismo patron que `EnemyAnimationController` — traduce estados ya resueltos a clips, sin mover el `CharacterBody3D` ni abrir hitboxes. El swing procedural (quaternions en `Hand`/`Pivot`) sigue siendo el motor mecanico de hitboxes; el resguardo previo vive en `player_legacy/` (scripts y `player_legacy.tscn`, con todos los `class_name` renombrados para no chocar con `player/`).

Capas por prioridad en cada physics frame: golpe de arma (via `WeaponBase.visual_clip_started`) → wall slide → aire (ninja jump) → locomocion por velocidad. La capsula `Mesh` quedo `visible = false` (como en el enemigo): el feedback de stun/poise-chip/glow que pintaba la capsula quedo sin hogar visual — pendiente de re-ubicar (juice).

Probe automatizado: `res://world/probe_animaciones_player.tscn` (mismo patron que `probe_animaciones_ia`: estados forzados a mano + tick manual del controlador + prints `PROBE animaciones_player=...`, termina en `=OK`). Cubre locomocion, salto/doble salto/aterrizaje, wall slide (rotacion del maniqui incluida), los tramos de Espada y Mazo con su speed_scale, el corte por `end_visual_clip`, el stun (suelo/aire, pose congelada, vuelta a idle) y las interrupciones por stun/dash (con regresion de que el aire recupera su loop tras un override).

Este nodo cubre locomoción, salto y slide. Los combos de arma tienen nota propia: [[Animacion Espada]] y [[Animacion Mazo]].

Los clips salen del mismo maniqui UAL de 67 huesos que ya usa [[Animacion|el piloto de enemigos]]: **UAL2** (`assets/animations/Universal Animation Library 2[Standard]/.../Unreal-Godot/UAL2_Standard.glb`) aporta ninja jump y slide; **UAL1** (`.../Universal Animation Library[Standard]/.../UAL1_Standard.glb`) aporta la locomoción base (idle/walk/sprint).

> [!warning] Nombres verificados contra el IMPORT de Godot, no contra el JSON del .glb
> El plan original usaba sufijos `_Loop` (`Walk_Loop`, `NinjaJump_Idle_Loop`…) que NO existen en las animaciones importadas — el probe explotó ahí en la primera corrida. Los nombres de abajo salen de `AnimationPlayer.get_animation_list()` sobre los `.glb` reales (Godot 4.7.1 headless, 2026-07-16). `Idle_No_Loop` tampoco existía: se usa `Idle` de UAL1, el mismo del enemigo.

## Clips usados (nombre técnico + duración real)

| Clip | Biblioteca | Duración |
|---|---|---|
| `Idle` | UAL1 | 2.50 s |
| `Walk` | UAL1 | 1.333 s |
| `Sprint` | UAL1 | 0.667 s |
| `NinjaJump_Start` | UAL2 | 0.967 s |
| `NinjaJump_Idle` | UAL2 | 2.00 s |
| `NinjaJump_Land` | UAL2 | 1.267 s |
| `Slide_Start` | UAL2 | 0.833 s |
| `Slide` | UAL2 | 2.00 s |
| `Slide_Exit` | UAL2 | 0.50 s |

## Locomoción (blend por velocidad)

Igual patrón que `EnemyAnimationController._update_locomotion_animation`: clips por umbral de velocidad horizontal con crossfade (`blend_time` del controlador), no un corte seco. Se eligió `AnimationPlayer` + crossfade (patrón ya probado del enemigo) en vez de un `AnimationTree` con BlendSpace; si el blend por crossfade no alcanza jugando, migrar a BlendSpace1D es la mejora siguiente. Umbrales (`moving_speed_threshold`, `sprint_speed_threshold`) como exports del controlador, igual que en el enemigo.

| Velocidad horizontal | Clip |
|---|---|
| ~0 | `Idle` |
| Caminando | `Walk` |
| Corriendo (por encima del umbral de sprint) | `Sprint` |

## Salto (Ninja Jump)

Blend con la locomoción, no un one-shot aislado: sale del suelo, sostiene en el aire y aterriza.

| Momento | Clip |
|---|---|
| Despegue | `NinjaJump_Start` |
| Sostenido en el aire | `NinjaJump_Idle` |
| Aterrizaje | `NinjaJump_Land` |

## Stun (agregado post-plan)

No estaba en el plan original; espeja al [[Animacion|piloto de enemigos]]: al entrar (o extenderse) el stun se reproduce un tramo del clip y la pose final queda congelada hasta que el stun termina. Capa de prioridad máxima del controlador (gana al golpe de arma, al slide y al aire). Tramos como exports (`ground_stun_start/end`, `air_stun_start/end`), pendientes de tunear jugando.

| Momento | Clip | Tramo |
|---|---|---|
| Stun en suelo | `Zombie_Scratch` (UAL2) | 0.00–0.40 s |
| Stun en aire | `Hit_Knockback` (UAL2) | 0.15–0.25 s |

## Slide (Wall Slide)

[[Wall Slide y Wall Jump]]: el maniqui tiene que rotar según la dirección de la pared, no quedar fijo al forward del player.

| Momento | Clip |
|---|---|
| Entrada al slide | `Slide_Start` |
| Sostenido deslizando | `Slide` |
| Salida del slide | `Slide_Exit` |

## Relacionado

- [[Animacion]]
- [[Animacion Espada]]
- [[Animacion Mazo]]
- [[Combate]]
- [[Traversal]]
