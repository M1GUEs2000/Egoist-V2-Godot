---
title: Momentum y Bump
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
status: active
system_status: E3
hito: H1
---

# Momentum y Bump

`bump_velocity` es el exceso horizontal del jugador: la velocidad extra que se suma encima de la locomocion normal (`move_speed`). No es otro motor ni otro canal; es aditivo sobre el horizontal que produce `PlayerLocomotion`.

## Implementado en Godot

- `Player.bump()` suma momentum horizontal y aplica velocidad vertical.
- `Player.add_momentum()` compone impulsos y clampa contra `momentum_max_speed`.
- `Player.set_momentum()` reemplaza el exceso y tambien respeta el techo.
- `Player._bleed_momentum()` drena el exceso a rate constante.

## Modelo

Hay una velocidad normal (`move_speed`) y un exceso (`|bump_velocity|`) encima. El exceso se drena linealmente: el doble de exceso tarda el doble en irse.

| Apoyo | Tuning |
|---|---|
| Suelo | `momentum_bleed_ground` (la referencia: 1.0) |
| Pared | `momentum_bleed_wall` |
| Aire | `momentum_bleed_air` |

Las escalas por superficie y el ritmo base son knobs de `player_tuning.tres`; los valores vigentes viven ahi, no en esta nota.

`momentum_bleed_seconds_per_unit` mide cuantos segundos tarda en drenarse un exceso igual a una `move_speed` en suelo. Ejemplo: con `move_speed = 6` y `momentum_bleed_seconds_per_unit = 3`, venir a 12 m/s (2x total) tarda 3s en volver a normal; venir a 18 m/s (3x total) tarda 6s.

El drenaje solo come el exceso. Como `bump_velocity` se suma encima del movimiento base, llevarlo a `Vector3.ZERO` deja al jugador exactamente en `move_speed`, nunca por debajo.

## Casos actuales

- `TraversalBlock` con feature Launch: suma bump horizontal/vertical y restauracion de habilidades.
- `SpikeWall`: stun `PUSH` + rebote, restaura doble salto y airdash.
- Wall jump: reemplaza el exceso por el impulso de pared.
- Rebote en enemigos: reemplaza el exceso por la salida del rebote y opcionalmente redirige parte de la velocidad de llegada.
- Dash con boost de momentum: reemplaza el exceso en la direccion del dash y queda limitado por `momentum_max_speed`.

## Interacciones conocidas

- Stun `PUSH` esta aislado del modelo de superficie: drena con `stun_bump_decay` para que recibir un golpe no se convierta en una fuente normal de traversal.
- Wall slide tiene dos drenajes actuando, pero **ya no compiten**: `momentum_bleed_wall` drena `bump_velocity`, mientras que la velocidad interna del slide la gobierna su propia rampa y su drenaje exponencial (`wall_slide_fall_lateral_halflife`, ver [[Wall Slide y Wall Jump]]). Desde la reescritura del 2026-07-27 el slide **no lee la velocidad de entrada como magnitud**: la usa solo para elegir rumbo y punto dentro de sus rangos, asi que `momentum_bleed_wall` ya no puede frenar el deslice — solo afecta el exceso que se arrastra al salir de la pared.
- El dash boost antes podia llegar hasta `dash_bump_max_speed`; ahora, al pasar por `set_momentum()`, tambien respeta `momentum_max_speed`. Primer sospechoso si el dash se siente demasiado corto o apagado.

## Relacionado

- [[Bloques]]
- [[Launcher y Aire]]
- [[Combate]]
- [[Traversal]]
