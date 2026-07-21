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
- **WeaponBase** `combat/weapons/weapon_base.gd`: `setup_vertical_hitbox`,
  `_on_vertical_about_to_hit`, `run_vertical_window`, `end_vertical_window`; los perfiles se piden
  con `request_mover` y el air-hit-stall legacy sigue separado.
- **Sword** `combat/weapons/sword/sword.gd`: `setup_vertical_hitbox`, `run_vertical_window` y los
  perfiles de Y aérea/sweet spot mediante `request_mover`.
- **Mace** queda fuera del loadout y pendiente de rehacerse; no forma parte de la superficie vertical
  vigente.
- **Arm** `player/player_arm.gd:256`: `register_arm_air_freeze`.
- **Escena** `player/player.tscn`: nodo hijo `PlayerLauncher`.
- **Smoke** `world/smoke_test.gd`: `launch` (108), `launcher.is_launched` (109), `launcher.cancel`
  (164, 174, 397, 400, 418), `run_launcher_window` (398).

## Cierre Batch 9 - contrato vigente

- Las armas y ataques deciden `MoverSettings` y los datos de `Floater`; `Player`, `EnemyBase` y
  `HitDummy` solo ejecutan `request_mover(...)` y `request_float(...)`.
- `TOTAL` toma el movimiento completo. `PARTIAL` controla solo Y dentro del tick normal del Player,
  conservando locomocion, contactos, dash, wall-slide y rebote.
- Todo golpe nuevo que afecte a `EnemyBase` cancela su Mover y Floater activos. Solo se preserva el
  perfil armado por ese mismo golpe en `about_to_hit`, antes de aplicar dano.
- Espada usa perfiles para Y cargado terrestre/aereo, sweet spot, hop, finisher y plunge. El rebote
  del Y aereo esta desactivado. PlayerLauncher no participa en el flujo activo de Espada.
- Mace esta fuera del loadout y se reconstruira desde este contrato. `HitDummy` usa Mover/Floater
  reales y no expone verbos verticales legacy.
- No se crearon, modificaron ni ejecutaron smoke tests por decision explicita del proyecto.

### Limpieza posterior

`PlayerLauncher`, su nodo de escena, su adaptador `Player.launch(...)` y sus knobs de tuning fueron
eliminados. `PlayerDash` pide su Float directamente con `dash_air_hit_float_*`; Player conserva solo
Mover y Floater como control vertical de combate.

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

**Callers legacy activos:** Mace conserva `mace.gd:348` (`launch`) y `mace.gd:361-366`
(`slam_arc`) hasta su futura reconstrucción. Espada y WeaponBase ya piden perfiles.

**Dobles de test / otros implementadores:** `combat/dummies/hit_dummy.gd` implementa
launch/slam/push/slam_bounce/slam_arc + `_airborne_until` (11-73); `world/smoke_test.gd` pushers
inline (11, 21), `push` (484, 548), `launch` (482, 490), lee `_airborne_until` (466);
`world/probe_animaciones_ia.gd:135` (`push`).

> Ojo: `enemies/attacks/ranged_attack.gd:80` y `projectile.gd:63` tienen su propio `launch(origin,
> dir, ...)` de **proyectil** — NO es autoridad vertical, no se toca.

## Verbos verticales del Player (`player/player.gd`)

- `launch(height, hang_time, rise_time)` (383) → `launcher.start_launch`.
- Mover parcial: el plunge y el hop aéreo de Espada conservan contactos de locomoción mientras
  el perfil controla el eje vertical.
- `hover` (318), `register_arm_air_freeze` (311),
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
- `sword_tuning.gd`: perfiles `ground_charged_y_*_mover`, `aerial_charged_y_*_mover` y
  `sweet_spot_explosion_enemy_mover`; `ground_charged_y_hitbox_duration` y
  `ground_charged_y_deals_damage` gobiernan el Y terrestre.
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
| Y cargado aereo de Espada | Mover UP Player + Mover DOWN Enemy; rebote desactivado | Batch 6 |
| plunge de Espada | Mover DOWN parcial Player + Mover DOWN total Enemy | Batch 7 |
| `push` | Mover propio (push necesita arco → ver F5) | F5 |
| `air_charge_fall_control` (freno) | Floater al Player | F4 |
| Mazo/Brazo, `slam_arc`, rebotes balisticos | Mover en modo **bouncer** balistico | F5 |
| `_airborne_until` | se retira cuando nadie lo use como hold legacy | F5 |
| `StunSettings.airborne` | duración real de stun aéreo, sin autoridad de hang | Batch 4 |

