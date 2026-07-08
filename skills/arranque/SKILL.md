---
name: arranque
description: >
  Arranca una sesion de trabajo en Egoist V2 Godot leyendo el CLAUDE.md y la
  METODOLOGIA.md del repo, y la boveda de Obsidian
  (D:/Proyectos/Egoist/Egoist-V2-Godot-main/obsidian). Lee el README y la
  Arquitectura Godot para tener el mapa general, y si el usuario pidio un nodo
  especifico tambien lo lee antes de empezar. Usar cuando el usuario diga
  "arranque", "arranca la sesion", "empecemos con Egoist", "leamos la boveda",
  "dame contexto de Egoist V2", o invoque /arranque (con o sin el nombre de un
  nodo como argumento, ej: /arranque Combate).
---

# Skill: arranque

Carga de contexto inicial para trabajar en Egoist V2 (Godot). No modifica nada,
solo lee la brujula del repo, la boveda y reporta un resumen para arrancar la
sesion informado.

Rutas base:
- Repo: `D:/Proyectos/Egoist/Egoist-V2-Godot-main/`
- Boveda: `D:/Proyectos/Egoist/Egoist-V2-Godot-main/obsidian/`

---

## Paso 1 — Detectar si se pidio un nodo especifico

Revisar el mensaje/argumento con el que se invoco `/arranque` (ej: `/arranque Combate`,
"arranca y dame contexto de Traversal").

- Si se menciona un nodo, area o sistema puntual (Combate, Traversal, Enemigos, IA,
  Armas, Areas, Historia, Exploracion, Animacion, Blender Pipeline, un hito como
  H1, etc.) → guardarlo para el Paso 5.
- Si no se menciona nada especifico → solo se hace la lectura base (CLAUDE.md +
  METODOLOGIA.md + README + Arquitectura) y se salta el Paso 5.

## Paso 2 — Leer el CLAUDE.md del repo

Leer `CLAUDE.md` (raiz del repo Godot). Es la brujula de entrada: senala donde
vive la fuente de verdad, el orden de lectura minimo y las skills instaladas
para gameplay/UI/Obsidian.

## Paso 3 — Leer la METODOLOGIA.md del repo

Leer `METODOLOGIA.md` (raiz del repo Godot). Define el ciclo de estados E0-E4,
responsabilidades y el flujo de cierre de una tarea — necesario antes de tocar
codigo o proponer cambios.

## Paso 4 — Leer el README y la arquitectura de la boveda

1. Leer `obsidian/README.md`. Ahi esta la tabla de "Estado actual" (motor, hito
   activo), la tabla de navegacion por nodos y las "Reglas madre" (avisos
   `[!important]` / `[!warning]` que aplican a todo el proyecto).
2. Leer `obsidian/Arquitectura Godot.md`. Ahi esta la estructura real de
   carpetas del repo Godot, el indice de nodos de gameplay con sus subnotas,
   los patrones obligatorios y el mapa de equivalencias Unity V1 → Godot V2.

## Paso 5 — Leer el nodo pedido (solo si el Paso 1 detecto uno)

1. Ubicar el nodo en la tabla de navegacion del README o en el indice de la
   Arquitectura para saber la ruta exacta (ej: Combate → `Gameplay/Combate/Combate.md`).
2. Leer la nota indice de ese nodo.
3. Si el usuario pidio una subnota puntual (ej: "Meter" dentro de Combate, o
   "World Switch" dentro de Traversal), leer tambien esa subnota especifica.
4. Si el nodo pedido es un hito (`H0`, `H1`, etc.) en vez de un sistema de
   gameplay, leerlo desde `obsidian/Tareas/`.

Si el nodo mencionado no se encuentra en ninguna tabla, decirlo directamente al
usuario en vez de asumir o inventar una ruta.

## Paso 6 — Reportar el contexto cargado

Cerrar con un resumen corto (no repetir el contenido completo de los archivos):

```
📖 Contexto cargado: Egoist V2 Godot
   CLAUDE.md + METODOLOGIA.md: leidos
   Hito activo: [hito de la tabla Estado actual]
   Reglas madre relevantes: [si aplica alguna al pedido del usuario]
   Nodo leido: [nombre del nodo] — [una linea de que cubre] (si se pidio uno)

Listo para arrancar.
```

Si el usuario no pidio nodo especifico, omitir la linea "Nodo leido" y en su
lugar preguntar en que sistema o tarea quiere trabajar.

---

## Reglas

- Esta skill es de solo lectura: nunca editar archivos del repo, la boveda ni
  el codigo durante el arranque.
- No leer toda la boveda de punta a punta — solo CLAUDE.md, METODOLOGIA.md,
  README, Arquitectura y el nodo pedido (mas su subnota si el usuario la nombro).
- Si el nombre del nodo es ambiguo (ej: coincide con mas de una entrada),
  preguntar cual antes de leer.
- Las notas de la boveda estan en español; responder en español.