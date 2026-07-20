---
title: Mapa Impacto Autoridad Vertical
tags:
  - egoist
  - godot
  - combate
  - plan
status: active
fase: F0
---

# Mapa de Impacto — Autoridad Vertical (F0)

Compañera de [[Plan Autoridad Vertical]]. Foto de los consumidores del sistema vertical viejo al
inicio de la migracion. Cada fila migra a **Mover** y/o **Floater**. `archivo:linea` al momento de F0.

## PlayerLauncher — hub vertical del Player (`player/player_launcher.gd`)

Es el nodo que hoy concentra launcher, air-hit-stall, whiff, hover y arm-freeze del Player.

- **Glue** `player/player.gd`: `setup` (58); tick del launcher (114, 119); `gravity_scale()` en la
  integracion de gravedad (150); `consume_air_freeze()` (147); `reset_air_stall()` (170, 205);
  `cancel()` (284, 362); `start_launch()` (391); `register_air_hit_stall()` (307);
  `register_arm_air_freeze()` (312); `notify_aerial_attack()` (315); `hover()` (319).
- **Dash** `player/player_dash.gd`: recibe `register_air_hit_stall` y `cancel` como callbacks
  (cableados en `player.gd:63`).
- **Enemy bounce** `player/player_enemy_bounce.gd:32`: lee `launcher.is_launched`.
- **WeaponBase** `combat/weapons/weapon_base.gd`: `setup_launcher_hitbox` (414),
  `_on_launcher_about_to_hit` (427), `run_launcher_window` (436), `end_launcher_window` (285);
  llama `_player.launch` (446) y `_player.register_air_hit_stall` (321).
- **Sword** `combat/weapons/sword/sword.gd`: `setup_launcher_hitbox` (46), `run_launcher_window`
  (151), `_player.launch` (168), `_player.hover` (246).
- **Mace** `combat/weapons/mace/mace.gd`: `setup_launcher_hitbox` (48), `run_launcher_window` (204),
  `_player.notify_aerial_attack` (253), `end_launcher_window` (317).
- **Arm** `player/player_arm.gd:256`: `register_arm_air_freeze`.
- **Escena** `player/player.tscn`: nodo hijo `PlayerLauncher`.
- **Smoke** `world/smoke_test.gd`: `launch` (108), `launcher.is_launched` (109), `launcher.cancel`
  (164, 174, 397, 400, 418), `run_launcher_window` (398).

## Verbos verticales del Enemy (`enemies/enemy_base.gd`)

Superficie duck-typed (`has_method`) que invocan las armas; ver `combat/hurtbox.gd:7`.

- `launch(height, hang_time, stun=null, starts_lying=false) -> bool` (457) → `_launch_routine`
  (475), fija `_airborne_until` (486). **Balistico? No** — subida lineal a `height/rise_time`.
- `slam(down_speed)` (488) — clava la caida; requiere stun + airborne.
- `slam_bounce(down_speed, target_world_y, hang_time)` (496) — baja y rebota a una altura objetivo
  con hang. `_bounce_hang_time` (163, 500) reusa `launch` en `_do_bounce` (805).
- `slam_arc(down_speed, bounce_dir, bounce_up_speed, bounce_forward_speed, bounce_gravity)` (510)
  — **BALISTICO** (up + forward + gravedad propia). No cabe en el Mover lineal → bouncer en **F5**.
- `push(direction, settings: PushSettings)` (534) → `_start_push_arc` (559), `_tick_push_arc`
  — **BALISTICO** (arco por geometria, mete al enemigo en aire aunque este en piso).
- `_airborne_until` (158, 427, 486, 491, 546, 764, 781, 818, 883) — gate de hold en aire; el stun
  se sostiene mientras `now < _airborne_until`.

**Callers (duck typing):** `weapon_base.gd:430` (`launch`); `sword.gd:180-184` (`slam_bounce`),
`sword.gd:232` (`launch`); `mace.gd:348` (`launch`), `mace.gd:361-366` (`slam_arc`).

