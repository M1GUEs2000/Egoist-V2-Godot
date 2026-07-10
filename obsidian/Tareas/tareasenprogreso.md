---
title: Tareas en progreso
tags:
  - egoist
  - tareas
  - kanban
estado: En progreso
orden: 2
status: active
---

# Tareas en progreso

Construido, falta probar/tunear jugando. Ver [[tareas]] para el modelo y las reglas. Al aprobarse jugando la fila pasa a [[tareascompletadas]]; si aun no se empezo, vuelve a [[tareaspendientes]].

| Tarea | Qué falta | Nodo(s) |
|---|---|---|
| Ragdoll de aterrizaje (pose acostada) | Correr headless/smoke y tunear jugando: pose acostada, radio de `GroundSense`, `ragdoll_getup_delay` / `ragdoll_spin` / `ragdoll_gravity_scale` | [[Stun]], [[Enemigos]] |
| Espada X/Y | Iterar combos/angulos/ventanas y mano orbital jugando (`hand_radius`, `thrust_reach`); tunear `sword_tuning.tres` | [[Espada]], [[Combate]] |
| Mazo | Probar combos jugando (E2→E3); Mazo aereo: AOE cilindrico + `slam_bounce`, rebote del jugador arriba+adelante al clavar en aire, combo X de 2 (mango sin push + cabezazo con push); probar loadout X/Y + placeholder | [[Mazo]] |
| Movimiento del player | Probar/tunear `player_tuning.tres` jugando: momentum, dash, wall slide/jump y gracia | [[Movimiento Base]] |
| Reset aereo por kill/carga | Probar jugando: reset de doble salto/airdash por kill aerea y reduccion de caida por cargas (`air_charge_fall_reduction_steps`) | [[Reset Aereo por Kill]] |
| Occlusion fade de camara | Tunear feel/valores jugando (funciona) | [[Occlusion Fade de Camara]] |
| IA por hostilidad y port LimboAI | Probar en engine FSM/percepcion/FLEE-HIDE (sin revisar aun); validar carga de LimboAI v1.1.1 sin errores de GDExtension; revisar port code-only (`AIBackend.LIMBO`, `BTPlayer`, `EnemyAIBlackboard`, `EnemyLimboTreeBuilder`, hojas en `enemies/ai/tasks/`) y su equivalencia contra la FSM; decidir si se retira el fallback FSM o queda dual para H1 | [[IA]] |
| Stun universal + spike wall | Probar jugando en player y enemigos | [[Stun]], [[Combate]] |
| Combo entre dos armas | Verificar que no deje daño fantasma por `cancel_routines()` por arma | [[Combate]] |
| Verificacion headless del batch | Correr `--import`, `--quit-after 2` y `smoke_test` (=SMOKE OK) de todo lo pendiente | [[Arquitectura Godot]] |
