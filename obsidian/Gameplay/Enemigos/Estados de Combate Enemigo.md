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
| `ARMORED` | No se lanza ni se parrea; la armadura tiene vida propia y sube el threshold de stun. Detalle en [[Stun]]. |
| `STUNNED` | IA congelada; entra solo si el ataque supera el threshold efectivo del enemigo, y la duracion la define quien ataca. Detalle en [[Stun]]. |
| `AIRBORNE` | En el aire por launcher, push, slam o bounce. |
| Parry vulnerable | Ventana cian donde recibe dano multiplicado. |
| Dead | Muere, puede disparar `WorldSwitchTrigger.ON_DEATH`. |

## Armadura y stun

El sistema completo de umbral de stun, resistencia por armadura y su interaccion con el aire (juggle) vive en [[Stun]] — separado de esta nota porque tiene su propio criterio de entrada, independiente del resto de `combat_state`. *(2026-07-08)*

## Aereo

- `launch`: sube y queda suspendido por el hang time del golpe; cae al terminar. La suspension la manda el hang/stun, no `airborne_max_time` (ese es solo el tope de seguridad de caida). *(2026-07-06)*
- `slam`: cae fuerte.
- `push`: arco balistico. Velocidad, altura y cierre del arco los define QUIEN ataca via `PushSettings`, no el enemigo: cada arma/ataque empuja distinto. *(2026-07-06)*
- `slam_bounce`: baja y rebota vertical hasta una altura objetivo (Espada).
- `slam_arc`: baja y, al tocar el piso, pica en un arco balistico propio (up + forward + su gravedad) en una direccion dada, sin altura objetivo; stuneado todo el arco, ragdoll al aterrizar (Mazo). *(2026-07-12)*

> [!important] El golpe frena el momentum
> Un golpe que aplica stun mientras el enemigo vuela (por `launch` o `push`) cancela su `velocity`: queda quieto, suspendido durante el stun, y cae al terminar. *(2026-07-06)*

## Relacionado

- [[Combate]]
- [[Espada]]
- [[Armored Enemy]]
- [[Stun]]