## Pendiente actual — autoridad todavia en receptores

### Batch 2 - perfiles de Espada listos

- `SwordTuning` ya contiene perfiles `MoverSettings` para Y cargado terrestre (Player y Enemy),
  auto-launch aereo del Player, explosion del sweet spot Enemy y spike del Y aereo Enemy.
- Los perfiles incluyen `float_duration` y `float_fall_scale`: el hang ya no necesita vivir dentro
  de `StunSettings`. Se migraron los valores vigentes de altura, tiempo de subida y Float.
- El rebote aereo sigue desactivado y queda fuera de esta migracion hasta que vuelva a estar en juego.
- Los consumidores que todavía usan `launch` permanecen marcados como legacy hasta migrar sus rutas.
  El Y cargado terrestre ya usa perfiles mediante `request_mover`.

### Batch 3 - WeaponBase por perfiles

- `WeaponBase.run_vertical_window(...)` recibe perfiles `MoverSettings` separados para Player y
  Enemy. El golpe previo al dano llama `EnemyBase.request_mover(...)`, con `StunSettings` solo para
  el gate de poise. Ya no existe fallback desde WeaponBase a `launch(height, hang_time)`.
- El Y cargado terrestre de Espada es el primer consumidor: usa los perfiles de `SwordTuning`.
- `register_weapon_hit(...)` puede pedir un Float del Player con duracion y fall scale del ataque,
  sin pasar por `PlayerLauncher`. Los golpes no migrados siguen temporalmente en air-hit-stall.
- Mace queda fuera de la seleccion del loadout y su launcher terrestre ya no aplica control vertical.
  Sus rutas restantes no se preservaran: se rehara sobre la arquitectura nueva en otro hito.

### Limpieza de nomenclatura posterior al Batch 3

- La superficie vigente cambió de `launcher_*` a `vertical_*`: `WeaponBase`, el hitbox/nodo de
  Espada y sus parámetros de Y cargado terrestre usan el mismo vocabulario.
- `launch(...)` se conserva exclusivamente como adaptador legacy de Player/EnemyBase para las rutas
  que aún no llegaron a su batch. No es parte de la API nueva.

### Batch 4 - Stun separado de hang

- `EnemyBase.apply_stun(...)` ya no inicia ni extiende Floater, ni modifica el timer de hold. El stun
  solo decide estado, poise y pose; el perfil del ataque es el único que puede pedir suspensión.
- `StunSettings.airborne` queda como duración real de stun aéreo. El sweet spot de Espada dejó de
  derivarla de subida + Float y usa directamente el stun configurado para su dash cargado.
- Se conserva el gate: un `request_float(...)` de EnemyBase solo entra sobre un enemigo aéreo que ya
  está stuneado/quebrado. El Mover iniciado antes del daño mantiene su perfil propio al completarse.

### Batch 6 - Espada aérea y sweet spot por perfiles

- La Y cargada aérea de Espada pide `aerial_charged_y_player_mover` al Player y, tras conectar,
  `aerial_charged_y_enemy_spike_mover` al Enemy. El rebote permanece desactivado y fuera de la ruta.
- El sweet spot pide `sweet_spot_explosion_enemy_mover` antes de cobrar el daño, junto al stun que
  consulta poise. Ya no usa `target.launch(...)`.
- Se retiraron de `SwordTuning` los knobs legacy de altura, tiempo de subida, hang y rebote que esas
  rutas dejaron de consumir.

### Batch 7 - Plunge de Espada

