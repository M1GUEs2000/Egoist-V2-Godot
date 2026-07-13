---
title: World Switch
tags:
  - egoist
  - gameplay
  - sistema
status: active
system_status: E2
hito: H1
---

# World Switch

Mecanica central de los dos mundos.

## Decision V2

Switch por triggers ganados, no dodge gratis.

## Modulos

- `WorldManager`
- `WorldMembership`
- `WorldSwitchTrigger` (modulo componible ON_HIT/ON_DEATH; lo usa `world_switch_enemy.tscn`. El switch de los bloques no pasa por el: corre inline en `TraversalBlock.enable_world_switch`)
- `ActionWorldSwitchModifier`
- `WorldScan` + `WorldScanTuning`

## Triggers

- `TraversalBlock` con world switch OnHit: brilla con el color del mundo destino. Implementacion inline en `traversal_block.gd`, no usa `WorldSwitchTrigger`.
- Enemigo OnDeath: `world_switch_enemy.tscn` voltea el mundo al morir y late con el color del mundo destino (ver [[Afiliacion de Mundo]]). Es el switch que se gana peleando.
- Proyectil enemigo OnHit al jugador: `Projectile.world_switch_on_player_hit` (export, default `false`). Si un proyectil con el flag activo pega al `Player` (no a otro enemigo ni al mundo), llama `WorldManager.switch_world(global_position)` ademas del dano normal. Vive en el proyectil, no en `WorldSwitchTrigger`: es un flag por `projectile_scene`, asi que cada enemigo ranged decide con que variante dispara (ver [[Ataques Enemigos]]).
- Maldicion amarilla + proxima accion.
- Boton/HUD o especiales futuros.

## Scan de cambio de mundo *(2026-07-12, pendiente de probar)*

El switch no es instantaneo en el espacio: sale una **onda** desde el trigger que lo disparo y el
mundo destino aparece **barrido por el frente**, no todo junto.

- **Origen**: el trigger pasa su posicion global a `WorldManager.switch_world(origin)` (el bloque
  golpeado, el enemigo que murio). Sin origen la onda nace en el jugador; sin jugador no hay onda y
  el switch cae de golpe (caso del smoke test).
- **Gameplay**: cada `WorldMembership` se voltea cuando la onda lo alcanza. El retardo es
  `distancia / speed`, clampeado a `max_radius` para que ninguna esquina lejana tarde una eternidad
  en existir (`WorldManager.scan_delay_for`). Si el mundo vuelve a cambiar mientras una membresia
  espera, esa espera se descarta (token `switch_count`).
- **Visual**: `WorldScan` (nodo en la escena) dibuja una cascara esferica que crece desde el origen —
  trama de poligonos + filo fresnel, aditiva y tenue (`visual/world_scan.gdshader`) — y una
  `OmniLight3D` que viaja con el frente e ilumina el entorno. El color es siempre el del **mundo
  destino** (`World.world_emission`), segun [[Colores de mundo]].
- **Tuneables**: `data/world_scan_tuning.tres` — velocidad, radio maximo, fade, brillo/alpha/borde de
  la cascara, densidad y grosor de la trama, energia y alcance de la luz. `speed = 0` apaga la onda.

## Relacionado

- [[Traversal]]
- [[Colores de mundo]]
- [[Decisiones Congeladas]]
