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

## Presencia del otro mundo

Un objeto del mundo opuesto **ya no desaparece**: queda su cascara (contorno encendido que late) mas el humo. Antes se apagaba entero y solo flotaba el humo, asi que no habia borde donde brillar — por eso `hide_when_inactive` dejo de apagar `visible` y ahora solo apaga la colision. Lo hereda gratis de `WorldMembership`, igual que los enemigos: es la misma lectura para todo el mundo. Detalle completo en [[Afiliacion de Mundo]]. *(2026-07-13)*

Ojo con el par **cascara + colision**: se ve el contorno pero **no es solido** — esa es justo la lectura que se busca (esta ahi, pero no en tu mundo). Si un objeto tiene que seguir siendo solido estando "fuera", eso es `Mode.BOTH`, no la cascara.

## Relacionado

- [[Bloques]]
- [[World Switch]]
- [[Traversal]]