**Dobles de test / otros implementadores:** `combat/dummies/hit_dummy.gd` implementa
launch/slam/push/slam_bounce/slam_arc + `_airborne_until` (11-73); `world/smoke_test.gd` pushers
inline (11, 21), `push` (484, 548), `launch` (482, 490), lee `_airborne_until` (466);
`world/probe_animaciones_ia.gd:135` (`push`).

> Ojo: `enemies/attacks/ranged_attack.gd:80` y `projectile.gd:63` tienen su propio `launch(origin,
> dir, ...)` de **proyectil** — NO es autoridad vertical, no se toca.

## Verbos verticales del Player (`player/player.gd`)

- `launch(height, hang_time, rise_time)` (383) → `launcher.start_launch`.
- `plunge(down_speed)` (332), `is_plunging` (338), `cancel_plunge` (341) — caida clavada constante.
  Caller: `sword.gd:330` (`_player.plunge`).
- `hover` (318), `air_hop` (346), `register_arm_air_freeze` (311),
  `apply_air_charge_fall_control` (230).
- Integracion de gravedad: lee `launcher.gravity_scale()` + `consume_air_freeze()` (147-150).

## Carga aerea — freno de caida (`player/player_air_kill_reset.gd`)

- `apply_air_charge_fall_control` (13), `reset_air_charge_fall_control` (21), `apply_air_kill_reset`
  (24), `_fall_reduction_for_use` (31, lee `tuning.air_charge_fall_reduction_steps`).
- Wrappers en `player.gd` (230-234); reset al pisar (171).
- `player/player_combat.gd`: aplica al llegar la carga a 1.0 en aire (116, 152), flag
  `_air_charge_fall_applied` (30, 105, 114, 150).
- Smoke `world/smoke_test.gd` (284-328).
- Migra a **Floater** en F4. El reset de doble salto/airdash (`apply_air_kill_reset`) **NO se toca**.

## Tuning atado al sistema viejo (`data/`)

- `player_tuning.gd`: `launcher_float_duration` (209), `launcher_float_gravity` (211),
  `launcher_fall_duration` (213), `launcher_fall_gravity` (215); `air_stall_*` (276-296);
  `aerial_whiff_fall_gravity` (298); `air_charge_fall_reduction_steps` (303).
- `sword_tuning.gd`: `launcher_height` (97), `launcher_hang_time` (98), `launcher_hitbox_duration`
  (99), `launcher_deals_damage` (100); `sweet_spot_air_stall_bonus` (59).
- `mace_tuning.gd`: `ground_y_launcher_*` (46-56), `air_y_launcher_hang_time` (90),
  `air_freeze_stun` (103), `air_freeze_extra_hang_time` (104).
- `weapon_tuning.gd`: `air_stall_scale` (37). `arm_tuning.gd`: `air_freeze_duration` (30).
- `World.LAUNCH_RISE_TIME` (autoload) — lo usan launcher y `_launch_routine` del enemy.

## A donde va cada cosa

| Sistema viejo | Migra a | Fase |
|---|---|---|
| `launch` (Player y Enemy) + `launcher_*` | Mover UP + Floater | F2 |
| air-hit-stall / whiff / hover del combo aereo normal | Mover(s) o Floater directo (a probar) | F3 |
| X cargado aereo | Mover `DISTANCE\|WALL` + Floater | F4 |
| Y cargado aereo (spike/rebote), `slam_bounce` | Movers descendente/ascendente + Floaters | F4 |
| `plunge`, `push` | Mover propio (push necesita arco → ver F5) | F4 |
| `air_charge_fall_control` (freno) | Floater al Player | F4 |
| Mazo/Brazo, `slam_arc`, rebotes balisticos | Mover en modo **bouncer** balistico | F5 |
| `_airborne_until`, `StunSettings.airborne` | se retiran cuando nadie los use | F5 |

## Relacionado

- [[Plan Autoridad Vertical]]
- [[Reset Aereo por Kill]]
- [[Stun]]
