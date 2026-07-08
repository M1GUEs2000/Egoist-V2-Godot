---
title: Ataques Enemigos
tags:
  - egoist
  - enemigo
  - combate
status: active
system_status: E2
hito: H1
---

# Ataques Enemigos

Los ataques son componentes. Un enemigo puede no tener ataques, tener melee, ranged o ambos.

| Componente | Funcion |
|---|---|
| `MeleeAttack` | Combo de swings, dano, cooldown, ventana de parry. |
| `RangedAttack` | Windup, proyectil, homing, cadencia y dano. |
| `Projectile` | Viaja, gira hacia objetivo si hay homing, impacta y expira. |

## Hibridos

Si un enemigo tiene melee y ranged, `GroundedEnemy` elige por distancia:

- Melee si el objetivo esta cerca.
- Ranged si esta lejos pero dentro de rango.

## Pendiente

- Tuning por enemigo.
- Feedback de windup/proyectil.
- Decidir si H1 necesita evasiones o lanzamientos de objetos.

## Relacionado

- [[IA]]
- [[Melee Living]]
- [[Ranged Dead]]

