---
title: Backlog
tags:
  - egoist
  - tareas
status: active
---

# Backlog

Fuente de todas las subtareas (plugin **Tasks**). Cada tarea es una linea `- [ ]` con su **etapa** (la casilla) y el/los **nodo(s)** al final como `[[wikilink]]`. Las vistas se arman solas en [[tareas]].

Etapas (casilla → estado del ciclo E0-E4): `[ ]` Por implementar (E0) · `[/]` Implementacion (E1) · `[t]` Tuning (E2) · `[f]` Tuning final (E3) · `[x]` Completada (E4). Cambiar de etapa = clic en la casilla (cicla en orden). Para ver las tareas de un nodo, mira sus backlinks o filtra `description includes <Nodo>`.

## Tareas

- [ ] Definir que pasa tras la muerte del player (hoy solo estado global) — [[Combate]]
- [ ] Rediseñar el HUD de combate: armas, meter, combo y cooldowns — [[Combate]]
- [ ] Decidir el knockback de golpes normales — [[Combate]]
- [ ] Implementar el columpio de cadenas (PlayerSwing, batch 6) — [[Cadenas]]
- [ ] Implementar Visual de mundos (WorldVisual: 2 Environments + lerp) — [[Colores de mundo]]
- [f] Scan de cambio de mundo: tunear world_scan_tuning (velocidad, radio, brillo/trama, luz) y validar que la revelacion barrida no rompa el feel del switch — [[World Switch]]
- [ ] Crear prefabs/escenas: player, melee, ranged, armored, bloques y pickups — [[Enemigos]] [[Arquitectura Godot]]
- [ ] Greybox del primer tramo de Playa — [[Playa]]
- [ ] Playtest externo con 2-3 personas — [[Playa]]
- [f] Ragdoll de aterrizaje: headless + tunear pose acostada, radio GroundSense, getup/spin/gravity — [[Stun]] [[Enemigos]]
- [t] Reset aereo por kill/carga: probar doble salto/airdash por kill + reduccion de caida por cargas — [[Reset Aereo por Kill]]
- [t] Dash del bloque verde: probar el daño al atravesar — [[Bloques]]
- [t] Rebote en enemigos: probar el push sin dañar — [[Rebote en Enemigos]]
- [t] Mazo aereo: probar AOE cilindrico + slam_bounce, rebote del jugador arriba+adelante, combo X de 2 — [[Mazo]]
- [f] Espada X/Y: iterar combos/angulos/ventanas + mano orbital; tunear sword_tuning — [[Espada]] [[Combate]]
- [t] Mazo: probar combos jugando; loadout X/Y + placeholder — [[Mazo]]
- [t] Movimiento del player: tunear player_tuning (momentum, dash, wall slide/jump, gracia) — [[Movimiento Base]]
- [t] IA por hostilidad: tunear percepcion/FLEE-HIDE jugando — [[IA]]
- [t] Stun universal + spike wall: probar en player y enemigos — [[Stun]] [[Combate]]
- [t] Enemigo de world switch: probar latido, fogonazo de muerte y su costo (vida/stun) jugando — [[Afiliacion de Mundo]] [[World Switch]]
- [t] Combo entre dos armas: verificar sin daño fantasma por cancel_routines — [[Combate]]
- [t] Occlusion fade de camara: tunear feel/valores — [[Occlusion Fade de Camara]]
- [t] Tunear el bloom del glow (WorldEnvironment) jugando — [[Combate]]
- [t] Verificacion headless del batch (--import, --quit-after 2, smoke = SMOKE OK) — [[Arquitectura Godot]]
- [t] I-frames del dodge del player: implementados (dodge_iframe_duration, gate en Player.try_apply_stun + Hurtbox.can_receive_hit vía dash.is_invulnerable). Falta tunear el valor jugando; el esquive enemigo (EVADE) ya existe pero **sin i-frames** por diseño — [[Combate]] [[Stun]]
- [x] Entender y documentar el stun threshold efectivo: el umbral instantaneo (`power >= threshold`) se reemplazo por el medidor de poise — [[Stun]] [[Combate]]
- [/] Poise (stagger): correr headless + smoke del medidor nuevo — [[Stun]] [[Combate]]
- [t] Poise: tunear reservas por enemigo, poise por arma/ataque, drenaje, escalera de degradacion y el fogonazo blanco del golpe absorbido — [[Stun]] [[Combate]] [[Espada]] [[Mazo]]
- [t] Hostilidad/ecosistema: hacer que todos los enemigos consideren al ultra agresivo tambien como enemigo valido y validar el targeting sin flip-flop grave — prefab `ultra_aggressive_enemy.tscn` + score de utility (proximidad/compromiso) + stuck-check; falta headless y tunear pesos/stats jugando — [[Ultra Agresivo]] [[Ecosistema Vivo]] [[IA]]
- [t] Enemigo hibrido: alternar entre melee y ranged, y evaluar si su variante/proyectil puede forzar cambio de mundo sin romper la lectura del combate — modulo `AttackLoadout` (inyectable a cualquier enemigo) + prefab `hybrid_enemy.tscn` con WorldSwitchTrigger ON_DEATH; falta headless y tunear rangos/cadencia jugando — [[Ataques Enemigos]] [[Ranged Dead]] [[World Switch]] [[IA]]
- [t] VFX de presencia para enemigos y objetos: humo + afterimages (capa constante) y borde encendido que late, con el humo enganchado al pulso (capa por pulsos) — cascara `other_world_shell.gdshader` en `WorldMembership`; el cuerpo fuera de mundo ya no desaparece; falta headless y tunear tiempos/intensidades jugando — [[Enemigos]] [[Objetos Golpeables]] [[Colores de mundo]] [[Afiliacion de Mundo]]
- [ ] Activity enemiga: implementar una actividad idle real dentro del comportamiento enemigo y definir cuando cae a `ACTIVITY` vs `ROAM`/`GUARD` — [[Comportamientos]] [[IA]]
- [/] Camara que rota: implementado offset de yaw por stick (`camera_left`/`camera_right`) clamped a ±max_yaw_offset sobre `center_yaw`, con recentrado suave tras `recenter_delay`; falta headless, tunear jugando y el centro por area (hoy `center_yaw` es fijo) — [[Camara]]
- [/] Enemigo de la grieta: su reloj arranca con el PRIMER golpe recibido (no es un timer suelto); al cumplirse se va al otro mundo y deja una [[Grieta]] cruzable donde estaba, de un solo uso y con ventana antes de cerrarse. Irse no voltea el mundo de nadie: cruzar la grieta si. Modulos `RiftSpawner` + `WorldRift` (detonable por cualquier sistema, no solo por este enemigo) + prefab `rift_enemy.tscn`; falta headless y tunear jugando el delay, la ventana y la lectura visual — [[Grieta]] [[World Switch]] [[Afiliacion de Mundo]]
- [/] Enemigo con proyectil de world switch: variante de `RangedAttack`/`Projectile` que cambia el mundo al impactar al JUGADOR (`world_switch_on_player_hit` en `Projectile`); falta headless/smoke y armar el `projectile_scene` con el flag activo — [[World Switch]] [[Ataques Enemigos]]
- [f] EVADE enemigo (esquive humano): aprobado jugando — salta hacia atras (recto o diagonal, sorteado), distancia tuneable con evade_distance, sin i-frames por diseño. Faltan juice y edge cases — [[Comportamientos]] [[IA]] [[Stun]]
- [f] Engage en rango: aprobado jugando — el melee entra, pega, retrocede de cara y orbita en vez de plantarse encima. Faltan juice y edge cases — [[Comportamientos]] [[IA]]
- [f] Giro comprometido del combo: aprobado jugando — combo_turn_speed entre golpes, combo_swing_turn_speed durante el swing — [[Comportamientos]] [[IA]]
- [ ] Retirar el fallback FSM de GroundedEnemy (use_simple_fsm + _update_fsm / _process_*): LimboAI es el backend unico — [[IA]]
- [f] Lock-on vertical: ultimos detalles de rango/angulo/reticle para enemigos aereos + indicador de aterrizaje del target cuando corresponda — [[Lock On]] [[Landing Indicator]]
- [f] Bloques traversal: probar combinaciones, glow por proximidad e impulsos — [[Bloques]]
- [x] Fundacion tecnica Godot: proyecto 4.7, autoloads, estructura feature-based, Health/Hurtbox/Hitbox, tuning, smoke_test — [[Arquitectura Godot]]
- [x] Particulas greybox: polvo al correr, polvo wall-slide y dash brillante — [[Movimiento Base]]
- [x] Precedencia rebote-vs-slam del Mazo — [[Rebote en Enemigos]] [[Mazo]]

## Relacionado

- [[tareas]]
- [[hitos]]
- [[ideas]]
