---
title: Brazo
tags:
  - egoist
  - gameplay
  - sistema
  - brazo
status: planned
system_status: E0
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

- Si el uso basico es gratis y solo el cargado cuesta meter.
- Alcance, cooldown y numero de usos encadenables.
- Si el objetivo pasivo prioriza enemigos, agarres de traversal o direccion pura.
- Como se comunica visualmente el lock-on pasivo sin ensuciar el lock-on de combos.
- Si el brazo puede agarrar objetos golpeables ademas de enemigos y puntos de traversal.

## Estado Godot

- No implementado.
- No entra en H1. H1 sigue siendo validar Espada + world switch + traversal base.
- Cuando entre, debe nacer como sistema propio del player, no como `WeaponBase`.

## Relacionado

- [[brazo-combate|Brazo Combate]]
- [[brazo-traversal|Brazo Traversal]]
- [[Combate]]
- [[Traversal]]
- [[Lock On]]
- [[Meter]]
- [[H1 - Vertical Slice]]
