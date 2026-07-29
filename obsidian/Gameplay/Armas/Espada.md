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
| X cargado            | Dash recto. Al primer enemigo impactado lo atraviesas y apareces al otro lado, segun la direccion del dash; entonces termina. Rompe armadura. |
| X cargado sweet spot | Tras atravesar al primer enemigo, ejecuta un launcher sin gastar otra barra. |
| Tap adelante + X (lock-on) | Dos vueltas de `X X espera X X`, estaticas: no mueven al Player ni empujan al enemigo. X debe llegar dentro de `tap_forward_x_window`. |
| Tap atras + X (lock-on) | Animacion del launcher con golpe de hoja normal y retroceso del Player mediante `tap_back_x_player_mover`; no eleva ni mueve al enemigo. X debe llegar dentro de `tap_back_x_window`. |
| Y cargado            | Launcher. Area pequena/media.                                                                                              |
| Tap atras + Y (lock-on) | Launcher sin gastar barra que eleva solo al enemigo con `tap_back_y_enemy_mover`. "Atras" se calcula alejandose del objetivo lockeado y Y debe llegar dentro de `tap_back_y_window`; al iniciar, el Player vuelve a encarar al objetivo y limpia su momentum horizontal. |
| Tap adelante + Y (lock-on) | Vuelta final de `X X espera X X`: avanza al Player con `tap_forward_y_player_mover` hacia el objetivo bloqueado, sin empujar al enemigo. Y debe llegar dentro de `tap_forward_y_window`. |
| Y cargado sweet spot | Golpe hacia arriba que sube a los enemigos un poco. Despues te elevas con otro Y. Aumenta un poco el AOE.                  |

## Aereo

| Input                | Descripcion                                                                                                                                                                        |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X X X                | Diagonal, diagonal, hacia abajo.                                                                                                                                                   |
| X espera X X         | Diagonal, doble vuelta con empuje hacia adelante. La primera vuelta te eleva un poco; el empuje final es un arco tuneable (`push`: velocidad + altura + cierre). *(2026-07-09)*    |
| X X espera X         | Diagonal, diagonal, plunge: tu y el enemigo golpeado caen juntos hasta el piso a velocidad constante. Cada cuerpo baja con su Mover DOWN del tuning (`plunge_player_mover` / `plunge_enemy_mover`, mismo speed). El enemigo se alinea a tu altura al conectar (si estaba arriba tuyo baja a tu Y) para dejar servido el rebote. El rebote en enemigo cancela el plunge; el doble salto no sale (ni se gasta) mientras dura. El plunge es reutilizable: `Player.plunge(MoverSettings)`. *(2026-07-21)* |
| X cargado            | Con lock-on, dash 3D hacia el objetivo aunque este arriba o abajo; sin lock-on, dash recto. Al primer impacto lo atraviesas y apareces al otro lado de la trayectoria. |
| X cargado sweet spot | Igual que el terrestre: tras atravesar al objetivo, activa el launcher sin gasto extra. |
| Tap adelante + X (lock-on) | Dos vueltas estaticas con Floater de gravedad 0 para Player y enemigos conectados. |
| Tap atras + X (lock-on) | Una vuelta y Movers UP para Player y enemigos conectados, cada uno con su distancia; ambos terminan en hang con gravedad 0. |
| Y cargado            | **Desactivado por ahora** (ver Estado Godot): diseño es golpe hacia abajo que hace rebotar al enemigo (auto-lanza al jugador y spikea/rebota al enemigo hasta su altura), pero depende de `slam_bounce`, que espera el "bouncer" sin diseñar. Sostener Y en el aire cae al combo aereo normal. |
| Tap atras + Y (lock-on) | Plunge sin barra: hachazo y, al cerrar el swing, Player y enemigo golpeado caen con `tap_back_y_air_player_mover` / `tap_back_y_air_enemy_mover`. En whiff el Player tambien cae. El tap se lee contra el eje jugador-objetivo y fija el facing al enemigo durante el hachazo. |
| Tap adelante + Y (lock-on) | Vuelta final, Mover de avance hacia el objetivo y push al enemigo, a diferencia de la variante terrestre. |
| Y cargado sweet spot | Diseño pendiente (doble rebote, el segundo sube mas a jugador y enemigos): no implementado, bloqueado por lo mismo que el Y cargado.                               |

## Estado Godot

- Implementada como arma procedural hasta H3.
- Los swings mueven la mano alrededor del jugador (ver Mano orbital en [[Combate]]); la hoja va rigida, apuntando hacia afuera. *(2026-07-09)*
- Tap X/Y usa la misma cadena de combo terrestre/aérea; solo el cargado bifurca por slot. *(2026-07-09)*
- `SwordTuning` controla ventanas, angulos, dash cargado, launcher y el `push` (arco del empuje armado por `arm_push`). *(2026-07-09)*
- El launcher comun de la Espada fija el facing al target bloqueado y corta input/momentum horizontal durante el swing. Y cargado terrestre y sweet spot del X elevan tambien al Player. *(2026-07-24)*
- Los gestos `tap atras/adelante + Y` solo se arman desde input de movimiento neutral y consumen la primera direccion al salir de neutral. Girar el stick de forma continua no debe crear un especial al atravesar esas direcciones. *(2026-07-28)*
- Los cuatro gestos direccionales de X/Y, sus ventanas y sus rutas de suelo/aire se documentan en [[Taps Direccionales]].
- El Sweet Spot del X cargado reduce su coste y encadena launcher al conectar; el Y cargado aun no consume ese flag. Ver [[Sweet Spots]].
- Habilidad especial de X cargado existe parcialmente por ventana de kill.
- La hoja brilla al cargar un ataque (glow de carga, ver [[Combate]]). *(2026-07-06)*
- **Y cargado aereo DESACTIVADO temporalmente** *(2026-07-20)*: usa `slam_bounce` (rebote balistico
  del enemigo), un move del "bouncer" que todavia no existe. Hasta que se implemente el bouncer, el
  Y cargado en el aire cae al combo aereo normal (sin gastar barra). El codigo del move queda intacto.
  Ver [[Plan Autoridad Vertical]] F5.

