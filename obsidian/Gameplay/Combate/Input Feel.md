---
title: Input Feel
tags:
  - egoist
  - gameplay
  - sistema
  - combate
status: active
system_status: E3
hito: H1
---

# Input Feel

Reglas que definen la respuesta del combate.

## Reglas

- Buffer: 0.15s.
- Hold threshold: 0.18s.
- Tap al presionar, salvo que una accion use carga exclusiva.
- Dodge cancela casi todo.
- Ataques se encadenan por ventanas definidas.

## Niveles de carga

Cruzar el hold threshold ya es carga nivel 1. Cada arma decide si hay mas niveles
sostiendo: el Mazo suma uno por cada `charge_level_step` extra (hasta
`max_charge_level`), la Espada ignora el nivel y solo distingue tap/cargado.

El nivel se resuelve **al disparar el hold**, no al presionar: `InputBuffer.held_duration()`
deja de contar en ese instante. Si el cargado sale bufferizado (soltar mid-swing, regla del
buffer), el arma lee lo que el jugador sostuvo de verdad y no los hasta 0.15s extra que
tardo en ejecutarse — si no, soltar al ras de un umbral regalaba un nivel segun que tan
ocupado estuviera el player.

## Pendiente

- Tunear ventanas jugando, no desde teoria.

## Decidido

- Los cargados usan `press_then_charge`: el tap sale en el press y el cargado al soltar,
  sin tap+hold doble. Ya en uso en `PlayerCombat._on_press`.

## Relacionado

- [[Combate]]
- [[Espada]]
- [[Mazo]]

