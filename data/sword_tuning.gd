class_name SwordTuning extends WeaponTuning
## Tuning de la Espada (ex SwordWeapon.cs). Instancia editable: data/sword_tuning.tres.
## Los tamaños de los hitboxes (hoja, disco aéreo, vertical) viven como shapes en
## sword.tscn, igual que la cápsula del player.
##
## Organizacion del inspector: una CATEGORIA por tipo de ataque (normales, cargados, taps),
## un GRUPO por golpe y un SUBGRUPO por tramo (suelo/aire) con los perfiles Mover/Floater de
## cada cuerpo. Un perfil solo mueve/cuelga a su dueno: si un golpe toca a los dos, hay dos
## campos (Player y Enemy); si solo toca a uno, hay uno solo. Ver obsidian/Mover y Floater.

@export_group("Debug")
## Dibuja un wireframe rojo de cada hitbox (BladeHitbox, AirDiscHitbox, VerticalHitbox,
## ChargedDashHitbox) solo mientras esta activo (begin_swing/end_swing). Solo en builds de
## debug; en release no hace nada. Ver combat/hitbox.gd.
@export var debug_show_hitboxes := true

@export_group("Comun a varios golpes")
## Medio arco del golpe Y basico, en grados. Lo comparten el launcher terrestre (Y cargado),
## la Y cargada aerea y el tap atras + X, que reusan el mismo swing vertical.
@export var strike_angle := 150.0

# ============================================================================
@export_category("Ataques normales (tap)")
# ============================================================================

@export_group("Combo terrestre (X X X X)")
## Segundos para encadenar el siguiente golpe del combo terrestre.
@export var combo_window := 0.6
## Rama "espera": tardar al menos esto (dentro de la ventana) en encadenar el 3er golpe
## convierte los golpes 3-4 de estocadas a vueltas completas.
@export var ground_wait_branch_threshold := 0.3
## Medio arco de los swings 1-2 del combo terrestre, en grados (de -esto a +esto).
@export var combo_swing_angle := 70.0
## Metros que el brazo extiende por encima de hand_radius en el pico de la estocada
## (golpes 3-4 sin espera). La mano sale hasta ahi y vuelve; la hoja no rota, avanza
## porque la mano se aleja.
@export var thrust_reach := 1.0

@export_group("Combo aereo (X X X)")
## Diagonal aerea: medio arco horizontal en grados, cuanto cruza la mano por delante del jugador.
@export var air_diagonal_yaw := 55.0
## Diagonal aerea: medio arco vertical en grados, cuanto baja la mano mientras cruza. Igualarlo
## al yaw da una diagonal a 45°; subirlo la pica mas, bajarlo la aplana hacia horizontal.
@export var air_diagonal_pitch := 45.0
## Medio arco del hachazo vertical del finisher aereo, en grados.
@export var air_finisher_angle := 95.0
## Estira VERTICALMENTE los hitboxes del hachazo aereo mientras dura ese golpe: multiplica el
## alto de la caja de la hoja y convierte el disco aereo en una capsula vertical de esa altura.
## 1 = sin estirar. Aplica al finisher (X X X), al plunge (X X espera X) y al tap atras + Y aereo,
## que comparten coreografia; no afecta a los otros golpes.
@export var air_finisher_hitbox_v_scale := 1.5

@export_subgroup("Finisher X X X — Mover")
## Spike descendente del Enemy al cerrar el hachazo aereo. El Player no recibe perfil: sigue
## su caida normal.
@export var air_finisher_enemy_spike_mover: MoverSettings

@export_subgroup("Rama espera: hop — Mover")
## Hop PARTIAL del Player en la primera vuelta de la rama aerea de espera (X espera X X).
## Solo el Player: es juice de la vuelta, no toca al Enemy.
@export var air_wait_spin_player_mover: MoverSettings

@export_subgroup("Rama espera: plunge — Mover")
## Perfil descendente del Player para el plunge de X X espera X. Es PARTIAL para controlar Y
## sin apagar sus contactos de locomocion.
@export var air_plunge_player_mover: MoverSettings
## Perfil descendente del Enemy para el mismo plunge. Mantener el mismo speed que el del Player
## es lo que los hace bajar a la par.
@export var air_plunge_enemy_mover: MoverSettings

@export_subgroup("Impacto aereo — Floater")
## Hold del ENEMIGO al conectarle un golpe aereo NORMAL (no cargado): lo suspende en el aire
## mientras dura el juggle, simetrico al air_hit_player_floater de WeaponTuning. Es un hold PURO
## sin recorrido (request_float), no un Mover. Cada golpe renueva el tiempo (el Floater usa max),
## asi el enemigo queda "pegado" durante el combo y cae al dejar de golpearlo. Sin esto, pegarle
## en plena caida no lo frena (solo lo sostenia el launcher/hang, ya vencido). fall_scale 0 =
## hold total (vertical en 0); subirlo lo deja hundirse. duration 0 = desactiva el hold.
## Ver combat/floater.gd y obsidian/Plan Autoridad Vertical. Pendiente de tunear jugando.
@export var air_hit_enemy_floater: FloaterSettings

