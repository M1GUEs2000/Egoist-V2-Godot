class_name PlayerTuning extends Resource
## TODOS los valores tuneables del jugador en un solo Resource (regla v2: los refactors
## nunca más resetean el tuning). Los defaults son los valores tuneados a mano en la v1.
## La instancia editable es data/player_tuning.tres.

@export_group("Locomotion")
## Velocidad horizontal base de movimiento, en m/s (suelo y aire).
@export var move_speed := 6.0
## Velocidad horizontal en tierra mientras se carga un ataque (X o Y sostenido), en m/s.
## Cargar obliga a caminar: reemplaza a move_speed durante la carga, siempre por debajo del
## umbral de Sprint del animation controller para que la pose de caminar-cargando sea consistente.
@export var ground_charge_move_speed := 3.0
## Aceleración del control aéreo, en m/s². En el aire la velocidad de input se CONSERVA
## (inercia) y el stick solo la empuja hacia donde apunta a este ritmo; en el suelo el input
## sigue mandando directo. Referencia: move_speed / air_acceleration = segundos de quieto a
## velocidad plena (9/30 ≈ 0.3 s; invertir el rumbo tarda el doble). Muy alto (>= 1000) ≈
## control instantáneo, como era antes de existir este knob.
@export var air_acceleration := 30.0
## Magnitud mínima del stick/input para contar como movimiento (debajo se ignora).
@export var move_input_deadzone := 0.15
## Si el input apunta a menos de estos grados del target lockeado, el movimiento snapea hacia él (LockOn).
@export var lock_move_snap_angle := 45.0
## Avance (lunge) hacia adelante en cada golpe del combo terrestre, en metros.
@export var attack_step_distance := 0.7

