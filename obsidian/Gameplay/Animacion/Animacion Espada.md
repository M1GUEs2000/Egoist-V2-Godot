---
title: Animacion Espada
tags:
  - egoist
  - gameplay
  - animacion
  - combate
status: active
system_status: E1
hito: H1
---

# Animacion Espada

Clips UAL para el combate de [[Espada]] sobre el player. Implementado: `sword.gd` emite `visual_clip_started` (señal de `WeaponBase.play_visual_clip`) al arrancar cada golpe y `PlayerAnimationController` reproduce el tramo en el maniqui, escalado a la duracion mecanica del golpe (`swing_time` / `charged_dash_duration`). Los swings por quaternion en `Hand` siguen siendo el motor de hitboxes: la animacion es solo visual. Ver [[Player]] para locomocion/salto/slide.

Clips en `assets/animations/Universal Animation Library 2[Standard]/.../Unreal-Godot/UAL2_Standard.glb`, nombres verificados contra el JSON del `.glb` (no inventados).

## Clips usados

| Clip | Duración |
|---|---|
| `Sword_Regular_A` | 0.433 s |
| `Sword_Regular_B` | 0.533 s |
| `Sword_Regular_C` | 2.00 s |
| `Sword_Dash` | 1.567 s |
| `Sword_Heavy_Combo` | 4.333 s (se usa por tramos) |

> [!warning]
> `Sword_Regular_A_Rec` / `Sword_Regular_B_Rec` (clips de recuperación) existen en UAL2 pero no están pedidos en este plan — quedan disponibles si el combo terrestre necesita un respiro entre golpes mas adelante.

## Combo terrestre (tap)

Motor: `run_combo_chain` en `sword.gd`, combo de 4 pasos con rama de espera en los pasos 3-4 (ver [[Espada]] para la descripción de diseño: swing, swing, estocada/vuelta).

| Input | Secuencia de clips |
|---|---|
| Tap tap tap tap (sin espera) | `Sword_Regular_A`, `Sword_Regular_B`, `Sword_Regular_A`, `Sword_Regular_B` |
| Tap tap (espera) tap tap | `Sword_Regular_A`, `Sword_Regular_B`, `Sword_Regular_C`, `Sword_Regular_C` |

## Combo aereo (tap)

Espejo del terrestre: diagonales con A/B, vueltas de la rama espera con C y el hachazo vertical con el mismo tramo aereo de `Sword_Heavy_Combo` que la Y cargada.

| Input | Secuencia de clips |
|---|---|
| X X X (sin espera) | `Sword_Regular_A`, `Sword_Regular_B`, `Sword_Heavy_Combo` 2.40-2.70 s |
| X (espera) X X | `Sword_Regular_A`, `Sword_Regular_C`, `Sword_Regular_C` |
| X X (espera) X (plunge) | Mismos clips que X X X: el plunge reusa el hachazo (`Sword_Heavy_Combo` 2.40-2.70 s), sin clip propio. |

## Cargados

| Move | Clip / tramo |
|---|---|
| X cargado (piso y aire — dash ofensivo) | `Sword_Dash` completo |
| Y cargado en piso (launcher) | `Sword_Heavy_Combo` de 0.90 a 1.30 s |
| Y cargado en aire | `Sword_Heavy_Combo` de 2.40 a 2.70 s |

## Relacionado

- [[Player]]
- [[Animacion]]
- [[Espada]]
- [[Combate]]
- [[Animacion Mazo]]
