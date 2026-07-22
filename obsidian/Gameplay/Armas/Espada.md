---
title: Espada
tags:
  - egoist
  - gameplay
  - arma
  - combate
status: active
system_status: E2
hito: H1
---

# Espada

Arma base / equilibrada. Velocidad media. Sirve para mantener el flujo del combate. En Godot V2 vive en `combat/weapons/sword/` con `Sword` y `SwordTuning`.

**Habilidad especial:** si matas a un enemigo con X cargado, recuperas 1 barra de meter para usar de nuevo.

## Terrestre

| Input                | Descripcion                                                                                                                |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| X X X X              | Swing horizontal, swing horizontal, estocada, estocada. La estocada extiende el brazo al frente (`thrust_reach`) y vuelve. |
| X X espera X X       | Izquierda a derecha, derecha a izquierda, vuelta completa, vuelta completa. El ultimo golpe empuja.                        |
| X cargado            | Dash hacia adelante que golpea todo. Rompe armadura.                                                                       |
| X cargado sweet spot | Todo lo que toca el dash explota despues y les impulsa hacia arriba.                                                       |
| Y cargado            | Launcher. Area pequena/media.                                                                                              |
| Y cargado sweet spot | Golpe hacia arriba que sube a los enemigos un poco. Despues te elevas con otro Y. Aumenta un poco el AOE.                  |

## Aereo

| Input                | Descripcion                                                                                                                                                                        |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X X X                | Diagonal, diagonal, hacia abajo.                                                                                                                                                   |
| X espera X X         | Diagonal, doble vuelta con empuje hacia adelante. La primera vuelta te eleva un poco; el empuje final es un arco tuneable (`push`: velocidad + altura + cierre). *(2026-07-09)*    |
| X X espera X         | Diagonal, diagonal, plunge: tu y el enemigo golpeado caen juntos hasta el piso a velocidad constante. Cada cuerpo baja con su Mover DOWN del tuning (`plunge_player_mover` / `plunge_enemy_mover`, mismo speed). El enemigo se alinea a tu altura al conectar (si estaba arriba tuyo baja a tu Y) para dejar servido el rebote. El rebote en enemigo cancela el plunge; el doble salto no sale (ni se gasta) mientras dura. El plunge es reutilizable: `Player.plunge(MoverSettings)`. *(2026-07-21)* |
| X cargado            | Mismo dash que en el piso, pero en el aire.                                                                                                                                        |
| X cargado sweet spot | Igual que el terrestre. Las explosiones suben a los enemigos afectados como si fuera un launcher.                                                                                  |
| Y cargado            | **Desactivado por ahora** (ver Estado Godot): diseño es golpe hacia abajo que hace rebotar al enemigo (auto-lanza al jugador y spikea/rebota al enemigo hasta su altura), pero depende de `slam_bounce`, que espera el "bouncer" sin diseñar. Sostener Y en el aire cae al combo aereo normal. |
| Y cargado sweet spot | Diseño pendiente (doble rebote, el segundo sube mas a jugador y enemigos): no implementado, bloqueado por lo mismo que el Y cargado.                               |

## Autoridad vertical

`SwordTuning` contiene los perfiles `MoverSettings` de cada ruta vertical. Espada los solicita a
Player y EnemyBase; no escribe velocidad vertical ni llama verbos especializados. El plunge usa
Mover PARTIAL para Player y TOTAL para Enemy. El hop y los finishers tambien usan perfiles. El
rebote del Y cargado aereo esta desactivado.

## Estado Godot

