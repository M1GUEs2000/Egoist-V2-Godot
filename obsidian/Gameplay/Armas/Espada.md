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
| X X X X              | Swing horizontal, swing horizontal, estocada, estocada. |
| X X espera X X       | Izquierda a derecha, derecha a izquierda, vuelta completa, vuelta completa. El ultimo golpe empuja.                        |
| X cargado            | Dash recto. Al primer enemigo impactado lo atraviesas y apareces al otro lado, segun la direccion del dash; entonces termina. Rompe armadura. |
| X cargado sweet spot | Tras atravesar al primer enemigo, ejecuta un launcher sin gastar otra barra. |
| Tap adelante + X (lock-on) | Vueltas estaticas: no mueven al Player, no empujan al enemigo y nunca disparan proyectil en piso. RT gasta medio meter, activa el brillo y repite la vuelta mas veces. |
| Tap atras + X (lock-on) | Animacion del launcher con golpe de hoja normal y retroceso del Player; no eleva ni mueve al enemigo. Si RT esta presionado al llegar X dentro de `tap_back_x_window`, gasta medio meter, el retroceso sale mas lejos y mas rapido, y dispara un proyectil al terminar. |
| Y cargado            | Launcher. Area pequena/media. Gasta 1 barra (con kill window, como el X cargado); sin barra cae al tap normal. *(2026-07-28: antes era gratis)* |
| Tap atras + Y (lock-on) | Launcher sin gastar barra que eleva solo al enemigo. "Atras" se calcula alejandose del objetivo lockeado y Y debe llegar dentro de `tap_back_y_window`; al iniciar, el Player vuelve a encarar al objetivo y limpia su momentum horizontal. |
| Tap adelante + Y (lock-on) | Vuelta final de `X X espera X X`: avanza al Player hacia el objetivo bloqueado, sin empujar al enemigo. Y debe llegar dentro de `tap_forward_y_window`. |
| Y cargado sweet spot | Golpe hacia arriba que sube a los enemigos un poco. Despues te elevas con otro Y. Aumenta un poco el AOE.                  |

## Aereo

| Input                | Descripcion                                                                                                                                                                        |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X X X                | Diagonal, diagonal, hacia abajo.                                                                                                                                                   |
| X espera X X         | Diagonal, doble vuelta con empuje hacia adelante. La primera vuelta te eleva un poco; el empuje final es un arco tuneable (`push`: velocidad + altura + cierre). *(2026-07-09)*    |
| X X espera X         | Diagonal, diagonal, plunge: tu y el enemigo golpeado caen juntos hasta el piso a velocidad constante. Cada cuerpo baja con su Mover DOWN, declarado en el perfil del paso. El enemigo se alinea a tu altura al conectar (si estaba arriba tuyo baja a tu Y) para dejar servido el rebote. El rebote en enemigo cancela el plunge; el doble salto no sale (ni se gasta) mientras dura. |
| X cargado            | Con lock-on, dash 3D hacia el objetivo aunque este arriba o abajo; sin lock-on, dash recto. Al primer impacto lo atraviesas y apareces al otro lado de la trayectoria. |
| X cargado sweet spot | Igual que el terrestre: tras atravesar al objetivo, activa el launcher sin gasto extra. |
| Tap adelante + X (lock-on) | Vueltas con Floater y sin proyectil. RT + medio meter usa mas vueltas y Floaters RT propios para Player y Enemy. |
| Tap atras + X (lock-on) | Una vuelta y retroceso corto, sin proyectil. RT usa mas vueltas, retroceso largo y Floaters propios; al terminar dispara un proyectil con launcher aereo independiente. |
| Y cargado            | Tres golpes seguidos con las animaciones del combo aereo, y un remate que saca al enemigo en diagonal hacia abajo (30 grados, alejandose del jugador). Gasta 1 barra; sin barra cae al combo aereo normal. *(2026-07-30: antes era el rebote bloqueado por el "bouncer")* |
| Tap atras + Y (lock-on) | Plunge sin barra: hachazo y, al cerrar el swing, Player y enemigo golpeado caen juntos. En whiff el Player tambien cae. El tap se lee contra el eje jugador-objetivo y fija el facing al enemigo durante el hachazo. |
| Tap adelante + Y (lock-on) | Vuelta final, Mover de avance hacia el objetivo y push al enemigo, a diferencia de la variante terrestre. |
| Y cargado sweet spot | Los dos primeros golpes van repetidos (A B A B) y despues entra el MISMO remate en diagonal: cinco golpes en vez de tres. Cuesta lo mismo que la version normal — el premio es el largo del gesto, no un final distinto. *(2026-07-30: antes era el doble rebote bloqueado por el "bouncer")* |

