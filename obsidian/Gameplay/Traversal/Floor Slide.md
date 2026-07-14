---
title: Floor Slide
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
status: active
system_status: E0
hito: H1
---

# Floor Slide

Deslizamiento de suelo **por plataforma**: una plataforma marcada permite deslizar, el resto es
suelo normal. Modulo inyectable hermano de [[Wall Slide y Wall Jump|wall slide]] (`PlayerFloorSlide`,
nodo hijo `FloorSlide` del player). *(2026-07-14)*

## Como se marca una plataforma

Se le agrega un nodo hijo **`FloorSlideSurface`** al cuerpo de la plataforma (StaticBody3D u otro
cuerpo de mundo), con un **`FloorSlideTuning` (.tres)** asignado en su export `tuning`. Cada
plataforma puede llevar su propio `.tres` para ser mas o menos resbaladiza sin tocar codigo — eso es
lo que hace el slide "por plataforma" literal. Sin ese nodo (o sin tuning), la plataforma no desliza.

`PlayerFloorSlide` busca el `FloorSlideSurface` entre los hijos del collider de suelo real bajo el
jugador tras `move_and_slide` (filtra colisiones con `normal.y > 0.5` = suelo, no pared).

## Modelo

Una sola formula cubre hielo y rampa: el termino de pendiente se calcula desde la normal del suelo,
que en plataforma plana es vertical y se anula solo.

- **Enganche**: estar en el suelo de una `FloorSlideSurface` + velocidad horizontal ≥ `min_enter_speed`.
  Mientras desliza, el modulo es el **dueño del horizontal** del jugador (reemplaza la locomocion
  normal), igual que el wall slide manda mientras esta pegado.
- **Pendiente** (`slope_accel`, tope `max_speed`): empuja cuesta abajo segun la inclinacion. En plano
  no hace nada → queda hielo puro.
- **Friccion** (`friction`): cuanto frena el slide por si solo. 0 = hielo (no frena nunca).
- **Volante** (`steer_control` 0-1 + `steer_accel`): cuanto puede redirigir el input la direccion del
  slide. 0 = cero control (te llevan la velocidad y la pendiente), 1 = el input arrastra el slide
  hacia el a `move_speed`.
- **Salir**: se acaba la plataforma, se despega o se frena por debajo del enganche → el **exceso**
  sobre `move_speed` se vuelca como `bump_velocity` (ver [[Momentum y Bump]]) para no frenar de golpe;
  de ahi lo drena el modelo de momentum normal. Stun / dash / launch / bump lo cortan en seco (sin
  arrastre, esos setean su propio momentum).

## Wall jump / salto desde el slide

Saltar desde el floor slide **conserva `jump_momentum_keep`** (0-1) de la velocidad del slide como
momentum aereo: 0 = el salto sale limpio, 1 = te llevas todo el slide al aire. Es el knob que pediste
para elegir con cuanto te quedas al saltar.

## Tuning

`FloorSlideTuning` (`data/floor_slide_tuning.gd`), instancia de ejemplo `data/floor_slide_ice.tres`.
Knobs: `min_enter_speed`, `max_speed`, `slope_accel`, `friction`, `steer_control`, `steer_accel`,
`jump_momentum_keep`. Todos con comentario `##` de tooltip en el inspector.

## Verificacion

Probe de regresion headless: `world/floor_slide_probe.tscn` (plataforma plana de hielo, lanza al
player con momentum y cuenta transiciones del estado de slide + frames deslizando).

**Estado E0**: recien construido. Falta correr headless/probe y validarlo jugando (feel de friccion,
pendiente, control y retencion al saltar). Los knobs existen pero la direccion del feel es desconocida.

## Pendiente / deferido

- Feedback visual por plataforma (glow/particulas): deferido hasta el 2º caso real (regla de 2); hoy
  la plataforma puede reaccionar leyendo `floor_slide.is_sliding`.
- Rampas reales en `test_scene` + un `.tres` de rampa (hoy el ejemplo es hielo plano).

## Relacionado

- [[Wall Slide y Wall Jump]]
- [[Momentum y Bump]]
- [[Movimiento Base]]
- [[Bloques]]
- [[Traversal]]
