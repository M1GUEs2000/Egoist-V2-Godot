---
title: H1 - Vertical Slice
tags:
  - egoist
  - tarea
status: active
hito: H1
priority: 1
---

# H1 - Vertical Slice

10 minutos jugables de Playa con Espada completa.

## Objetivo

Demostrar que pelear con Espada, moverse en 3D isometrico y cambiar de mundo se siente bien antes de producir contenido grande.

## Backlog activo

- [ ] Verificar headless `--import`, `--quit-after 2` y `smoke_test`.
- [ ] Probar y tunear `player_tuning.tres`.
- [ ] Probar y tunear `sword_tuning.tres`.
- [ ] Probar en engine la IA por hostilidad (FSM, percepcion, FLEE/HIDE): sin revisar aun.
- [ ] Validar carga de LimboAI v1.1.1 en Godot/headless y ausencia de errores de GDExtension.
- [ ] Portar selector actual de IA a LimboAI BT/HSM despues del refactor de decouple.
- [ ] Probar el stun universal (player y enemigos) y la spike wall: sin revisar aun.
- [ ] Tunear el occlusion fade de camara (funciona; falta ajustar feel/valores).
- [ ] Probar el loadout X/Y y el Maso placeholder en juego.
- [ ] Diseñar e implementar scanner de cambio de mundo.
- [ ] Implementar AOE aereo del [[Mazo]] que lance a todos los enemigos del area.
- [ ] Cambiar el hitbox del AOE aereo del [[Mazo]] a cilindro.
- [ ] Rediseñar el combo aereo del [[Mazo]].
- [ ] Hacer que el dash del bloque verde haga daño.
- [ ] Hacer que el rebote en enemigos stunee sin dañar.
- [ ] Verificar que el combo entre dos armas no deje daño fantasma por `cancel_routines()` por arma.
- [ ] Decidir precedencia entre rebote en enemigos y slam del [[Mazo]] cuando compiten por el mismo contacto.
- [x] Agregar `WorldEnvironment` con glow. *(en `test_scene`; falta tunear bloom jugando)*
- [x] Añadir particulas de polvo al correr para jugador y enemigos, tuneables por recurso/export. *(player: `RunDust` + `PlayerTuning.run_dust_min_speed`; enemigos: `RunDust` + export `run_dust_min_speed`)*
- [x] Añadir particulas de polvo al deslizarse por pared, tuneables por recurso/export. *(`WallSlideDust`, en sync con el glow)*
- [x] Añadir particulas brillantes para el dash, tuneables por recurso/export. *(`DashParticles`, color desde `World.COLOR_TRAVERSAL_DASH`)*
- [ ] Implementar `PlayerSwing`.
- [ ] Implementar `WorldVisual`.
- [ ] Rehacer HUD H1.
- [ ] Crear prefabs/escenas de player, melee, ranged, armored, bloques y pickups.
- [ ] Greybox del primer tramo de Playa.
- [ ] Reset aereo por kill.
- [ ] Decidir knockback normal.
- [ ] Playtest externo 2-3 personas.

## Go/no-go

> [!danger]
> Si la Espada + world switch no se siente bien, se redisenia aqui. No se empuja el problema a H4.

## Relacionado

- [[Combate]]
- [[Traversal]]
- [[Areas]]