- El Player recibe `air_plunge_player_mover`: perfil Mover parcial que preserva su tick de
  locomoción, contactos, dash, wall-slide y enemy-bounce mientras controla Y.
- El Enemy del plunge recibe `air_plunge_enemy_mover`, un perfil Mover DOWN que corta en piso. Espada
  alinea y pide ese perfil solo cuando el objetivo ya está aéreo y stuneado.
- El hop de la rama aérea de espera y el hachazo aéreo normal también usan perfiles Mover. Espada ya
  no llama `Player.plunge(...)`, `Player.air_hop(...)` ni `EnemyBase.slam(...)`.
- Todo hit nuevo sobre EnemyBase cancela su Mover y Floater anteriores. El único Mover preservado es
  el que el mismo golpe armó antes del daño mediante `about_to_hit`.

### Batch 8 - PlayerLauncher fuera del flujo activo

- `WeaponBase` calcula el Float por impacto aéreo desde `WeaponTuning` y lo pide directamente al
  Player. `PlayerLauncher` ya no crea Floater para los golpes de Espada.
- El whiff aéreo dejó de modificar gravedad mediante PlayerLauncher: sin impacto, la caída conserva
  gravedad normal.
- El nodo PlayerLauncher queda solo como compatibilidad legacy para rutas aún no migradas; no decide
  movimiento vertical en el flujo activo de Espada.

Foto posterior a F4 parcial: `Player` y `EnemyBase` ya tienen `Mover`/`Floater` como
infraestructura, pero todavia no son receptores tontos. Hay capacidad migrada, no autoridad
centralizada. Criterio nuevo para limpiar: **el arma/ataque decide el perfil vertical**; `Player` y
`EnemyBase` solo ejecutan/cancelan lo que se les pide.

Regla de contrato: en enemigos, **Floater solo puede sostener aire durante stun/quiebre**. El arma
puede pedir el float, pero `EnemyBase` debe validarlo contra su estado quebrado (`is_stunned()`,
ragdoll/poise roto o el stun que acaba de entrar por el golpe). Un enemigo que aguanta poise o no
esta stuneado no flota.

### Player

- `player/player.gd` instancia `Floater` y `Mover` por codigo y los ejecuta en `_physics_process`.
  Eso esta bien: el cuerpo es el dueño fisico.
- `Player.launch(height, hang_time, rise_time)` todavia arma un `MoverSettings` adentro y decide el
  `float_duration`/`float_fall_scale` desde `PlayerTuning` (`launcher_float_duration`,
  `launcher_fall_duration`, `launcher_float_gravity`). Falta mover esa decision al arma/ataque y
  dejar una API tipo `request_mover(settings)` / `request_float(duration, fall_scale)`.
- `Player.apply_air_charge_float()` prende Floater desde el player usando `PlayerTuning`
  (`air_charge_float_duration`, `air_charge_float_fall_scale`). Si la autoridad es el arma, la carga
  debe pedir el float desde `PlayerCombat`/arma con tuning del arma o del ataque, y el player solo
  ejecuta.
- El air-hit Float de Espada ya se calcula en `WeaponBase` con `WeaponTuning`; PlayerLauncher no lo
  decide. El whiff aéreo ya no altera gravedad.
- El plunge de Espada usa `air_plunge_player_mover` en modo `PARTIAL`; sigue el tick normal para no
  apagar contactos, dash, wall-slide ni enemy-bounce, pero su autoridad vive en Mover.
- El hop aéreo de Espada ya usa `air_wait_spin_player_mover`; no queda `Player.air_hop(...)` en esa
  ruta.
- `Player.bump(...)`, `force_dash(...)`, `set_dash_exit_bop(...)`, salto/doble salto, wall/floor
  slide y enemy bounce escriben vertical por traversal/locomocion/stun. No son necesariamente deuda
  de autoridad de combate, pero deben quedar explicitamente fuera del alcance o migrarse si un arma
  los usa como move de combate.

### EnemyBase

- `enemies/enemy_base.gd` instancia `Floater` y `Mover` por codigo y los ejecuta en
  `_update_airborne`. Eso esta bien: el enemigo es el dueño fisico.