@export_group("Sprint")
# El sprint NO es una velocidad aparte: es un nivel 0-1 (boton `meter_button` sostenido) que multiplica
# los valores de abajo. Todo lo demas de este Resource sigue siendo el BASE — con el sprint en 0 el
# movimiento es identico al de siempre. Cada bono es un PORCENTAJE aplicado a sprint pleno: 40 = a
# nivel 1 ese canal vale 1.4x, a nivel 0.5 vale 1.2x. En 0 el canal no participa del sprint.
## Segundos de boton sostenido para pasar de sprint 0 a pleno. Mas bajo = arranca lanzado enseguida.
@export var sprint_charge_seconds := 1.2
## Segundos en volver de sprint pleno a 0 al soltar el boton. Corre igual en tierra que en el aire:
## soltar en pleno salto tambien apaga la carrera. Mas bajo = perdes la carrera apenas soltas.
@export var sprint_decay_seconds := 0.6
## Fraccion del meter COMPLETO por segundo que cuesta tener el sprint activo (nivel > 0). Es sobre
## el total, no por barra: 0.1 = 10% del meter por segundo, o sea un meter lleno se vacia en 10s
## corriendo, valga 2 o 5 barras. Sin meter no se puede cargar y el nivel cae solo: el sprint
## compite con el gasto de combate en vez de ser gratis.
@export_range(0.0, 1.0, 0.01) var sprint_meter_drain_per_second := 0.1
## Si el sprint exige ademas input direccional. true = frenar en seco corta la carga aunque sostengas
## el boton; false = el boton solo alcanza (el nivel sube incluso parado).
@export var sprint_requires_move_input := true
## Bono % a la velocidad horizontal en tierra (move_speed). Es el canal que mas se siente.
@export_range(0.0, 300.0, 1.0) var sprint_move_speed_bonus := 40.0
## Bono % a la ALTURA de cuspide del salto y del doble salto (min y max por igual).
@export_range(0.0, 300.0, 1.0) var sprint_jump_height_bonus := 20.0
## Bono % al AVANCE horizontal del salto, aparte de la altura. Alarga el arco sin subirlo mas.
@export_range(0.0, 300.0, 1.0) var sprint_jump_forward_bonus := 30.0
## Bono % a la velocidad INICIAL de deslice al enganchar la pared (escala min y max a la vez, asi
## el rango entero se corre sin deformarse). 100 = con sprint pleno el rango 2-4 pasa a 4-8.
@export_range(0.0, 300.0, 1.0) var sprint_wall_slide_initial_speed_bonus := 100.0
## Bono % a la velocidad FINAL de deslice, o sea al techo al que llega la rampa (min y max a la vez).
## Es el que decide cuanto mas lejos te lleva la pared con sprint: la rampa apunta mas alto y, como
## el wall jump se mide contra este mismo techo, el rebote escala con el.
@export_range(0.0, 300.0, 1.0) var sprint_wall_slide_final_speed_bonus := 40.0
## Bono % a la ACELERACION de la rampa del wall slide. No cambia adonde llegás (eso es el bono de
## velocidad final), cambia QUE TAN RAPIDO llegás: con sprint la rampa se recorre en menos tiempo,
## así que el tramo a potencia plena empieza antes y el slide se siente mas agresivo.
@export_range(0.0, 300.0, 1.0) var sprint_wall_slide_acceleration_bonus := 50.0
## Bono % a la salida HORIZONTAL del wall jump (escala su min y su max a la vez): que tan lejos te tira.
@export_range(0.0, 300.0, 1.0) var sprint_wall_jump_h_bonus := 30.0
## Bono % a la salida VERTICAL del wall jump (escala su min y su max a la vez): que tan alto te tira.
@export_range(0.0, 300.0, 1.0) var sprint_wall_jump_v_bonus := 20.0
## Bono % al carril Wall Impulse (velocidad inicial, aceleracion y tope de la pared).
@export_range(0.0, 300.0, 1.0) var sprint_wall_impulse_bonus := 25.0
## Bono % al techo global de momentum (momentum_max_speed). IMPORTANTE: todo impulso pasa por ese
## techo, asi que si este bono queda por debajo de los de wall jump / impulse, el recorte se los
## come y el sprint no se nota en las cadenas largas. Regla: dejarlo >= al mayor de esos dos.
@export_range(0.0, 300.0, 1.0) var sprint_momentum_max_bonus := 40.0

