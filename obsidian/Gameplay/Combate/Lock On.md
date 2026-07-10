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

Sistema tipo Hades. No reemplaza movimiento: solo ajusta target, orientacion y snap si coincide con la direccion del input.

## Referencia Unity

`LockOnTargeting.cs`

## Godot

`player/lock_on.gd` implementado: adquisicion de target por direccion cuantizada a 16 direcciones (`_find_best_target`/`_quantize`), reticle sobre el AABB combinado de las mallas del target (`_reticle_position`), visibilidad condicionada a armas afuera (`has_visible_target`/`_is_weapons_out`), e integracion con `PlayerLocomotion.tick` (`set_aim_direction`). Cobertura en `world/smoke_test.gd`.

## Pendiente

- Tunear rango/angulo/altura del reticle jugando.

## Relacionado

- [[Combate]]
- [[Input Feel]]

