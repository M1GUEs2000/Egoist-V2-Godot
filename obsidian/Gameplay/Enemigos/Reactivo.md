---
title: Reactivo
tags:
  - egoist
  - enemigo
  - ia
  - hostilidad
status: active
system_status: E2
hito: H1
---

# Reactivo

`Hostility.REACTIVE`. Defiende territorio: a diferencia de [[Pasivo]], `Perception` SI lo deja detectar normalmente (rango + angulo + raycast, sin el corte especial de `PASSIVE`). No persigue por iniciativa propia mas alla de eso — no hay un radio de "zona" separado codificado; el gatillo de combate es la deteccion normal de `Perception`. *(2026-07-08)*

## Sin target

`_process_no_target` cae a `GUARD` (queda quieto en su posicion) en vez de patrullar — es la diferencia de comportamiento clave frente a [[Agresivo]], que patrulla (`ROAM`) buscando.

## Con target

Una vez detecta, la rama de FSM es identica a `AGGRESSIVE`: persigue si esta fuera de rango de ataque, ataca si esta dentro.

## SEARCH

Orientado a "investigar quien invadio" mas que a "recuperar target perdido" (tonalmente; la implementacion de `_process_search` es la misma FSM para todos los niveles).

## Huida

- `FLEE` al cruzar 30% de vida. Chance: **0.25**.
- `HIDE` solo tras `FLEE` exitoso.

## Memoria de percepcion

`reactive_memory` = **20s**.

## Hueco de diseno

> [!warning]
> La nota conceptual dice "defiende territorio: ataca si el jugador entra demasiado cerca o invade su zona", pero en codigo no existe un radio de zona propio para `REACTIVE` — usa el mismo cono de vision/proximidad de `Perception` que cualquier otro nivel. Si se quiere una zona de guardia real (volver a la posicion de spawn, alcance limitado de persecucion), falta implementarla. *(2026-07-08)*

## Relacionado

- [[Hostilidad]]
- [[IA]]
- [[Comportamientos]]
