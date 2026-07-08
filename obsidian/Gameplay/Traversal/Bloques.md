---
title: Bloques
tags:
  - egoist
  - gameplay
  - sistema
status: active
system_status: E2
hito: H1
---

# Bloques

Objetos golpeables de traversal.

| Bloque | Script | Funcion |
|---|---|---|
| Tomato | `TomatoLaunchBlock` | Bump horizontal/vertical y restaurar habilidades. Mundo vivo. |
| Purple dash | `PurpleDashBlock` | Fuerza dash en direccion del jugador. Mundo muerto. |
| Breakable wall | `BreakOnDeath` + `Health` | Desaparece al romperse. |
| Spike wall | `SpikeWall` | Stun PUSH + rebote, restaura doble salto y airdash. Existe en los dos mundos. |

## Spike wall

Pared de pinchos reusable (`world/blocks/spike_wall.tscn`). **Una sola escena para los dos mundos**: el export raiz `world` decide en cual existe y de que color se pinta. En `test_scene` hay `DeadSpikeWall` 1-3 (moradas) y `LivingSpikeWall` (tomate). *(2026-07-08, pendiente de probar)*

- Root `StaticBody3D` con colision fisica contra el jugador y un `WorldMembership` hijo. `SpikeWall._ready` escribe `world` en `membership.affiliation` y llama `membership.refresh()` — el `_ready` del modulo hijo ya corrio con la afiliacion vieja. Si el mundo actual no coincide, apaga visual, colision y trigger.
- El color NO vive en el `.tscn`: `_paint_world_colors()` genera los materiales de rayas y pinchos desde `World.world_color(world)` (ver [[Colores de mundo]]). Los materiales del `.tscn` son solo preview de editor. Cuerpo siempre negro; pinchos traseros al 40% de brillo.
- Un `Area3D` (`Trigger`) detecta el contacto. Al tocarla: calcula la normal perpendicular hacia afuera, aplica `PlayerStun.Mode.PUSH` via `try_apply_stun` del player (respeta su threshold, ver [[Combate]]), empuja horizontal + vertical, y restaura doble salto y airdash.
- Cooldown `hit_cooldown` para evitar multiples rebotes por frame.
- Exports: `world`, `stun_duration`, `stun_power`, `push_horizontal_speed`, `push_vertical_speed`, `hit_cooldown`.
- Como el `Trigger` es un nodo hijo separado, la spike wall lo apaga manualmente escuchando `WorldMembership.changed` (ver [[Afiliacion de Mundo]]).

> [!warning] Historico
> Hasta el 2026-07-08 las tres instancias se llamaban `LivingSpikeWall*` pero tenian `affiliation = 1` (DEAD) y rayas moradas: el nombre y esta nota mentian, el `.tscn` mandaba. Se resolvio a favor del `.tscn` (son del mundo muerto) y se agrego la instancia viva que faltaba.

## Pendiente

- Prefabs H1.
- Tuning de impulsos por zona.
- Decidir si purple dash se consume.

## Relacionado

- [[Traversal]]
- [[Playa]]

