---
title: Animacion Mazo
tags:
  - egoist
  - gameplay
  - animacion
  - combate
status: active
system_status: E0
hito: H1
---

# Animacion Mazo

Plan de clips UAL para el combate de [[Mazo]] sobre el player. Hoy el Mazo es 100% procedural (swings por quaternion en `Hand`, ver `combat/weapons/mace/mace.gd`); este plan lo pasa a clips reales del maniqui UAL2. Ver [[Player]] para locomocion/salto/slide.

El Mazo no tiene clips propios: todo sale de tramos de `Sword_Heavy_Combo` (misma clip que usa [[Animacion Espada]] para los cargados), duración total 4.333 s.

## Combo terrestre (tap)

Motor: `run_combo_chain` en `mace.gd`, combo de 3 pasos (`STEP_COUNT`) + rama de espera con pasos extra (`WAIT_BRANCH_EXTRA_STEPS`) — ver [[Mazo]] para la descripción de diseño (swing, swing, smash AOE).

| Input | Tramos de `Sword_Heavy_Combo` |
|---|---|
| Tap tap tap (sin espera) | 0.00–0.70 s → 1.50–2.10 s → 2.10 s hasta el final |
| Tap tap (espera) tap tap | 0.00–0.70 s → 1.50–2.10 s → 2.10–3.10 s → 2.10 s hasta el final |

> [!warning] Verificar antes de implementar
> El plan de arriba lista 4 tramos para la rama de espera, pero el código actual arma esa rama como `STEP_COUNT (3) + WAIT_BRANCH_EXTRA_STEPS (2)` = 5 pasos. Revisar `run_combo_chain`/`_begin_ground_step` en `mace.gd` antes de cablear los tramos: falta decidir si dos pasos comparten tramo, si `WAIT_BRANCH_EXTRA_STEPS` cambia a 1, o si el mapeo de pasos a tramos es distinto al de la Espada.

## Cargados

| Move | Tramo de `Sword_Heavy_Combo` |
|---|---|
| X cargado en piso (vueltas — nivel de carga) | 1.30–2.00 s, en loop según cuántas vueltas dé la carga |
| X cargado en aire | 2.40–2.70 s |
| Y cargado en piso | 0.90–1.30 s |
| Y cargado en aire | 2.40–3.00 s |

## Relacionado

- [[Player]]
- [[Animacion]]
- [[Mazo]]
- [[Combate]]
- [[Animacion Espada]]
