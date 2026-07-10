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
status: planned
system_status: E0
hito: H2
---

# Brazo Traversal

Uso del [[Brazo]] fuera del combate o durante plataformeo. Es una herramienta para agarrar cosas, estabilizar rutas rapidas y dar pseudo checkpoints momentaneos cuando el jugador necesita respirar.

## Intencion

En traversal, el brazo funciona como un agarre remoto. Puede engancharse a puntos, objetos o superficies validas para cortar una caida, corregir trayectoria o sostener al jugador por un instante.

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

Puede compartir la logica del lock-on pasivo del [[Brazo]], pero con filtros de traversal:

- Puntos de agarre validos.
- Objetos interactuables.
- Enemigos si el jugador esta en combate o cerca de entrar a combate.
- Direccion pura si no hay target claro.

Regla: marcar un punto con el brazo no debe forzar movimiento automatico hacia enemigos como el lock-on de combos.

## Costos y limites

Pendiente decidir:

- Si el uso de traversal tiene cooldown propio.
- Si consume carga, stamina o meter cuando salva caidas.
- Si hay limite de usos antes de tocar suelo.
- Si ciertos puntos de agarre pertenecen a un mundo especifico.
- Si el brazo puede fallar por mundo equivocado, distancia o linea de vision.

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