- Implementada como arma procedural hasta H3.
- Los swings mueven la mano alrededor del jugador (ver Mano orbital en [[Combate]]); la hoja va rigida, apuntando hacia afuera. *(2026-07-09)*
- Tap X/Y usa la misma cadena de combo terrestre/aérea; solo el cargado bifurca por slot. *(2026-07-09)*
- `SwordTuning` controla ventanas, angulos, dash cargado, launcher y el `push` (arco del empuje armado por `arm_push`). *(2026-07-09)*
- Habilidad especial de X cargado existe parcialmente por ventana de kill.
- La hoja brilla al cargar un ataque (glow de carga, ver [[Combate]]). *(2026-07-06)*
- **Y cargado aereo DESACTIVADO temporalmente** *(2026-07-20)*: usa `slam_bounce` (rebote balistico
  del enemigo), un move del "bouncer" que todavia no existe. Hasta que se implemente el bouncer, el
  Y cargado en el aire cae al combo aereo normal (sin gastar barra). El codigo del move queda intacto.
  Ver [[Plan Autoridad Vertical]] F5.

### Tuneables de coreografia

| Knob | Que mueve |
|---|---|
| `thrust_reach` | Metros que el brazo extiende sobre `hand_radius` en el pico de la estocada. |
| `air_diagonal_yaw` | Diagonal aerea: cuanto cruza la mano por delante del jugador. |
| `air_diagonal_pitch` | Diagonal aerea: cuanto baja la mano al cruzar. Igualarlo al yaw da una diagonal a 45°. |
| `combo_swing_angle` | Arco de los swings 1-2 del combo terrestre. |
| `strike_angle` | Arco del golpe Y basico, launcher y cargada aerea. |
| `air_finisher_angle` | Arco del hachazo vertical del finisher aereo. |
| `air_finisher_hitbox_v_scale` | Estira verticalmente los hitboxes del finisher aereo (hachazo y plunge) mientras dura el golpe: alto de la hoja y disco aereo como capsula vertical. 1 = sin estirar. |
| `charged_fallback_angle` | Swing degradado del X cargado sin barra. |

### Perfiles Mover/Floater (feel vertical, `.tres`)

Cada ruta vertical de la Espada vive como recurso `MoverSettings`/`FloaterSettings` en
`sword_tuning.tres`, uno por cuerpo (ver [[Plan Autoridad Vertical]]):

| Recurso | Que hace |
|---|---|
| `ground_charged_y_player_mover` / `ground_charged_y_enemy_mover` | Launcher Y terrestre: Mover UP del jugador y del enemigo, cada uno con su Floater de hang en el tope. |
| `aerial_charged_y_player_mover` / `aerial_charged_y_enemy_spike_mover` | Y cargada aerea: auto-launch del jugador + spike lineal descendente del enemigo (corta al tocar piso). El rebote esta desactivado. |
| `sweet_spot_explosion_enemy_mover` | Lo que la explosion del sweet spot (X cargado) pide a cada enemigo antes de cobrar el dano. |
| `air_plunge_player_mover` / `air_plunge_enemy_mover` | Movers DOWN del plunge (X X espera X): mismo speed = bajan a la par; el del jugador es PARTIAL para conservar contactos. |
| `air_wait_spin_player_mover` | Hop PARTIAL de la primera vuelta de la rama aerea de espera. |
| `air_finisher_enemy_spike_mover` | Spike descendente del enemigo en el hachazo aereo normal (finisher). |
| `air_hit_enemy_floater` | Hold del ENEMIGO al conectarle un golpe aereo NORMAL: lo suspende con un Floater (`request_float`), simetrico al air-hit-float del jugador. Se renueva por golpe (`max`), asi queda pegado durante el combo y cae al dejar de golpearlo. Gate: enemigo aereo + quebrado. Excluye el cargado Y (que ya le da su propio spike). |

El X cargado (dash) no usa perfil Mover: sale por `Player.force_dash` con `charged_dash_distance` /
`charged_dash_duration`.

## Pendiente H1

- Tunear `sword_tuning.tres`.
- Validar que hold no dispare tap si se decide carga exclusiva.
- Confirmar dano distinto por golpes finales/cargados.
- Probar reset aereo por kill con [[Reset Aereo por Kill]].

## Relacionado

- [[Armas]]
- [[Combate]]
