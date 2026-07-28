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

- Carga: boton `sprint` sostenido **en el suelo**, sube a lo largo de `sprint_charge_seconds`.
- Descarga: al soltar, baja a lo largo de `sprint_decay_seconds`, tambien solo en el suelo.
- `sprint_requires_move_input`: si `true`, frenar en seco corta la carga aunque se sostenga el boton.
- El stun lo tira a **cero de golpe** (`cancel()`): comerse un golpe apaga la carrera.

## Regla 1 — En el aire el nivel queda congelado

`tick` corta temprano si el player no esta en el suelo. Lo que se gano corriendo **viaja con el salto y con la cadena de paredes entera**, y recien vuelve a bajar al pisar suelo sin sostener el boton.

Sin esto el sprint no le llegaria nunca al wall jump: se descargaria en el aire antes de que el rebote lo leyera.

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

## Verificacion

Estado **E2**: los knobs existen y el sistema funciona mecanicamente; el feel no fue aprobado jugando. *(2026-07-27)*

## Relacionado

- [[Wall Slide y Wall Jump]]
- [[Movimiento Base]]
- [[Momentum y Bump]]
- [[Traversal]]
