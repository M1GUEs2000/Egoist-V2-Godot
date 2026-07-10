---
title: Pendientes e Ideas
tags:
  - egoist
  - tarea
  - backlog
status: active
priority: 2
---

# Pendientes e Ideas

Lugar unico de las cosas **que todavia no existen en el juego**. No hay que entrar a cada nodo a buscarlas.

Lo que NO vive aca: tunear valores y probar jugando de un sistema ya implementado — eso es parte del estado E2 de su nodo y se queda ahi.

> [!important] Dos categorias
> **Pendientes**: decididos, entran al juego. Falta hacerlos.
> **Ideas potenciales**: no comprometidas. Pueden no entrar.

## Pendientes

| Que | Nodo | Detalle |
|---|---|---|
| Scanner de cambio de mundo | [[World Switch]] | Sin diseño: no hay modulo, trigger ni tuneables. Tutupa lo define el 2026-07-10. |
| El AOE aereo del [[Mazo]] debe lanzar a **todos** los enemigos del area | [[Mazo]] | Hoy `AirSlamHitbox` es un `Area3D` que reacciona a `area_entered` y se enciende al iniciar la caida: alcanza al primer enemigo que atraviesa, y no ve a los que ya estaban parados dentro del radio al impactar. Hay que consultar los solapamientos vigentes en el instante del impacto. |
| El hitbox del AOE aereo del Mazo debe ser un **cilindro** | [[Mazo]] | Hoy es una esfera (`air_y_aoe_radius`). El area es de suelo: la esfera cubre de menos al ras y de mas en altura. |
| Rediseñar el combo aereo del [[Mazo]] | [[Mazo]] | Sin diseño. Hoy el aereo del Mazo no es una cadena encadenable como la de la [[Espada]]: son moves puntuales sueltos (tap con push, X cargado ground pound, Y cargado slam). Definir que reemplaza a que. |
| El dash del bloque verde debe hacer daño | [[Bloques]] | Hoy no daña: la caracteristica Dash entra por `Player.force_dash`, que es solo movimiento. El dodge normal si daña, via `dash_deals_damage`. El daño de un dash forzado lo pone un hitbox propio — ver como lo resuelve el X cargado de la [[Espada]] con su `ChargedDashHitbox`. |
| El rebote en enemigos debe **stunear sin dañar** | [[Rebote en Enemigos]] | El stun ya esta desacoplado del daño: `EnemyBase.receive_stun` no toca `Health`. Falta un `enemy_bounce_stun: StunSettings` en `PlayerTuning` (mismo patron que `enemy_bounce_push`) y un verbo `receive_stun_from(source, stun)` en `EnemyBase`, porque un rebote no pasa por la hurtbox y la reaccion visual del stun se orienta con `_last_hit_direction`. |

### Verificaciones abiertas

| Que | Nodo | Detalle |
|---|---|---|
| El combo cruza dos armas y `cancel_routines()` es por arma | [[Combate]] | Espada (slot X) → Mazo (slot Y): la rutina de la Espada no se cancela al atacar con el Mazo. Su tween y su ventana de daño siguen vivos, y como el arma saliente se oculta con `visible = false`, el sintoma seria daño fantasma invisible. Sin verificar. |
| Rebote en enemigos y slam del Mazo compiten por el mismo contacto | [[Mazo]] | Al caer sobre un enemigo, `PlayerEnemyBounce` ve la colision fisica y el `Hitbox` ve la hurtbox. Rebotar conserva el doble salto; el slam lo deja disponible via su hang. Falta decidir la precedencia y hacerla tuneable. |
| Falta un `WorldEnvironment` con glow | [[Combate]] | Sin el no hay halo de bloom: ni en el glow de carga de la hoja, ni en las chispas de impacto, ni en la luz del stun. Es un cambio de una escena pero afecta a todo lo que se ve. |

## Ideas potenciales

*(No comprometidas: pueden no entrar al juego.)*

| Idea | Nodo | Detalle |
|---|---|---|
| Bloques dañinos | [[Bloques]] | Colores de `TraversalBlock` que le hagan **daño** al jugador al tocarlos, en vez de darle un beneficio. Hoy toda caracteristica del bloque es a favor del jugador; lo unico que lo castiga es la spike wall, que no es un `TraversalBlock`. Sin color ni efecto definidos. |
| El color negro es un efecto oculto | [[Bloques]] | El efecto todavia no esta definido. No existe como caracteristica; el negro que se ve hoy es el cuerpo de la spike wall. |
| Brazo que dispara | [[Combate]] | Disparo a distancia. **Cargarlo atrae** lo que golpea hacia el jugador: enemigos, objetos. La carga se paga con meter. Sin daño, alcance ni cooldown definidos. |
| Lock-on de marcado | [[Lock On]] | Un lock-on que **no acerca** al jugador, solo mantiene el objetivo presente. Existiria para que el brazo dispare a lo que este marcado. |
| Combo aereo de las [[Dagas]] `X X espera X X` | [[Dagas]] | Sube al enemigo **mas alto de lo que esta el jugador**, no solo un poco. |

### Tensiones a resolver si estas ideas entran

- **El brazo no es un arma de slot X/Y.** El roster de V2 esta congelado en [[Espada]], [[Mazo]], [[Dagas]] y [[Punos]], y [[Arquitectura Godot]] prohibe explicitamente Capa, Guantes, Ruedarang y Latigo. Si el brazo entra, hay que decidir si es un sistema aparte de los slots o si rompe esa decision congelada.
- **El lock-on actual no es quien acerca al jugador.** Eso lo hace `PlayerLocomotion.attack_step`, que avanza hacia el target lockeado en cada golpe. Un modo de marcado tendria que saltearse eso, y falta definir si convive con el lock-on actual o lo reemplaza.
- **El combo de las Dagas contradice su propia tabla.** Su fila aerea de hoy describe la rama espera como `X espera X` → "empuja hacia abajo a los enemigos con mayor AOE, 1 vuelta, 1 corte en X". Si la idea entra, cambia la cantidad de taps y la direccion del efecto.

## Relacionado

- [[H1 - Vertical Slice]]
- [[Roadmap Futuro]]
- [[Metodologia V2]]