# ============================================================================
@export_category("Cargados (hold)")
# ============================================================================

@export_group("X cargado — dash (suelo y aire)", "charged_")
## Metros que recorre el dash ofensivo.
@export var charged_dash_distance := 5.0
## Segundos que dura el dash. Junto con la distancia define su velocidad.
@export var charged_dash_duration := 0.14
## El dash cargado tiene su PROPIO hitbox (en la espada), separado del dash de movimiento
## del dodge: su daño/stun/tamaño se tunean aca, no en PlayerTuning.
@export var charged_dash_damage := 1.0
## Radio en metros de la esfera del hitbox propio del dash.
@export var charged_dash_hit_radius := 1.1
## Stun que aplica el dash al conectar.
@export var charged_dash_stun: StunSettings
## Separacion en metros al salir por el lado opuesto de la trayectoria del dash tras el
## primer impacto (el Player atraviesa al enemigo y aparece detras).
@export var charged_dash_behind_offset := 1.2
## Medio arco del swing degradado, en grados, cuando no hay barra para el dash.
@export var charged_fallback_angle := 130.0

@export_group("Y cargado suelo — launcher", "ground_charged_y_")
## Segundos que queda activo el hitbox vertical del launcher.
@export var ground_charged_y_hitbox_duration := 0.18
## Si el launcher cobra daño ademas de elevar. Apagarlo lo deja como puro abre-juggle.
@export var ground_charged_y_deals_damage := true

@export_subgroup("Mover", "ground_charged_y_")
## Ascenso del Player. Incluye su Float final: no depende de PlayerTuning.
@export var ground_charged_y_player_mover: MoverSettings
## Ascenso del Enemy. El arma lo envia junto al Stun que consulta poise.
@export var ground_charged_y_enemy_mover: MoverSettings

@export_group("Y cargado aereo (DESACTIVADO)", "aerial_charged_y_")
## El rebote de este move depende del "bouncer", que todavia no existe: hasta entonces sostener Y
## en el aire cae al combo aereo normal y estos perfiles no se usan. Ver obsidian/Espada.

@export_subgroup("Mover", "aerial_charged_y_")
## Auto-launch del Player al iniciar el golpe, incluido su Float final.
@export var aerial_charged_y_player_mover: MoverSettings
## Spike lineal descendente del Enemy; corta al tocar piso.
@export var aerial_charged_y_enemy_spike_mover: MoverSettings

# ============================================================================
@export_category("Taps direccionales (lock-on)")
# ============================================================================

@export_group("Tap X adelante — vueltas estaticas", "tap_forward_x_")
## Segundos para pulsar X despues de un tap que se acerca al objetivo lockeado. 0 desactiva
## el gesto. En suelo y aire solo hace vueltas; nunca dispara proyectil.
@export var tap_forward_x_window := 0.15
## Cantidad de vueltas de la variante normal, tanto en suelo como en aire.
@export_range(1, 8, 1) var tap_forward_x_spins := 2

@export_subgroup("Aire — Floater", "tap_forward_x_air_")
## Hang de las vueltas aereas. Se pide con el mismo perfil para el Player y para cada
## enemigo conectado, por eso hay un solo campo. fall_scale 0 congela la gravedad.
@export var tap_forward_x_air_floater: FloaterSettings

@export_subgroup("RT + meter", "tap_forward_x_sprint_")
## Cantidad de vueltas al pagar RT. No usa Mover ni proyectil en suelo o aire.
@export_range(1, 8, 1) var tap_forward_x_sprint_spins := 3

@export_subgroup("RT aire — Floater", "tap_forward_x_sprint_air_")
## Hang del Player durante adelante X + RT aereo, separado de la variante normal.
@export var tap_forward_x_sprint_air_player_floater: FloaterSettings
## Hang de cada Enemy conectado por adelante X + RT aereo.
@export var tap_forward_x_sprint_air_enemy_floater: FloaterSettings

@export_group("Tap X atras — retroceso", "tap_back_x_")
## Segundos para pulsar X despues de un tap que se aleja del objetivo lockeado. 0 desactiva
## el gesto. En suelo y aire retrocede horizontalmente al Player.
@export var tap_back_x_window := 0.15

@export_subgroup("Suelo — Mover", "tap_back_x_")
## Retroceso terrestre normal del Player. La Espada lo clona y orienta en sentido opuesto al target.
@export var tap_back_x_player_mover: MoverSettings

@export_subgroup("Aire — Mover y vueltas", "tap_back_x_air_")
## Retroceso aereo corto de la variante normal. No dispara proyectil.
@export var tap_back_x_air_player_mover: MoverSettings
## Cantidad de vueltas de la variante normal aerea.
@export_range(1, 8, 1) var tap_back_x_air_spins := 1

