---
title: Mover y Floater
tags:
  - egoist
  - gameplay
  - sistema
  - combate
  - movimiento
status: active
system_status: E2
hito: H1
---

# Mover y Floater

`Floater` y `Mover` son las primitivas de control dirigido del combate. Un ataque decide el perfil que necesita; el cuerpo que recibe la orden lo ejecuta. Esta separacion evita que Espada, Mazo, Brazo y enemigos inventen su propia gravedad, timers o movimiento por frame.

## Regla central

- El ataque es dueno de la intencion y del tuning: define `MoverSettings` o `FloaterSettings` en su recurso.
- `Player` y `EnemyBase` son duenos de su fisica: instancian ambos componentes, aplican el resultado en su loop y deciden sus gates de estado.
- Cada componente solo controla a su propio cuerpo. Un movimiento para Player y Enemy requiere dos solicitudes y, normalmente, dos perfiles distintos.
- No mezclar estos movimientos con `push`, `slam_arc` o rebotes balisticos: esas rutas conservan trayectoria balistica propia hasta que exista el bouncer planeado.

## Floater

`combat/floater.gd` controla una suspension temporal. No recorre una distancia ni guarda velocidad para restaurarla despues: durante su ventana aplica la gravedad multiplicada por `fall_scale` y, al vencer, el cuerpo vuelve a su gravedad normal.

| Dato | Efecto |
|---|---|
| `FloaterSettings.duration` | Segundos de suspension. `0` desactiva la solicitud. |
| `FloaterSettings.fall_scale` | `0` fija la vertical en `0`; `1` deja gravedad normal; un valor intermedio deja caer lentamente. |
| Solicitudes repetidas | Conserva el vencimiento mas lejano y el ultimo `fall_scale` pedido. |

### Pedir un Floater

El perfil vive junto al ataque. Para el Player se pide mediante su API publica:

```gdscript
var hold := tuning.tap_forward_x_air_floater
if hold != null:
    _player.request_float(hold.duration, hold.fall_scale)
```

Para un Enemy, el ataque debe hacerlo despues de que el enemigo sea un receptor valido de control vertical. `EnemyBase.request_float(...)` protege esa regla con el gate de poise/stun:

```gdscript
if target is EnemyBase:
    (target as EnemyBase).request_float(hold.duration, hold.fall_scale)
```

### Ejemplos vigentes

- `WeaponBase._register_air_hit_float()` usa `WeaponTuning.air_hit_player_floater` al conectar un golpe aereo normal.
- `Sword._run_forward_x_static_spin()` usa `tap_forward_x_air_floater`: dos vueltas y hang para Player y objetivos conectados.
- `PlayerDash._on_dash_hit()` usa `PlayerTuning.dash_air_hit_floater` cuando el dash ofensivo conecta en el aire.
- `PlayerArm` aplica `ArmTuning.air_enemy_floater` al enemigo que conecta en aire.
- Un `MoverSettings` tambien puede terminar en Floater con `float_duration` y `float_fall_scale`; es la forma correcta de encadenar viaje y hang.

### Reglas de autoridad

- En Player, `request_float` no actua en piso ni mientras un dash es dueno de la vertical. Cancela el salto en curso y fija la vertical inicial en cero para que el hang sea legible.
- Un salto, wall jump o rebote de enemigo cancela el Floater. Tambien lo cancelan stun, dash, Mover nuevo y movimiento de locomocion que toma autoridad.
- En Enemy, un Floater no puede levantar ni sostener a alguien con poise intacto: requiere stun, ragdoll o que el golpe haya quebrado la reserva.

## Mover

`combat/mover.gd` recorre una direccion con distancia, velocidad, aceleracion y condiciones de corte. El componente normaliza la direccion, recorta el ultimo frame para llegar a la distancia exacta y emite `mover_finished` o `mover_cancelled`.

