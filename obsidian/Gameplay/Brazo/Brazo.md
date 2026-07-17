---
title: Brazo
tags:
  - egoist
  - gameplay
  - sistema
  - brazo
status: active
system_status: E2
hito: H2
---

# Brazo

Habilidad permanente del jugador. No es un arma nueva, no ocupa los slots X/Y y no compite con [[Espada]], [[Mazo]], [[Dagas]] ni [[Punos]]. Vive encima del loadout: el jugador siempre puede usar el brazo tenga el arma que tenga.

El brazo aumenta las opciones de [[Combate]] y [[Traversal]]: en combate da control, aire y respiro; en plataformeo permite agarrarse a puntos o cosas para estabilizar rutas rapidas.

## Fantasia

El jugador tiene un brazo/puño remoto. Al activarlo, el puño se proyecta o se teletransporta hacia el objetivo pasivo marcado, pega o se engancha, y vuelve.

No es un disparo de arma tradicional. La palabra "disparo" describe la accion de mandar el puño a distancia.

## Reglas base

- Siempre disponible como habilidad del personaje.
- Input propuesto: gatillo izquierdo.
- Usa su propio lock-on pasivo, separado del lock-on de combos.
- El lock-on del brazo marca hacia donde el jugador mira/apunta, pero no arrastra al jugador ni altera su movimiento base.
- No reemplaza el lock-on actual de combate: lo complementa.
- Puede costar meter en usos cargados, extensiones o efectos fuertes.
- Debe sentirse como una herramienta de control y respiracion, no como otra arma del roster.

## Subnodos

| Nota | Cubre |
|---|---|
| [[brazo-combate|Brazo Combate]] | Uso para mantener enemigos en aire, extender ventanas y controlar caos. |
| [[brazo-traversal|Brazo Traversal]] | Uso para agarres, estabilizacion y pseudo checkpoints en plataformeo. |

## Decisiones abiertas

- Si el uso basico de combate es gratis y solo el cargado cuesta meter (hoy: gratis, sin
  cargado implementado todavia).
- Si el brazo puede agarrar objetos golpeables genericos o puntos de agarre puros ademas de
  los bloques de dash (hoy: solo bloques verdes de [[Bloques|traversal]]).

## Estado Godot

- Implementado: combate (tap sobre el target del lock-on pasivo) y traversal (teletransporte +
  activacion de bloques de dash verdes). Ver [[brazo-combate|Brazo Combate]] y
  [[brazo-traversal|Brazo Traversal]].
- Entro en H1, adelantado respecto al roadmap original que lo preveia para H2.
- Nace como sistema propio del player (`PlayerArm` + `ArmTuning`), no como `WeaponBase`.
- El objetivo pasivo prioriza combate: si hay un enemigo en el cono de mira/lock, el tap le
  pega; si no, marca el bloque de dash mas cercano en su propio cono/rango de traversal. El
  lock-on pasivo del brazo (punto morado, `ArmMarker`) es el mismo para ambos casos.
- Golpe aereo con reaccion propia sobre el movimiento del jugador: pausa corta que conserva la
  caida (vertical) + freno que decelera el momentum horizontal, ambos tuneables y separados del
  air stall del arma. Ver [[brazo-combate|Brazo Combate]].

## Relacionado

- [[brazo-combate|Brazo Combate]]
- [[brazo-traversal|Brazo Traversal]]
- [[Combate]]
- [[Traversal]]
- [[Lock On]]
- [[Meter]]
- [[hitos]]
