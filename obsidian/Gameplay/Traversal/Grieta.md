---
title: Grieta
tags:
  - egoist
  - gameplay
  - traversal
  - world-switch
  - sistema
status: active
system_status: E3
hito: H1
---

# Grieta

> [!abstract] Que es
> Una puerta temporal al otro mundo. Se abre donde algo cruzo, queda un rato abierta y **cruzarla
> voltea el mundo de todos**. Es de un solo uso: se cierra apenas alguien la atraviesa.

La grieta es una mecanica de traversal por derecho propio, no un accesorio del enemigo que la
deja. Es una **fuente de world switch mas** (ver [[World Switch]]), con una personalidad que las
otras no tienen: no se gana golpeando ni matando, se gana **llegando a tiempo**. La grieta pone
un reloj en pantalla.

## Contrato

| | |
|---|---|
| Modulo | `WorldRift` (`world/rifts/world_rift.gd` + `.tscn`) |
| Tuning | `WorldRiftTuning` — `data/world_rift_tuning.tres` |
| Se abre con | `WorldRift.spawn(position, parent, tuning)` |
| La cruza | Solo el jugador (`collision_mask = World.LAYER_PLAYER`); los enemigos la ignoran |
| Al cruzarla | `WorldManager.switch_world(posicion_de_la_grieta)` y se cierra |
| Si nadie la cruza | Se cierra sola al vencer `lifetime`, **sin cambiar nada** |
| Avisa que se cierra | Parpadea durante los ultimos `warning_time` segundos |

> [!important] Cualquier cosa puede abrir una grieta
> `spawn()` es el unico punto de entrada y no le pregunta a nadie quien lo llamo. El enemigo del
> `RiftSpawner` es el primer detonante, pero un bloque, un pickup, un jefe o un evento de nivel
> pueden dejar una grieta sin tocar una linea de `WorldRift`. Es el mismo eje que separa
> `WorldSwitchTrigger` (quien lo dispara) de `WorldManager` (que hace).

## Un solo uso

Cruzarla la gasta, aunque le sobrara ventana. No es una puerta de ida y vuelta: si el jugador
cruza, el mundo se voltea y la grieta se cierra detras suyo. Esa es la decision que la vuelve
tensa — abrirla no garantiza poder volver.

## Color y lectura

La grieta lleva el color del **mundo destino** (el opuesto al actual), igual criterio que los
bloques de world switch y el enemigo de world switch: anuncia adonde manda, no donde esta. Sale de
`World.world_color(World.opposite_world(...))`, nunca del `.tscn` — ver [[Colores de mundo]]. Si el
mundo cambia por otra via mientras la grieta sigue abierta, se repinta sola.

El **parpadeo solo significa "me cierro"**: fuera de la ventana de aviso el brillo es plano. No hay
latido decorativo que compita con esa lectura (el latido constante es el lenguaje del enemigo de
world switch, no el de la grieta).

## Quien la deja hoy

El **enemigo de la grieta** (`rift_enemy.tscn`): al recibir el primer golpe arranca su reloj y, al
cumplirse, se va al otro mundo dejando una grieta donde estaba. El modulo que lo hace es
`RiftSpawner` (`core/rift_spawner.gd`), componible en cualquier cosa que tenga `Hurtbox` y
`WorldMembership` hermanos. Detalle en [[Afiliacion de Mundo]].

> [!warning] Irse no es cambiar el mundo
> Cuando el enemigo se va al otro mundo **no voltea el mundo de nadie**: solo voltea su propia
> afiliacion (se vuelve intangible y pasa a leerse como cascara/humo, ver [[Afiliacion de Mundo]]).
> El unico que decide el cambio de mundo es el jugador, cruzando o no la grieta.

## Tuneables

`data/world_rift_tuning.tres`: `lifetime` (la ventana), `trigger_radius` (la boca), `close_time`,
`warning_time` / `warning_pulse_speed` (el aviso) y `glow_energy` / `light_energy` / `light_range`.
*(pendiente de tunear jugando)*

## Pendiente

- Verificacion headless + smokes.
- Tunear jugando la ventana (`lifetime`) contra el `delay` del enemigo: juntos definen si la
  grieta es un premio alcanzable o una zanahoria.
- Decidir si otros sistemas la adoptan (bloque que abre grieta, jefe que deja grietas al
  teleportarse) — hoy solo la usa el enemigo.
- Arte: hoy es greybox (una ranura vertical que brilla). Arte final es H3.

## Relacionado

- [[World Switch]]
- [[Traversal]]
- [[Afiliacion de Mundo]]
- [[Colores de mundo]]
