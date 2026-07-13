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

## Prefab

`enemies/ultra_aggressive_enemy.tscn` (hereda `grounded_enemy.tscn`). Trae la config del nivel horneada, asi que la escena que lo instancia no la repite: `hostility = ULTRA_AGGRESSIVE` y `allowed_state_flags = 7647` (todo menos `GUARD`, `ATTACK_GROUP`, `FLEE` y `HIDE` — cinturon y tirantes sobre el veto por codigo).

Lectura greybox: **carmesi oscuro** (`0.42, 0.03, 0.06`) mas dos cuernos. El color es propio, no de mundo — la instancia vieja de `test_scene` usaba un morado que chocaba con `World.COLOR_DEAD`. Stats de primer pase (mas vida, mas rapido, mas dificil de stunear, vision mas amplia, cooldown de ataque mas corto): **pendientes de tunear jugando**. *(2026-07-13)*

## Seleccion de target

`_acquire_target()` recalcula cada tick, pero ya no por distancia cruda: usa un **score de utility de dos terminos** (proximidad + compromiso), el diseno que `ai_spec/leaf_tasks.yaml#target_selection` tenia pendiente.

```
score(candidato) = target_proximity_weight   * (1 - dist/vision_range)
                 + target_commitment_weight  * (candidato == target actual)
```

El termino de **compromiso** ES la histeresis: el target actual arranca con ventaja, asi que solo lo desbanca alguien claramente mas cercano — no un empate. Con `target_commitment_weight = 0.25` (default), robarle el foco pide estar ~25% mas cerca. En `0` vuelve el flip-flop viejo. Es la semilla de la capa utility que `ATTACK_GROUP` reusara; no crece a mas consideraciones (vulnerabilidad, etc.) hasta que haya un segundo caso real. *(2026-07-13, pendiente de probar jugando)*

`test_scene` trae el escenario de prueba: `UltraPreyA` y `UltraPreyB` son dos pasivos **equidistantes** del ultra agresivo — sin histeresis oscila entre ambos, con histeresis se compromete con uno.

## Vetos duros por codigo

`_state_legal_for_hostility` prohibe `FLEE`, `HIDE`, `GUARD` y `ATTACK_GROUP` para este nivel **sin importar** lo que diga `allowed_state_flags` de la escena — es un veto a nivel de codigo, no solo de configuracion. La escena de prueba ademas los desactiva explicitamente por `allowed_state_flags` (cinturon y tirantes).

## Huida

Chance de `FLEE`: **0.0**. Ademas `_should_flee` retorna `false` de entrada si la hostilidad efectiva es `ULTRA_AGGRESSIVE`, antes de mirar la chance — nunca huye, ni por bug ni por tirada.

## Sin target

`_process_no_target` cae a `ROAM` (nunca `GUARD` ni queda quieto en `ACTIVITY`, por el veto de arriba).

## No se traba

Al perseguir en linea recta (sin navmesh) un berserker molia contra los muros del greybox para siempre. `GroundLocomotion` ahora corre el **stuck-check** (`ai_spec/leaf_tasks.yaml#locomotion_contract`): compara lo que recorrio contra lo que esperaba recorrer y, si se queda corto `stuck_time_threshold` segundos, dispara un **rodeo** lateral (`stuck_sidestep_time`) mezclando la direccion deseada con una perpendicular. Aplica a TODOS los enemigos de suelo, no solo al ultra. *(2026-07-13, pendiente de probar jugando)*

## Memoria de percepcion

`ultra_aggressive_memory` = **60s** — la mas larga: no suelta la persecucion facil.

## Actividad idle

Su `ACTIVITY` se limita a dormir o comer presas (segun [[Hostilidad]]); en la practica hoy casi no aplica porque `ROAM` es el fallback real sin target.

## Relacionado

- [[Hostilidad]]
- [[Ecosistema Vivo]]
- [[IA]]
- [[Comportamientos]]