## Estado Godot

- **Casi todo el arma son datos.** Los dos combos, los cuatro taps direccionales y los cargados X/Y
  corren por el runner de secuencias (`WeaponBase.run_attack_sequence`): cada uno es
  un `AttackSequence` en su propio `.tres`. En `sword.gd` queda solo lo que no es dato — si el gesto
  cuesta barra, si exige estar en el aire, encarar al objetivo, los locks de facing/movimiento y el
  fallback sin barra. Ver [[Armas]] > Los combos tambien son datos. *(2026-07-30)*
- El hitbox cuelga del hueso de la mano y el arco de cada golpe lo dibuja su `AttackClip`; el swing
  procedural ya no existe. Ver [[Contrato AttackClip]].
- Tap X/Y usa la misma cadena de combo terrestre/aerea; solo el cargado bifurca por slot.
- El launcher comun de la Espada fija el facing al target bloqueado y corta input/momentum horizontal durante el swing. Y cargado terrestre y sweet spot del X elevan tambien al Player.
- Los gestos `tap atras/adelante + Y` solo se arman desde input de movimiento neutral y consumen la primera direccion al salir de neutral. Girar el stick de forma continua no debe crear un especial al atravesar esas direcciones.
- Los cuatro gestos direccionales de X/Y, sus ventanas y sus rutas de suelo/aire se documentan en [[Taps Direccionales]].
- El meter button (`meter_button`, RT — el mismo que carga el sprint, ver [[Meter]] > El meter button) combinado con `tap adelante/atras + X` cuesta `tap_x_meter_cost` y activa flash y valores mejorados. Adelante X nunca dispara; atras X dispara con RT, y suelo y aire definen launchers independientes.
- Mantener X despues de cualquier tap X direccional sigue cargando desde ese mismo press: la hoja muestra el progreso durante el tap, pero el cargado no se ejecuta hasta que hayan terminado tanto sus vueltas como su Mover. El float aereo de carga tambien espera ese cierre para no competir por la autoridad vertical. El flash RT usa un overlay HDR rojo-anaranjado sobre todas las mallas reales de `Visual`, y su duracion la calcula la propia secuencia (`automatic_sequence_duration`), asi que cambiar pasos o repeticiones no lo desincroniza.
- El Sweet Spot del X cargado reduce su coste y encadena launcher al conectar. Ver [[Sweet Spots]].
- Habilidad especial de X cargado existe parcialmente por ventana de kill.
- La hoja brilla al cargar un ataque (glow de carga, ver [[Combate]]).
- **Y cargado aereo: tres golpes que rematan en diagonal.** `AttackSequence` con `auto_chain`
  (`sword_air_charged_y.tres`): los tres pasos salen solos, reusan las animaciones del combo aereo
  (Regular_A, Regular_B, el tramo 2.4-2.7 de Heavy_Combo) y el ultimo saca al enemigo con un Mover
  propio, 30 grados por debajo de la horizontal y alejandose del Player. El Player no se mueve en
  ningun paso. Soltada dentro del sweet spot repite los dos primeros golpes antes del remate
  (`sword_air_charged_y_sweet.tres`, cinco golpes) y no cambia de precio: el remate es literalmente
  el mismo recurso (`sword_air_charged_y_knock.tres`), compartido por las dos.

## Tuning

`SwordTuning` (instancia `data/sword_tuning.tres`) sigue la organizacion por tipo de ataque de [[Armas]]: categoria por familia, grupo por golpe, subgrupo por tramo y un campo por cuerpo. La Espada no escribe velocidad vertical ni llama verbos especializados: pide perfiles `MoverSettings`/`FloaterSettings` a Player y EnemyBase, que son los duenos de su fisica (ver [[Mover y Floater]]).

### Ataques normales (tap)

Las dos cadenas son **datos**: `ground_combo` y `air_combo` apuntan a `data/sword_ground_combo.tres` y `data/sword_air_combo.tres`, un `AttackSequence` cada uno. Ahi viven los pasos, sus clips, su dano, sus ramas y los Movers de cada beat. Ver [[Armas]] > Los combos tambien son datos. *(2026-07-30)*

