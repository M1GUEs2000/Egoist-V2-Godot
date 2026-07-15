class_name PlayerTuning extends Resource
## TODOS los valores tuneables del jugador en un solo Resource (regla v2: los refactors
## nunca más resetean el tuning). Los defaults son los valores tuneados a mano en la v1.
## La instancia editable es data/player_tuning.tres.

@export_group("Locomotion")
## Velocidad horizontal base de movimiento, en m/s (suelo y aire).
@export var move_speed := 6.0
## Magnitud mínima del stick/input para contar como movimiento (debajo se ignora).
@export var move_input_deadzone := 0.15
## Si el input apunta a menos de estos grados del target lockeado, el movimiento snapea hacia él (LockOn).
@export var lock_move_snap_angle := 45.0
## Avance (lunge) hacia adelante en cada golpe del combo terrestre, en metros.
@export var attack_step_distance := 0.7

@export_group("Jump")
## Velocidad vertical inicial del salto y del doble salto, en m/s.
@export var jump_force := 8.0

@export_group("Wall slide")
## Velocidad mínima de empuje CONTRA la pared para engancharse al slide (m/s).
@export var wall_slide_min_push_speed := 2.0
## Velocidad de presion contra la pared mientras se eslidea: mantiene el contacto fisico
## (sin esto el estado titila frame a frame).
@export var wall_slide_press_speed := 2.5
## Qué tan alineado debe estar el input con la pared para engancharse/mantenerse (0-1;
## 1 = exactamente de frente, más bajo = más permisivo). Ahora solo mide cuándo el jugador
## apunta EN CONTRA de la pared para soltarse; input neutro mantiene el slide.
@export_range(0.0, 1.0) var wall_slide_input_dot := 0.35
## Ventana de gracia (coyote) tras perder contacto con la pared antes de cortar el slide,
## en segundos. Evita que el estado titile en esquinas o micro-separaciones del muro.
@export var wall_slide_release_grace := 0.12
## Duración de la fase inicial "pegado": casi no cae, en segundos.
@export var wall_slide_stick_time := 0.16
## Velocidad máxima de caída durante la fase pegado (m/s).
@export var wall_slide_stick_fall_speed := 0.35
## Velocidad máxima de caída deslizando, después de la fase pegado (m/s).
@export var wall_slide_max_fall_speed := 3.4
## Fracción de la gravedad aplicada mientras eslidea, tanto subiendo como cayendo
## (0 = no cae/no frena la subida, 1 = gravedad completa). Gobierna la altura del arco.
@export_range(0.0, 1.0) var wall_slide_gravity_scale := 0.35
## Frenado del momentum lateral a lo largo de la pared (m/s²). Más alto = el arco de la
## caída se endereza antes y terminas cayendo vertical más rápido.
@export var wall_slide_momentum_decay := 4.0
## Autoridad del input vivo para moverse a lo largo de la pared mientras eslidea (0-1).
## 0 = sin control, solo coasteás el momentum de entrada; 1 = control total como en el
## movimiento normal. Bajarlo evita sentir que te movés demasiado libre de lado sobre el muro.
@export_range(0.0, 1.0) var wall_slide_steer_control := 1.0
## Empuje horizontal (m/s) a lo largo de la pared al enganchar, en la dirección en que ya
## venías. Ensancha el arco del slide (evita el arco alto y flaco que cae vertical cuando
## llegás lento). 0 = sin empuje. Se nota junto con un `wall_slide_momentum_decay` bajo,
## que conserva el lateral durante toda la bajada.
@export var wall_slide_stick_push := 0.0
## Impulso vertical del wall jump (m/s). Junto con away_speed define el ángulo vertical del rebote.
@export var wall_slide_wall_jump_up_speed := 7.2
## Impulso horizontal perpendicular a la pared del wall jump (m/s). Junto con up_speed
## define el ángulo vertical; junto con along_speed, el desvío horizontal.
@export var wall_slide_wall_jump_away_speed := 4.8
## Componente lateral del wall jump cuando el input traía dirección a lo largo del muro (m/s).
## 0 = siempre sales perpendicular exacto.
@export var wall_slide_wall_jump_along_speed := 2.0
## Tiempo en que el rebote manda: bloquea el input de movimiento y el re-agarre de pared.
@export var wall_slide_wall_jump_lock_time := 0.2

