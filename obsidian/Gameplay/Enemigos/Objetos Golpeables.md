---
title: Objetos Golpeables
tags:
  - egoist
  - enemigo
  - traversal
status: active
system_status: E2
hito: H1
---

# Objetos Golpeables

No son enemigos, pero comparten el eje de ser golpeables.

## Regla

Objetos golpeables usan `Health` y `Hurtbox`, pero no `EnemyBase`, no IA y no lock-on.

| Objeto | Funcion |
|---|---|
| World switch pickup | Cambia mundo al golpearlo. |
| Action curse pickup | La proxima accion cambia mundo. |
| Tomato block | Bump y restauracion de habilidades. |
| Purple dash block | Dash forzado. |
| Breakable wall | Se rompe con golpes. |

## Ejes separados

- Vida: cuanto aguanta antes de romperse.
- Reaccion: que pasa al recibir hit.
- Mundo: `WorldMembership` si debe existir solo en un mundo.

## Relacionado

- [[Bloques]]
- [[World Switch]]
- [[Traversal]]

