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

| Input                | Descripcion                                                                                                                |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| X X X X              | Swing horizontal, swing horizontal, estocada, estocada. La estocada extiende el brazo al frente (`thrust_reach`) y vuelve. |
| X X espera X X       | Izquierda a derecha, derecha a izquierda, vuelta completa, vuelta completa. El ultimo golpe empuja.                        |
| X cargado            | Dash hacia adelante que golpea todo. Rompe armadura.                                                                       |
| X cargado sweet spot | Todo lo que toca el dash explota despues y les impulsa hacia arriba.                                                       |
| Y cargado            | Launcher. Area pequena/media.                                                                                              |
| Y cargado sweet spot | Golpe hacia arriba que sube a los enemigos un poco. Despues te elevas con otro Y. Aumenta un poco el AOE.                  |

## Aereo

| Input                | Descripcion                                                                                                                                                                        |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| X X X                | Diagonal, diagonal, hacia abajo.                                                                                                                                                   |
| X espera X X         | Diagonal, doble vuelta con empuje hacia adelante. La primera vuelta te eleva un poco; el empuje final es un arco tuneable (`push`: velocidad + altura + cierre). *(2026-07-09)*    |
| X cargado            | Mismo dash que en el piso, pero en el aire.                                                                                                                                        |
| X cargado sweet spot | Igual que el terrestre. Las explosiones suben a los enemigos afectados como si fuera un launcher.                                                                                  |
| Y cargado            | Golpe hacia abajo que hace rebotar al enemigo. Implementado 2026-07-02: gasta 1 barra; te auto-lanza hacia arriba y spikea/rebota al enemigo hasta tu altura. Pendiente de probar. |
| Y cargado sweet spot | Doble rebote con los enemigos que alcance a dar. Sweet spot aun no implementado. El segundo rebote te sube mas a ti y a todos los enemigos afectados                               |

## Estado Godot

- Implementada como arma procedural hasta H3.
- Los swings mueven la mano alrededor del jugador (ver Mano orbital en [[Combate]]); la hoja va rigida, apuntando hacia afuera. *(2026-07-09)*
- Tap X/Y usa la misma cadena de combo terrestre/aérea; solo el cargado bifurca por slot. *(2026-07-09)*
- `SwordTuning` controla ventanas, angulos, dash cargado, launcher y el `push` (arco del empuje armado por `arm_push`). *(2026-07-09)*
- Habilidad especial de X cargado existe parcialmente por ventana de kill.
- La hoja brilla al cargar un ataque (glow de carga, ver [[Combate]]). *(2026-07-06)*

### Tuneables de coreografia

| Knob | Que mueve |
|---|---|
| `thrust_reach` | Metros que el brazo extiende sobre `hand_radius` en el pico de la estocada. |
| `air_diagonal_yaw` | Diagonal aerea: cuanto cruza la mano por delante del jugador. |
| `air_diagonal_pitch` | Diagonal aerea: cuanto baja la mano al cruzar. Igualarlo al yaw da una diagonal a 45°. |
| `combo_swing_angle` | Arco de los swings 1-2 del combo terrestre. |
| `strike_angle` | Arco del golpe Y basico, launcher y cargada aerea. |
| `air_finisher_angle` | Arco del hachazo vertical del finisher aereo. |
| `charged_fallback_angle` | Swing degradado del X cargado sin barra. |

## Pendiente H1

- Tunear `sword_tuning.tres`.
- Validar que hold no dispare tap si se decide carga exclusiva.
- Confirmar dano distinto por golpes finales/cargados.
- Probar reset aereo por kill con [[Reset Aereo por Kill]].

## Relacionado

- [[Armas]]
- [[Combate]]
