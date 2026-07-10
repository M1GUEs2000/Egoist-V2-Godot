---
title: Tareas
tags:
  - egoist
  - tareas
  - home
status: active
---

# Tareas

Hub de navegacion de las subtareas del proyecto. El seguimiento tiene **dos niveles**:

- **Nodos (Sistemas)** — los sistemas que ya existen (Brazo, Combate, Enemigos...), gobernados por [[Sistemas.base]]. Ahi se ve cada nodo con su estado E0-E4. El nodo es el **dueño**: de aca sale el conteo ("Brazo tiene 3 pendientes").
- **Subtareas** — el detalle del trabajo. Cada subtarea vive en **una sola** de las tres tablas de abajo (el archivo *es* el estado). Puede pertenecer a **uno o mas nodos**.

## Los nodos de Tareas

Todo el seguimiento vive en cinco nodos (carpeta `Tareas/`), nada mas:

| Nodo | Que contiene |
|---|---|
| [[tareaspendientes]] | Subtareas decididas, todavia no empezadas. |
| [[tareasenprogreso]] | Subtareas en construccion o tuneo activo. |
| [[tareascompletadas]] | Subtareas terminadas (historial). |
| [[hitos]] | Los hitos H0-H5 en un solo lugar: meta, puerta de salida y roadmap. |
| [[ideas]] | Ideas potenciales, no comprometidas (pueden no entrar). |

Las tres tablas de subtareas tienen columnas iguales: **Tarea · Qué falta · Nodo(s)**. El **estado** lo dice el archivo (no hay columna Estado). El **hito** sale del nodo (cada nodo lleva su `hito` en el frontmatter).

## Como se usa

- **Ver las tareas de un nodo**: buscar el wikilink del nodo (ej. `[[Brazo]]`) dentro de la tabla. Salen sus filas con Tarea y Qué falta.
- **Mover de estado**: cortar la fila de un archivo y pegarla en el otro. Nunca vive en dos a la vez — esa es la unica fuente de verdad del estado, sin drift.
- **Una tarea, varios nodos**: si toca a mas de un sistema, se listan todos en Nodo(s) (ej. `[[Stun]], [[Enemigos]]`).

> [!important]
> Tunear valores y "probar jugando" de un sistema ya implementado **son subtareas** (van en [[tareasenprogreso]]), no parte silenciosa del estado del nodo.

## Relacionado

- [[Tareas.base]] — las 3 tablas por estado como base navegable
- [[Sistemas.base]] — sistemas por estado E0-E4
- [[Hitos.base]] — sistemas por hito
- [[hitos]]
- [[ideas]]
- [[Metodologia V2]]