| Dato de `MoverSettings` | Efecto |
|---|---|
| `direction` | Direccion del viaje, normalizada al iniciar. |
| `distance` | Metros maximos. Es el limite duro de seguridad. |
| `speed`, `acceleration` | Velocidad inicial y cambio en m/s2. |
| `stop_on` | Flags de distancia, piso, pared o enemigo. La deteccion de `ENEMY` aun no esta implementada. |
| `mode` | `TOTAL` toma el cuerpo completo; `PARTIAL` controla solo Y del Player. |
| `float_duration`, `float_fall_scale` | Floater solicitado al finalizar correctamente. |

### TOTAL y PARTIAL

- `TOTAL`: el Mover escribe `velocity`, llama `move_and_slide()` y reemplaza locomocion/gravedad durante el recorrido. Usarlo para launchers, desplazamientos verticales del enemigo y trayectorias dirigidas completas.
- `PARTIAL`: el Mover solo escribe la velocidad vertical dentro del tick normal del Player. Conserva input horizontal, contactos, wall slide, dash y rebote de enemigo. Usarlo para un plunge o hop estrictamente vertical; no para diagonales u horizontales.

### Pedir un Mover

```gdscript
var profile := tuning.air_plunge_player_mover
if profile != null:
    _player.request_mover(profile)

var enemy_profile := tuning.air_plunge_enemy_mover
if target is EnemyBase:
    (target as EnemyBase).request_mover(enemy_profile, tuning.stun)
```

`WeaponBase.run_vertical_window(...)` es la utilidad para ataques cuyo hitbox debe solicitar primero el Mover del enemigo y luego cobrar el dano. Conecta al objetivo mediante `Hitbox.about_to_hit`, de modo que el stun del mismo golpe ya lo ve en el aire. Es el **mecanismo**; los ataques migrados no lo llaman directo sino a traves de `run_vertical_window_from_profile`, que saca los dos Movers del perfil del gesto.

### Ejemplos vigentes

- Espada: los **especiales** (taps de X, taps de Y, cargados de Y) sacan sus Movers de un `AttackMovementProfile`; ver la seccion siguiente.
- Espada: `air_wait_spin_player_mover` para el hop de la rama aerea de espera y `air_plunge_player_mover` en modo `PARTIAL` para el plunge del combo. Los combos siguen con campos sueltos a proposito.
- Mazo: su launcher terrestre usa `run_vertical_window` con perfiles sueltos; todavia no migro.

## Perfil de movimiento por ataque

`AttackMovementProfile` (`data/attack_movement_profile.gd`) agrupa, para UN gesto de ataque (gesto x tramo), todo lo que ese golpe le hace a la posicion de los cuerpos. No cambia las primitivas ni quien tiene autoridad: es un contenedor de datos que `WeaponBase.run_attack_movement` traduce a `request_mover` / `request_float`, con los mismos gates de siempre. *(2026-07-29)*

| Slot | Que es |
|---|---|
| `player_travel` | Recorrido del Player, y tambien su hang: el Floater sale de `player_travel.float_duration`, no de un slot aparte. Colgar sin viajar es `distance = 0`. |
| `player_travel_at_window_end` | El recorrido del Player espera al cierre de la ventana de dano en vez de salir con el golpe. Gemelo de `WINDOW_END`: en un plunge, caer durante el swing te saca de rango. |
| `enemy_travel` + `enemy_travel_at` | Recorrido del Enemy y en que momento sale, con su hang en `float_duration` igual que el del Player. Ver la seccion siguiente. |
| `enemy_travel_aligns_y` | Antes de mover al enemigo, lo sube/baja a tu altura. Es lo que hace que un plunge se sienta "bajamos juntos". Solo alinea si el Mover va a entrar (aereo y quebrado). |
| `enemy_push` + `enemy_push_at` | Empujon en arco al enemigo y en que fraccion del golpe se arma (normalizado 0-1). No es un Mover: usa su propio impulso inicial, angulo y aceleracion vertical. Vive aca igual porque un empujon es exactamente "que le hace el golpe a la posicion". |
| `rt_*_bonus` | Bonos en % de la variante RT sobre los slots de arriba. Ver mas abajo. |
| `rt_only` | El golpe existe SOLO con RT. Dentro de una secuencia se omite el paso entero sin barra, lo que permite declarar [ataque normal, remate RT] en el mismo auto-chain. |
| `rt_projectile_enemy_mover` | Launcher que el proyectil aplica al impactar. Quien dispara es el paso (`AttackStep.fires_projectile`), no el cierre del recorrido. |
| `overrides_air_hit` | El golpe se hace cargo de la vertical del Player: el arma no le aplica encima su air-hit-stall generico. Aplica con RT y sin RT: es regla del gesto, no recompensa. |

