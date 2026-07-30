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
| Tap adelante + X (lock-on) | Vueltas estaticas: no mueven al Player, no empujan al enemigo y nunca disparan proyectil en piso. RT gasta medio meter, activa el brillo y usa su cantidad de vueltas tuneable. |
| Tap atras + X (lock-on) | Animacion del launcher con golpe de hoja normal y retroceso del Player mediante `tap_back_x_player_mover`; no eleva ni mueve al enemigo. Si RT esta presionado al llegar X dentro de `tap_back_x_window`, gasta medio meter, el Mover usa el perfil RT mas rapido y dispara un proyectil al terminar. |
| Y cargado            | Launcher. Area pequena/media. Gasta 1 barra (con kill window, como el X cargado); sin barra cae al tap normal. *(2026-07-28: antes era gratis)* |
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
| Tap adelante + X (lock-on) | Vueltas con Floater y sin proyectil. RT + medio meter usa mas vueltas y Floaters RT propios para Player y Enemy. |
| Tap atras + X (lock-on) | Una vuelta y retroceso corto, sin proyectil. RT usa mas vueltas, retroceso largo y Floaters propios; al terminar dispara un proyectil con launcher aereo independiente. |
| Y cargado            | **Desactivado por ahora** (ver Estado Godot): diseño es golpe hacia abajo que hace rebotar al enemigo (auto-lanza al jugador y spikea/rebota al enemigo hasta su altura), pero depende de `slam_bounce`, que espera el "bouncer" sin diseñar. Sostener Y en el aire cae al combo aereo normal. |
| Tap atras + Y (lock-on) | Plunge sin barra: hachazo y, al cerrar el swing, Player y enemigo golpeado caen con `tap_back_y_air_player_mover` / `tap_back_y_air_enemy_mover`. En whiff el Player tambien cae. El tap se lee contra el eje jugador-objetivo y fija el facing al enemigo durante el hachazo. |
| Tap adelante + Y (lock-on) | Vuelta final, Mover de avance hacia el objetivo y push al enemigo, a diferencia de la variante terrestre. |
| Y cargado sweet spot | Diseño pendiente (doble rebote, el segundo sube mas a jugador y enemigos): no implementado, bloqueado por lo mismo que el Y cargado.                               |

## Estado Godot

- El swing procedural murio el 2026-07-30: el hitbox cuelga del hueso de la mano y el arco de
  cada golpe lo dibuja su `AttackClip`. Ver [[Contrato AttackClip]].
- Los swings mueven la mano alrededor del jugador (ver Mano orbital en [[Combate]]); la hoja va rigida, apuntando hacia afuera. *(2026-07-09)*
- Tap X/Y usa la misma cadena de combo terrestre/aérea; solo el cargado bifurca por slot. *(2026-07-09)*
- `SwordTuning` controla ventanas, angulos, dash cargado, launcher y el `push` (arco del empuje armado por `arm_push`). *(2026-07-09)*
- El launcher comun de la Espada fija el facing al target bloqueado y corta input/momentum horizontal durante el swing. Y cargado terrestre y sweet spot del X elevan tambien al Player. *(2026-07-24)*
- Los gestos `tap atras/adelante + Y` solo se arman desde input de movimiento neutral y consumen la primera direccion al salir de neutral. Girar el stick de forma continua no debe crear un especial al atravesar esas direcciones. *(2026-07-28)*
- Los cuatro gestos direccionales de X/Y, sus ventanas y sus rutas de suelo/aire se documentan en [[Taps Direccionales]].
- En Espada, el meter button (`meter_button`, RT — el mismo que carga el sprint, ver [[Meter]] > El meter button) combinado con `tap adelante/atras + X` cuesta `tap_x_meter_cost` y activa flash y valores mejorados. Los RT aereos tienen Floaters separados por ataque y cuerpo. Adelante X nunca dispara. Atras X dispara con RT; suelo y aire definen launchers independientes dentro de su ataque. *(2026-07-28)*
- Los taps de X pasaron a `AttackMovementProfile`: uno por variante, en vez de once campos sueltos mas siete ids de rutina que la Espada guardaba para reconectarlos en runtime. Un efecto lateral **deliberado**: los RT aereos, que antes dejaban al enemigo sin ningun hang (su slot propio estaba vacio y el `return` temprano salteaba el fallback), ahora caen al hold generico `air_hit_enemy_floater` de 0.2 s como el resto de los golpes aereos. Todo lo demas es 1:1. *(2026-07-29)*
- Mantener X despues de cualquier tap X direccional sigue cargando desde ese mismo press: la hoja muestra el progreso durante el tap, pero el cargado no se ejecuta hasta que hayan terminado tanto sus vueltas como su Mover. El float aereo de carga tambien espera ese cierre para no competir por la autoridad vertical. El flash RT usa un overlay HDR rojo-anaranjado sobre todas las mallas reales de `Visual`, igual que el brillo de [[Wall Slide y Wall Jump]]. *(2026-07-28)*
- El Sweet Spot del X cargado reduce su coste y encadena launcher al conectar; el Y cargado aun no consume ese flag. Ver [[Sweet Spots]].
- Habilidad especial de X cargado existe parcialmente por ventana de kill.
- La hoja brilla al cargar un ataque (glow de carga, ver [[Combate]]). *(2026-07-06)*
- **Y cargado aereo DESACTIVADO temporalmente** *(2026-07-20)*: usa `slam_bounce` (rebote balistico
  del enemigo), un move del "bouncer" que todavia no existe. Hasta que se implemente el bouncer, el
  Y cargado en el aire cae al combo aereo normal (sin gastar barra). El codigo del move queda intacto.
  Ver [[Plan Autoridad Vertical]] F5.

