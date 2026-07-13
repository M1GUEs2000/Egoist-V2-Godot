---
title: Smoke Test
tags:
  - egoist
  - godot
  - metodologia
  - test
status: active
---

# Smoke Test

Cómo se usan los smoke tests headless (`world/smoke_test.gd` y los `*_smoke_test.gd` por
dominio) en este proyecto. Se lee **antes de tocar lógica core**: el smoke se corre en casi
toda petición que cambia comportamiento, así que su regla tiene que estar clara. Complementa
las reglas de cierre de `METODOLOGIA.md`.

> [!important] Regla de oro
> El smoke test verifica **lógica invariante, nunca valores de tuning**. Si el valor esperado
> de un `assert` vive en un `.tres`, ese assert **no va**: es feel, y el feel se valida jugando
> (regla madre: "el feel no se verifica headless").

## Qué verifica y qué no

| Va al smoke | No va al smoke |
|---|---|
| Contratos de lógica que **no se ven jugando** y que un cambio de código puede romper en silencio. | Números de tuning (`.tres` / exports). |
| Booleano / estructural: "una rutina cancelada apaga su hitbox", "el push no se filtra al golpe siguiente", "el launcher lanza ANTES del daño", "un flag no-interrumpible bloquea el input". | Valores exactos de feel: `stun.grounded == 0.35`, `swing_time == 0.3`, ángulos, daños. |

Para tocar tuning en un assert solo valen invariantes que **sobreviven al tuneo**:

- Existencia: `!= null`, `> 0`.
- Relaciones de diseño: `stun.airborne >= stun.grounded` (el juggle dura más en el aire).

Nunca el número exacto.

## Dónde vive

- **Por dominio** en su `*_smoke_test.gd` (`world/combat_smoke_test.gd` para combate).
- **`world/smoke_test.gd`** queda solo para regresiones **transversales** (que cruzan sistemas).

## Cuándo se corre

Solo al tocar **lógica core**: motores compartidos (`WeaponBase`, `Player`, `EnemyBase`,
`run_combo_chain`, `Hitbox` / `Hurtbox`).

**Nunca** para cambios de tuning, arte, escenas ni UI-only. Para tunear, ni se toca: el feel se
aprueba jugando. El costo (~30 s) es del import de Godot + LimboAI, no del test; por eso no se
corre porque sí.

## Cuándo se edita

- Al agregar o cambiar lógica, su assert de contrato entra o se ajusta **en el mismo commit**.
- Si un assert rompe por un tuneo → **se borra** (no se actualiza el número): que existiera era
  el bug.

## Cuando falla, una sola pregunta

¿Esto es un contrato de lógica o un valor de feel?

- **Lógica rota** → se arregla el código.
- **Valor de feel** → se borra el assert.

## Relacionado

- [[Arquitectura Godot]]
- [[README]]