| Knob / perfil | Que mueve |
|---|---|
| `ground_combo` | Cadena terrestre: 4 pasos (A, B, A, B), ventana de encadene `0.8`, rama tras el golpe 2 con umbral `0.2` que reemplaza los golpes 3-4 por dos vueltas, la ultima con `pushes`. |
| `air_combo` | Cadena aerea: 3 pasos (A, B, tramo de Heavy), paso de `0.2` s, ventana `0.45`, y DOS ramas — tras el golpe 1 a vueltas (la primera con el hop del Player), tras el golpe 2 al plunge. |
| `air_finisher_hitbox_v_scale` | Estira verticalmente los hitboxes del hachazo mientras dura el golpe: alto de la hoja y disco aereo como capsula. Aplica al finisher, al plunge y al tap atras + Y aereo, que comparten coreografia. |
| `air_hit_enemy_floater` | Hold del Enemy al conectarle un golpe aereo normal (`request_float`). Se renueva por golpe (`max`), asi queda pegado durante el combo y cae al dejar de golpearlo. Gate: enemigo aereo y quebrado. No se aplica al golpe que ya esta sacando al enemigo (perfil con `enemy_travel` en `ON_HIT`), porque el Floater le pelearia al Mover; un recorrido en `WINDOW_END` si lo recibe, y de hecho lo necesita. |

Los tres Movers del aereo que antes estaban sueltos aca —el hop de la primera vuelta, el spike del finisher y el plunge de los dos cuerpos— ahora viven dentro del `AttackMovementProfile` del paso que los emite, en `sword_air_combo.tres`. El spike y el plunge salen en `WINDOW_END`: arrancarlos durante el swing saca al objetivo del alcance del propio golpe.

> [!warning] Un paso = un golpe
> Cada paso abre su propia ventana de dano. Antes la cadena entera compartia una, asi que el combo de 4 cobraba **una vez**. Ahora cobra cuatro: el dano total de los dos combos se multiplico sin que se toque un solo numero. Se ajusta con `damage_scale` por paso. Pendiente de tunear jugando. *(2026-07-30)*

El hold simetrico del jugador, `air_hit_player_floater`, vive en `WeaponTuning`: es comun a todas las armas.

### Cargados (hold)

| Knob / perfil | Que mueve |
|---|---|
| `charged_x_dash_sequence` | El X cargado entero: un paso, con el clip que declara cuando abre y cierra su hitbox y el `AttackMovementProfile` del recorrido. El dano no sale de la hoja sino del `ChargedDashHitbox`, y el sweet spot aereo con lock-on reapunta el Mover en 3D al objetivo. |
| `charged_dash_damage` / `charged_dash_hit_radius` / `charged_dash_stun` | Hitbox propio del dash en la espada, separado del dash de movimiento del dodge. |
| `charged_dash_behind_offset` | Distancia de salida al otro lado del primer enemigo impactado, medida sobre la trayectoria del dash. |
| `ground_charged_y_sequence` | La Y cargada terrestre como secuencia de un paso: el `AttackClip` declara el recorte de `Sword_Launcher` y su ventana; el paso usa `VerticalHitbox` y su perfil sube a ambos cuerpos, con Enemy en `BEFORE_DAMAGE`. |
| `ground_charged_y_deals_damage` | Si el `VerticalHitbox` del launcher terrestre cobra daño además de elevar. |
| `aerial_charged_y_sequence` | La Y cargada aerea entera como datos: tres pasos con `auto_chain`, y el Mover diagonal del Enemy dentro del perfil del ultimo. Reemplazo del perfil suelto `aerial_charged_y`. |
| `aerial_charged_y_sweet_sequence` | La misma Y cargada aerea soltada en la ventana de sweet spot: cinco pasos (A B A B + remate). null = el sweet spot no cambia nada y sale la version normal. |

### Taps direccionales

Ventanas en segundos; `0` desactiva el gesto. El contrato de input esta en [[Taps Direccionales]].

**Cada gesto (gesto x tramo) es una `AttackSequence` propia, salvo el tap atras + Y terrestre.** Adentro de cada paso viven el clip, el `AttackMovementProfile` con todo lo que el golpe le hace a la posicion de los cuerpos, y las vueltas como `repeat` / `repeat_with_meter`. RT vive dentro del perfil como porcentajes sobre esa misma base. Debajo del gesto quedan los knobs de coreografia e input, que si conservan su valor propio para RT porque no son posicion. Ver [[Mover y Floater]] > Perfil de movimiento por ataque.

