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
system_status: E2
hito: H2
---

# Mazo / Morningstar

Arma de mas dano. Controla masas. Tiene bastante knockback. Tumba a los enemigos. Velocidad lenta.

## Terrestre

| Input | Descripcion |
|---|---|
| X X X | Swing horizontal, swing horizontal, smash vertical con AOE. |
| X X espera X X | Swing horizontal, swing horizontal, tres smash verticales. Todos con AOE. |
| X cargado (3 niveles) | Das vueltas y golpeas. 1 carga = 1 vuelta, 2 cargas = 2 vueltas, 3 cargas = 3 vueltas. Gasta 1 barra por nivel; si no alcanza el meter, degrada al nivel maximo pagable. |
| X cargado sweet spot | Los enemigos que pega quedan congelados hasta la ultima vuelta, que siempre los manda a volar. |
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

*(2026-07-09)* En desarrollo activo. Combos codificados sobre el mismo motor que la
[[Espada]]; knobs en `mace_tuning.tres` y direccion de diseño clara (`system_status: E2`).

> [!warning] Pendiente de playtest
> La tabla de combos de arriba describe la **intención** de diseño, no un
> comportamiento validado jugando. El feel real (ventanas, daños, sweet spots) todavia
> no se probó — el salto E2→E3 solo lo decide Tutupa jugando (ver `METODOLOGIA.md`).

- `combat/weapons/mace/mace.gd` define `Mace extends WeaponBase` (no hereda de
  `Sword`): coreografía propia sobre el motor genérico de `WeaponBase`.
- Sus swings mueven la mano alrededor del jugador, igual que la Espada (ver Mano orbital
  en [[Combate]]); el palo va rigido, apuntando hacia afuera. *(2026-07-09)*
- Tap X/Y terrestre: combo de 3 (swing, swing, smash AOE) vía `run_combo_chain` con el
  parámetro nuevo `wait_branch_extra_steps` — la rama espera agrega 2 smashes más
  (5 golpes totales) en vez de solo cambiar coreografía como la Espada. Si la ventana
  del launcher Y cargado está abierta, el tap confirma primero el segundo golpe del
  sweet spot antes de arrancar la cadena normal. *(2026-07-09)*
- Terrestre X cargado: 3 niveles de carga (1/2/3 vueltas), resueltos por
  `Mace.charge_level()` a partir de `InputBuffer.held_duration()` (plomería nueva,
  también en `WeaponBase`/`PlayerCombat`, sin afectar a la Espada). Gasta 1 barra de
  meter por vuelta real: si cargas a nivel 3 pero solo hay 2 barras, corre nivel 2; si
  no hay barra, cae al tap normal. Sweet spot (nivel máximo real): las vueltas
  intermedias congelan (`StunSettings` largo) en vez de empujar; el golpe final hace
  el daño real y siempre arma un `charged_final_push` propio, mas fuerte que el `push`
  base del arma. *(2026-07-09)*
- Terrestre Y: launcher omnidireccional (área más grande que el cono de la Espada).
  Sweet spot: un segundo tap Y dentro de una ventana corta confirma "dos golpes" y
  lanza antes; si no, lanza igual con un solo golpe.
- Aéreo: tap X/Y sin carga arma `push` hacia adelante a mitad del swing (`push_at = 0.5`);
  X cargado cae con AOE (ground pound) y gasta 1 barra fija; sweet spot agrega una
  vuelta final que congela; Y cargado sin sweet spot arma `push`, sweet spot congela y
  extiende el tiempo airborne del jugador (`PlayerLauncher.notify_aerial_attack`).
- `air_stall_scale = 1.8`: el Mazo sostiene mas al jugador por golpe conectado porque
  tiene menos impactos y cada uno pesa mas. *(2026-07-09)*
- "Congelar" no es un verbo nuevo: reusa el sistema de stun existente
  (`StunSettings` con power/duración altos, mode STILL) — ver [[Combate]].
- Las primitivas de swing procedural (`swing`/`swing_up`/`_play_spin`/`thrust`) y el
  patrón de launcher (`run_launcher_window`) viven en `weapon_base.gd`, compartidas con
  la Espada. Cada arma pone solo su coreografía.
- `mace.tscn`: visual de palo con bola, sin `ChargedDashHitbox` (el Mazo no usa dash
  cargado). `AirDiscHitbox`/`LauncherHitbox` son grandes ("área grande"/"omnidireccional").
- Los ángulos/tiempos/daños de `data/mace_tuning.tres` son un primer pase sin jugar.
- Instanciado como hijo del player en `player.tscn`; `PlayerCombat` solo muestra las
  armas asignadas a slots.

## Pendiente

- Probar jugando cada fila de la tabla contra un `HitDummy`/enemigo.
- Tunear `mace_tuning.tres` con el feel real.

## Relacionado

- [[Armas]]
- [[Combate]]