@export_subgroup("RT suelo — Mover y launcher", "tap_back_x_sprint_")
## Retroceso terrestre mas rapido. Al terminar dispara el proyectil.
@export var tap_back_x_sprint_player_mover: MoverSettings
## Launcher aplicado por el proyectil de atras X + RT terrestre.
@export var tap_back_x_sprint_projectile_enemy_mover: MoverSettings

@export_subgroup("RT aire — Mover, vueltas y launcher", "tap_back_x_sprint_air_")
## Retroceso aereo extendido. Al terminar dispara el proyectil.
@export var tap_back_x_sprint_air_player_mover: MoverSettings
## Cantidad de vueltas de la variante aerea con RT.
@export_range(1, 8, 1) var tap_back_x_sprint_air_spins := 2
## Launcher aplicado por el proyectil de atras X + RT aereo.
@export var tap_back_x_sprint_air_projectile_enemy_mover: MoverSettings
## Floater del Player al terminar el retroceso aereo RT, separado del Mover.
@export var tap_back_x_sprint_air_player_floater: FloaterSettings
## Floater de cada Enemy conectado por atras X + RT aereo.
@export var tap_back_x_sprint_air_enemy_floater: FloaterSettings

@export_group("Tap X direccional + RT — meter y brillo", "tap_x_sprint_")
## Barras que cuesta combinar RT con tap adelante/atras + X. 0 desactiva el coste.
@export_range(0.0, 5.0, 0.05) var tap_x_sprint_meter_cost := 0.5
## Fogonazo aditivo del Player al pagar el gesto. Duracion en segundos.
@export var tap_x_sprint_flash_color := Color(1.0, 0.16, 0.015)
@export_range(0.0, 12.0, 0.1) var tap_x_sprint_flash_energy := 5.0
@export_range(0.0, 2.0, 0.01) var tap_x_sprint_flash_duration := 0.45

@export_group("Tap X direccional — proyectil", "tap_x_sprint_projectile_")
## Valores visuales y ofensivos compartidos. Cada ataque que dispara define su launcher junto a
## sus propios perfiles; el proyectil no decide cuanto eleva al Enemy.
## Velocidad del proyectil, en m/s.
@export var tap_x_sprint_projectile_speed := 22.0
## Grados por segundo de homing hacia el target bloqueado. 0 = recto.
@export var tap_x_sprint_projectile_turn_rate := 180.0
## Daño del proyectil ofensivo. El stun reutiliza el `stun` de la Espada.
@export var tap_x_sprint_projectile_damage := 3.0
## Segundos antes de destruir el proyectil si no impacta.
@export var tap_x_sprint_projectile_lifetime := 1.5
## Radio de colision y del mesh esferico del proyectil, en metros.
@export var tap_x_sprint_projectile_radius := 0.22
## Avance y altura del origen respecto al Player, en metros.
@export var tap_x_sprint_projectile_forward_offset := 1.1
@export var tap_x_sprint_projectile_height := 1.0
## Color HDR y energia del proyectil. El RGB se escala con la energia para producir bloom.
@export var tap_x_sprint_projectile_color := Color(0.2, 0.9, 1.0)
@export_range(0.0, 12.0, 0.1) var tap_x_sprint_projectile_energy := 3.0

@export_group("Tap Y adelante — avance con vuelta", "tap_forward_y_")
## Segundos para pulsar Y despues de un tap que se acerca al objetivo lockeado. 0 desactiva
## el gesto. Reusa la vuelta final de la rama espera; en aire ademas arma el push del Enemy.
@export var tap_forward_y_window := 0.15

@export_subgroup("Suelo y aire — Mover", "tap_forward_y_")
## Avance del Player hacia el objetivo. La Espada clona el recurso y orienta su direccion al
## target lockeado antes de solicitarlo, para no mutar el .tres compartido. Al Enemy no lo
## mueve un Mover: en aire lo desplaza el push (WeaponTuning).
@export var tap_forward_y_player_mover: MoverSettings

@export_group("Tap Y atras — launcher / plunge", "tap_back_y_")
## Segundos para pulsar Y despues de un tap que se aleja del objetivo lockeado. 0 desactiva
## el gesto. Es gratis (no gasta barra): en suelo eleva solo al Enemy, en aire hunde a los dos.
@export var tap_back_y_window := 0.15

@export_subgroup("Suelo — Mover", "tap_back_y_")
## Ascenso del Enemy en el launcher sin barra. El Player no se mueve en esta rama, por eso no
## tiene perfil propio. Separado del Y cargado terrestre para poder tunearlo aparte.
@export var tap_back_y_enemy_mover: MoverSettings

@export_subgroup("Aire — Mover (plunge)", "tap_back_y_air_")
## Caida del Player en el plunge del hachazo. PARTIAL, para conservar sus contactos. Separado
## del plunge de la rama espera para poder tunearlo aparte.
@export var tap_back_y_air_player_mover: MoverSettings
## Caida del Enemy golpeado. Mismo speed que el del Player = bajan a la par.
@export var tap_back_y_air_enemy_mover: MoverSettings