| Gesto | Secuencia | Coreografia, input y dano RT |
|---|---|---|
| Tap adelante + X | `tap_forward_x_ground_sequence` · `tap_forward_x_air_sequence` | `tap_forward_x_window` · `tap_forward_x_ground_meter_damage_bonus` · `tap_forward_x_air_meter_damage_bonus` |
| Tap atras + X | `tap_back_x_ground_sequence` · `tap_back_x_air_sequence` | `tap_back_x_window` · `tap_back_x_ground_meter_damage_bonus` · `tap_back_x_air_meter_damage_bonus` |
| Tap adelante + Y | `tap_forward_y_ground_sequence` · `tap_forward_y_air_sequence`. Van partidas por tramo porque el empujon al enemigo (`enemy_push` del perfil) solo sale en aire; con una sola secuencia habria empujado tambien en piso. | `tap_forward_y_window` |
| Tap atras + Y | SUELO: `tap_back_y_ground`, perfil suelto y no secuencia; sigue usando la ventana vertical legacy porque el gesto comparte el golpe pero no la secuencia del cargado. Sube al Enemy en `BEFORE_DAMAGE`; el slot del Player queda vacio. AIRE: `tap_back_y_air_sequence` (plunge: los dos bajan en `WINDOW_END`, con `enemy_travel_aligns_y`). | `tap_back_y_window` · `tap_back_y_ground_hitbox_duration` |

> [!info] Las vueltas son repeticiones del paso, no un `int`
> `tap_forward_x_spins` y familia dejaron de existir: cada vuelta es una repeticion del paso
> (`AttackStep.repeat`, y `repeat_with_meter` para RT), o sea su propia ventana de dano y su propio
> `register_hit`. Un paso con `repeat = 0` y `repeat_with_meter` mayor es como se declara un golpe
> que solo existe pagando barra. La repeticion es una copia literal: si la primera vuelta tiene que
> desplazarte y las otras no, eso son dos pasos, no un campo.

Que hace RT en cada gesto de X, ya expresado como bonos:

| Gesto | Base | Con RT |
|---|---|---|
| Adelante X suelo | perfil en `null`: vueltas puras, no mueve a nadie | igual, solo mas vueltas |
| Adelante X aire | cuelga al Player y al Enemy que conecta | `rt_player_hang_bonus -100` (el Player no cuelga) y `rt_enemy_hang_bonus -33` |
| Atras X suelo | retrocede 3 m a 10 m/s | `+33%` distancia, `+80%` velocidad, `+100%` aceleracion, y dispara |
| Atras X aire | vueltas en el sitio, sin recorrido | `rt_only`: aparece el retroceso de 2 m, cuelga al cerrarlo y dispara |

Ademas, cada tramo tiene su **bono % de dano con RT**, hoy en `0` (RT pega igual, solo hace mas cosas). Vive en el tuning y no en el perfil porque el dano no es posicion: ver [[Armas]] > La variante RT es un porcentaje. El bono escala el `1.0` base del hitbox y lo limpia la entrada del ataque siguiente, por eso la Espada llama `reset_hit_profile()` en todas sus entradas de ataque.

El vuelo, dano y visual del proyectil siguen compartidos bajo `tap_x_meter_projectile_*`, pero el disparo es un beat de la secuencia (`AttackStep.fires_projectile`) y no el cierre de un recorrido: asi se puede declarar "sale en el segundo golpe de los tres que agrega RT". El launcher que aplica al impactar sigue en el perfil del paso (`rt_projectile_enemy_mover`), a mano y sin porcentajes — es el unico Mover que no le pertenece a ninguno de los dos cuerpos del swing. Un launcher en `null` conserva el proyectil y desactiva solo su elevacion.

## Pendiente H1

- Tunear los bonos de RT jugando: son la traduccion literal de los perfiles viejos, no una decision de feel.
- Re-tunear el dano de todo gesto de mas de un paso con `damage_scale`. Al pasar a "un paso = un golpe" el dano de cada cadena se multiplico por su cantidad de golpes.
- Tunear `sword_tuning.tres`.
- Validar que hold no dispare tap si se decide carga exclusiva.
- Confirmar dano distinto por golpes finales/cargados.
- Probar reset aereo por kill con [[Reset Aereo por Kill]].

## Relacionado

- [[Armas]]
- [[Combate]]