@export_group("Enemy bounce")
## Impulso vertical del rebote sobre enemigos (m/s). Encadenar enemigos no aumenta esta altura.
@export var enemy_bounce_up_speed := 7.2
## Impulso horizontal perpendicular al enemigo (m/s).
@export var enemy_bounce_away_speed := 4.8
## Componente lateral del rebote cuando el input traia direccion (m/s).
@export var enemy_bounce_along_speed := 2.0
## Fraccion de la velocidad horizontal de llegada que se redirige hacia la salida del rebote.
@export_range(0.0, 1.0) var enemy_bounce_momentum_keep := 0.0
## Ventana tras el ultimo contacto en que el salto todavia rebota (segundos).
@export var enemy_bounce_grace := 0.1
## Bloqueo para rebotar del mismo enemigo otra vez; otros enemigos siempre se permiten.
@export var enemy_bounce_cooldown := 0.25
## Tiempo en que el rebote lateral manda: bloquea el input de movimiento un instante. El stomp no lo usa.
@export var enemy_bounce_lock_time := 0.2
## Reaccion opcional del enemigo al rebote. Null = sin reaccion.
@export var enemy_bounce_push: PushSettings

@export_group("Motor")
## Gravedad, en m/s² (negativa hacia abajo).
@export var gravity := -20.0
@export_group("Momentum")
## Segundos que tarda en drenarse un exceso equivalente a UNA move_speed, apoyado en el suelo.
## El drenaje es lineal: el doble de exceso tarda el doble de tiempo.
@export var momentum_bleed_seconds_per_unit := 3.0
## Techo del exceso acumulable (m/s). Encadenar rebotes compone: sin techo, diverge.
@export var momentum_max_speed := 18.0
## Multiplicador del drenaje apoyado en el suelo. Es la referencia: dejarlo en 1.0.
@export_range(0.0, 1.0) var momentum_bleed_ground := 1.0
## Multiplicador del drenaje pegado a una pared. 0.5 = la pared te frena la mitad que el suelo.
@export_range(0.0, 1.0) var momentum_bleed_wall := 0.5
## Multiplicador del drenaje en el aire. 0.1 = el aire te frena una decima parte que el suelo.
@export_range(0.0, 1.0) var momentum_bleed_air := 0.1

@export_group("Stun")
## Duración del stun si la fuente no manda una propia, en segundos.
@export var default_stun_duration := 0.45

@export_subgroup("Poise")
# Mismo medidor que los enemigos (combat/poise.gd): los golpes comen poise y el stun entra
# cuando el acumulado supera la reserva. Diferencia clave: el player NO degrada — su escalera
# es un solo escalón, así que cada quiebre le vuelve a costar lo mismo al enemigo.
## Reserva de poise a romper para stunear al player. Subirla = aguanta más presión enemiga.
@export var poise_max := 6.0
## Poise extra mientras el player esté armado (hoy is_armored() es stub: queda listo para cuando exista).
@export var armor_poise_bonus := 6.0
## Drenaje del poise acumulado, en puntos por segundo. Alto = perdona más los golpes espaciados.
@export var poise_decay_per_second := 1.5
## Escalera de degradación tras cada quiebre. [1.0] = el player nunca degrada (siempre al 100%).
@export var poise_break_levels: Array[float] = [1.0]
## Segundos sin recibir golpes tras los que la reserva vuelve al 100%.
@export var poise_recovery_time := 20.0

