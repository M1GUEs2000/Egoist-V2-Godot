---
title: Pasivo
tags:
  - egoist
  - enemigo
  - ia
  - hostilidad
status: active
system_status: E2
hito: H1
---

# Pasivo

`Hostility.PASSIVE`. No inicia combate por ver al jugador — de hecho no puede: `Perception._compute()` corta en seco si la hostilidad efectiva es `PASSIVE` (`return false` antes de chequear rango/angulo/raycast), asi que un pasivo no provocado nunca detecta nada, ni siquiera si el jugador se para al lado. *(2026-07-08)*

## Como se activa

- Solo reacciona si lo golpean: `EnemyBase._on_passive_attacked` fija `_forced_target` al atacante y sube `hostility` a `AGGRESSIVE`.
- Mientras esta provocado, se comporta exactamente como un [[Agresivo]] (misma rama de FSM), con el jugador o quien lo haya golpeado como target forzado.
- La provocacion dura `passive_memory` (10s por defecto, ver [[IA]]). Al expirar, si `passive_remembers_attackers` esta en `false` (default), `_update_passive_memory` lo devuelve a `PASSIVE` y suelta `_forced_target`. Si el toggle esta en `true`, se queda `AGGRESSIVE` para siempre (nunca vuelve a calmarse).

## Contagio a otros pasivos

`_provoke_nearby()` recorre el grupo `"enemy"` dentro de `alert_radius` y pone `AGGRESSIVE` a los pasivos cercanos.

> [!warning] Nuance sin validar jugando
> El contagio a los vecinos **no fija su propio `_passive_provoked_until`** — solo el atacado directo tiene ese timer. Eso significa que en el siguiente `_update_passive_memory` de cada vecino (mismo frame o el proximo), como `World.now() >= _passive_provoked_until` (que quedo en su default `-999`), el vecino vuelve a `PASSIVE` de inmediato, salvo que ese vecino en particular tenga `passive_remembers_attackers = true`. Hoy el "todos se alertan" es casi cosmetico a menos que ese toggle este activo por enemigo. Puede ser un bug o una decision de diseno no documentada — falta probarlo en el editor. *(2026-07-08)*

## SEARCH

Investigacion/curiosidad, no urgencia de combate — tonalmente distinto al `SEARCH` de [[Reactivo]] o [[Agresivo]], aunque la implementacion de `_process_search` es la misma FSM para todos.

## Huida

- `FLEE` se evalua una sola vez al cruzar 30% de vida (`low_health_threshold`). Chance: **0.50** — el nivel mas propenso a huir.
- `HIDE` solo puede activarse despues de un `FLEE` exitoso (`_hide_unlocked`).

## Memoria de percepcion

`passive_memory` = **10s** (la mas corta de los 4 niveles): una vez provocado, si pierde de vista al target se calma rapido.

## Relacionado

- [[Hostilidad]]
- [[IA]]
- [[Comportamientos]]
- [[Mascaras y Cordura]]
