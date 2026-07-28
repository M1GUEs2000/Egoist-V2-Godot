---
title: Sprint
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
status: active
system_status: E2
hito: H1
---

# Sprint

Modulo componible `PlayerSprint` (nodo hijo `Sprint` del player). Tuning en `PlayerTuning` grupo `Sprint`.

## Que es

El sprint **no es una velocidad aparte**: es un **nivel 0-1** que multiplica los valores que ya existen. Con el nivel en 0 el movimiento es identico al de siempre — todo lo demas del `PlayerTuning` sigue siendo el BASE.

- Carga: boton `sprint` sostenido, sube a lo largo de `sprint_charge_seconds`. En tierra y en aire por igual.
- Descarga: al soltar, baja a lo largo de `sprint_decay_seconds`, tambien en los dos.
- `sprint_requires_move_input`: si `true`, frenar en seco corta la carga aunque se sostenga el boton.
- El stun lo tira a **cero de golpe** (`cancel()`): comerse un golpe apaga la carrera.
- **Cuesta meter mientras esta encendido** (nivel > 0), no solo mientras se carga: el tramo de decay todavia da bono, asi que todavia paga.

## Regla 1 — Sostener el boton es lo unico que lo mantiene

*(2026-07-28, reemplaza el congelado en el aire)*

`tick` corre igual en tierra que en aire: soltar el boton en pleno salto tambien apaga la carrera, y
el nivel decae mientras volas.

> [!note] Lo que habia antes y por que se fue
> Hasta 2026-07-27 el nivel quedaba **congelado** al despegar: lo que ganabas corriendo viajaba con
> el salto y con la cadena de paredes entera. Eso existia para que el sprint le llegara al wall
> jump, pero lo volvia gratis — una vez cargado, la cadena entera heredaba el bono sin que costara
> nada sostenerlo. Con el sprint cobrando meter, congelarlo en el aire seria regalar el bono justo
> donde mas rinde.

**Consecuencia a mirar jugando:** el wall jump y el momentum leen el nivel en el aire. Antes lo
heredaban del despegue; ahora, si soltas a mitad de cadena, el rebote sale con bono menor. Es el
cambio buscado, pero es lo que hay que sentir.

## Regla 3 — El costo es fraccion del meter, no barras

`sprint_meter_drain_per_second` es la fraccion del meter **completo** que se drena por segundo:
`0.1` = 10% del total por segundo, o sea un meter lleno se vacia en 10s corriendo, valga 2 barras o
5. Se cobra sobre el total y no por barra a proposito: subir `meter_max_bars` (la mejora futura a 5
barras, ver [[Meter]]) no tiene que abaratar la carrera.

Sin meter no se puede cargar: el nivel cae solo aunque se siga apretando. *(2026-07-28)*

> [!warning] Con la carga actual el cobro es casi por presion
> `sprint_charge_seconds = 0.2` y `sprint_decay_seconds = 0.1` hacen que el nivel suba y baje casi
> instantaneo, asi que en la practica se paga mientras el boton esta apretado. Si se alargan esos
> tiempos, el tramo de decay empieza a pesar en el costo.

## Regla 2 — El multiplicador se aplica en el consumidor, nunca sobre el Resource

`PlayerSprint.scale(canal)` devuelve el multiplicador y **cada sistema se lo aplica a su propio tuning**. Nunca se escribe sobre `PlayerTuning`.

> [!important]
> Esto no es cosmetico. `tuning.move_speed` se usa en varios lados como **unidad de medida**, no como velocidad — por ejemplo, el wall slide mide contra el que tan rasante fue una llegada. Si el sprint escalara el Resource, correr cambiaria esa referencia y a igual velocidad real se saldria distinto de la pared: lo contrario de lo que el sprint deberia hacer.

## Canales

Cada canal tiene su porcentaje propio, asi se decide por separado cuanto le entra el sprint a cada pieza. Un bono de 40 significa que a nivel 1 ese canal vale `1.4x`; a nivel 0.5, `1.2x`. En 0 el canal no participa.

