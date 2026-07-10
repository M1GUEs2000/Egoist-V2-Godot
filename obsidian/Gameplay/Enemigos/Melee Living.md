---
title: Melee Living
tags:
  - egoist
  - enemigo
status: planned
hito: H1
---

# Melee Living

Primer enemigo melee de produccion para H1.

## Base tecnica

- `GroundedEnemy`
- `Perception`
- `GroundLocomotion`
- `MeleeAttack`
- `WorldMembership` en Living (pendiente: hoy no hay prefab propio, todas las instancias de `test_scene` reutilizan `grounded_enemy.tscn`, cuya afiliacion por defecto es Dead — ver [[Afiliacion de Mundo]])

## Pendiente

- Prefab/escena de produccion con `WorldMembership.affiliation = LIVING`.
- Silueta y placeholder claro.
- Tuning de rango, cooldown, vision y stun.

## Relacionado

- [[Enemigos]]
- [[IA]]