## Tuning

`SwordTuning` (instancia `data/sword_tuning.tres`) sigue la organizacion por tipo de ataque de [[Armas]]: categoria por familia, grupo por golpe, subgrupo por tramo y un campo por cuerpo. La Espada no escribe velocidad vertical ni llama verbos especializados: pide perfiles `MoverSettings`/`FloaterSettings` a Player y EnemyBase, que son los duenos de su fisica (ver [[Mover y Floater]]).

### Comun a varios golpes

| Knob | Que mueve |
|---|---|
| `strike_angle` | Arco del golpe Y basico. Lo comparten el launcher terrestre, la Y cargada aerea y el tap atras + X. |

### Ataques normales (tap)

| Knob / perfil | Que mueve |
|---|---|
| `combo_window` | Segundos para encadenar el siguiente golpe del combo terrestre. |
| `ground_wait_branch_threshold` | Espera minima que convierte los golpes 3-4 de estocadas a vueltas. |
| `combo_swing_angle` | Arco de los swings 1-2 del combo terrestre. |
| `thrust_reach` | Metros que el brazo extiende sobre `hand_radius` en el pico de la estocada. |
| `air_diagonal_yaw` / `air_diagonal_pitch` | Diagonal aerea: cuanto cruza la mano por delante y cuanto baja al cruzar. Igualarlos da una diagonal a 45°. |
| `air_finisher_angle` | Arco del hachazo vertical del finisher aereo. |
| `air_finisher_hitbox_v_scale` | Estira verticalmente los hitboxes del hachazo mientras dura el golpe: alto de la hoja y disco aereo como capsula. 1 = sin estirar. Aplica al finisher, al plunge y al tap atras + Y aereo, que comparten coreografia. |
| `air_finisher_enemy_spike_mover` | Spike descendente del Enemy al cerrar el hachazo `X X X`. El Player sigue su caida normal. |
| `air_wait_spin_player_mover` | Hop PARTIAL del Player en la primera vuelta de la rama espera. |
| `air_plunge_player_mover` / `air_plunge_enemy_mover` | Plunge de `X X espera X`: mismo speed = bajan a la par; el del Player es PARTIAL para conservar contactos. |
| `air_hit_enemy_floater` | Hold del Enemy al conectarle un golpe aereo normal (`request_float`). Se renueva por golpe (`max`), asi queda pegado durante el combo y cae al dejar de golpearlo. Gate: enemigo aereo y quebrado. Excluye el cargado Y, que ya le da su propio spike. |

El hold simetrico del jugador, `air_hit_player_floater`, vive en `WeaponTuning`: es comun a todas las armas.

### Cargados (hold)

| Knob / perfil | Que mueve |
|---|---|
| `charged_dash_distance` / `charged_dash_duration` | Recorrido del X cargado. No usa perfil Mover: sale por `Player.force_dash`. |
| `charged_dash_damage` / `charged_dash_hit_radius` / `charged_dash_stun` | Hitbox propio del dash en la espada, separado del dash de movimiento del dodge. |
| `charged_dash_behind_offset` | Distancia de salida al otro lado del primer enemigo impactado, medida sobre la trayectoria del dash. |
| `charged_fallback_angle` | Swing degradado del X cargado sin barra. |
| `ground_charged_y_hitbox_duration` / `ground_charged_y_deals_damage` | Ventana activa y dano del launcher terrestre. |
| `ground_charged_y_player_mover` / `ground_charged_y_enemy_mover` | Launcher Y terrestre: Mover UP de cada cuerpo, cada uno con su Floater de hang en el tope. |
| `aerial_charged_y_player_mover` / `aerial_charged_y_enemy_spike_mover` | Y cargada aerea: auto-launch del Player y spike lineal descendente del Enemy. Sin uso mientras el move este desactivado. |

### Taps direccionales

Ventanas en segundos; `0` desactiva el gesto. El contrato de input esta en [[Taps Direccionales]].

| Gesto | Ventana | Perfiles |
|---|---|---|
| Tap adelante + X | `tap_forward_x_window` | Aire: `tap_forward_x_air_floater`, el mismo perfil para el Player y para cada enemigo conectado. En suelo la vuelta es estatica y no pide perfil. |
| Tap atras + X | `tap_back_x_window` | Suelo: `tap_back_x_player_mover`, clonado y orientado en sentido opuesto al target. Aire: `tap_back_x_air_player_mover` / `tap_back_x_air_enemy_mover`. |
| Tap adelante + Y | `tap_forward_y_window` | `tap_forward_y_player_mover` en suelo y aire, clonado y orientado hacia el target. Al enemigo no lo mueve un Mover: en aire lo desplaza el `push`. |
| Tap atras + Y | `tap_back_y_window` | Suelo: `tap_back_y_enemy_mover`; el Player no se mueve, por eso no tiene perfil. Aire: `tap_back_y_air_player_mover` / `tap_back_y_air_enemy_mover`. |

## Pendiente H1

- Tunear `sword_tuning.tres`.
- Validar que hold no dispare tap si se decide carga exclusiva.
- Confirmar dano distinto por golpes finales/cargados.
- Probar reset aereo por kill con [[Reset Aereo por Kill]].

## Relacionado

- [[Armas]]
- [[Combate]]