## Tuning

`SwordTuning` (instancia `data/sword_tuning.tres`) sigue la organizacion por tipo de ataque de [[Armas]]: categoria por familia, grupo por golpe, subgrupo por tramo y un campo por cuerpo. La Espada no escribe velocidad vertical ni llama verbos especializados: pide perfiles `MoverSettings`/`FloaterSettings` a Player y EnemyBase, que son los duenos de su fisica (ver [[Mover y Floater]]).

### Ataques normales (tap)

Las dos cadenas son **datos**: `ground_combo` y `air_combo` apuntan a `data/sword_ground_combo.tres` y `data/sword_air_combo.tres`, un `AttackSequence` cada uno. Ahi viven los pasos, sus clips, su dano, sus ramas y los Movers de cada beat. Ver [[Armas]] > Los combos tambien son datos. *(2026-07-30)*

| Knob / perfil | Que mueve |
|---|---|
| `ground_combo` | Cadena terrestre: 4 pasos (A, B, A, B), ventana de encadene `0.8`, rama tras el golpe 2 con umbral `0.2` que reemplaza los golpes 3-4 por dos vueltas, la ultima con `pushes`. |
| `air_combo` | Cadena aerea: 3 pasos (A, B, tramo de Heavy), paso de `0.2` s, ventana `0.45`, y DOS ramas — tras el golpe 1 a vueltas (la primera con el hop del Player), tras el golpe 2 al plunge. |
| `air_finisher_hitbox_v_scale` | Estira verticalmente los hitboxes del hachazo mientras dura el golpe: alto de la hoja y disco aereo como capsula. Aplica al finisher, al plunge y al tap atras + Y aereo, que comparten coreografia. |
| `air_hit_enemy_floater` | Hold del Enemy al conectarle un golpe aereo normal (`request_float`). Se renueva por golpe (`max`), asi queda pegado durante el combo y cae al dejar de golpearlo. Gate: enemigo aereo y quebrado. Excluye el cargado Y, que ya le da su propio spike. |

Los tres Movers del aereo que antes estaban sueltos aca —el hop de la primera vuelta, el spike del finisher y el plunge de los dos cuerpos— ahora viven dentro del `AttackMovementProfile` del paso que los emite, en `sword_air_combo.tres`. El spike y el plunge salen en `WINDOW_END`: arrancarlos durante el swing saca al objetivo del alcance del propio golpe.

> [!warning] Un paso = un golpe
> Cada paso abre su propia ventana de dano. Antes la cadena entera compartia una, asi que el combo de 4 cobraba **una vez**. Ahora cobra cuatro: el dano total de los dos combos se multiplico sin que se toque un solo numero. Se ajusta con `damage_scale` por paso. Pendiente de tunear jugando. *(2026-07-30)*

El hold simetrico del jugador, `air_hit_player_floater`, vive en `WeaponTuning`: es comun a todas las armas.

### Cargados (hold)

| Knob / perfil | Que mueve |
|---|---|
| `charged_dash_distance` / `charged_dash_duration` | Recorrido del X cargado. No usa perfil Mover: sale por `Player.force_dash`. |
| `charged_dash_damage` / `charged_dash_hit_radius` / `charged_dash_stun` | Hitbox propio del dash en la espada, separado del dash de movimiento del dodge. |
| `charged_dash_behind_offset` | Distancia de salida al otro lado del primer enemigo impactado, medida sobre la trayectoria del dash. |
| `charged_fallback_angle` | Swing degradado del X cargado sin barra. |
| `ground_charged_y_hitbox_duration` / `ground_charged_y_deals_damage` | Ventana activa y dano del launcher terrestre. |
| `ground_charged_y` | Perfil del launcher Y terrestre: Mover UP de cada cuerpo, cada uno con su Floater de hang en el tope. El del Enemy en `BEFORE_DAMAGE`, para que el Stun del mismo golpe ya lo vea en el aire. |
| `aerial_charged_y` | Perfil de la Y cargada aerea: auto-launch del Player y spike lineal descendente del Enemy en `ON_HIT`. Sin uso mientras el move este desactivado. |

### Taps direccionales