> [!warning] Un solo slot por cuerpo, a proposito
> El hang dejo de ser un campo aparte (`player_hang` / `enemy_on_hit`). Los dos podian convivir con
> el recorrido en el mismo perfil, y esa es la fuente de los conflictos de vertical: un Floater
> arrancado mientras corre un Mover no se aplica **durante** el recorrido pero si despues, y en el
> enemigo el Mover directamente le mataba el Floater declarado al lado. Con un solo slot el conflicto
> no se puede ni declarar.

Reglas que se mantienen: un slot por cuerpo, un perfil por gesto (dos gestos que hoy se sienten igual llevan perfiles separados), y un slot en `null` significa "este golpe no hace eso". Un perfil entero en `null` significa que el golpe no mueve a nadie — es el caso real de tap adelante + X en suelo.

Lo consumen **todos los ataques especiales** de [[Espada]]: los cuatro taps direccionales de X, los taps de Y y los cargados de Y. Quedan afuera a proposito el **X cargado**, que mueve al Player con `force_dash` (i-frames, hitbox propio, reposicionamiento al atravesar) y no con un Mover —darle un slot seria un campo que miente—, y los **combos normales**, cuyo Mover sale en un beat concreto de una cadena de varias fases: eso es coreografia, y vive en codigo igual que la secuencia de swings. *(2026-07-29)*

### Cuando sale el recorrido del Enemy

El mismo slot `enemy_travel` alimenta tres momentos, y **solo el perfil puede distinguirlos**, por eso este eje es tuning y no codigo: el momento cambia lo que se siente, no solo cuando ocurre. *(2026-07-29)*

| `enemy_travel_at` | Cuando | Para que | Quien lo cobra |
|---|---|---|---|
| `BEFORE_DAMAGE` | En `about_to_hit`, antes del dano | El Stun del mismo golpe ya lo ve en el aire — es lo que convierte un launcher en abre-juggle en vez de empujon | Solo un golpe con ventana vertical (`run_vertical_window_from_profile`) |
| `ON_HIT` | Al conectar, despues del dano | Spikes y empujones a los que les da igual lo que vio el Stun | `WeaponBase._on_hit`, para **cualquier** golpe del arma |
| `WINDOW_END` | Al cerrar la ventana, sobre todo lo golpeado en ella | Plunges: arrancar el recorrido durante el swing saca al objetivo del alcance del propio golpe | El cierre de `begin_damage_window` |

`ON_HIT` y `WINDOW_END` los cobra `WeaponBase` sin que la rutina del arma pida nada. Esa es la razon de ser del componente: **agregar o sacar movimiento de un especial es poner o vaciar un slot en el inspector**, no editar la rutina del golpe. `BEFORE_DAMAGE` es la excepcion —necesita una ventana vertical— y en un golpe que no la tiene es un momento que nunca llega.

`enemy_travel` **no tiene bonos de RT**: hoy ningun gesto que mueva al Enemy tiene variante RT (los taps de Y son gratis, los cargados cobran barra entera y sin rama), asi que serian sliders muertos. Se agregan cuando exista el primer caso real.

### El hang lo pide siempre el Mover

El hang de un golpe sale de `float_duration` del propio Mover (`player_travel` / `enemy_travel`), que lo detona en `_finish`: al cerrar el recorrido, y solo si NO se cancelo. **Colgar sin viajar es `distance = 0`** — el Mover corre un frame, termina y detona su Floater.

