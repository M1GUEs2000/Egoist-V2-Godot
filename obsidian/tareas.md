---
title: Tareas
tags:
  - egoist
  - tareas
  - home
status: active
---

# Tareas

Board de subtareas con el plugin **Tasks**. El seguimiento tiene **dos niveles**:

- **Nodos (Sistemas)** — los sistemas que ya existen (Combate, Enemigos...), con su estado E0-E4 en [[Sistemas.base]] y su hito en [[Hitos.base]]. Son el dueño del trabajo.
- **Subtareas** — el detalle, viven como lineas `- [ ]` en [[backlog]]. La **etapa** de cada tarea es su casilla y sigue el mismo ciclo que los estados del nodo:

| Casilla | Etapa | Estado |
|---|---|---|
| `[ ]` | Por implementar | E0 |
| `[/]` | Implementacion | E1 |
| `[t]` | Tuning | E2 |
| `[f]` | Tuning final | E3 |
| `[x]` | Completada | E4 |

Cambiar de etapa = **clic en la casilla** (cicla en orden). Una tarea puede llevar **varios nodos** como `[[wikilink]]` al final.

## Board por etapa

```tasks
group by function const m = {' ': '1 · Por implementar', '/': '2 · Implementacion', 't': '3 · Tuning', 'f': '4 · Tuning final', 'x': '5 · Completada'}; return m[task.status.symbol] ?? ('9 · ' + task.status.name);
sort by description
```

## Solo lo activo (sin completadas)

```tasks
not done
group by function const m = {' ': '1 · Por implementar', '/': '2 · Implementacion', 't': '3 · Tuning', 'f': '4 · Tuning final'}; return m[task.status.symbol] ?? ('9 · ' + task.status.name);
sort by description
```

## Por nodo

Para ver las tareas de un nodo, abri su nota y mira los **backlinks** (cada tarea lo linkea), o pega un bloque como este cambiando el nombre:

````text
```tasks
not done
description includes Mazo
```
````

Ejemplo en vivo (Mazo):

```tasks
not done
description includes Mazo
```

## Relacionado

- [[backlog]] — la fuente editable de las tareas
- [[Sistemas.base]] — sistemas por estado E0-E4
- [[Hitos.base]] — sistemas por hito
- [[hitos]]
- [[ideas]]
- [[Metodologia V2]]
