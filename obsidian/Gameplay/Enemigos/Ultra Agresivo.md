---
title: Ultra Agresivo
tags:
  - egoist
  - enemigo
  - ia
  - hostilidad
status: active
system_status: E2
hito: H1
---

# Ultra Agresivo

`Hostility.ULTRA_AGGRESSIVE`. Berserker: ataca cualquier objetivo valido, jugador u otro enemigo, y puede cambiar a uno mejor si aparece. Es la base de [[Ecosistema Vivo]] — el unico nivel que hace infighting real. *(2026-07-08)*

## Seleccion de target

`_acquire_target()` recalcula cada tick: compara distancia al jugador contra todos los nodos del grupo `"enemy"` que esten `is_active_in_current_world()` y se queda con el mas cercano por `distance_squared_to`. No hay histeresis — puede saltar de target frame a frame si dos candidatos estan a distancia similar (marcado como pendiente en [[Ecosistema Vivo]]: "Histeresis de target si hay flip-flop"). *(2026-07-08)*

## Vetos duros por codigo

`_state_legal_for_hostility` prohibe `FLEE`, `HIDE`, `GUARD` y `ATTACK_GROUP` para este nivel **sin importar** lo que diga `allowed_state_flags` de la escena — es un veto a nivel de codigo, no solo de configuracion. La escena de prueba ademas los desactiva explicitamente por `allowed_state_flags` (cinturon y tirantes).

## Huida

Chance de `FLEE`: **0.0**. Ademas `_should_flee` retorna `false` de entrada si la hostilidad efectiva es `ULTRA_AGGRESSIVE`, antes de mirar la chance — nunca huye, ni por bug ni por tirada.

## Sin target

`_process_no_target` cae a `ROAM` (nunca `GUARD` ni queda quieto en `ACTIVITY`, por el veto de arriba).

## Memoria de percepcion

`ultra_aggressive_memory` = **60s** — la mas larga: no suelta la persecucion facil.

## Actividad idle

Su `ACTIVITY` se limita a dormir o comer presas (segun [[Hostilidad]]); en la practica hoy casi no aplica porque `ROAM` es el fallback real sin target.

## Relacionado

- [[Hostilidad]]
- [[Ecosistema Vivo]]
- [[IA]]
- [[Comportamientos]]
