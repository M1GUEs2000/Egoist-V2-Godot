---
title: Estados de Combate Enemigo
tags:
  - egoist
  - enemigo
  - combate
status: active
system_status: E2
hito: H1
---

# Estados de Combate Enemigo

Estados mecanicos compartidos por cualquier enemigo.

| Estado | Significado |
|---|---|
| `NORMAL` | Actua y recibe dano normal. |
| `ARMORED` | No se lanza ni se parrea; la armadura tiene vida propia y sube el threshold de stun (`armor_stun_threshold`). *(2026-07-07)* |
| `STUNNED` | IA congelada; entra solo si `stun_power` supera el threshold efectivo del enemigo, y la duracion la define quien ataca. |
| `AIRBORNE` | En el aire por launcher, push, slam o bounce. |
| Parry vulnerable | Ventana cian donde recibe dano multiplicado. |
| Dead | Muere, puede disparar `WorldSwitchTrigger.ON_DEATH`. |

## Armadura

- `armored` define si inicia armado.
- `armor_hits_to_break` define cuantos golpes aguanta.
- El golpe que rompe armadura debe poder aplicar stun si corresponde.
- Mientras esta armado, el enemigo usa `armor_stun_threshold` en vez de `stun_threshold`: la armadura es resistencia al stun, no inmunidad. *(2026-07-07)*

## Resistencia al stun

El criterio es universal (igual que el player, ver [[Combate]]): la fuente manda `StunSettings` con `power`; el receptor solo queda stunned si `power >= _effective_stun_threshold()`. La entrada normal es `receive_stun` / `try_apply_stun`; `apply_stun` queda como aplicacion directa que ignora resistencia. Los ataques enemigos con `StunSettings` tambien llaman `receive_stun` en su target (`MeleeAttack`). *(2026-07-07)*

## Aereo

- `launch`: sube y queda suspendido por el hang time del golpe; cae al terminar. La suspension la manda el hang/stun, no `airborne_max_time` (ese es solo el tope de seguridad de caida). *(2026-07-06)*
- `slam`: cae fuerte.
- `push`: arco balistico. Velocidad, altura y cierre del arco los define QUIEN ataca via `PushSettings`, no el enemigo: cada arma/ataque empuja distinto. *(2026-07-06)*
- `slam_bounce`: baja y rebota hasta una altura objetivo.

> [!important] El golpe frena el momentum
> Un golpe que aplica stun mientras el enemigo vuela (por `launch` o `push`) cancela su `velocity`: queda quieto, suspendido durante el stun, y cae al terminar. *(2026-07-06)*

## Relacionado

- [[Combate]]
- [[Espada]]
- [[Armored Enemy]]

