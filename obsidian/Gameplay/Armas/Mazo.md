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

| Input                 | Descripcion                                                                                                                                                                                                                              |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X X X                 | Swing horizontal, swing horizontal, smash vertical con AOE.                                                                                                                                                                              |
| X X espera X X        | Swing horizontal, swing horizontal, tres smash verticales. Todos con AOE.                                                                                                                                                                |
| X cargado (3 niveles) | Das vueltas y golpeas. 1 carga = 1 vuelta, 2 cargas = 2 vueltas, 3 cargas = 3 vueltas. Gasta 1 barra por nivel; si no alcanza el meter, degrada al nivel maximo pagable.                                                                 |
| X cargado sweet spot  | Cada sweet spot exitoso, es decir con 3 cargas si al tercero logras bien el sweet spot das 6 vueltas, si al primero lo logras das 2 y si logras al segundo das 4                                                                         |
| Y cargado             | Paso corto hacia adelante con el launcher armado durante el paso: si el paso choca con un enemigo, se activa ahi; si no toca a nadie, cubre igual el final. Eleva enemigos pero no al jugador. No tiene niveles ni sweet spot por ahora. |
| Y cargado sweet spot  | Diseño pendiente (shockwave hacia adelante que levanta a todos en su camino): no implementado todavia.                                                                                                                                   |

## Aereo

| Input                | Descripcion                                                                                                                                                                                                                                                              |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X                    | Combo de 2: golpe con el mango (sin push) y luego cabezazo con knockback hacia adelante.                                                                                                                                                                                    |
| X cargado            | Caes con un ataque AOE.                                                                                                                                                                                                                                                     |
| X cargado sweet spot | Un spike hacia abajo que cuando impacta en el suelo los eleva un poco y realizas una vuelta que empuja a los afectados.                                                                                                                                                    |
| Y cargado            | **Fuera de scope por ahora** (ver Estado Godot): no existe move propio. Sostener Y en el aire cae al combo aereo normal, igual que un cargado sin barra.                                                                                                                   |

## Estado Godot

*(2026-07-21)* `system_status: E2`: reconstruido desde cero sobre el contrato Mover/Floater
(ver [[Plan Autoridad Vertical]]). Combos sobre el mismo motor que la [[Espada]]; knobs en
`mace_tuning.tres`. Pendiente de playtest completo (Tutupa).

- **Y cargado aereo QUITADO, no solo desactivado** *(2026-07-21)*: la caida diagonal + AOE
  cilindrico + rebote balistico del jugador y del enemigo (`slam_arc`) dependian de un "bouncer"
  balistico que no existe, y el contrato de armas prohibe fingir un arco balistico con un Mover
  lineal (ver `references/contrato-armas.md` del skill de armas). Se decidio no implementarlo hasta
  diseñar ese bouncer: se borro el codigo entero de ese move (`_aerial_hold_y`, `_burst_air_slam`,
  `_on_air_slam_about_to_hit`, `_on_air_slam_hit`, el nodo `AirSlamHitbox` de `mace.tscn` y todo el
  tuning `air_y_*` de caida/rebote), no quedo comentado a la espera. Sostener Y en el aire cae al
  combo aereo normal. Si mas adelante se diseña el bouncer, este move se piensa de nuevo desde cero;
  no se recupera el codigo viejo.
- **Y cargado terrestre ahora SI eleva al enemigo**: el `LauncherHitbox` estaba cableado con
  `enemy_mover = null` — pegaba pero no lanzaba a nadie, pese a que esta nota siempre documento
  "eleva enemigos". Ahora pide `ground_y_launcher_enemy_mover` (Mover UP + Floater del hang, mismo
  patron que `Sword.ground_charged_y_enemy_mover`). El jugador sigue sin recibir perfil propio (el
  paso corto es horizontal, via `force_dash`): "eleva enemigos pero no al jugador" ya se cumple.
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
  `ground_y_dash_duration`, via `Player.force_dash`, horizontal) con el `LauncherHitbox` armado
  durante el paso, asi se activa al chocar con un enemigo durante el dash; si no toca a nadie, la
  ventana cubre igual el final. El enemigo golpeado pide su propio `ground_y_launcher_enemy_mover`
  (Mover UP + Floater); el jugador no recibe perfil vertical. El salto para perseguirlos sigue
  siendo manual. No gasta meter por ahora y no tiene niveles ni sweet spot. *(2026-07-21)*
- Aéreo: tap X sin carga es un **combo de 2** (un tap por golpe, corre a `swing_time` porque
  el Mazo es pesado) — golpe 1 jab con el mango (`thrust`, `air_handle_reach`, sin push) y
  golpe 2 cabezazo horizontal que arma el `push` a mitad del swing (`push_at`);
  X cargado cae con AOE (ground pound, `air_smash_fall_speed`) y gasta 1 barra fija; sweet spot
  agrega una vuelta final que congela (`air_freeze_stun`). El ground pound escribe
  `vertical_velocity` directo a proposito: es una caida recta, no un arco balistico, y el plan
  vertical lo deja como excepcion viva (no depende del bouncer). *(2026-07-21)*
- `air_stall_scale = 1.8`: el Mazo sostiene mas al jugador por golpe conectado porque
  tiene menos impactos y cada uno pesa mas. *(2026-07-09)*
- "Congelar" no es un verbo nuevo: reusa el sistema de stun existente
  (`StunSettings` con power/duración altos, mode STILL) — ver [[Combate]].
- Las primitivas de swing procedural (`swing`/`swing_up`/`_play_spin`/`thrust`) viven en
  `weapon_base.gd`, compartidas con la Espada. Cada arma pone solo su coreografía.
- `mace.tscn`: visual de palo con bola, sin `ChargedDashHitbox` (el Mazo no usa dash
  cargado ofensivo tipo Espada). `LauncherHitbox` es el area terrestre del Y cargado;
  `AirDiscHitbox` es el disco para golpes aereos normales. `AirSlamHitbox` (el AOE del Y aereo con
  rebote) se borro junto con el move. *(2026-07-21)*
- Los ángulos/tiempos/daños de `data/mace_tuning.tres` son un primer pase sin jugar.
- Instanciado como hijo del player en `player.tscn`; `PlayerCombat` solo muestra las
  armas asignadas a slots.

## Pendiente

- Probar jugando cada fila de la tabla contra un `HitDummy`/enemigo, en especial el launcher
  terrestre (ahora que si eleva al enemigo).
- Tunear `mace_tuning.tres` con el feel real, incluido `ground_y_launcher_enemy_mover`.
- Definir si el Y cargado terrestre gasta meter, y si recupera niveles/sweet spot.
- Diseñar el "bouncer" balistico (ver [[Plan Autoridad Vertical]] F5) antes de retomar un Y
  cargado aereo para el Mazo.

Las verificaciones abiertas del Mazo viven en el board de tareas ([[tareas]]).

## Relacionado

- [[Armas]]
- [[Combate]]
- [[Plan Autoridad Vertical]]
