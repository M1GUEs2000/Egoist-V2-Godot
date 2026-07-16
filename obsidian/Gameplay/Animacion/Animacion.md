---
title: Animacion
tags:
  - egoist
  - gameplay
  - animacion
  - sistema
status: active
system_status: E2
hito: H1
---

# Animacion

> [!note] Resueltos (pendientes de re-validar jugando)
> 1. **El maniqui miraba 180° al reves**: mismo fix que el player (ver [[Player]]) — `UAL2_Standard` con 180° en Y dentro de `Visual` en `grounded_enemy.tscn`. El `UAL2_Ragdoll` no se roto (pose aprobada jugando).
> 2. **La espada ya esta anclada a la mano**: opcion A del player replicada en `EnemyAnimationController._setup_hand_attachment` — `BoneAttachment3D` en `hand_r` con una copia visual del `BladeMesh` de cada ataque (`*/Hand/Pivot`), y el arma orbital invisible con su `BladeHitbox` intacto (el daño no cambia). Por codigo, asi lo heredan todos los prefabs (ultra agresivo, hibrido, rift, world switch). Efecto lateral bueno: durante el ragdoll el arma se oculta con el `Visual` en vez de quedar flotando suelta. Grip tuneable: `hand_bone_name`, `hand_attach_offset`, `hand_attach_rotation_degrees`.

`EnemyAnimationController` es una capa visual de `GroundedEnemy`. Traduce estados ya resueltos de IA y combate a clips UAL sin mover el `CharacterBody3D`, abrir hitboxes ni decidir impactos. El piloto es `ReactiveEnemyA` en `lvl_1_v_0_1`.

Ver [[Player]] para las animaciones del player (implementadas en `player/player_animation_controller.gd` sobre el mismo maniqui UAL, con el swing procedural como motor mecanico): locomoción por velocidad, ninja jump y el slide de pared. Los combos de arma tienen nota propia: [[Animacion Espada]] y [[Animacion Mazo]].

UAL2 aporta combate, reacciones y recuperacion; UAL1 completa locomocion, esquive y muerte. Ambos comparten el esqueleto de 67 huesos, asi que el controlador copia en runtime los clips necesarios de UAL1 al `AnimationPlayer` de UAL2.

## Enemigo animado

| Momento | Condicion | Clip | Biblioteca |
|---|---|---|---|
| Guardia, idle, actividad | Sin desplazamiento | `Idle` | UAL1 |
| Roam | `ROAM` con velocidad | `Walk` | UAL1 |
| Persecucion y busqueda | `CHASE` o `SEARCH` con velocidad | `Jog_Fwd` | UAL1 |
| Huida | `FLEE` | `Sprint` | UAL1 |
| Esquive | `EVADE` | `Roll` | UAL1 |
| Defensa | `DEFEND` | `Sword_Block` | UAL2 |
| Ataque melee | Ataque activo | `Sword_Regular_Combo` | UAL2 |
| Primer ataque reactivo | Windup activo | El combo avanza 0.10 s y se congela hasta acabar el windup | UAL2 |
| Dano sin romper poise | `Health.damaged`, pero sigue estable o armado | Sin animacion; solo feedback de impacto | - |
| Stun en suelo | Entra o se extiende `STUNNED` en suelo | `Zombie_Scratch`, de 0.00 a 0.40 s; sostiene la pose final hasta terminar el stun | UAL2 |
| Stun en aire | Entra o se extiende `STUNNED` en el aire | `Hit_Knockback`, de 0.15 a 0.25 s; sostiene la pose final hasta terminar el stun | UAL2 |
| Push | Empujon valido sobre enemigo stuneado | `Hit_Knockback` completo; sostiene la pose final mientras persista el stun | UAL2 |
| Ragdoll | Capsula fisica rodando | `Hit_Knockback` congelado | UAL2 |
| Recuperacion de ragdoll | La capsula devuelve el control al enemigo | `LayToIdle` completo (1.53 s), antes de volver a locomocion | UAL2 |
| Muerte | Senal `Health.died` | `Death01` | UAL1 |

## Reacciones de combate

El dano por si solo no reproduce una animacion. `EnemyBase` emite `stun_started` solo cuando el poise se quiebra o se extiende un stun, y `push_started` cuando comienza un empujon valido. El controlador sostiene la pose final del tramo elegido mientras dure `STUNNED`.

El ragdoll fisico sigue siendo una capsula `RigidBody3D`, pero lleva `UAL2_Ragdoll` como visual. La capsula no se muestra: el maniqui queda congelado en `Hit_Knockback` mientras el rigidbody rueda. Al terminar, `EnemyBase.ragdoll_recovered` dispara `LayToIdle` sobre el maniqui principal antes de devolverlo a locomocion. Un ragdoll esqueletico con `PhysicalBone3D` es una mejora futura, no parte de este piloto.

## Migracion desde Unity

| Unity V1 | Godot V2 |
|---|---|
| Humanoid Avatar | BoneMap/import Godot. |
| Animator Controller | AnimationTree o AnimationPlayer. |
| Blend Tree Speed | BlendSpace o script puente. |
| Root Motion off | Movimiento por `CharacterBody3D`. |
| Animation Events | Senales/metodos desde AnimationPlayer si hace falta. |

## H1

- El piloto enemigo usa UAL para locomocion, combate, stun, push, ragdoll y muerte.
- La espada mantiene hitboxes procedurales; los clips todavia no poseen marcadores de impacto.
- La animacion sigue siendo visual: el feel mecanico conserva autoridad sobre desplazamiento e impactos.

## H3

- Personaje final.
- Locomotion Mixamo retarget.
- Ataques de Espada hechos en Blender.

## Relacionado

- [[Player]]
- [[Animacion Espada]]
- [[Animacion Mazo]]
- [[Combate]]
- [[Enemigos]]
- [[Blender Pipeline]]
