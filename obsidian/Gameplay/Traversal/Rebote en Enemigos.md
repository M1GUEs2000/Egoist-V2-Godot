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

Rebote manual desde enemigos: el jugador no rebota por contacto, sino al pedir salto dentro de una ventana breve tras entrar en la caja de rebote del enemigo. La superficie se lee como impulso instantaneo.

## Implementado en Godot

- `PlayerEnemyBounce` es nodo hijo `EnemyBounce` del player.
- `Player._on_jump()` mantiene el orden: suelo, wall jump, enemy bounce, doble salto.
- Cada `EnemyBase` crea un `BounceHitbox` (`Area3D`) con `BoxShape3D` derivado de su `CollisionShape3D` corporal. Capsula, esfera, cilindro y caja se convierten a una caja con sus mismas dimensiones.
- La caja detecta solo `World.LAYER_PLAYER`; no bloquea movimiento ni participa en dano. La cara mas cercana al jugador define la normal del rebote.
- Enemigos inactivos por mundo y enemigos muertos desactivan su caja, igual que su colision corporal.

## Reglas

- Solo en el aire.
- El rebote no consume doble salto y tampoco lo restaura.
- `enemy_bounce_grace` permite saltar un instante despues del contacto.
- `enemy_bounce_cooldown` bloquea rebotar del mismo enemigo dos veces seguidas, pero permite encadenar enemigos distintos.
- El stomp (`normal == Vector3.UP`, sin normal horizontal) da solo vertical: `bump_velocity = Vector3.ZERO`, sin reaccion del enemigo y sin bloquear el input de movimiento — no hay impulso horizontal que proteger, y bloquearlo solo quitaria control aereo.
- El cooldown recuerda al enemigo por `instance_id`, no por referencia: un enemigo muerto se libera (`EnemyBase._die`) mientras su cooldown sigue corriendo.
- La reaccion del enemigo es un `push` en arco (**sin daño**) via `enemy_bounce_push` (`player_tuning.tres`), en direccion opuesta a la salida del jugador y **solo en el rebote lateral** (el stomp no tiene horizontal). El `push` esta sujeto al gate de poise y cancela el Mover activo del enemigo — ambas reglas viven en [[Stun]] (*El poise es el gate de TODO desplazamiento* y *Autoridad vertical*). En la practica desplaza al enemigo del plunge de la [[Espada]], que ya esta stuneado por el golpe, y lo saca del descenso que hacia a la par del jugador.
- Un rebote exitoso **cancela el plunge** del jugador (el finisher X X espera X de la [[Espada]]): es su unica salida antes del piso. Durante el plunge el doble salto no sale ni se gasta.

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
- Un enemigo con la reserva de poise intacta (armado o no) es plataforma firme: el jugador rebota igual pero el `push` no lo desplaza (ver el gate en [[Stun]]).
- El feel depende del drenaje de [[Momentum y Bump]], que sigue en E1 hasta validacion jugando.

## Estado

E3. Modulo, tunables y logica validados en engine: el rebote sale, cancela el plunge y empuja al enemigo stuneado. En tuning de feel (gracia, cooldown, direccion y arco del `push`).

## Relacionado

- [[Momentum y Bump]]
- [[Wall Slide y Wall Jump]]
- [[Enemigos]]
- [[Combate]]
