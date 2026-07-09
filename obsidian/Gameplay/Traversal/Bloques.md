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
| Traversal block | `TraversalBlock` | Bloque componible: launch/bump, dash, meter, maldicion y/o world switch por exports. |
| Breakable wall | `BreakOnDeath` + `Health` | Desaparece al romperse. |
| Spike wall | `SpikeWall` | Stun PUSH + rebote, restaura doble salto y airdash. Existe en los dos mundos. |

## Traversal block

`world/blocks/traversal_block.tscn` reemplaza los prefabs separados de Tomato, Purple dash, Action curse y World switch. Cada instancia activa caracteristicas con exports; puede tener una o varias a la vez.

| Caracteristica | Efecto | Color |
|---|---|---|
| Launch / bump | Bump horizontal/vertical, restaura doble salto y airdash. | Rojo tomate |
| Dash | Fuerza dash hacia donde mira el jugador. | Verde |
| Meter | Suma barras de meter al jugador. | Celeste |
| Maldicion | Al romperse, la proxima accion cambia de mundo. | Amarillo |
| World switch | Cambia de mundo al golpearlo. | Color del mundo destino |

- El glow se divide en partes iguales segun la cantidad de caracteristicas visibles: mitades, tercios o cuartos. `world switch` no tiene color fijo; visto desde vivo muestra morado porque manda al muerto, visto desde muerto muestra tomate/naranja porque manda al vivo.
- El glow por proximidad vive en `TraversalBlockTuning`: 10% lejos, 60% cerca, con radio tuneable. Los colores viven en `World`, no en la escena.
- `hits_to_break = 0` significa indestructible. Valores mayores usan `Health` + `BreakOnDeath` para romperse tras esa cantidad de golpes.

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
- Probar jugando si cada combinacion de caracteristicas se lee claro con el glow dividido.

## Relacionado

- [[Traversal]]
- [[Playa]]
