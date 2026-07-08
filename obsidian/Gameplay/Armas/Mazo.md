---
title: Mazo
aliases:
  - Morningstar
tags:
  - egoist
  - gameplay
  - arma
  - combate
status: active
system_status: E0
hito: H2
---

# Mazo / Morningstar

Arma de mas dano. Controla masas. Tiene bastante knockback. Tumba a los enemigos. Velocidad lenta.

## Terrestre

| Input | Descripcion |
|---|---|
| X X X | Swing horizontal, swing horizontal, smash vertical con AOE. |
| X X espera X X | Swing horizontal, swing horizontal, tres smash verticales. Todos con AOE. |
| X cargado (3 niveles) | Das vueltas y golpeas. 1 carga = 1 vuelta, 2 cargas = 2 vueltas, 3 cargas = 3 vueltas. |
| X cargado sweet spot | Los enemigos que pega quedan congelados hasta la ultima vuelta. |
| Y cargado | Launcher omnidireccional. Area grande. |
| Y cargado sweet spot | Hace dos golpes para subirlos al aire. |

## Aereo

| Input | Descripcion |
|---|---|
| X | Ataque con knockback hacia adelante. |
| X cargado | Caes con un ataque AOE. |
| X cargado sweet spot | Caes con un ataque y al final das una vuelta. Los mantiene en el aire. |
| Y cargado | Das vueltas y botas todo hacia los lados. |
| Y cargado sweet spot | Los mantiene en el aire como congelados. A ti tambien te da mas tiempo airborne. |

## Estado Godot

*(2026-07-08)* Combos completos implementados, adelantados respecto al plan original
(que los dejaba para después de cerrar H1 con [[Espada]]) a pedido explícito.
Pendiente de verificación headless y de jugar — ver `system_status: E0` arriba.

- `combat/weapons/mace/mace.gd` define `Mace extends WeaponBase` (ya no hereda de
  `Sword`): coreografía propia sobre el motor genérico de `WeaponBase`.
- Terrestre X: combo de 3 (swing, swing, smash AOE) vía `run_combo_chain` con el
  parámetro nuevo `wait_branch_extra_steps` — la rama espera agrega 2 smashes más
  (5 golpes totales) en vez de solo cambiar coreografía como la Espada.
- Terrestre X cargado: 3 niveles de carga (1/2/3 vueltas), resueltos por
  `Mace.charge_level()` a partir de `InputBuffer.held_duration()` (plomería nueva,
  también en `WeaponBase`/`PlayerCombat`, sin afectar a la Espada). Sweet spot
  (nivel máximo): las vueltas intermedias congelan (`StunSettings` largo) en vez de
  empujar; el golpe final hace el daño real.
- Terrestre Y: launcher omnidireccional (área más grande que el cono de la Espada).
  Sweet spot: un segundo tap Y dentro de una ventana corta confirma "dos golpes" y
  lanza antes; si no, lanza igual con un solo golpe.
- Aéreo: X sin carga empuja hacia adelante (`push`); X cargado cae con AOE
  (ground pound), sweet spot agrega una vuelta final que congela; Y cargado gira
  empujando a los lados, sweet spot congela y extiende el tiempo airborne del
  jugador (`PlayerLauncher.notify_aerial_attack`).
- "Congelar" no es un verbo nuevo: reusa el sistema de stun existente
  (`StunSettings` con power/duración altos, mode STILL) — ver [[Combate]].
- Refactor compartido con la Espada (sin cambiar su comportamiento): las primitivas
  de swing procedural (`swing`/`swing_up`/`_play_spin`/etc.) y el patrón de launcher
  (`run_launcher_window`) se movieron de `sword.gd` a `weapon_base.gd`, porque el
  Mazo los necesita igual.
- `mace.tscn`: visual de palo con bola; ya no tiene `ChargedDashHitbox` (huérfano,
  el Mazo no usa dash cargado). `AirDiscHitbox`/`LauncherHitbox` agrandados
  ("área grande"/"omnidireccional" según esta nota).
- Todos los ángulos/tiempos/daños en `data/mace_tuning.tres` son un primer pase sin
  jugar — pendiente iterar (gate E1→E2 lo puede promover Claude tras la
  verificación headless; E2→E3 es de Tutupa jugando, ver `METODOLOGIA.md`).
- Instanciado como hijo del player en `player.tscn`; `PlayerCombat` solo muestra las
  armas asignadas a slots.

## Pendiente

- Correr verificación headless (`--import`, `--quit-after 2`, `smoke_test`) — no se
  pudo correr en esta sesión (sin Godot instalado en esta máquina).
- Probar jugando cada fila de la tabla contra un `HitDummy`/enemigo.
- Confirmar que el combate de la Espada en el otro slot no regresionó (se tocaron
  `weapon_base.gd`, `input_buffer.gd` y `player_combat.gd`, compartidos por ambas).
- Tunear `mace_tuning.tres` con el feel real.

## Relacionado

- [[Armas]]
- [[Combate]]

