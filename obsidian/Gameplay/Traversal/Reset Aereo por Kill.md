---
title: Reset Aereo por Kill
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
  - combate
status: active
system_status: E1
hito: H1
---

# Reset Aereo por Kill

Sistema puente entre combate y traversal. Vive en `player/player_air_kill_reset.gd` como nodo hijo `AirKillReset` del `Player`.

## Responsabilidad

- Si el jugador mata estando en el aire, resetea recursos aereos:
  - doble salto (`restore_double_jump`)
  - airdash (`restore_airdash`)
  - secuencia de reduccion de caida por cargas aereas
- Si el jugador empieza a cargar un ataque en el aire, reduce solo la velocidad vertical negativa (`Player.vertical_velocity`), sin tocar momentum horizontal (`bump_velocity`) ni usar `hover`.

## Carga aerea y caida

La carga aerea no sostiene al jugador por tiempo. Solo modifica la caida al cruzar el umbral de carga en `PlayerCombat`:

| Uso en la misma vida aerea | Reduccion default | Ejemplo con `vertical_velocity = -20` |
|---|---:|---:|
| 1 | 100% | `0` |
| 2 | 80% | `-4` |
| 3 | 50% | `-10` |
| 4+ | 10% | `-18` |

El tuning vive en `PlayerTuning.air_charge_fall_reduction_steps`, instancia real `data/player_tuning.tres`:

```gdscript
Array[float]([1.0, 0.8, 0.5, 0.1])
```

Al agotarse la lista se repite el ultimo valor. Si el jugador esta subiendo (`vertical_velocity >= 0.0`) no se corta la subida.

## Integracion

- `PlayerCombat` detecta el inicio de carga por `InputBuffer.charge_progress() >= 1.0` y llama `Player.apply_air_charge_fall_control()` una vez por press.
- `WeaponBase.register_weapon_hit(..., died)` llama `Player.apply_air_kill_reset()` si el golpe mato y el player esta en aire.
- `Player._physics_process` resetea la secuencia al tocar suelo.

## Estado

E1. Implementado con knobs y asserts en `world/smoke_test.gd`, pero falta:

- Correr Godot/headless y confirmar `SMOKE OK`.
- Probar jugando que la secuencia `100% -> 80% -> 50% -> 10%` corta el abuso de cargas sin apagar el flow.
- Ajustar `air_charge_fall_reduction_steps` en `player_tuning.tres`.

## Relacionado

- [[Launcher y Aire]]
- [[Dash y Airdash]]
- [[Combate]]
- [[hitos]]
