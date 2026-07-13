---
title: Bloques
tags:
  - egoist
  - gameplay
  - sistema
status: active
system_status: E3
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
| Launch / bump | Suma momentum horizontal, aplica bump vertical, restaura doble salto y airdash. | Rojo |
| Dash | Fuerza dash hacia donde mira el jugador; el dash **daña al atravesar** enemigos (`dash_deals_damage`, prende el `DashHitbox` del player). | Verde |
| Meter | Suma barras de meter al jugador. | Celeste |
| Maldicion | Al romperse, la proxima accion cambia de mundo. | Amarillo |
| World switch | Cambia de mundo al golpearlo. | Color del mundo destino |

- El cuerpo del bloque se divide en partes iguales segun la cantidad de caracteristicas: mitades, tercios o cuartos. Cada parte prende entera, no solo una franja. `world switch` no tiene color fijo; visto desde vivo muestra morado porque manda al muerto, visto desde muerto muestra naranja porque manda al vivo.
- El bloque **prende por proximidad al jugador** dentro de `proximity_radius`, en dos capas. Los valores viven en `traversal_block_tuning.tres`, no en la nota:
  - **Emision**: la superficie brilla, de `glow_min_energy` lejos a `glow_max_energy` encima. El albedo va apagado a proposito; si llevara el color pleno, el sol lo iluminaria siempre y el encendido no se leeria.
  - **Luz real** (`OmniLight3D`, una por bloque, sin sombras): ilumina el entorno. Color = promedio de las features del bloque; energia de 0 lejos a `light_energy_max` encima, con alcance `light_range`. Poner `light_energy_max = 0` deja solo la emision de superficie.
- Los colores viven en `World`, no en la escena. Ver [[Colores de mundo]]: las features usan colores propios y nunca reusan un color de mundo.
- `hits_to_break = 0` significa indestructible. Valores mayores usan `Health` + `BreakOnDeath` para romperse tras esa cantidad de golpes.
- El launch ahora alimenta el modelo de [[Momentum y Bump]]: encadenar bloques compone exceso hasta `momentum_max_speed`, y el exceso se drena por superficie en vez de morir de golpe al aterrizar.

## Spike wall

Pared de pinchos reusable (`world/blocks/spike_wall.tscn`). **Una sola escena para los dos mundos**: el export raiz `world` decide en cual existe y de que color se pinta. En `test_scene` hay `DeadSpikeWall` 1-3 (moradas) y `LivingSpikeWall` (naranja). *(pendiente de probar)*

- Root `StaticBody3D` con colision fisica contra el jugador y un `WorldMembership` hijo. `SpikeWall._ready` escribe `world` en `membership.affiliation` y llama `membership.refresh()` — el `_ready` del modulo hijo ya corrio con la afiliacion vieja. Si el mundo actual no coincide, apaga visual, colision y trigger.
- El color NO vive en el `.tscn`: `_paint_world_colors()` genera los materiales de rayas y pinchos desde `World.world_color(world)` (ver [[Colores de mundo]]). Los materiales del `.tscn` son solo preview de editor. Cuerpo siempre negro; pinchos traseros al 40% de brillo.
- Un `Area3D` (`Trigger`) detecta player y enemigos. Al tocarla: calcula la normal perpendicular hacia afuera, aplica **daÃ±o + stun PUSH + empuje**; el stun es rojo para distinguir el hazard del stun amarillo de combate. El player conserva doble salto y airdash tras el rebote; el enemigo recibe el mismo impacto y arco de push. El stun respeta el threshold efectivo del receptor (ver [[Combate]]).
- Cooldown `hit_cooldown` para evitar multiples rebotes por frame.
- Exports: `world`, `stun_duration`, `stun_poise_damage`, `push_horizontal_speed`, `push_vertical_speed`, `hit_cooldown`.
- Como el `Trigger` es un nodo hijo separado, la spike wall lo apaga manualmente escuchando `WorldMembership.changed` (ver [[Afiliacion de Mundo]]).

## Pendiente

- Prefabs H1.
- Tuning de impulsos por zona.
- Probar la spike wall jugando.

Lo que todavia no existe (efecto del color negro, bloques dañinos) vive en [[ideas]].

## Relacionado

- [[Traversal]]
- [[Playa]]
