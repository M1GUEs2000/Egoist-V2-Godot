---
title: Espada
tags:
  - egoist
  - gameplay
  - arma
  - combate
status: active
system_status: E2
hito: H1
---

# Espada

Arma base / equilibrada. Velocidad media. Sirve para mantener el flujo del combate. En Godot V2 vive en `combat/weapons/sword/` con `Sword` y `SwordTuning`.

**Habilidad especial:** si matas a un enemigo con X cargado, recuperas 1 barra de meter para usar de nuevo.

## Terrestre

| Input | Descripcion |
|---|---|
| X X X X | Swing horizontal, swing horizontal, estocada, estocada. |
| X X espera X X | Izquierda a derecha, derecha a izquierda, vuelta completa, vuelta completa. |
| X cargado | Dash hacia adelante que golpea todo. Rompe armadura. |
| X cargado sweet spot | Todo lo que toca el dash explota despues. |
| Y cargado | Launcher. Area pequena/media. |
| Y cargado sweet spot | Golpe hacia arriba que sube a los enemigos un poco. Despues te elevas con otro Y. Aumenta un poco el AOE. |

## Aereo

| Input | Descripcion |
|---|---|
| X X X | Diagonal, diagonal, hacia abajo. |
| X espera X X | Diagonal, doble vuelta con empuje hacia adelante. La primera vuelta te eleva un poco; el empuje final es un arco tuneable (`air_push`: velocidad + altura + cierre). *(2026-07-06)* |
| X cargado | Mismo dash que en el piso, pero en el aire. |
| X cargado sweet spot | Igual que el terrestre. Las explosiones te mantienen en el aire a ti y a los enemigos. |
| Y cargado | Golpe hacia abajo que hace rebotar al enemigo. Implementado 2026-07-02: gasta 1 barra; te auto-lanza hacia arriba y spikea/rebota al enemigo hasta tu altura. Pendiente de probar. |
| Y cargado sweet spot | Doble rebote con los enemigos que alcance a dar. Sweet spot aun no implementado. |

## Estado Godot

- Implementada como arma procedural hasta H3.
- `SwordTuning` controla ventanas, angulos, dash cargado, launcher y el `air_push` (arco del empuje aereo). *(2026-07-06)*
- Habilidad especial de X cargado existe parcialmente por ventana de kill.
- La hoja brilla al cargar un ataque (glow de carga, ver [[Combate]]). *(2026-07-06)*

## Pendiente H1

- Tunear `sword_tuning.tres`.
- Validar que hold no dispare tap si se decide carga exclusiva.
- Confirmar dano distinto por golpes finales/cargados.
- Confirmar reset aereo por kill.

## Relacionado

- [[Armas]]
- [[Combate]]

