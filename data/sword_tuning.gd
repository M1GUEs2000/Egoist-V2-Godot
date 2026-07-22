class_name SwordTuning extends WeaponTuning
## Tuning de la Espada (ex SwordWeapon.cs). Instancia editable: data/sword_tuning.tres.
## Los tamaños de los hitboxes (hoja, disco aéreo, vertical) viven como shapes en
## sword.tscn, igual que la cápsula del player.

@export_group("Debug")
## Dibuja un wireframe rojo de cada hitbox (BladeHitbox, AirDiscHitbox, VerticalHitbox,
## ChargedDashHitbox) solo mientras esta activo (begin_swing/end_swing). Solo en builds de
## debug; en release no hace nada. Ver combat/hitbox.gd.
@export var debug_show_hitboxes := true

@export_group("Combo X")
@export var combo_window := 0.6
## Rama "espera": tardar al menos esto (dentro de la ventana) en encadenar el 3er golpe
## convierte los golpes 3-4 de estocadas a vueltas completas.
@export var ground_wait_branch_threshold := 0.3

@export_group("Swings (ángulos)")
## Barrido del golpe Y básico (tap, vertical y cargada aérea).
@export var strike_angle := 150.0
## Medio arco de los swings 1-2 del combo terrestre (de -esto a +esto).
@export var combo_swing_angle := 70.0
## Medio arco del hachazo vertical del finisher aéreo.
@export var air_finisher_angle := 95.0
## Diagonal aérea: medio arco horizontal, cuánto cruza la mano por delante del jugador.
@export var air_diagonal_yaw := 55.0
## Diagonal aérea: medio arco vertical, cuánto baja la mano mientras cruza. Igualarlo al
## yaw da una diagonal a 45°; subirlo la pica más, bajarlo la aplana hacia horizontal.
@export var air_diagonal_pitch := 45.0
## Swing degradado del X cargado cuando no hay barra para el dash.
@export var charged_fallback_angle := 130.0

@export_group("Estocada")
## Metros que el brazo extiende por encima de hand_radius en el pico de la estocada.
## La mano sale hasta ahí y vuelve; la hoja no rota, avanza porque la mano se aleja.
@export var thrust_reach := 1.0

@export_group("X cargado (dash sweet spot)")
@export var charged_dash_distance := 5.0
@export var charged_dash_duration := 0.14
## El dash cargado tiene su PROPIO hitbox (en la espada), separado del dash de movimiento
## del dodge: su daño/stun/tamaño se tunean acá, no en PlayerTuning.
@export var charged_dash_damage := 1.0
@export var charged_dash_hit_radius := 1.1
@export var charged_dash_stun: StunSettings

@export_subgroup("Sweet spot del dash (explosion)")
## Segundos entre el final del dash y la explosion de todo lo que atraveso. Es el respiro
## entre "pase de largo" y el estallido: subirlo separa mas las dos lecturas.
@export var sweet_spot_explosion_delay := 0.18
## Dano extra que mete la explosion, aparte del dano del propio dash.
@export var sweet_spot_explosion_damage := 1.0
## Hold PROPIO del jugador cuando la explosion del sweet spot conecta, para ver el estallido en vez
## de caerse encima (request_float). No gasta el doble salto y solo aplica en el aire. duration 0 =
## sin hang; fall_scale 0 = hold total, 0.15 = deriva lenta. Ver combat/floater.gd.
@export var sweet_spot_player_floater: FloaterSettings
@export_subgroup("Motas del estallido (solo visual)")
## Nada de acá toca fisica ni gameplay: son las motas del estallido de cada enemigo, las
## mismas que tira un bloque de traversal al golpearlo (World.spawn_color_burst).
## Cuantas motas salen por enemigo.
@export var sweet_spot_burst_amount := 40
## Con cuanta fuerza se abren desde el centro del enemigo, en m/s.
@export var sweet_spot_burst_speed := 7.0
## Gravedad de las MOTAS (no la del juego, no la del enemigo): cuanto caen mientras viven.
## 0 = quedan flotando donde el estallido las dejo; subirlo las tira al piso mas rapido.
@export var sweet_spot_burst_particle_gravity := 12.0
## Segundos que vive cada mota.
@export var sweet_spot_burst_lifetime := 0.7
## Lado del quad de cada mota, en metros.
@export var sweet_spot_burst_size := 0.18

## Estira VERTICALMENTE los hitboxes del finisher aéreo (hachazo X X X y plunge X X espera X)
## mientras dura ese golpe: multiplica el alto de la caja de la hoja y convierte el disco
## aéreo en una cápsula vertical de esa altura. 1 = sin estirar. No afecta a los otros golpes.
@export var air_finisher_hitbox_v_scale := 1.5

@export_group("Plunge aéreo (X X espera X)")
## El Player y el Enemy reciben perfiles Mover descendentes; el del Player no es exclusivo para
## conservar los contactos de locomoción durante la caída.

@export_group("Y cargado terrestre")
@export var ground_charged_y_hitbox_duration := 0.18
@export var ground_charged_y_deals_damage := true

@export_group("Autoridad vertical")
## Perfil del Y cargado terrestre para el Player. Incluye su Float final: no depende de PlayerTuning.
@export var ground_charged_y_player_mover: MoverSettings
## Perfil del Y cargado terrestre para el Enemy. El arma lo envia junto al Stun que consulta poise.
@export var ground_charged_y_enemy_mover: MoverSettings
## Perfil del auto-launch del Player al iniciar Y cargada aerea, incluido su Float final.
@export var aerial_charged_y_player_mover: MoverSettings
## Perfil que la explosion del sweet spot pide a cada Enemy antes de cobrar su dano.
@export var sweet_spot_explosion_enemy_mover: MoverSettings
## Perfil lineal descendente del Enemy para el spike de Y cargada aerea; corta al tocar piso.
@export var aerial_charged_y_enemy_spike_mover: MoverSettings
## Perfil descendente del Enemy para el plunge de Espada; mantiene la misma velocidad que el Player.
@export var air_plunge_enemy_mover: MoverSettings
## Perfil parcial del Player para el plunge: controla Y sin apagar sus contactos.
@export var air_plunge_player_mover: MoverSettings
## Perfil parcial del hop de la primera vuelta de la rama aérea de espera.
@export var air_wait_spin_player_mover: MoverSettings
## Perfil descendente del Enemy para el hachazo aéreo normal de Espada.
@export var air_finisher_enemy_spike_mover: MoverSettings
## Hold del ENEMIGO al conectarle un golpe aéreo NORMAL (no cargado): lo suspende en el aire
## mientras dura el juggle, simétrico al air-hit-float del jugador. Es un hold PURO sin recorrido
## (request_float), no un Mover. Cada golpe renueva el tiempo (el Floater usa max), así el enemigo
## queda "pegado" durante el combo y cae al dejar de golpearlo. Sin esto, pegarle en plena caída no
## lo frena (solo lo sostenía el launcher/hang, ya vencido). fall_scale 0 = hold total (vertical en
## 0); subirlo lo deja hundirse. duration 0 = desactiva el hold. Ver combat/floater.gd y
## obsidian/Plan Autoridad Vertical. Pendiente de tunear jugando.
@export var air_hit_enemy_floater: FloaterSettings
