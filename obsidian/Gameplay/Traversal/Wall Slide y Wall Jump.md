---
title: Wall Slide y Wall Jump
tags:
  - egoist
  - gameplay
  - sistema
  - traversal
status: active
system_status: E3
hito: H1
---

# Wall Slide y Wall Jump

Movimiento de pared implementado como modulo componible `PlayerWallSlide` (nodo hijo `WallSlide` del player). `Player` orquesta; la decision fina vive en el modulo. Tuning en `PlayerTuning` grupo `Wall slide`. *(2026-07-07)*

## Wall slide

- Engancharse requiere: estar en el aire + momentum suficiente contra la pared (`wall_slide_min_push_speed`). Ya **no exige apretar hacia el muro**: alcanza con llegar con empuje real contra el. La pared se detecta con las colisiones de `CharacterBody3D` tras `move_and_slide`, filtrando `World.LAYER_WORLD`.
- **Assist (no depende del stick):** una vez enganchado, el slide se mantiene con input neutro; solo se corta si el jugador dirige el stick claramente **en contra** de la pared (`wall_slide_input_dot`, reinterpretado como "apuntar hacia afuera"). Ademas hay una ventana de gracia coyote (`wall_slide_release_grace`) al perder contacto: en esquinas o micro-separaciones el estado no titila, se sostiene con la ultima normal conocida.
- Al pegarse hay una fase breve casi sin caida (`wall_slide_stick_time`, `wall_slide_stick_fall_speed`); despues cae controlado (`wall_slide_gravity_scale`, `wall_slide_max_fall_speed`). El momentum lateral con el que se llega decae con `wall_slide_momentum_decay`: la bajada es un arco que termina cayendo vertical.
- **Arco genuino:** la gravedad reducida (`wall_slide_gravity_scale`) se aplica **simetrica** — subiendo y cayendo. Entrar con momentum hacia arriba traza un arco que sube, frena y vuelve; entrar en caida seca no hace arco, solo ralentiza y sigue bajando. El largo/alto del arco escala con la velocidad de entrada. (Antes la gravedad solo se reducia al caer, asi que el momentum de subida moria a gravedad completa y no habia arco.) La altura se tunea con `wall_slide_gravity_scale`, el largo con `wall_slide_momentum_decay`.
- Ademas, el exceso global `bump_velocity` drena segun `momentum_bleed_wall` mientras el jugador esta apoyado en pared. Esto convive con `wall_slide_momentum_decay`; si se siente demasiado frenado, el primer knob a tocar es `momentum_bleed_wall`.
- Mientras eslidea se aplica una presion constante contra la pared (`wall_slide_press_speed`) que sostiene el contacto fisico.
- El personaje brilla verde mientras esta pegado (override de emision en el mesh; `glow_color` / `glow_energy` en el nodo `WallSlide`). El bloom ya existe (`WorldEnvironment` con glow en `test_scene`, ver [[Combate]]).
- Ademas levanta polvo mientras eslidea: emisor `WallSlideDust` (`GPUParticles3D`) hijo del player, que `PlayerWallSlide` prende/apaga en sync con el glow (arranca en `update_after_move`, corta en `cancel`). Look tuneable en el `ParticleProcessMaterial` del emisor. *(2026-07-10)*
- Se cancela al tocar suelo, dashear, ser lanzado, recibir bump o entrar en stun.
- API: `apply_slide_velocity`, `update_after_move`, `try_wall_jump`, `cancel`, `blocks_move_input`.

## Wall jump

- Contra una pared, el boton de salto SIEMPRE produce el rebote de pared, nunca un salto vertical ni el doble salto: si el slide no esta activo ese frame pero hay contacto real, se re-detecta la normal y rebota igual.
- Es un **impulso de la pared**, no un salto del jugador: no consume el doble salto, y la pared tampoco recarga uno gastado (eso solo lo hacen el suelo o `restore_double_jump`). Re-agarrarse a la misma pared esta permitido.
- Direccion: el **input reflejado en la pared**: la componente hacia la pared se invierte (sale por la normal con `_away_speed`) y la lateral del input se conserva (`_along_speed`; con input de frente al muro sale perpendicular exacto). Empuja hacia arriba con `_up_speed`.
- Durante `_lock_time` el rebote manda: input de movimiento y re-agarre quedan bloqueados; el lock se corta al tocar suelo.

## Verificacion

Chequeo de regresion headless: `world/wall_slide_probe.tscn` (cae pegado a una pared con input sostenido y cuenta transiciones del estado de slide).

Estado **E3**: assist (no depende del stick, gracia coyote) + arco genuino por gravedad reducida simetrica, aprobado jugando por Tutupa. Faltan juice y edge cases; conocidos: con `wall_slide_gravity_scale` bajo un wall-entry con mucho momentum vertical puede trepar de mas (subir el knob si pasa).

## Relacionado

- [[Movimiento Base]]
- [[Launcher y Aire]]
- [[Momentum y Bump]]
- [[Traversal]]
