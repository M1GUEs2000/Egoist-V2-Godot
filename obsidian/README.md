---
title: Egoist V2 - Boveda Godot
tags:
  - egoist
  - godot
  - home
aliases:
  - Inicio
  - Home
status: active
engine: Godot 4.7
---

# Egoist V2

> [!abstract] Concepto
> Hack and slash 3D isometrico con traversal, plataforming y dos mundos. El jugador es un neutro, ni vivo ni muerto, que busca revivir atravesando una isla donde la vida y la muerte se mezclan.

Esta es la boveda nueva del proyecto Godot. La boveda vieja queda como archivo historico de intencion; esta boveda es la fuente operativa para V2.

## Estado actual

| Area | Estado |
|---|---|
| Motor | Godot 4.7, Forward Plus, Jolt Physics |
| Codigo | GDScript tipado estatico |
| Main scene | `res://world/test_scene.tscn` |
| Hito activo | [[H1 - Vertical Slice]] |
| Fuente historica | `C:/Users/Tutupa/Documents/Proyectos/Egoist/Boveda` |
| Referencia tecnica | `C:/Users/Tutupa/Documents/Proyectos/Egoist/Unity/Egoist V1` |

## Navegacion

La boveda se navega por nodos. Primero se lee este README, despues [[Arquitectura Godot]] para entender el mapa general, y luego se entra al nodo especifico del trabajo. Cada nodo grande usa carpeta + nota indice con el mismo nombre, por ejemplo `Gameplay/Armas/Armas.md` o `Gameplay/Enemigos/Enemigos.md`.

| Nodo | Que contiene |
|---|---|
| [[Arquitectura Godot]] | Estructura real del repo, mapa Unity V1 a Godot V2 y contratos tecnicos. |
| [[Integraciones]] | Dependencias externas: Godot, Blender, LimboAI, Claude, Codex. |
| [[Metodologia V2]] | Flujo para crear, modificar, borrar y clasificar sistemas E0-E4. |
| [[Matriz Vault Unity Godot]] | Matriz de migracion por sistema: diseno viejo, referencia Unity y modulo Godot. |
| [[Combate]] | Slots X/Y, espada, hitbox/hurtbox, meter, parry, input feel. |
| [[Traversal]] | World switch, dash, salto, airdash, bloques, cadenas y momentum. |
| [[Brazo]] | Habilidad permanente: puño remoto con lock-on pasivo para combate y traversal. |
| [[Enemigos]] | Identidad, estados, salud, armadura, mundo y objetos golpeables. |
| [[IA]] | FSM, percepcion, persecucion, ataques y ecosistema vivo. |
| [[Armas]] | Roadmap de armas y personalidad por slot. |
| [[Areas]] | Playa, Castillo, Averno y Final. |
| [[Historia]] | Mascaras, NPCs, plot twist y finales. |
| [[Exploracion]] | Runas, consumibles, secretos y recompensas opcionales. |
| [[Animacion]] | Import/retarget Godot, Mixamo placeholder y animaciones propias H3. |
| [[Blender Pipeline]] | Regla de arte, targets tecnicos y workflow por asset. |
| [[H0 - Fundacion]] | Fundacion tecnica Godot. |
| [[H1 - Vertical Slice]] | Backlog activo: 10 minutos jugables de Playa con Espada. |
| [[Pendientes e Ideas]] | Lugar unico de lo que todavia no existe: pendientes decididos e ideas potenciales. |
| [[Roadmap Futuro]] | H2-H5 y v2.0, fuera del backlog activo. |

## Reglas madre

> [!important]
> El world switch ya no vive en dodge por default. Se gana por triggers: pickup, muerte, modificador de accion, HUD o especiales.

> [!warning]
> Cero arte final antes de H3. H1 se gana con feel, greybox y claridad mecanica.

## Bases

- [[Sistemas.base]]: vista de notas por estado E0-E4.
- [[Tareas.base]]: vista de tareas/hitos por estado.

## Relacionado

- [[Arquitectura Godot]]
- [[H1 - Vertical Slice]]
- [[Decisiones Congeladas]]
