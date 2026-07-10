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
| Y cargado | Paso corto hacia adelante; al terminar, launcher de area grande que eleva enemigos pero no al jugador. No tiene niveles ni sweet spot por ahora. |

## Aereo

| Input | Descripcion |
|---|---|
| X | Combo de 2: golpe con el mango (sin push) y luego cabezazo con knockback hacia adelante. |
| X cargado | Caes con un ataque AOE. |
| X cargado sweet spot | Caes con un ataque y al final das una vuelta. Los mantiene en el aire. |
| Y cargado | Caida diagonal con angulo tuneable; al impactar enemigo o suelo estalla un AOE cilindrico en la zona. Todos los enemigos del cilindro son clavados al suelo y rebotan hasta tu altura (`slam_bounce`), no lanzados hacia arriba. Conectar contra un enemigo **en el aire** hace que el jugador rebote arriba-y-adelante (segun la direccion de la caida), sin gastarle el doble salto: esa es la ventana para perseguir a los enemigos que quedan a tu altura. No tiene niveles ni sweet spot por ahora. |

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
  (5 golpes totales) en vez de solo cambiar coreografía como la Espada. *(2026-07-09)*
- Terrestre X cargado: 3 niveles de carga (1/2/3 vueltas), resueltos por
  `Mace.charge_level()` a partir de `InputBuffer.held_duration()` (plomería nueva,
  también en `WeaponBase`/`PlayerCombat`, sin afectar a la Espada). Gasta 1 barra de
  meter por vuelta real: si cargas a nivel 3 pero solo hay 2 barras, corre nivel 2; si
  no hay barra, cae al tap normal. Sweet spot (nivel máximo real): las vueltas
  intermedias congelan (`StunSettings` largo) en vez de empujar; el golpe final hace
  el daño real y siempre arma un `charged_final_push` propio, mas fuerte que el `push`
  base del arma. *(2026-07-09)*
- Terrestre Y cargado: paso corto hacia adelante (`ground_y_dash_distance` /
  `ground_y_dash_duration`) y luego launcher de area grande. El launcher lanza enemigos
  pero no lanza al jugador: el salto para perseguirlos es manual. No gasta meter por
  ahora y no tiene niveles ni sweet spot. *(2026-07-09)*
- Aéreo: tap X sin carga es un **combo de 2** (un tap por golpe, corre a `swing_time` porque
  el Mazo es pesado) — golpe 1 jab con el mango (`thrust`, `air_handle_reach`, sin push) y
  golpe 2 cabezazo horizontal que arma el `push` a mitad del swing (`push_at`);
  X cargado cae con AOE (ground pound) y gasta 1 barra fija; sweet spot agrega una
  vuelta final que congela. Y cargado cae en diagonal (`air_y_fall_angle` /
  `air_y_fall_speed`); al impactar estalla `AirSlamHitbox` (cilindro) una vez y todos los
  enemigos de adentro reciben `slam_bounce` (bajan, rebotan en el piso y vuelven a tu
  altura, `air_y_down_speed` / `air_y_meet_height` / `air_y_launcher_hang_time`). No gasta
  meter por ahora y no tiene niveles ni sweet spot. *(2026-07-10)*
- El Y aereo hace **rebotar al jugador**: al clavar un enemigo en el aire, el jugador sale
  arriba-y-adelante (`air_y_bounce_forward_speed` / `air_y_bounce_up_speed`, que juntos fijan
  el angulo del rebote segun la direccion de la caida), sin gastar el doble salto. Reemplaza
  el hover previo. Contra el suelo (sin enemigo en el aire) el jugador no rebota: solo estalla
  el AOE. Esa es la ventana para perseguir a los enemigos que quedan a tu altura. *(2026-07-10)*
- `AirSlamHitbox` es un **cilindro** (`air_y_aoe_radius` / `air_y_aoe_height`) que se prende
  **una sola vez en el impacto** (estallido), no durante toda la caida. El impacto se detecta
  por contacto fisico con el suelo o con un enemigo (mismas colisiones de `CharacterBody3D`
  que usa [[Rebote en Enemigos]]). *(2026-07-10)*
- `air_stall_scale = 1.8`: el Mazo sostiene mas al jugador por golpe conectado porque
  tiene menos impactos y cada uno pesa mas. *(2026-07-09)*
- "Congelar" no es un verbo nuevo: reusa el sistema de stun existente
  (`StunSettings` con power/duración altos, mode STILL) — ver [[Combate]].
- Las primitivas de swing procedural (`swing`/`swing_up`/`_play_spin`/`thrust`) y el
  patrón de launcher (`run_launcher_window`) viven en `weapon_base.gd`, compartidas con
  la Espada. Cada arma pone solo su coreografía.
- `mace.tscn`: visual de palo con bola, sin `ChargedDashHitbox` (el Mazo no usa dash
  cargado ofensivo tipo Espada). `LauncherHitbox` es el area terrestre del Y cargado;
  `AirSlamHitbox` es el AOE del Y aereo; `AirDiscHitbox` sigue siendo el disco para golpes aereos normales.
- Los ángulos/tiempos/daños de `data/mace_tuning.tres` son un primer pase sin jugar.
- Instanciado como hijo del player en `player.tscn`; `PlayerCombat` solo muestra las
  armas asignadas a slots.

## Pendiente

- Probar jugando cada fila de la tabla contra un `HitDummy`/enemigo.
- Tunear `mace_tuning.tres` con el feel real.
- Definir si el Y cargado (tierra y aire) gasta meter, y si recupera niveles/sweet spot.

Las verificaciones abiertas del Mazo viven en el board de tareas ([[tareas]]).

## Relacionado

- [[Armas]]
- [[Combate]]
