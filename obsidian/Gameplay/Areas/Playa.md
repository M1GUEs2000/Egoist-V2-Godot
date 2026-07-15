---
title: Playa
tags:
  - egoist
  - area
status: active
hito: H1
---

# Playa

Area del vertical slice. Debe entregar 10 minutos jugables con Espada.

## Tramos H1

| Tramo | Funcion |
|---|---|
| Beach | Tutorial de combate y world switch simple. |
| Outskirts | Traversal tutorial con salto, airdash y bloques. |
| Ruina | Primer reto real con enemigo ranged/armored. |

## Pendiente

- Greybox jugable: `world/lvl_1_v_0_1.tscn` es ahora la escena principal y contiene la ruta
  modular con Player, HUD, cambio de mundo y tres pickups de switch.
- Integrar el roster H1 (melee Living, ranged Dead y armored) en la ruta: hoy los enemigos viven
  en `test_scene`, no en el nivel.
- Ubicar pickups de switch sin softlock y probar el loop completo de combate + traversal.

## Relacionado

- [[Areas]]
- [[hitos]]
- [[Playa Arte]]
