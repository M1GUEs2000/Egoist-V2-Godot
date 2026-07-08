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
| Tomato | `TomatoLaunchBlock` | Bump horizontal/vertical y restaurar habilidades. |
| Purple dash | `PurpleDashBlock` | Fuerza dash en direccion del jugador. |
| Breakable wall | `BreakOnDeath` + `Health` | Desaparece al romperse. |
| Spike wall | `SpikeWall` | Pared de pinchos del mundo vivo: stun PUSH + rebote, restaura doble salto y airdash. |

## Spike wall

Pared de pinchos reusable del mundo vivo (`world/blocks/spike_wall.tscn`, instanciada en `test_scene` como `LivingSpikeWall`). *(2026-07-07, pendiente de probar)*

- Root `StaticBody3D` con colision fisica contra el jugador, visual negro/morado con pinchos rojos, y `WorldMembership` con `affiliation = LIVING`: si el mundo actual no es `LIVING`, apaga visual, colision y trigger.
- Un `Area3D` (`Trigger`) detecta el contacto. Al tocarla: calcula la normal perpendicular hacia afuera, aplica `PlayerStun.Mode.PUSH` via `try_apply_stun` del player (respeta su threshold, ver [[Combate]]), empuja horizontal + vertical, y restaura doble salto y airdash.
- Cooldown `hit_cooldown` para evitar multiples rebotes por frame.
- Exports: `stun_duration`, `stun_power`, `push_horizontal_speed`, `push_vertical_speed`, `hit_cooldown`.
- Como el `Trigger` es un nodo hijo separado, la spike wall lo apaga manualmente escuchando `WorldMembership.changed` (ver [[Afiliacion de Mundo]]).

## Pendiente

- Prefabs H1.
- Tuning de impulsos por zona.
- Decidir si purple dash se consume.

## Relacionado

- [[Traversal]]
- [[Playa]]

