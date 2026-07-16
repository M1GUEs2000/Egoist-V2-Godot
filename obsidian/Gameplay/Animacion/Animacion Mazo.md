---
title: Animacion Mazo
tags:
  - egoist
  - gameplay
  - animacion
  - combate
status: active
system_status: E1
hito: H1
---

# Animacion Mazo

Clips UAL para el combate de [[Mazo]] sobre el player. Implementado: `mace.gd` emite `visual_clip_started` con los tramos de `Sword_Heavy_Combo` (constantes `HEAVY_*` en el script) y `PlayerAnimationController` los reproduce escalados a la duracion mecanica (`swing_time` / `charged_spin_time`). Los swings por quaternion en `Hand` siguen siendo el motor de hitboxes: la animacion es solo visual. El combo aereo X (jab + cabezazo) no tiene tramos asignados y queda solo procedural. Ver [[Player]] para locomocion/salto/slide.

El Mazo no tiene clips propios: todo sale de tramos de `Sword_Heavy_Combo` (misma clip que usa [[Animacion Espada]] para los cargados), duración total 4.333 s.

## Combo terrestre (tap)

Motor: `run_combo_chain` en `mace.gd`, combo de 3 pasos (`STEP_COUNT`) + rama de espera con pasos extra (`WAIT_BRANCH_EXTRA_STEPS`) — ver [[Mazo]] para la descripción de diseño (swing, swing, smash AOE).

| Input | Tramos de `Sword_Heavy_Combo` |
|---|---|
| Tap tap tap (sin espera) | 0.00–0.70 s → 1.50–2.10 s → 2.10 s hasta el final |
| Tap tap (espera) tap tap | 0.00–0.70 s → 1.50–2.10 s → 2.10–3.10 s → 2.10 s hasta el final |

> [!note] Resuelto al implementar
> El plan listaba 4 tramos para la rama de espera de 5 pasos (`STEP_COUNT 3 + WAIT_BRANCH_EXTRA_STEPS 2`). Decision: los smashes intermedios (pasos 3-4 de la rama espera) **comparten** el tramo corto 2.10–3.10 y el finisher (paso 3 sin espera / paso 5 con espera) remata con 2.10–final. `WAIT_BRANCH_EXTRA_STEPS` no cambia. Ver `_play_ground_step_visual` en `mace.gd`.

## Cargados

| Move | Tramo de `Sword_Heavy_Combo` |
|---|---|
| X cargado en piso (vueltas — nivel de carga) | 1.30–2.00 s, en loop según cuántas vueltas dé la carga |
| X cargado en aire | 2.40–2.70 s (la vuelta congelante del sweet spot reusa 1.30–2.00, decidido al implementar) |
| Y cargado en piso | 0.90–1.30 s |
| Y cargado en aire | 2.40–3.00 s |

## Relacionado

- [[Player]]
- [[Animacion]]
- [[Mazo]]
- [[Combate]]
- [[Animacion Espada]]
