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
- Al pegarse hay una fase breve casi sin caida (`wall_slide_stick_time`, `wall_slide_stick_fall_speed`); despues cae controlado (`wall_slide_gravity_scale`, `wall_slide_max_fall_speed`).
- **Arco del slide:** al enganchar se siembra el momentum lateral de entrada (la velocidad con la que se llega, proyectada en la pared) **mas un empuje horizontal `wall_slide_stick_push`** en esa misma direccion, que ensancha el arco (evita el arco alto-y-flaco que cae vertical cuando se llega lento; solo aplica si hay direccion lateral clara). Ese momentum se siembra SOLO al enganchar y decae a cero con `wall_slide_momentum_decay` (mas bajo = arco mas ancho y tendido durante la bajada). La gravedad reducida `wall_slide_gravity_scale` es **simetrica** (subiendo y cayendo): entrar con momentum hacia arriba traza un arco que sube, frena y vuelve; caida seca no hace arco. Forma del arco = altura por `wall_slide_gravity_scale`, ancho por `wall_slide_stick_push` + `wall_slide_momentum_decay`.
- **Control lateral:** el input vivo a lo largo de la pared tiene la autoridad recortada por `wall_slide_steer_control` (0 = sin control, solo se coastea el momentum de entrada; 1 = control total como el movimiento normal). Evita sentir que uno "vuela" de lado sobre el muro.
- Ademas, el exceso global `bump_velocity` drena segun `momentum_bleed_wall` mientras el jugador esta apoyado en pared. Esto convive con `wall_slide_momentum_decay`; si se siente demasiado frenado, el primer knob a tocar es `momentum_bleed_wall`.
- **Topes separados:** la velocidad a lo largo del muro (steer vivo + momentum de entrada) esta capada por `wall_slide_max_horizontal_speed`; la caida, por `wall_slide_max_fall_speed`. El empuje contra la pared (`wall_slide_press_speed`) no cuenta para el tope horizontal.
- Mientras eslidea se aplica una presion constante contra la pared (`wall_slide_press_speed`) que sostiene el contacto fisico.
- El personaje brilla verde mientras esta pegado (override de emision en el mesh; `glow_color` / `glow_energy` en el nodo `WallSlide`). El bloom ya existe (`WorldEnvironment` con glow en `test_scene`, ver [[Combate]]).
- Ademas levanta polvo mientras eslidea: emisor `WallSlideDust` (`GPUParticles3D`) hijo del player, que `PlayerWallSlide` prende/apaga en sync con el glow (arranca en `update_after_move`, corta en `cancel`). Look tuneable en el `ParticleProcessMaterial` del emisor. *(2026-07-10)*
- **Wall Impulse:** un `StaticBody3D` con hijo `WallImpulseSurface` y su `WallImpulseTuning` convierte el wall slide en un carril. Captura el primer input horizontal tangencial para escoger el **sentido**, ignora el stick posterior, anula la caida y arranca con `initial_speed`; despues acelera con `acceleration` hasta `max_speed`. En una curva, el vector se recalcula como la tangente de la normal actual conservando el sentido inicial, asi no pierde velocidad al pasar de tramo curvo a recto dentro del mismo mesh. `angle_degrees` inclina el carril respecto a esa tangente: `0` horizontal, negativo baja y positivo sube. La velocidad del carril puede superar el tope normal del wall slide; al perder contacto se entrega como momentum aereo y vuelve a respetar `momentum_max_speed`. Un `GPUParticles3D` verde asignado al export `particles` de la superficie se prende solo mientras el impulso esta activo. *(2026-07-19)*
- Se cancela al tocar suelo, dashear, ser lanzado, recibir bump o entrar en stun.
- API: `apply_slide_velocity`, `update_after_move`, `try_wall_jump`, `cancel`, `blocks_move_input`.

## Wall jump

- Contra una pared, el boton de salto SIEMPRE produce el rebote de pared, nunca un salto vertical ni el doble salto: si el slide no esta activo ese frame pero hay contacto real, se re-detecta la normal y rebota igual.
- Es un **impulso de la pared**, no un salto del jugador: no consume el doble salto, y la pared tampoco recarga uno gastado (eso solo lo hacen el suelo o `restore_double_jump`). Re-agarrarse a la misma pared esta permitido.
- **Direccion y rapidez salen de tu velocidad A LO LARGO del muro** (la tangente), no del stick: solo cuenta la horizontal, el empuje contra la pared no entra. Encadenar paredes conserva y compone ese momentum en vez de resetearlo → **encadenar acelera** (topado por `momentum_max_speed`). El calculo vive en `_wall_jump_velocity`, que comparten el salto y la flecha de debug.
- **Angulo**, medido desde la cara de la pared: cuanto mas rapido vas a lo largo (respecto a `move_speed`), mas te acercas al piso `wall_slide_wall_jump_min_angle` (rasante, nunca menos, para no rozar el muro); sin velocidad lateral salis perpendicular (90°, recto para atras — entrar de frente y saltar).
- **Rapidez horizontal:** `max(velocidad_tangente × wall_slide_wall_jump_h_boost, wall_slide_wall_jump_h_base)`. El `h_base` es el piso que garantiza despegue aunque llegues casi quieto; el `h_boost` (>1) es la aceleracion de la cadena.
- **Rapidez vertical:** `velocidad_tangente × wall_slide_wall_jump_v_boost`, **sin piso**: a velocidad nula no hay subida (salis horizontal y caes); rapido subis mas, lento menos.
- Durante `wall_slide_wall_jump_lock_time` el rebote manda: input de movimiento y re-agarre quedan bloqueados; el lock se corta al tocar suelo.
- **Flecha de debug** (`wall_slide_show_jump_arrow`): mientras deslizas, una flecha de ~2 m desde el player apunta al angulo real de lanzamiento del wall jump segun tu velocidad del momento (usa el mismo `_wall_jump_velocity` que el salto). Ayuda de tuning; se apaga con el toggle. *(2026-07-16)*

## Verificacion

Chequeos de regresion headless: `world/wall_slide_probe.tscn` (cae pegado a una pared con input sostenido y cuenta transiciones del estado de slide) y `world/wall_impulse_probe.tscn` (captura el primer input tangencial y verifica que no cambie al alterar el stick).

Estado **E3**. Aprobado jugando: slide assist (no depende del stick, gracia coyote), arco genuino, control lateral y Wall Impulse (carril horizontal/inclinado que sigue curvas). Wall jump conserva rebote por velocidad tangente con angulo emergente y encadenado que acelera. Faltan juice y edge cases; el tuning por pared de Wall Impulse (`initial_speed`, `acceleration`, `max_speed`, `angle_degrees`) queda disponible para iterar sin tocar codigo.

## Relacionado

- [[Movimiento Base]]
- [[Launcher y Aire]]
- [[Momentum y Bump]]
- [[Traversal]]
