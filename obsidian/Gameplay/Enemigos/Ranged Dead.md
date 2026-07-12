---
title: Ranged Dead
tags:
  - egoist
  - enemigo
status: active
hito: H1
---

# Ranged Dead

Primer enemigo a distancia del mundo Dead.

## Base tecnica

- `GroundedEnemy`
- `RangedAttack`
- `Projectile`
- `WorldMembership` en Dead

## Implementado

- Prefab `enemies/ranged_dead.tscn`: hereda el cuerpo comun, pertenece al mundo Dead y equipa solo `RangedAttack`.
- Placeholder visual: baston y foco violeta para distinguir lectura de rango.
- Instancia en `test_scene` para probar percepcion, distancia de ataque, windup y homing.

## Pendiente

- Tuning jugando de windup, cadencia, velocidad y homing.
- Lectura visual clara del proyectil.

## Relacionado

- [[Enemigos]]
- [[IA]]