@export_group("Jump")
## Altura de cuspide con un toque corto, en metros. Mas alto = hasta donde llega un tap; mas bajo = salto corto.
@export var jump_min_apex_height := 2.0
## Altura de cuspide al mantener salto hasta el limite. Mas alto = hold salta mas alto; debe ser >= altura minima.
@export var jump_max_apex_height := 7.0
## Fraccion del impulso vertical inicial que se convierte en avance horizontal con direccion. 0 = salto vertical; mas alto = mas lejos por la misma altura.
@export_range(0.0, 2.0) var jump_forward_impulse_ratio := 0.7
## Duracion total de la parabola, en segundos. Mas bajo = salto rapido y tenso; mas alto = arco lento y flotante.
@export var jump_duration := 0.85
## Segundos de hold para pasar de altura minima a maxima. Mas bajo = alcanza la altura maxima antes; mas alto = requiere sostener mas tiempo.
@export var jump_hold_time := 0.25
## Porcentaje del arco en que se libera el control aereo. 0 = inmediatamente; 50 = cuspide; 100 = al aterrizar.
@export_range(0.0, 100.0, 1.0) var jump_control_release_percent := 45.0
## Cuanto se frena el avance horizontal en la cuspide. 0 = sin freno; mas alto = mas tiempo de reaccion; 1 = se detiene.
@export_range(0.0, 1.0) var jump_apex_slowdown_strength := 0.2
## Ancho del freno centrado en la cuspide, como porcentaje de la duracion. Mas bajo = pausa puntual; mas alto = frenado mas prolongado.
@export_range(0.0, 100.0, 1.0) var jump_apex_slowdown_window_percent := 30.0
## Fraccion del control aereo normal tras liberarse. 0 = sin correccion; mas alto = se frena y gira con mayor facilidad; 1 = control aereo normal.
@export_range(0.0, 1.0) var jump_post_release_air_control_scale := 0.4
## Estallido verde a los pies al gastar el doble salto (mismo verde que el bloque/dodge de traversal).
@export var double_jump_burst_enabled := true
## Cantidad de motas del estallido de doble salto.
@export_range(0, 128, 1) var double_jump_burst_amount := 20
## Velocidad de salida de las motas en m/s.
@export var double_jump_burst_speed := 4.0
## Gravedad que tira las motas hacia abajo tras estallar (m/s^2 del emisor).
@export var double_jump_burst_gravity := 6.0
## Cuanto dura la estela: tiempo emitiendo motas en los pies del jugador y vida de cada mota
## (nace, desvanece y muere en esta ventana). Mas alto = estela mas larga y persistente.
@export_range(0.05, 3.0, 0.05) var double_jump_burst_lifetime := 0.3
## Lado de cada mota del estallido en metros.
@export_range(0.01, 0.5, 0.01) var double_jump_burst_size := 0.12

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
## Cooldown para volver a engancharse tras despegarse A PROPÓSITO (stick hacia afuera), en segundos.
## Sin esto, soltar y re-pegar es un RESET GRATIS del slide: vuelve a arrancar la rampa, cancela el
## drenaje y devuelve potencia plena de rebote, así que aleteando el stick te quedás en la pared para
## siempre. Solo aplica al despegue voluntario: perder contacto por geometría (esquinas) sigue
## pudiendo re-enganchar de inmediato, que es lo que hace fluido el encadenado.
@export var wall_slide_reattach_cooldown := 0.35
## Velocidad máxima de caída deslizando, una vez que la rampa terminó y empezó la caída (m/s).
@export var wall_slide_max_fall_speed := 3.4
## Fracción de la gravedad aplicada durante la CAÍDA del slide (0 = no cae, 1 = gravedad completa).
## Solo actúa después de que la rampa llegó a su velocidad final: mientras acelerás, la pared te
## sostiene y no caés nada.
@export_range(0.0, 1.0) var wall_slide_gravity_scale := 0.35
## TREPADO: cuánto del empuje CONTRA la pared se dobla hacia arriba. Es lo que decide si el slide
## puede subir. 0 = solo deslizás de lado (aplastarte contra el muro no hace nada, comportamiento
## viejo); 1 = trepás tan rápido como deslizás. Vale tanto para la velocidad con la que LLEGÁS
## (entrar de frente lanzado = subís) como para el input en vivo (empujar al muro = seguís subiendo).
## Bajarlo hace que trepar sea más caro que deslizar de lado sin desactivarlo del todo.
@export_range(0.0, 1.0, 0.05) var wall_slide_climb_ratio := 1.0
## Ángulo MÁXIMO de trepado sobre la horizontal, en grados. Es un tope duro del rumbo: por más de
## frente que entres o más apretado que empujes el stick contra el muro, el slide nunca sube más
## empinado que esto. 0 = no trepás nunca (puro lateral); 45 = el rumbo más vertical es una diagonal
## a media altura; 90 = sin tope (trepás vertical puro, que se siente absurdo).
@export_range(0.0, 89.0, 1.0) var wall_slide_max_climb_angle := 45.0
## Autoridad del input vivo para REDIRIGIR el rumbo a lo largo de la pared (0-1). Ojo: el input ya
## no cambia la RAPIDEZ (esa la manda la rampa entera), solo hacia qué lado deslizás. 0 = el rumbo
## de entrada es inamovible; 1 = girás en ~1.4 s de un extremo al otro de la pared.
@export_range(0.0, 1.0) var wall_slide_steer_control := 1.0