# Fogonazo BLANCO del golpe que come poise sin quebrarlo: "me dieron, pero aguanté". Tercer color
# del lenguaje de impacto — amarillo = stuneado, rojo = hazard (SpikeWall), blanco = absorbido.
## Color del fogonazo del golpe absorbido.
@export var poise_chip_color := Color(1.0, 1.0, 1.0, 1.0)
## Emisión del fogonazo absorbido. Requiere el glow del WorldEnvironment para el bloom.
@export var poise_chip_emission_energy := 2.0
## Segundos que tarda en apagarse el fogonazo. Corto: es un destello, no un estado.
@export var poise_chip_time := 0.12
## Escala de gravedad durante el stun (1 = normal; menos = flota más en stuns aéreos).
@export_range(0.0, 2.0) var stun_gravity_scale := 1.0
## Frenado del empuje horizontal del stun PUSH (m/s²): qué tan rápido muere el rebote.
@export var stun_bump_decay := 3.5
## Color y emisión del mesh mientras el player está stuneado.
@export var stun_color := Color(1.0, 0.9, 0.15, 1.0)
## Intensidad de la emisión de stun. Requiere glow del WorldEnvironment para bloom.
@export var stun_emission_energy := 1.8

@export_group("Dodge")
## Si el golpe en curso ya pasó esta fracción (0-1), el dodge NO lo corta: se buferea
## y sale apenas termina. Antes del umbral, cancela el ataque y dashea ya.
@export_range(0.0, 1.0) var dodge_cancel_attack_threshold := 0.5
## Ventana de invulnerabilidad al empezar el dodge (i-frames), en segundos. Independiente
## de dash_duration: 0 = sin i-frames. No aplica a force_dash (dash ofensivo).
@export var dodge_iframe_duration := 0.1

@export_group("Dash")
## Distancia recorrida por el dash/dodge, en metros.
@export var dash_distance := 4.0
## Duración del dash, en segundos (velocidad = distancia / duración).
@export var dash_duration := 0.12
## Al dashear con momentum (bump) activo: multiplicador del momentum que ya traías.
@export var dash_bump_momentum_multiplier := 1.5
## Al dashear con momentum: cuánto aporta la velocidad propia del dash al bump resultante.
@export var dash_bump_dash_speed_multiplier := 1.0
## Tope de velocidad del bump ganado por dash + momentum (m/s).
@export var dash_bump_max_speed := 24.0
## Si el dodge hace daño cuando hay barra de meter disponible.
@export var dash_deals_damage := true
## Daño del golpe del dodge (con barra).
@export var dash_damage := 1.0
## Radio de la esfera de golpe que acompaña al dash, en metros.
@export var dash_hit_radius := 0.8
## Offset del hitbox del dash hacia adelante (en la dirección del dash), en metros.
@export var dash_hit_forward_offset := 0.8
## Offset vertical del hitbox del dash, en metros.
@export var dash_hit_vertical_offset := 0.6
## StunSettings del golpe del dodge (hoy: potencia 0, el dodge no stunea).
@export var dash_stun: StunSettings

@export_group("Launcher")
## Al terminar de subir por un launch: segundos flotando en el pico con float_gravity.
@export var launcher_float_duration := 0.15
## Escala de gravedad durante el float del pico (bajo = flota).
@export var launcher_float_gravity := 0.30
## Tras el float: segundos de caída suavizada con fall_gravity antes de gravedad normal.
@export var launcher_fall_duration := 0.30
## Escala de gravedad durante la caída suavizada post-float.
@export var launcher_fall_gravity := 0.85

@export_group("Meter")
## Barras máximas de meter (hasta 5 con mejoras, futuro).
@export var meter_max_bars := 2
## Barras al empezar (arranca vacío; subir para testear ataques cargados).
@export var meter_start_bars := 0.0
## Meter ganado por pegarle a un enemigo (en barras).
@export var meter_gain_on_hit := 0.1
## Meter ganado por matar a un enemigo (en barras).
@export var meter_gain_on_kill := 0.5
## Costo del dash/dodge (en barras; 0.15 = 15% de una barra).
@export var meter_dash_cost := 0.15
## Costo del ataque cargado / sweet spot (en barras).
@export var meter_charged_cost := 1.0
## Ventana tras el cargado para que un kill cuente como kill especial, en segundos.
@export var meter_charged_kill_window := 0.6