- `EnemyBase.launch(height, hang_time, stun, starts_lying)` todavia arma un `MoverSettings` adentro,
  decide `float_fall_scale = 0.0` y usa `hang_time` como float. Falta que el arma entregue el perfil
  completo del enemigo (mover + float) y que el enemigo solo aplique el gate de poise/stun y ejecute.
- `EnemyBase.apply_stun()` ya no modifica Floater ni `_airborne_until`. Mantiene el estado/pose del
  stun, mientras que el ataque decide cualquier hold mediante su perfil vertical.
- `EnemyBase.cancel_vertical_control()` corta Mover/Floater cuando llega otro ataque. Los Movers
  pre-daño usan un permiso de un impacto para no cancelarse a sí mismos.
- `EnemyBase.slam(down_speed)` sigue como adaptador legacy para consumidores pendientes. El plunge de
  Espada ya entrega `air_plunge_enemy_mover` directamente mediante `request_mover(...)`.
- `EnemyBase.slam_bounce(...)` y `_do_bounce()` guardan estado de rebote y reusan `launch`. Falta que
  el arma exprese la secuencia descendente/ascendente como perfiles, o que el bouncer cubra la
  coreografia completa.
- `EnemyBase.slam_arc(...)` y `push(direction, PushSettings)` siguen siendo balisticos internos
  (`_start_push_arc`, `_tick_push_arc`, `_do_bounce_arc`). Falta el modo bouncer/F5 o una excepcion
  documentada; el Mover lineal actual no los cubre.
- `_airborne_until` todavia existe como tope/hold legacy y fallback si no hay Floater. Falta reducirlo
  a safety timer puro o borrarlo cuando los floats de juggle ya vengan de ataques.
- `StunSettings.airborne` ya es solo duración de stun aéreo. No modifica Float, hang ni
  `_airborne_until`.

### Armas y callers que deben cambiar

- `WeaponBase` ya recibe perfiles separados para Player/Enemy, envia `request_mover` y conserva el
  `StunSettings` solo como gate de poise. No tiene adaptador a `launch`.
- `WeaponBase.register_weapon_hit(...)` ya acepta Float directo del Player; los consumidores que aun
  usan air-hit-stall se migran por ataque en los batches siguientes.
- `WeaponBase._begin_air_step(...)` llama `_player.notify_aerial_attack(...)` para whiff gravity.
  Falta que el whiff/hang de cada golpe aereo sea configuracion del ataque o se elimine como sistema
  vertical legacy.
- `WeaponBase._finish_air_combo(...)` todavia llama `target.slam(...)` en el spike generico. Falta
  migrarlo a perfil de spike pedido por el arma, o borrar el spike generico si cada arma lo define.
- `WeaponBase.arm_push(...)` / `_push_target(...)` llama `target.push(...)` con `PushSettings`. Aunque
  `PushSettings` viene del arma, la trayectoria balistica todavia la ejecuta EnemyBase por verbo
  legacy; falta bouncer/perfil balistico o excepcion documentada.
- `Sword._run_aerial_charged_y()`, `_on_aerial_charged_y_hit()` y `_explode_sweet_spot_hits()` ya
  piden perfiles `MoverSettings`; el sweet spot conserva su `request_float(...)` propio para Player.
- `Sword._finish_air_combo()` usa Movers para Player y Enemy, tanto en plunge como en el hachazo
  aéreo normal. Ya no llama `target.slam(...)`; `play_air_step()` tampoco usa `Player.air_hop(...)`.
- El sweet spot de Espada usa `charged_dash_stun` como stun real, sin derivar `airborne` de la subida
  ni del Float, y pide su perfil Enemy antes del daño.
- `Sword._hold_x()` usa `_player.force_dash(...)` para el X cargado. Esta pendiente decidir si el
  dash ofensivo queda como excepción de locomoción/dash o si entra en Mover parcial.
- `Sword.play_air_step(...)` usa `air_wait_spin_player_mover` como Mover parcial para el hop de
  la rama espera.