| Canal | Knob | Que escala |
|---|---|---|
| `MOVE_SPEED` | `sprint_move_speed_bonus` | Velocidad horizontal en tierra. El que mas se siente. |
| `JUMP_HEIGHT` | `sprint_jump_height_bonus` | Altura de cuspide del salto y doble salto. |
| `JUMP_FORWARD` | `sprint_jump_forward_bonus` | Avance horizontal del salto. Alarga el arco sin subirlo. |
| `WALL_SLIDE_INITIAL` | `sprint_wall_slide_initial_speed_bonus` | Velocidad **inicial** de la rampa del slide (min y max a la vez). |
| `WALL_SLIDE_FINAL` | `sprint_wall_slide_final_speed_bonus` | Velocidad **final** de la rampa: adonde llega. |
| `WALL_SLIDE_ACCEL` | `sprint_wall_slide_acceleration_bonus` | Aceleracion de la rampa: que tan rapido llega. |
| `WALL_JUMP_H` | `sprint_wall_jump_h_bonus` | Salida horizontal del rebote (min y max). |
| `WALL_JUMP_V` | `sprint_wall_jump_v_bonus` | Salida vertical del rebote (min y max). |
| `WALL_IMPULSE` | `sprint_wall_impulse_bonus` | Carril Wall Impulse entero: arranque, aceleracion y techo. |
| `MOMENTUM_MAX` | `sprint_momentum_max_bonus` | Techo global de momentum. |

**Los rangos se escalan enteros (min y max), no solo el techo.** Escalar solo el max cambiaria la *forma* de la progresion y no solo su magnitud.

> [!warning] `MOMENTUM_MAX` es el cuello de botella
> Todo impulso pasa por `momentum_max_speed` dentro de `set_momentum`. Si `sprint_momentum_max_bonus`
> queda por debajo de los bonos de wall jump o wall impulse, el recorte se los come y el sprint no se
> nota justo en las cadenas largas, que es donde tiene que notarse.
> **Regla: dejarlo >= al mayor de esos dos.**

## Interaccion con el wall slide

Los tres canales de wall slide reparten responsabilidades limpias (ver [[Wall Slide y Wall Jump]]):

- `WALL_SLIDE_FINAL` decide **adonde** llega la rampa. Como el wall jump se mide contra ese mismo techo, el rebote escala con el.
- `WALL_SLIDE_ACCEL` decide **que tan rapido** llega. No cambia el destino: acorta el tiempo, asi que el tramo a potencia plena empieza antes y el slide se siente mas agresivo.
- `WALL_SLIDE_INITIAL` decide con cuanto se **arranca**.

## Estelas de sprint

Con el nivel por encima de `sprint_trail_min_level`, el jugador entero emite estelas que quedan atras suyo: emisor `SprintTrail` (`GPUParticles3D`) con `local_coords = false`, asi las particulas quedan en espacio de mundo y es el propio movimiento del player el que dibuja la estela. La direccion de emision se fija cada frame como el reverso de la velocidad planar (o el `forward()` si esta quieto), y el color se empuja a HDR segun el nivel para que lo agarre el glow del `WorldEnvironment`.

Knobs en `PlayerTuning` grupo *Dust FX*: `sprint_trail_min_level`, `sprint_trail_color`, `sprint_trail_emission_energy`, `sprint_trail_backward_speed`.

`Player._stop_movement_fx()` corta polvo y estela de una. Lo usan los cortes tempranos del frame (stun, Mover total, dash): ahi el player no se mueve por locomocion y el calculo normal de la estela nunca llega a correr, asi que sin eso quedaria emitiendo colgada.

## Cambio de direccion — hecho

*(2026-07-28)*

El sprint dejo de ser una mejora de movilidad gratis y paso a ser un **estado de velocidad que
consume meter**: se sostiene el boton para mantenerlo, se paga mientras dura y compite con el gasto
de combate (ver [[Meter]]). Con eso se resolvieron las dos preguntas que quedaban abiertas:

- **Se sigue cobrando en el aire?** Si — y ademas se descongelo el nivel, porque cobrar por algo
  congelado no tiene sentido (ver Regla 1).
- **Cambia la carga?** No se toco `sprint_charge_seconds` / `sprint_decay_seconds`; con los valores
  actuales el cobro termina siendo casi por presion de boton.

Los canales de escalado no cambiaron.

## Verificacion

Estado **E2** (bajo de E3 por la regresion: se modifico un sistema aprobado jugando). Los knobs
existen y la direccion esta clara; falta re-probar jugando el sprint sin congelado y el costo de
meter. *(2026-07-28)*

Lo aprobado antes de este cambio, y que sigue en pie salvo que el aire lo desmienta: los canales de
velocidad final y aceleracion de la rampa del wall slide. *(2026-07-27)*

> [!bug] Sin verificar headless
> El cambio se commiteo sin correr `--import` ni los smokes: no habia Godot instalado en la maquina
> donde se escribio. *(2026-07-28)*

## Relacionado

- [[Wall Slide y Wall Jump]]
- [[Movimiento Base]]
- [[Momentum y Bump]]
- [[Meter]]
- [[Traversal]]
