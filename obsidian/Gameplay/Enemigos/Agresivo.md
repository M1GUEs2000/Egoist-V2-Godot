---
title: Agresivo
tags:
  - egoist
  - enemigo
  - ia
  - hostilidad
status: active
system_status: E2
hito: H1
---

# Agresivo

`Hostility.AGGRESSIVE`. Es el default de `EnemyBase` (`@export var hostility := Hostility.AGGRESSIVE`). Busca y ataca al jugador proactivamente en cuanto lo detecta. *(2026-07-08)*

## Sin target

`_process_no_target` cae a `ROAM`: patrulla alrededor de su punto de spawn (`GroundLocomotion.roam`) en vez de quedarse quieto como [[Reactivo]].

## Con target

Persigue si esta fuera de rango de ataque, ataca (melee o ranged segun distancia, ver [[Ataques Enemigos]]) si esta dentro.

## SEARCH

Intenta recuperar al jugador perdido: va a la ultima posicion conocida (`GroundLocomotion.search_last_known`) mientras dure `aggressive_memory`.

## Huida

- `FLEE` al cruzar 30% de vida. Chance: **0.05** — raramente huye.
- `HIDE` solo tras `FLEE` exitoso.

## Memoria de percepcion

`aggressive_memory` = **40s**.

## Target

Siempre el jugador — a diferencia de [[Ultra Agresivo]], no hace infighting con otros enemigos.

## Relacionado

- [[Hostilidad]]
- [[IA]]
- [[Comportamientos]]