# ────────────────────────────────────────────────────────────────────────────────────────────────
# LA RAMPA. El slide es un solo tramo de aceleración: al enganchar arrancás en una velocidad INICIAL
# y acelerás hacia una velocidad FINAL. Cuando llegás a la final, la pared deja de sostenerte y
# empieza la caída. Los dos extremos salen de rangos y el punto dentro del rango lo elige qué tan
# rasante llegaste (tangente 0 → min, tangente >= move_speed → max), así llegar lanzado te da un
# tramo más rápido Y un techo más alto.
#
# Por qué rangos absolutos y no multiplicadores: la salida del slide queda ANCLADA a la velocidad
# final pase lo que pase. Entrés con 5 o con 40, terminás en el mismo techo. Por eso encadenar
# paredes converge en vez de acelerarse rebote a rebote (que era el bug viejo del h_boost).
# ────────────────────────────────────────────────────────────────────────────────────────────────
## Velocidad (m/s) con la que ARRANCA el deslice llegando de frente al muro (sin componente lateral).
@export var wall_slide_initial_speed_min := 6.0
## Velocidad (m/s) con la que ARRANCA el deslice llegando rasante (tangente >= move_speed).
@export var wall_slide_initial_speed_max := 10.0
## Velocidad (m/s) a la que LLEGA la rampa si enganchaste de frente. Es el techo del tramo lento.
@export var wall_slide_final_speed_min := 10.0
## Velocidad (m/s) a la que LLEGA la rampa si enganchaste rasante. Es el techo absoluto del slide y
## la referencia contra la que se miden el wall jump y el brillo.
@export var wall_slide_final_speed_max := 15.0
## Aceleración de la rampa (m/s²). Es el knob que decide CUÁNTO DURA el slide: el tramo tarda
## (final − inicial) / esto segundos. Más bajo = deslice largo y planeado; más alto = llegás al
## techo enseguida y la caída empieza casi de una.
@export var wall_slide_acceleration := 8.0

# CAÍDA. Al tocar la velocidad final el lateral no se corta de golpe: aguanta un momento al 100% y
# después se drena exponencialmente. Así la potencia del wall jump se degrada suave (tenés margen
# para reaccionar) en vez de desplomarse al mínimo en un par de frames.
## Segundos al 100% de la velocidad final antes de que arranque el drenaje. Es la ventana en la que
## el wall jump sale a máxima potencia: subirlo perdona la ejecución, bajarlo la exige.
@export_range(0.0, 2.0, 0.01) var wall_slide_fall_hold_time := 0.15
## Vida media del drenaje lateral (segundos): cada tanto tiempo la velocidad a lo largo del muro cae
## a la MITAD. Al ser exponencial nunca llega a cero seco — se desploma rápido al principio y va
## aflojando. Más bajo = pierde el lateral de golpe; más alto = sigue avanzando de costado al caer.
@export_range(0.05, 3.0, 0.01) var wall_slide_fall_lateral_halflife := 0.35