Ventanas en segundos; `0` desactiva el gesto. El contrato de input esta en [[Taps Direccionales]].

**Ningun especial lista ya Movers y Floaters sueltos, y la variante RT tampoco duplica el perfil.** Cada GESTO (gesto x tramo) tiene UN `AttackMovementProfile` con todo lo que le hace a la posicion de los cuerpos, y RT vive adentro como porcentajes sobre esa misma base. Debajo quedan los knobs de coreografia e input, que si conservan su valor propio para RT porque no son posicion. Ver [[Mover y Floater]] > Perfil de movimiento por ataque. *(2026-07-29)*

| Gesto | Perfil | Coreografia, input y dano RT |
|---|---|---|
| Tap adelante + X | `tap_forward_x_ground` · `tap_forward_x_air` | `tap_forward_x_window` · `tap_forward_x_spins` · `tap_forward_x_meter_spins` · `tap_forward_x_ground_meter_damage_bonus` · `tap_forward_x_air_meter_damage_bonus` |
| Tap atras + X | `tap_back_x_ground` · `tap_back_x_air` | `tap_back_x_window` · `tap_back_x_air_spins` · `tap_back_x_meter_air_spins` · `tap_back_x_ground_meter_damage_bonus` · `tap_back_x_air_meter_damage_bonus` |
| Tap adelante + Y | `tap_forward_y`, con `player_direction` en `PLAYER_FORWARD`. Al enemigo no lo mueve un Mover: en aire lo desplaza el `push`, por eso `enemy_travel` esta vacio. | `tap_forward_y_window` |
| Tap atras + Y | `tap_back_y_ground` (solo sube al Enemy, `BEFORE_DAMAGE`; el slot del Player queda vacio) · `tap_back_y_air` (plunge: los dos bajan en `WINDOW_END`, con `enemy_travel_aligns_y`) | `tap_back_y_window` |

Que hace RT en cada gesto de X, ya expresado como bonos:

| Gesto | Base | Con RT |
|---|---|---|
| Adelante X suelo | perfil en `null`: vueltas puras, no mueve a nadie | igual, solo mas vueltas |
| Adelante X aire | cuelga al Player y al Enemy que conecta | `rt_player_hang_bonus -100` (el Player no cuelga) y `rt_enemy_hang_bonus -33` |
| Atras X suelo | retrocede 3 m a 10 m/s | `+33%` distancia, `+80%` velocidad, `+100%` aceleracion, y dispara |
| Atras X aire | vueltas en el sitio, sin recorrido | `rt_only`: aparece el retroceso de 2 m, cuelga al cerrarlo y dispara |

Ademas, cada tramo tiene su **bono % de dano con RT**, hoy en `0` (RT pega igual, solo hace mas cosas). Vive en el tuning y no en el perfil porque el dano no es posicion: ver [[Armas]] > La variante RT es un porcentaje. El bono escala el `1.0` base del hitbox y lo limpia la entrada del ataque siguiente — por eso la Espada ahora llama `reset_hit_profile()` en sus siete entradas de ataque, como ya hacia el [[Mazo]]. Sin eso, un tap RT dejaba el combo posterior pegando de mas. *(2026-07-29)*

El vuelo, dano y visual del proyectil siguen compartidos bajo `tap_x_meter_projectile_*`, pero cada perfil que dispara trae su propio launcher (`rt_projectile_enemy_mover`), a mano y sin porcentajes: es el unico Mover del perfil que no le pertenece al Player. Un launcher en `null` conserva el proyectil y desactiva solo su elevacion.

Los taps de Y y los cargados de Y tambien migraron: el Resource sumo `enemy_travel` con su eje `enemy_travel_at` (tres momentos) y `enemy_travel_aligns_y`. El unico especial sin perfil es el **X cargado**, que mueve con `force_dash`; el porque esta en [[Armas]] > Todos los especiales llevan perfil. *(2026-07-29)*

Los combos tambien tienen perfil, uno por paso: un `AttackStep` lleva su propio `AttackMovementProfile`, asi que el beat de la cadena en el que sale un Mover dejo de ser codigo. *(2026-07-30)*

## Pendiente H1

- **Correr la verificacion headless de los tres refactors de perfiles** (`--import`, `--quit-after 2` y los dos smokes): quedaron commiteados sin verificar. *(2026-07-29)*
- Tunear los bonos de RT jugando. Los cinco slots vacios que quedaban desaparecieron al pasar RT a porcentajes —"sin RT no hace nada" ahora es un valor y no un hueco—, pero los bonos actuales son la traduccion literal de los perfiles viejos, no una decision de feel.
- Tunear `sword_tuning.tres`.
- Validar que hold no dispare tap si se decide carga exclusiva.
- Confirmar dano distinto por golpes finales/cargados.
- Probar reset aereo por kill con [[Reset Aereo por Kill]].

## Relacionado

- [[Armas]]
- [[Combate]]
