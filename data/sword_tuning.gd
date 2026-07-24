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
## Separacion al salir por el lado opuesto de la trayectoria del dash tras el primer impacto.
@export var charged_dash_behind_offset := 1.2

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

@export_group("Launcher tap atras + Y")
## Segundos durante los cuales Y consume un toque que se alejo del objetivo lockeado. Cero lo
## desactiva. El gesto se interpreta sobre el plano horizontal tambien cuando el Player esta en aire.
@export var lock_back_y_launcher_window := 0.15

@export_group("Autoridad vertical")
## Perfil del Y cargado terrestre para el Player. Incluye su Float final: no depende de PlayerTuning.
@export var ground_charged_y_player_mover: MoverSettings
## Perfil del Y cargado terrestre para el Enemy. El arma lo envia junto al Stun que consulta poise.
@export var ground_charged_y_enemy_mover: MoverSettings
## Perfil del auto-launch del Player al iniciar Y cargada aerea, incluido su Float final.
@export var aerial_charged_y_player_mover: MoverSettings
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
