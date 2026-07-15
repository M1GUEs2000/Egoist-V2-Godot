---
title: Rebote en Enemigos
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
status: active
system_status: E3
hito: H1
---

# Rebote en Enemigos

Rebote manual desde enemigos: el jugador no rebota por contacto, sino al pedir salto dentro de una ventana breve tras tocar fisicamente un enemigo. La superficie del enemigo es demasiado chica para slidear; se lee como impulso instantaneo.

## Implementado en Godot

- `PlayerEnemyBounce` es nodo hijo `EnemyBounce` del player.
- `Player._on_jump()` mantiene el orden: suelo, wall jump, enemy bounce, doble salto.
- La deteccion usa las colisiones reales de `CharacterBody3D`: collider con `collision_layer & World.LAYER_ENEMY`.
- No hay `Area3D`, no se tocan capas y no se consulta `is_dead()` ni afiliacion de mundo. Cadaveres y enemigos fuera de mundo ya quedan con `collision_layer = 0`.

## Reglas

- Solo en el aire.
- El rebote no consume doble salto y tampoco lo restaura.
- `enemy_bounce_grace` permite saltar un instante despues del contacto.
- `enemy_bounce_cooldown` bloquea rebotar del mismo enemigo dos veces seguidas, pero permite encadenar enemigos distintos.
- El stomp (`normal == Vector3.UP`, sin normal horizontal) da solo vertical: `bump_velocity = Vector3.ZERO`, sin reaccion del enemigo y sin bloquear el input de movimiento — no hay impulso horizontal que proteger, y bloquearlo solo quitaria control aereo.
- El cooldown recuerda al enemigo por `instance_id`, no por referencia: un enemigo muerto se libera (`EnemyBase._die`) mientras su cooldown sigue corriendo.
- La reaccion del enemigo es un `push` (knockback horizontal + vertical, **sin daño**) via `enemy_bounce_push`, hoy configurado en `player_tuning.tres`. Se llama `push()` con la direccion opuesta a la salida del jugador. Solo en el rebote **lateral**: el stomp no tiene direccion horizontal, asi que no empuja.

## Tuning

`PlayerTuning`, grupo `Enemy bounce`:

| Tuning | Funcion |
|---|---|
| `enemy_bounce_up_speed` | Impulso vertical fijo. Encadenar no sube mas alto. |
| `enemy_bounce_away_speed` | Impulso horizontal perpendicular al enemigo. |
| `enemy_bounce_along_speed` | Componente lateral si habia input. |
| `enemy_bounce_momentum_keep` | Fraccion de velocidad de llegada redirigida a la salida. Default 0.0. |
| `enemy_bounce_grace` | Ventana tras el contacto. |
| `enemy_bounce_cooldown` | Bloqueo contra el mismo enemigo. |
| `enemy_bounce_lock_time` | Tiempo en que el rebote lateral bloquea input de movimiento. El stomp no lo usa. |
| `enemy_bounce_push` | `PushSettings` de la reaccion del enemigo (knockback sin daño). Configurado en tuning. |

## Bordes conocidos

- Si el jugador queda parado sobre la cabeza de un enemigo, `is_on_floor()` gana y el salto es normal. Tambien drena momentum como suelo. Se deja asi para mantener simple la cadena de `_on_jump()` y el modelo de drenaje.
- Enemigos con armadura no reaccionan a `push()`, pero el jugador rebota igual. Eso los vuelve plataformas estables.
- El feel depende del drenaje de [[Momentum y Bump]], que sigue en E1 hasta validacion jugando.

## Estado

E1. Tiene modulo, tunables y smoke tests de logica; falta probarlo con Godot y jugarlo para tunear gracia, cooldown, direccion y reaccion.

## Relacionado

- [[Momentum y Bump]]
- [[Wall Slide y Wall Jump]]
- [[Enemigos]]
- [[Combate]]