@export_group("Input feel")
## Input durante animación se guarda esto y dispara en el primer frame libre (InputBuffer).
@export var input_buffer_time := 0.15
## Tap ejecuta al PRESS; si sigue presionado más que esto → hold (InputBuffer).
@export var input_hold_threshold := 0.18

@export_group("Lock-on")
## Rango máximo 3D para adquirir target (ex LockOnTargeting.maxRange).
@export var lock_max_range := 12.0
## Tolerancia respecto a la mira, en grados, medida en el plano horizontal (ex LockOnTargeting.lockHalfAngle).
@export var lock_half_angle := 45.0
## Tolerancia vertical del lock-on por encima/debajo del plano horizontal, en grados (enemigos aereos/GroundLocomotion en distinto nivel).
@export var lock_vertical_half_angle := 35.0
## Si es true, el reticle solo se muestra con armas afuera (el auto-aim del golpe
## y el snap de movimiento funcionan igual, tengan armas afuera o no).
@export var lock_require_weapons_out := true
## Offset vertical del reticle sobre la cabeza del enemigo.
@export var lock_reticle_height := 0.25

@export_group("Combat")
## Cuánto duran las "armas afuera" tras el último ataque (gatilla el lock-on, batch 6).
@export var weapons_out_duration := 3.0
## Ángulo de la pose de descanso del arma guardada, en grados.
@export var inactive_weapon_angle := 75.0
## Velocidad de giro al cambiar el arma entre pose activa y de descanso (grados/s).
@export var weapon_pose_rotate_speed := 720.0

@export_group("Dust FX")
## Velocidad horizontal mínima (m/s) a partir de la cual el jugador levanta polvo al correr.
## Solo aplica en el suelo; el look del polvo vive en el ParticleProcessMaterial del emisor RunDust.
@export var run_dust_min_speed := 1.5

@export_group("Air hit stall")
## Duración base del stall (freno de caída) al conectar un golpe en el aire, en segundos.
@export var air_stall_base := 0.08
## Duración extra de stall por cada golpe encadenado dentro de la ventana de combo.
@export var air_stall_per_hit := 0.04
## Tope de duración del stall por golpe, en segundos.
@export var air_stall_max := 0.28
## Ventana entre golpes aéreos para que el stall siga escalando; si pasa más tiempo, el conteo se resetea.
@export var air_stall_combo_window := 0.75
## Escala de gravedad durante el stall: conectando golpes en el aire la caída se RALENTIZA.
@export var air_stall_float_gravity := 0.15
## Tope de la subida (velocidad vertical positiva) que el stall preserva, en m/s. El stall congela
## la caída pero NO debe amplificar una subida grande: sin este cap, conectar un golpe justo tras un
## salto conservaba toda la velocidad del salto (jump_force) y con la gravedad baja del stall el
## jugador salía disparado. Debe quedar al nivel del hop intencional (air_wait_spin_hop = 5) y por
## debajo de jump_force (8).
@export var air_stall_max_rise := 5.0
## Escala de gravedad al atacar en el aire SIN conectar: cae MÁS fuerte que lo normal.
@export var aerial_whiff_fall_gravity := 1.6

@export_group("Air charge fall")
## Reduccion de caida al empezar cargas en el aire. 1.0 reinicia la caida a 0; 0.8 deja
## el 20% de la velocidad vertical negativa; al agotarse la lista se repite el ultimo valor.
@export var air_charge_fall_reduction_steps: Array[float] = [1.0, 0.8, 0.5, 0.1]
