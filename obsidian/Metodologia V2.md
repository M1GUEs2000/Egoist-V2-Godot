---
title: Metodologia V2
tags:
  - egoist
  - godot
  - metodologia
status: active
hito: H0
---

# Metodologia V2

La verdad operativa vive en esta boveda y en `METODOLOGIA.md` del repo Godot. La boveda vieja ya no se edita para planificar V2.

## Ciclo E0-E4

| Estado | Nombre | Criterio |
|---|---|---|
| E0 | Inutilizable | Stub o sistema que no cumple su funcion. |
| E1 | Utilizable, falta tunear mucho | Funciona mecanicamente, pero los knobs/feel aun son dudosos. |
| E2 | Utilizable, falta tunear | Knobs correctos existen; falta iterar jugando. |
| E3 | Ultimos detalles | Feel aprobado por Tutupa; faltan juice o edge cases. |
| E4 | Lista | Aprobada jugando; solo bugs. |

## Responsabilidades

| Quien | Que hace |
|---|---|
| Codex | Codigo Godot, refactors, pruebas headless, smoke tests, notas tecnicas. |
| Tutupa | Diseno, tuning en `.tres`, editor/playtest, Blender, aprobacion de feel E3/E4. |

## Flujo de cierre

1. Verificar headless.
2. Correr smoke test si toca core.
3. Probar en `test_scene` cuando toque feel.
4. Actualizar estado E0-E4 si cambio.
5. Actualizar esta boveda si cambia la verdad del proyecto.
6. Commit al cerrar una feature que funcione.

## Reglas anti-regresion

- No renombrar `@export` al pasar: resetea valores en escenas y `.tres`.
- No crear un singleton si basta un nodo hijo.
- No hardcodear tunables nuevos.
- No portar Unity literal si Godot tiene un patron nativo mas simple.
- Si un sistema E3/E4 se modifica, baja de estado hasta volver a probarse.

## Relacionado

- [[Arquitectura Godot]]
- [[Workflow]]
- [[Deuda Tecnica]]

