class_name SwordTuning extends WeaponTuning
## Tuning de la Espada (ex SwordWeapon.cs). Instancia editable: data/sword_tuning.tres.
## Los tamaños de los hitboxes (hoja, disco aéreo, launcher) viven como shapes en
## sword.tscn, igual que la cápsula del player.

@export_group("Combo X")
@export var combo_window := 0.6
## Rama "espera": tardar al menos esto (dentro de la ventana) en encadenar el 3er golpe
## convierte los golpes 3-4 de estocadas a vueltas completas.
@export var ground_wait_branch_threshold := 0.3

@export_group("Swings (ángulos)")
## Barrido del golpe Y básico (tap, launcher y cargada aérea).
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

@export_group("Y cargada aérea (spike + rebote)")
## Velocidad del spike hacia el suelo antes de rebotar. La altura del auto-launch y del
## rebote reusan el launcher Y (height/hang_time), "lo mismo que un launcher".
@export var aerial_charged_down_speed := 30.0
## La cargada aerea usa un auto-launch mas lento que el launcher Y normal para que el
## enemigo alcance el punto de encuentro tras rebotar.
@export var aerial_charged_player_height := 2.4
@export var aerial_charged_player_rise_time := 0.32
@export var aerial_charged_meet_height := 2.2

@export_group("Launcher Y")
@export var launcher_height := 4.0
@export var launcher_hang_time := 1.0
@export var launcher_hitbox_duration := 0.18
@export var launcher_deals_damage := true
