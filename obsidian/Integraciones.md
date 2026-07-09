---
title: Integraciones
tags:
  - egoist
  - integraciones
  - home
status: active
---

# Integraciones

Registro de todo lo externo que usa el proyecto: herramientas, motores, plugins
y asistentes. Si se agrega o quita una dependencia externa, se actualiza aca. *(2026-07-08)*

## Motor y arte

| Nombre | Que es | Uso en Egoist | Version |
|---|---|---|---|
| Godot | Motor de juego (Forward Plus, Jolt Physics) | Motor de V2, todo el runtime y las escenas | 4.7 stable |
| Blender | Modelado/animacion 3D | Pipeline de assets (greybox y arte propio desde H3, ver [[Blender Pipeline]]) | — |

## Plugins / addons de Godot

| Nombre | Que es | Uso en Egoist | Estado |
|---|---|---|---|
| LimboAI | Behavior Trees + HSM para Godot 4 (GDExtension drop-in, MIT) | Motor de decision de la IA de enemigos (reemplaza la FSM escrita a mano). Ver detalle abajo. | **Instalado v1.1.1** — `addons/limboai/` |

## Asistentes de desarrollo

| Nombre | Que es | Uso en Egoist |
|---|---|---|
| Claude (Claude Code) | Asistente de codigo/agente | Desarrollo, documentacion, boveda |
| Codex | Asistente de codigo | Desarrollo |

## LimboAI — detalle

- **Repositorio**: https://github.com/limbonaut/limboai
- **Que es**: combinacion de Behavior Trees y State Machines jerarquicas (HSM) para
  Godot 4. Tareas de BT escribibles en GDScript. Blackboard nativo. Debugger visual
  de ejecucion del arbol en runtime.
- **Distribucion**: GDExtension drop-in (Godot 4.6+, cubre 4.7). NO requiere recompilar
  el engine. Licencia MIT (arte CC-BY 4.0).
- **Por que se eligio**: la IA de enemigos ya es un priority-selector escrito a mano
  (ver [[Comportamientos]]); el roster futuro (varios arquetipos + jefes), la coordinacion
  de grupo y los perfiles data-driven la empujan a BT. Al ser drop-in (no fork del engine),
  el costo de integracion que antes lo desaconsejaba desaparece. Se adopta desde el inicio
  para NO tener que migrar despues.
- **Que resuelve**: SOLO la capa de decision (estructura de arbol, blackboard, HSM de modo,
  debugger). **No toca** locomocion/pathfinding, steering, seleccion de target por utility,
  el telegraph, ni la coordinacion de grupo — esos son codigo propio.
- **Plan de adopcion**: el spec destino vive en el codigo, en `enemies/ai_spec/*.yaml`
  (blackboard, hojas BTAction/BTCondition, forma del arbol, perfiles). El port se hace
  DESPUES del refactor de decouple (que la decision emita intent y la locomocion lo ejecute),
  para no meter spaghetti en un BTAction gigante.

> [!tip] Instalado
> LimboAI v1.1.1 esta instalado en `addons/limboai/` (GDExtension, se carga automaticamente). El codigo todavia no esta portado al BT. Ver pendientes en [[IA]].

## Relacionado

- [[IA]]
- [[Comportamientos]]
- [[Arquitectura Godot]]