- `Mace._set_air_y_fall_velocity()` escribe momentum + `player.vertical_velocity` directo;
  `_burst_air_slam()` escribe rebote directo; `_on_air_slam_about_to_hit()` llama `target.launch(...)`;
  `_on_air_slam_hit()` llama `target.slam_arc(...)`. Falta migrar a bouncer/perfiles o documentar
  excepciones.
- `Mace._aerial_charged_x(...)` escribe `_player.vertical_velocity = -air_smash_fall_speed` y usa
  `notify_aerial_attack(...)` para el tramo/freeze. Falta que el descenso y el hang/congelado vengan
  de perfiles del ataque.
- `Mace._aerial_hold_y(...)` mantiene un loop propio hasta suelo/contacto y usa colisiones del
  `Player` para decidir rama. Falta decidir si ese detector vive en el ataque con bouncer no
  exclusivo, o si queda como excepcion documentada del Y aereo.
- `Mace._burst_air_slam(...)` escribe el rebote del Player (`set_momentum` + `vertical_velocity`) o
  planta al jugador cortando momentum. Falta expresar ese rebote como perfil pedido por el ataque, o
  dejarlo fuera de autoridad vertical por ser rebote/locomocion.
- `Mace._on_air_slam_about_to_hit(...)` lanza enemigos via `target.launch(...)` antes del daño; el
  orden es correcto para poise/stun, pero falta que envie el perfil vertical completo del AOE.
- `Mace._on_air_slam_hit(...)` llama `target.slam_arc(...)` despues del daño. Es deuda directa de
  bouncer balistico.
- `Mace._run_charged_spins(...)` arma `arm_push(t.charged_final_push, ...)`: mismo pendiente de push
  balistico en EnemyBase.
- `PlayerCombat` dispara `body.apply_air_charge_float()` al llegar a carga completa. Falta mover esa
  autoridad al arma/slot/ataque si la carga aerea depende del arma.

### Stun

- `StunSettings` es dato definido por quien ataca: `poise_damage`, `grounded` y `airborne` viven en
  el recurso del golpe. La duración de stun ya está separada de la de hang/Floater.
- `StunSettings.airborne` representa duración real de stun aéreo. Los hangs se expresan mediante
  `MoverSettings.float_*` o `request_float(...)` del ataque.
- `EnemyBase.apply_stun(...)` no inicia Floater. Se conserva el gate: **enemigo sin stun/quiebre no
  puede flotar**.
- `EnemyBase.try_apply_stun(...)` y `Player.receive_stun(...)` usan
  `stun.duration_for(is_airborne())`. El gate de poise esta bien; lo pendiente es que esa duracion no
  sea usada indirectamente como perfil vertical.
- `Hitbox.about_to_hit` se usa para lanzar antes del daño y que `receive_hit` vea `is_airborne`.
  El orden es correcto y probablemente se conserva, pero el efecto previo debe pasar de
  `target.launch(...)` a "pedir perfil vertical" al receptor.
- `Hurtbox` documenta capacidades legacy `launch/slam/push/slam_bounce`. Falta actualizar ese
  registro de verbos cuando la API final sea `request_mover`/`request_float`/bouncer o equivalente.

### Dobles, smokes y docs

- `combat/dummies/hit_dummy.gd` implementa los verbos legacy (`launch`, `slam`, `push`,
  `slam_bounce`, `slam_arc`) y `_airborne_until`. Hay que actualizarlo junto con la API nueva.
- `world/smoke_test.gd` y `world/combat_smoke_test.gd` todavia prueban llamadas legacy y acceso a
  `player.floater`/`enemy.floater` en algunos asserts. Al migrar autoridad, los smokes deben probar
  que el arma pide perfiles y que el receptor solo ejecuta.
- Actualizar [[Plan Autoridad Vertical]], [[Combate]], [[Espada]], [[Mazo]], [[Stun]] y
  [[Reset Aereo por Kill]] cuando se cierre la API final.

## Relacionado

- [[Plan Autoridad Vertical]]
- [[Reset Aereo por Kill]]
- [[Stun]]
