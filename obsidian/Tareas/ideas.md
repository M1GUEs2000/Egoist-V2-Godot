---
title: Ideas
tags:
  - egoist
  - ideas
status: active
---

# Ideas

Ideas **potenciales**, no comprometidas: pueden no entrar al juego. Lo que ya esta decidido y falta hacer NO vive aca — eso es una subtarea del kanban ([[tareas]]).

## Ideas potenciales

| Idea | Nodo | Detalle |
|---|---|---|
| Bloques dañinos | [[Bloques]] | Colores de `TraversalBlock` que le hagan **daño** al jugador al tocarlos, en vez de darle un beneficio. Hoy toda caracteristica del bloque es a favor del jugador; lo unico que lo castiga es la spike wall, que no es un `TraversalBlock`. Sin color ni efecto definidos. |
| El color negro es un efecto oculto | [[Bloques]] | El efecto todavia no esta definido. No existe como caracteristica; el negro que se ve hoy es el cuerpo de la spike wall. |
| [[Brazo]] | [[Brazo]] | Habilidad permanente, no arma de slot. Puño remoto con lock-on pasivo: en combate mantiene enemigos en aire y da respiro; en traversal agarra cosas/puntos como pseudo checkpoint. Tap/carga, costo de meter y limites por definir. |
| Lock-on de marcado | [[Brazo]] | Lock-on pasivo del brazo: marca hacia donde mira/apunta el jugador, pero **no acerca** al jugador ni alimenta `attack_step`. Existe para que el brazo pegue o agarre lo marcado. |
| Combo aereo de las [[Dagas]] `X X espera X X` | [[Dagas]] | Sube al enemigo **mas alto de lo que esta el jugador**, no solo un poco. |

## Tensiones a resolver si estas ideas entran

- **El brazo no es un arma de slot X/Y.** El roster de V2 esta congelado en [[Espada]], [[Mazo]], [[Dagas]] y [[Punos]], y [[Arquitectura Godot]] prohibe explicitamente Capa, Guantes, Ruedarang y Latigo. Si el brazo entra, entra como habilidad permanente del jugador, no como `WeaponBase`.
- **El lock-on del brazo debe ser separado del lock-on de combos.** El acercamiento lo hace `PlayerLocomotion.attack_step` durante golpes de arma. El brazo necesita marcar pasivamente sin disparar ese avance.
- **El combo de las Dagas contradice su propia tabla.** Su fila aerea de hoy describe la rama espera como `X espera X` → "empuja hacia abajo a los enemigos con mayor AOE, 1 vuelta, 1 corte en X". Si la idea entra, cambia la cantidad de taps y la direccion del efecto.

## Relacionado

- [[tareas]]
- [[hitos]]
- [[Metodologia V2]]
