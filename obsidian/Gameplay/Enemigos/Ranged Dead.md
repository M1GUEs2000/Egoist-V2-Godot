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
- `AttackLoadout` (solo la familia Ranged)
- `Projectile`
- `WorldMembership` en Dead

## Implementado

- Prefab `enemies/ranged_dead.tscn`: hereda el cuerpo comun, pertenece al mundo Dead y equipa solo `RangedAttack`.
- Placeholder visual: baston y foco violeta para distinguir lectura de rango.
- Instancia en `test_scene` para probar percepcion, distancia de ataque, windup y homing.

> [!info] Ya no tiene script propio *(2026-07-13)*
> Hasta ahora, "solo usa ranged" lo lograba una **subclase** (`ranged_dead.gd`) que vaciaba `_attacks` en su `_ready` y re-registraba el ranged a mano. Esa clase se borro: hoy lo hace su [[Ataques Enemigos|AttackLoadout]], el mismo modulo que vuelve hibrido a cualquier otro enemigo. `RangedDead` ya **no es un `class_name`** — la escena corre sobre `GroundedEnemy` pelado.

## Pendiente

- Tuning jugando de windup, cadencia, velocidad y homing.
- Lectura visual clara del proyectil.

## Relacionado

- [[Enemigos]]
- [[IA]]