# ────────────────────────────────────────────────────────────────────────────────────────────────
# EL WALL JUMP. Rangos absolutos, igual que la rampa: hay un rebote mínimo y uno máximo, y tu
# velocidad del momento a lo largo del muro decide dónde caés dentro de ellos. Sin multiplicadores,
# así el rebote no puede escalar solo. El ángulo de salida sale gratis de tener H y V por separado;
# `min_angle` solo decide el reparto HORIZONTAL entre alejarse del muro y seguir de largo.
# ────────────────────────────────────────────────────────────────────────────────────────────────
## Salida HORIZONTAL (m/s) del rebote más flojo: llegás casi sin velocidad a lo largo del muro.
## Es el piso que garantiza que siempre despegues de la pared.
@export var wall_slide_wall_jump_h_min := 8.0
## Salida HORIZONTAL (m/s) del rebote pleno: qué tan lejos te tira yendo a tope por la pared.
@export var wall_slide_wall_jump_h_max := 20.0
## Salida VERTICAL (m/s) del rebote más flojo. Es el piso de subida: aunque llegues cayendo casi
## vertical, el rebote de emergencia igual te levanta algo.
@export var wall_slide_wall_jump_v_min := 8.0
## Salida VERTICAL (m/s) del rebote pleno: qué tan alto te tira yendo a tope.
## Referencia: la altura del salto normal la definen jump_min_apex_height y jump_max_apex_height.
@export var wall_slide_wall_jump_v_max := 16.0
## Porcentaje de la velocidad final del slide en el que el rebote ya entrega el 100%. Con 80, todo
## lo que esté por encima del 80% del techo da salto pleno: hay una MESETA arriba en vez de un pico
## exacto, así no perdés potencia por no clavar el frame justo. Bajarlo la ensancha más.
@export_range(10.0, 100.0, 1.0) var wall_slide_wall_jump_full_power_percent := 80.0
## Ángulo MÍNIMO de salida respecto a la cara de la pared, en grados. Reparte la salida HORIZONTAL
## entre alejarse del muro y seguir tu rumbo: cuanto más rápido vas a lo largo, más rasante salís
## (nunca menos que esto, para no rozar el muro); sin velocidad lateral salís perpendicular (90°).
@export_range(0.0, 90.0) var wall_slide_wall_jump_min_angle := 35.0
## Tiempo en que el rebote manda: bloquea el input de movimiento y el re-agarre de pared.
@export var wall_slide_wall_jump_lock_time := 0.2
## DEBUG: muestra una flecha de ~2 m mientras deslizás, apuntando al ángulo al que te va a lanzar el
## wall jump ahora mismo (ayuda visual para tunear). Apagar para jugar limpio.
@export var wall_slide_show_jump_arrow := true

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
## Stun que aplica el rebote (poise, nunca daño). Es lo que le da derecho al push a desplazar al
## enemigo: `EnemyBase.push()` solo mueve si la reserva quedo quebrada, asi que sin esto el empujon
## se descarta entero. Null = el rebote no stunea y solo empuja a un enemigo ya stuneado o aereo.
@export var enemy_bounce_stun: StunSettings
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
## Estallido verde al aplicarse el bop de salida del bloque verde (empuje horizontal/vertical).
@export var dash_bop_burst_enabled := true
## Cantidad de motas del estallido de salida.
@export_range(0, 128, 1) var dash_bop_burst_amount := 24
## Velocidad de salida de las motas en m/s.
@export var dash_bop_burst_speed := 7.0
## Gravedad que tira las motas al piso tras estallar (m/s^2 del emisor).
@export var dash_bop_burst_gravity := 9.0
## Cuanto vive cada mota del estallido, en segundos.
@export_range(0.1, 3.0, 0.1) var dash_bop_burst_lifetime := 0.6
## Lado de cada mota del estallido en metros.
@export_range(0.01, 0.5, 0.01) var dash_bop_burst_size := 0.12

