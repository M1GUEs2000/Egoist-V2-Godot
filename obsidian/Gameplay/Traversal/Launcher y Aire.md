---
title: Launcher y Aire
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
status: active
system_status: E2
hito: H1
---

# Launcher y Aire

Movimiento y control cuando el jugador entra en estado aereo por salto, launcher, bump o acciones de combate.

## Implementado en Godot

- `PlayerLauncher`
- Integracion desde `Player`
- Interacciones con `PlayerDash`, `PlayerWallSlide` y `LandingIndicator`

## Responsabilidad

- Aplicar impulsos verticales o direccionales del jugador.
- Coordinar restauraciones de habilidades aereas cuando otro sistema lo permite.
- Mantener el control aereo tuneable desde `PlayerTuning`.

## Que se tunea y que no

El "sube y flota" de un launcher se reparte en tres duenos distintos. *(2026-07-09)*

| Pieza | Donde vive | Tuneable |
|---|---|---|
| Cuanto sube (`launcher_height`) | `.tres` del arma (`sword_tuning`, `mace_tuning`) | Si |
| Cuanto flota (`launcher_hang_time`) | `.tres` del arma | Si |
| Cuanto dura el area que atrapa (`launcher_hitbox_duration`) | `.tres` del arma | Si |
| Cuanto tarda en subir (`World.LAUNCH_RISE_TIME`) | `core/world.gd` | **No** |
| Como cae despues del hang (`airborne_gravity`) | `@export` por escena del enemigo | Si |

> [!important] `LAUNCH_RISE_TIME` es una constante compartida, no un tunable
> `World.LAUNCH_RISE_TIME = 0.15` es el tiempo de subida de **todo** launch, del jugador y
> de los enemigos: comparten el mismo feel de despegue a proposito. No vive en ningun
> `.tres` y no se puede ajustar por arma ni por enemigo. Si el despegue se siente lento o
> brusco, se cambia la constante — y cambia para todos a la vez. Es una decision de
> diseno, no un descuido: si en algun momento hace falta un rise time por arma, primero
> se decide que jugador y enemigos dejen de compartirlo.

`Player.launch()`, `PlayerLauncher.start_launch()` y `HitDummy.launch_rise_time` aceptan un
`rise_time` opcional que ya default-ea a esta constante. Hoy solo la Y cargada aerea de la
[[Espada]] lo sobreescribe (`aerial_charged_player_rise_time`), y es para el jugador, no
para el enemigo: `EnemyBase._launch_routine` lee la constante directo, sin parametro.

## Interacciones importantes

- [[Dash y Airdash]] consume/restaura disponibilidad de airdash segun la accion.
- [[Wall Slide y Wall Jump]] no consume doble salto al rebotar de pared.
- [[Momentum y Bump]] puede lanzar al jugador desde bloques o impactos.
- [[Landing Indicator]] solo visualiza el punto de caida; no decide gameplay.

## Relacionado

- [[Movimiento Base]]
- [[Momentum y Bump]]
- [[Landing Indicator]]
- [[Traversal]]
