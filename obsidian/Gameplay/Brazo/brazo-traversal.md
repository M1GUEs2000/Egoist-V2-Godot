---
title: Brazo Traversal
aliases:
  - brazo-traversal
  - Brazo Traversal
tags:
  - egoist
  - gameplay
  - traversal
  - brazo
status: active
system_status: E3
hito: H2
---

# Brazo Traversal

Uso del [[Brazo]] fuera del combate o durante plataformeo. Es una herramienta para agarrar cosas, estabilizar rutas rapidas y dar pseudo checkpoints momentaneos cuando el jugador necesita respirar.

## Implementado en Godot

Primera pasada, mas angosta que la vision completa de mas abajo: el brazo (`player/player_arm.gd`)
solo marca bloques de dash verdes (`world/blocks/traversal_block.gd`, `enable_dash = true`), no
puntos de agarre ni objetos interactuables genericos todavia.

- **Targeting**: si no hay enemigo en el cono de combate del brazo (ver [[brazo-combate|Brazo
  Combate]]), busca el `TraversalBlock` verde mas cercano dentro de su propio cono/rango
  (`ArmTuning.traversal_lock_max_range`/`traversal_lock_half_angle`/
  `traversal_lock_vertical_half_angle` — separado del rango de combate a proposito). Los bloques
  de dash se registran solos en el grupo `arm_dash_target` al nacer.
- **Marcador**: el mismo punto morado (`ArmMarker`) que usa el brazo en combate sigue al bloque
  marcado, flotando `traversal_marker_height` metros sobre su base.
- **Activacion**: al tap (`arm_attack`), empuja al jugador hacia el bloque con un dash forzado
  (`Player.force_dash`, reusa [[Dash y Airdash|PlayerDash]]) a lo largo de
  `ArmTuning.teleport_duration` segundos — no es un salto instantaneo, el viaje es visible y no
  pelea con la gravedad porque toma el mismo camino que cualquier otro dash forzado. Al llegar,
  activa el bloque (`TraversalBlock.activate()`, mismo efecto que golpearlo: dispara TODAS sus
  features activas, no solo el dash).
- **Costo**: gratis, no gasta taps ni entra en el cooldown de combate. Tiene su propio cooldown
  corto (`ArmTuning.traversal_cooldown_duration`, default 1s) para no encadenar bloques verdes
  en teletransportes instantaneos seguidos.

*(pendiente de probar en engine — no corrio headless ni se jugo todavia)*

## Intencion

En traversal, el brazo funciona como un agarre remoto. Puede engancharse a puntos, objetos o superficies validas para cortar una caida, corregir trayectoria o sostener al jugador por un instante. Hoy eso se resuelve solo para bloques de dash; agarres/objetos genericos son la direccion a futuro (ver Pendiente).

No reemplaza dash, airdash, salto, wall slide ni [[Cadenas]]. Los aumenta.

## Pseudo checkpoints

La idea clave: en secciones rapidas y caoticas, el brazo puede dar un punto de apoyo temporal.

Ejemplos de uso:

- Agarrarse a un punto antes de caer.
- Pausar un instante la trayectoria para leer la siguiente plataforma.
- Tirar de un objeto o interruptor sin aterrizar.
- Crear una respiracion corta entre dos acciones de alta velocidad.

## Diferencia con cadenas

| Sistema | Funcion |
|---|---|
| [[Cadenas]] | Swing/pendulo como ruta de traversal dedicada. |
| [[brazo-traversal|Brazo Traversal]] | Agarre corto, correctivo o de respiro, disponible como habilidad base. |

El brazo debe sentirse mas inmediato y tactico que las cadenas. Las cadenas pueden ser setpieces; el brazo es herramienta del jugador.

## Lock-on/targeting de traversal

Filtro propio de traversal, separado del lock-on pasivo de combate (ver Implementado): hoy solo
bloques de dash verdes. Pendiente para ampliar el filtro:

- Puntos de agarre validos.
- Objetos interactuables.
- Direccion pura si no hay target claro.

Regla: marcar un punto con el brazo no debe forzar movimiento automatico hacia enemigos como el lock-on de combos (los bloques de traversal no son enemigos, no aplica ahi).

## Costos y limites

- Cooldown propio: si, `traversal_cooldown_duration` (ver Implementado).
- No consume meter ni ningun otro recurso.
- Sin limite de usos en el aire.
- Los bloques de dash no filtran por mundo (no tienen `WorldMembership`) — el brazo no puede
  fallar por mundo equivocado hoy.
- Puede fallar por estar fuera del cono/rango de traversal; no hay chequeo de linea de vision
  (un bloque detras de una pared en rango igual se marca).

Pendiente decidir cuando se sumen puntos de agarre/objetos genericos: si consumen los mismos
costos que el bloque de dash o tienen los suyos propios.

## Relacion con mundos

El brazo puede conectar con [[World Switch]] mas adelante, pero no debe entrar antes de que H1 estabilice el feel base. Posibles direcciones:

- Puntos agarrables solo en Living o Dead.
- Objetos que se traen desde un mundo al otro.
- Uso cargado que active una interaccion de mundo.

## Relacionado

- [[Brazo]]
- [[Traversal]]
- [[Cadenas]]
- [[World Switch]]
- [[Bloques]]
