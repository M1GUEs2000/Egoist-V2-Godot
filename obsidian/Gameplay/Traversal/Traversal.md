---
title: Traversal
tags:
  - egoist
  - gameplay
  - sistema
status: active
system_status: E2
hito: H1
---

# Traversal

Traversal cubre movimiento, salto, airdash, momentum, cadenas, bloques y world switch como herramienta de exploracion/plataforming.

## Implementado en Godot

| Pieza | Modulos | Estado |
|---|---|---|
| Movimiento base | `Player`, `PlayerLocomotion` | E2 |
| Dash / airdash | `PlayerDash` | E2 |
| Launcher / aire | `PlayerLauncher` | E2 |
| Momentum por bump | `Player.bump()` | E2 |
| Wall slide / wall jump | `PlayerWallSlide` | E2 |
| Occlusion fade de camara | `CameraOcclusionFade` | E2 (falta tunear) |
| Tomato block | `TomatoLaunchBlock` | E2 |
| Purple dash block | `PurpleDashBlock` | E2 |
| Breakable wall | `BreakOnDeath`, escena de pared | E2 |
| Spike wall | `SpikeWall` (ver [[Bloques]]) | E1 (pendiente de probar) |
| Cadenas | `PlayerSwing` | E0 |
| Landing indicator | `LandingIndicator` | E2 |

## Dash

- **Dodge (esquivar):** choca con enemigos y objetos, no los traspasa. *(2026-07-06)*
- Si hay barra, el dodge puede hacer daño, pero no aplica stun; el stun del dash normal es 0 en suelo y aire. *(2026-07-07)*
- **Dash ofensivo** (`PlayerDash.force_dash`, ej. el X cargado de la espada): atraviesa enemigos y choca con objetos.
- La diferencia es el flag `pass_through_enemies` en `_start_dash`: solo el ofensivo quita la capa `enemy` del `collision_mask`.

## Wall slide

Modulo componible `PlayerWallSlide` (nodo hijo `WallSlide` del player): `Player` orquesta, la decision fina vive en el modulo. Tuning en `PlayerTuning` grupo `Wall slide`. *(2026-07-07)*

- Engancharse requiere: estar en el aire + input hacia la pared (`wall_slide_input_dot`) + momentum suficiente contra ella (`wall_slide_min_push_speed`). La pared se detecta con las colisiones de `CharacterBody3D` tras `move_and_slide`, filtrando `World.LAYER_WORLD`.
- Al pegarse hay una fase breve casi sin caida (`wall_slide_stick_time`, `wall_slide_stick_fall_speed`); despues cae controlado (`wall_slide_gravity_scale`, `wall_slide_max_fall_speed`). El momentum lateral con el que se llega decae con `wall_slide_momentum_decay`: la bajada es un arco que termina cayendo vertical.
- Mientras eslidea se aplica una presion constante contra la pared (`wall_slide_press_speed`) que sostiene el contacto fisico.
- El personaje brilla verde mientras esta pegado (override de emision en el mesh; `glow_color` / `glow_energy` en el nodo `WallSlide`). Sin bloom aun, igual que el glow de la espada.
- Se cancela al tocar suelo, dashear, ser lanzado, recibir bump o entrar en stun.
- API: `apply_slide_velocity`, `update_after_move`, `try_wall_jump`, `cancel`, `blocks_move_input`.

### Wall jump

- Contra una pared, el boton de salto SIEMPRE produce el rebote de pared, nunca un salto vertical ni el doble salto: si el slide no esta activo ese frame pero hay contacto real, se re-detecta la normal y rebota igual.
- Es un **impulso de la pared**, no un salto del jugador: no consume el doble salto, y la pared tampoco recarga uno gastado (eso solo lo hacen el suelo o `restore_double_jump`). Re-agarrarse a la misma pared esta permitido.
- Direccion: el **input reflejado en la pared** — la componente hacia la pared se invierte (sale por la normal con `_away_speed`) y la lateral del input se conserva (`_along_speed`; con input de frente al muro sale perpendicular exacto). Empuja hacia arriba con `_up_speed`.
- Durante `_lock_time` el rebote manda: input de movimiento y re-agarre quedan bloqueados; el lock se corta al tocar suelo.

Chequeo de regresion headless: `world/wall_slide_probe.tscn` (cae pegado a una pared con input sostenido y cuenta transiciones del estado de slide).

## World switch

El switch de mundo se gana por:

- `WorldSwitchTrigger` en modo OnHit.
- `WorldSwitchTrigger` en modo OnDeath.
- `ActionWorldSwitchModifier`, que cambia el mundo con la proxima accion.
- Boton/HUD o especiales futuros.

> [!important]
> Dodge no cambia mundo automaticamente. Dodge puede disparar switch solo si una maldicion/bonus lo modifico.

## Occlusion fade de camara

Si un muro del mundo queda entre la camara y el jugador, se vuelve semitransparente (se sigue viendo y sigue proyectando su sombra) y recupera su material original al dejar de tapar. *(2026-07-07, falta tunear)*

- `CameraOcclusionFade` (`visual/camera_occlusion_fade.gd`), nodo `OcclusionFade` hijo del `CameraRig`.
- Raycast camara -> jugador contra `LAYER_WORLD` cada frame de fisica, con `hit_from_inside` (funciona aunque la camara quede dentro del muro). Puede desvanecer varios muros en fila (`max_occluders`).
- El material del mesh ocluyente se duplica en version `TRANSPARENCY_ALPHA_DEPTH_PRE_PASS`: conserva color, sombra y orden de dibujado estable.
- Al dejar de tapar espera `restore_delay` antes de volver a solido (estabilidad en bordes de pared).
- Tuneables en el nodo: `fade_alpha`, `target_height_offset`, `max_occluders`, `restore_delay`.

## Landing indicator

Circulo (anillo) azul que aparece en el suelo, bajo el jugador, cuando esta en el aire por encima de `min_air_height` (0.5 m por defecto). *(2026-07-06)*

- `LandingIndicator` es un `Node3D` hijo del Player con `top_level = true` (se posiciona en coordenadas globales propias, no hereda el transform del jugador).
- Cada frame lanza un raycast hacia abajo contra `LAYER_WORLD`, se coloca en el punto de impacto y se orienta segun la normal del suelo (sirve para rampas/plataformas). Solo se muestra si el jugador esta a mas de `min_air_height` del suelo.
- Malla (`TorusMesh`) y material (azul unshaded, emisivo, sin sombra) se generan por codigo: no hay `.tres`. Todo tuneable via `@export` en el nodo: `min_air_height`, `max_ray_distance`, `radius`, `thickness`, `surface_offset`, `color`.
- No detecta enemigos (raycast solo contra `LAYER_WORLD`): el circulo siempre marca suelo/plataforma real.

## Pendiente H1

- Implementar `PlayerSwing` con agarre, subir/bajar, impulso de salida y cooldown de reagarre.
- Construir un greybox de Playa con loop salto + airdash + switch + bloques.
- Probar que no haya softlocks si el jugador consume mal un switch.

## Relacionado

- [[Combate]]
- [[Areas]]
- [[H1 - Vertical Slice]]