No hay una segunda via, y eso es deliberado: un Floater arrancado mientras corre un Mover **no se aplica durante el recorrido** (en `TOTAL` el loop del Player hace `return` antes de leer el Floater, y en `PARTIAL` el Mover le sobreescribe la vertical el mismo frame) pero **si despues**, asi que "no se aplica nunca" era falso y el hang se colaba tarde. En el enemigo era peor: `request_mover` llama `_cancel_air_hold()`, o sea que el recorrido mataba el hang declarado justo al lado. Con un solo slot por cuerpo el conflicto no se puede declarar.

### RT como porcentaje, no como perfil aparte

La variante RT de un gesto no es otro perfil: son **bonos en % sobre la misma base**, aplicados en el consumidor. Mismo modelo que [[Sprint]] — el valor base vive una sola vez y "sin RT" es literalmente multiplicar por `1.0`, no una rama aparte. *(2026-07-29)*

| Bono | Sobre que |
|---|---|
| `rt_travel_distance_bonus` | Metros del recorrido de Player y Enemy. |
| `rt_travel_speed_bonus` | Velocidad inicial de ambos Movers. |
| `rt_travel_acceleration_bonus` | Aceleracion de ambos Movers. Va aparte de la velocidad: subir solo el arranque deja un recorrido que se siente lavado al final. |
| `rt_player_hang_bonus` | Segundos de hang del Player (`player_travel.float_duration`). |
| `rt_enemy_hang_bonus` | Segundos de hang del Enemy (`enemy_travel.float_duration`). `-100` lo apaga. |

Dos cosas quedan afuera del modelo a proposito:

- **El `fall_scale` no lleva %.** `0` es hold total y `0` por cualquier bono sigue siendo `0`; ademas el rango esta clampeado a 0-1, asi que un bono positivo no tendria a donde ir. Si RT tiene que cambiar COMO caes y no solo cuanto, eso es un campo propio.
- **`rt_projectile_enemy_mover` va a mano.** Es el unico Mover del perfil que no le pertenece al Player, asi que no comparte escala con nada.

Un bono se recorta en `0`: `-100` apaga el canal en vez de invertirlo. Distancias y duraciones negativas no significan nada.

## Cancelacion y orden

Un Mover nuevo reemplaza al anterior con `Mover.CancelReason.SUPERSEDED`; no inicia el Floater del perfil cancelado. El receptor tambien debe cancelar control previo cuando gana otra autoridad:

- Stun cancela Mover y Floater.
- Dash, bump y locomocion dirigida cancelan ambos en Player cuando corresponda.
- Un golpe nuevo cancela Mover/Floater previos del Enemy. La excepcion es el Mover que el mismo golpe armo antes del dano por `about_to_hit`.
- Al aterrizar, Player corta su Floater; los `stop_on` del Mover deciden si el recorrido tambien termina en piso o pared.

Antes de agregar una mecanica, elegir una sola fuente de autoridad por tramo: Mover para recorrido, Floater para hang, gravedad normal para caida. No escribir `vertical_velocity` directo en paralelo salvo que sea una excepcion de traversal o una trayectoria balistica documentada.

## Archivos clave

| Archivo | Responsabilidad |
|---|---|
| `combat/floater.gd` | Estado temporal y calculo de gravedad escalada. |
| `combat/mover.gd` | Recorrido, finales, cancelaciones y Float opcional de salida. |
| `data/floater_settings.gd` | Perfil de hang por ataque. |
| `data/mover_settings.gd` | Perfil de trayectoria por ataque. |
| `player/player.gd` | API y ejecucion de Player. |
| `enemies/enemy_base.gd` | API, gate de poise y ejecucion del Enemy. |
| `combat/weapons/weapon_base.gd` | Ventana vertical que coordina Player, Enemy e hitbox; aplicador de `AttackMovementProfile`. |
| `data/attack_movement_profile.gd` | Perfil de movimiento de una variante de ataque (agrupa los slots de arriba). |

## Relacionado

- [[Combate]]
- [[Armas]]
- [[Espada]]
- [[Mazo]]
- [[brazo-combate|Brazo Combate]]
- [[Stun]]
- [[Plan Autoridad Vertical]]
- [[Mapa Impacto Autoridad Vertical]]
