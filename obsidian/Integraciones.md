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
y asistentes. Si se agrega o quita una dependencia externa, se actualiza aca. *(2026-07-18)*

## Motor y arte

| Nombre | Que es | Uso en Egoist | Version |
|---|---|---|---|
| Godot | Motor de juego (Forward Plus, Jolt Physics) | Motor de V2, todo el runtime y las escenas | 4.7 stable |
| Blender | Modelado/animacion 3D | Pipeline de assets (greybox y arte propio desde H3, ver [[Blender Pipeline]]) | — |

## Plugins / addons de Godot

| Nombre | Que es | Uso en Egoist | Estado |
|---|---|---|---|
| LimboAI | Behavior Trees + HSM para Godot 4 (GDExtension drop-in, MIT) | Motor de decision de la IA de enemigos. Ver detalle abajo. | **En uso, v1.1.1** — `addons/limboai/` |

## Asistentes de desarrollo

| Nombre | Que es | Uso en Egoist |
|---|---|---|
| Claude (Claude Code) | Asistente de codigo/agente | Desarrollo, documentacion, boveda |
| Codex | Asistente de codigo de OpenAI (modelo por defecto `gpt-5.6-terra`) | Delegacion de tareas en paralelo/background desde Claude Code — investigacion, fixes puntuales, segunda opinion/revision de codigo |
| RTK | Proxy CLI que filtra/comprime la salida de comandos de terminal (`git`, `grep`, `ls`, etc.) antes de que llegue al contexto del asistente | Hook activo en Claude Code (`PreToolUse`), reduce tokens de sesion sin tocar el codigo del proyecto |

### Codex — detalle

- **Acceso**: CLI oficial (`@openai/codex`), logueado con cuenta ChatGPT.
- **Modelo**: `gpt-5.6-terra` fijado en `~/.codex/config.toml` (`model_reasoning_effort = "medium"`).
- **Integracion con Claude Code**: plugin `codex-plugin-cc` (marketplace `openai/codex-plugin-cc`). Expone comandos `/codex:review`, `/codex:adversarial-review`, `/codex:rescue`, `/codex:status`, `/codex:result`, `/codex:cancel` y el subagente `codex:codex-rescue`, que permiten delegarle trabajo a Codex sin salir de la sesion de Claude Code.
- **Alcance**: Codex no tiene visibilidad de la conversacion de Claude Code ni de quien lo invoca — solo recibe la tarea puntual que se le delega.

## LimboAI — detalle

- **Repositorio**: https://github.com/limbonaut/limboai
- **Que es**: combinacion de Behavior Trees y State Machines jerarquicas (HSM) para
  Godot 4. Tareas de BT escribibles en GDScript. Blackboard nativo. Debugger visual
  de ejecucion del arbol en runtime.
- **Distribucion**: GDExtension drop-in (Godot 4.6+, cubre 4.7). NO requiere recompilar
  el engine. Licencia MIT (arte CC-BY 4.0).
- **Por que se eligio**: el roster (varios arquetipos + jefes), la coordinacion de grupo y los
  perfiles data-driven piden un BT. Al ser drop-in (no fork del engine), el costo de integracion
  es bajo.
- **Que resuelve**: SOLO la capa de decision (estructura de arbol, blackboard, HSM de modo,
  debugger). **No toca** locomocion/pathfinding, steering, seleccion de target por utility,
  el telegraph, ni la coordinacion de grupo — esos son codigo propio.
- **Donde vive**: hojas `BTAction` / `BTCondition` en `enemies/ai/tasks/`, arbol en
  `EnemyLimboTreeBuilder`, blackboard en `EnemyAIBlackboard`, spec en `enemies/ai_spec/*.yaml`.

> [!tip] Backend unico de IA
> LimboAI es el motor de decision en uso (validado en engine el 2026-07-13). Todo comportamiento nuevo de IA se escribe como hoja del arbol; la FSM manual queda solo como fallback. Ver [[IA]].

## Relacionado

- [[IA]]
- [[Comportamientos]]
- [[Arquitectura Godot]]