@export_group("Meter")
# Acá vive lo que el meter CUESTA, porque el gasto es del jugador. Lo que el meter GANA es de la
# fuente: cada arma trae su `WeaponTuning.meter_gain_on_hit` / `meter_gain_on_kill`, el Brazo el
# suyo (`ArmTuning`) y los bloques el de su escena.
## Barras máximas de meter (hasta 5 con mejoras, futuro).
@export var meter_max_bars := 2
## Barras al empezar (arranca vacío; subir para testear ataques cargados).
@export var meter_start_bars := 0.0
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
## Cono de adquisición del lock-on, en grados: distancia angular máxima al CENTRO DE PANTALLA
## (se mide desde la cámara, no desde el jugador — ver LockOn._best_camera_target). Cono circular,
## no separa horizontal de vertical. Referencia: el FOV vertical de la escena es 60, o sea que ~35
## ya cubre pantalla completa; más alto que eso deja de filtrar y lockea cosas fuera de cuadro.
@export var lock_half_angle := 35.0
## Tolerancia vertical del SNAP DE ATAQUE por encima/debajo del plano horizontal, en grados
## (enemigos aereos/GroundLocomotion en distinto nivel). Solo lo usa LockOn.nearest_in_cone; el
## lock-on ya no lo mira. En 90 queda desactivado de hecho (atan2 nunca lo supera).
@export var lock_vertical_half_angle := 35.0
## Cono horizontal del snap del golpe sin lock, en grados, medido desde el jugador contra su
## propio forward (ex LockOnTargeting.lockHalfAngle). Separado de `lock_half_angle` porque ese
## vive en el marco de la cámara: mezclarlos hacía que tunear el lock-on moviera el feel del golpe.
@export var attack_snap_half_angle := 60.0
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
## Color del polvo de correr con el sprint a tope. Se mezcla desde el color normal del emisor
## siguiendo la MISMA rampa gradual que la velocidad, así el verde entra a la par que acelerás.
## Default: el verde de traversal del proyecto (World.COLOR_TRAVERSAL_DASH), el mismo del wall slide.
@export var run_dust_sprint_color := World.COLOR_TRAVERSAL_DASH
## Intensidad HDR del polvo verde de sprint. El emisor es unshaded, así que el brillo no sale de
## una emisión propia sino de empujar el color por encima de 1.0 para que lo agarre el glow del
## WorldEnvironment (mismo truco que Wall Impulse). 1 = sin brillo extra, 3 = 200% más brillante.
## Solo escala el RGB: el alpha queda intacto, así el fade del color_ramp del polvo no se pierde.
@export_range(1.0, 20.0, 0.25) var run_dust_sprint_emission_energy := 3.0

# ESTELAS DE SPRINT: a diferencia del polvo (que nace en los pies y solo en el suelo), el emisor
# SprintTrail cubre el cuerpo entero y funciona también en el aire. Emite en coordenadas de MUNDO,
# así las partículas se quedan donde nacieron mientras el jugador avanza: eso es lo que dibuja la
# estela. Encima se les da velocidad hacia atrás para que además se despeguen.
## Nivel de sprint (0-1) a partir del cual aparecen las estelas. Por debajo el emisor está apagado,
## así trotar no las dispara: son la señal visual de que el sprint ya está cargado.
@export_range(0.0, 1.0, 0.05) var sprint_trail_min_level := 0.35
## Color de las estelas. Default: el mismo verde de traversal que el polvo y el wall slide.
@export var sprint_trail_color := World.COLOR_TRAVERSAL_DASH
## Intensidad HDR de las estelas, con el mismo truco que el polvo: el emisor es unshaded, así que el
## brillo sale de empujar el RGB por encima de 1.0 para que lo levante el glow del WorldEnvironment.
@export_range(1.0, 20.0, 0.25) var sprint_trail_emission_energy := 4.0
## Velocidad (m/s) con la que las estelas se van hacia ATRÁS respecto a tu rumbo. 0 = quedan donde
## nacieron y la estela sale solo de que vos avanzás; subirlo las despega más rápido.
@export var sprint_trail_backward_speed := 2.5

@export_group("Dash air hit float")
## Hold del jugador cuando el hitbox del dash ofensivo conecta en el aire (request_float). duration 0
## = sin hang; fall_scale 0 = hold total, 0.15 = deriva lenta. Ver combat/floater.gd.
@export var dash_air_hit_floater: FloaterSettings

@export_group("Air charge float")
## Cargar en el aire cuelga al jugador con un Floater (mismo primitivo que el resto). Reemplaza al
## viejo freno de caida escalonado: ya no hay "desgaste" por uso, cada carga aerea abre la misma
## ventana. El desgaste queda como idea futura del Floater. duration 0 = cargar en aire no sostiene;
## fall_scale 0 = hold total, 0.15 = deriva lenta (como el air stall). Ver combat/floater.gd.
@export var air_charge_floater: FloaterSettings
