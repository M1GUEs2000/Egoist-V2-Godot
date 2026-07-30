class_name SwordTuning extends WeaponTuning
## Tuning de la Espada (ex SwordWeapon.cs). Instancia editable: data/sword_tuning.tres.
## Los tamaños de los hitboxes (hoja, disco aéreo, vertical) viven como shapes en
## sword.tscn, igual que la cápsula del player.
##
## Organizacion del inspector: una CATEGORIA por tipo de ataque (normales, cargados, taps),
## un GRUPO por golpe y un SUBGRUPO por tramo (suelo/aire) con los perfiles Mover/Floater de
## cada cuerpo. Un perfil solo mueve/cuelga a su dueno: si un golpe toca a los dos, hay dos
## campos (Player y Enemy); si solo toca a uno, hay uno solo. Ver obsidian/Mover y Floater.
##
## TODOS los ataques especiales —taps direccionales de X y de Y, cargados de Y— tienen UN
## AttackMovementProfile por GESTO (gesto x tramo) con todo lo que le hace a la posicion de los
## cuerpos, en vez de Movers y Floaters sueltos. La variante RT vive adentro como porcentajes sobre
## esa misma base, no como un perfil aparte. Debajo de cada gesto quedan los knobs de coreografia e
## input (ventana, vueltas, dano RT), que si siguen teniendo su valor propio porque no son posicion.
## Ver data/attack_movement_profile.gd.
##
## Un slot vacio dentro de un perfil es una decision legitima y visible ("este golpe no mueve a
## nadie"), asi que agregar o sacar movimiento de un especial se hace en el inspector, sin tocar
## codigo. El unico que NO lleva perfil es el X cargado, que mueve con force_dash y no con un Mover.
##
## Los COMBOS tambien son datos: un AttackSequence por cadena, con un AttackStep por golpe. Cada
## paso lleva su propio perfil de movimiento, asi que "el Mover sale en el tercer golpe" se declara
## en el inspector — era lo unico que faltaba para que la coreografia de una cadena dejara de ser
## codigo. Ver data/attack_sequence.gd.

@export_group("Debug")
## Dibuja un wireframe rojo de cada hitbox (BladeHitbox, AirDiscHitbox, VerticalHitbox,
## ChargedDashHitbox) solo mientras esta activo (begin_swing/end_swing). Solo en builds de
## debug; en release no hace nada. Ver combat/hitbox.gd.
@export var debug_show_hitboxes := true

# ============================================================================
@export_category("Ataques normales (tap)")
# ============================================================================

@export_group("Combo terrestre (X X X X)")
## La cadena entera declarada como datos: los cuatro golpes con su clip, su duracion, su dano y su
## movimiento, mas la rama de espera que convierte los golpes 3-4 en vueltas. Ver
## data/attack_sequence.gd. La ventana de encadene y el umbral de la rama viven adentro, no aca:
## son forma de la cadena, no personalidad del arma.
@export var ground_combo: AttackSequence

@export_group("Combo aereo (X X X)")
## La cadena aerea como datos, con sus DOS ramas de espera: tras el golpe 1 se va a vueltas
## (X espera X X) y tras el golpe 2 al plunge (X X espera X). Los Movers del spike, del hop y del
## plunge viven dentro del AttackMovementProfile del paso que los emite, no sueltos aca: el beat de
## la cadena en el que sale un recorrido es justamente lo que un paso puede expresar y un campo
## suelto no. Ver data/attack_sequence.gd.
@export var air_combo: AttackSequence

@export_subgroup("Hitbox del finisher aereo")
## Estira VERTICALMENTE los hitboxes del hachazo aereo mientras dura ese golpe: multiplica el
## alto de la caja de la hoja y convierte el disco aereo en una capsula vertical de esa altura.
## 1 = sin estirar. Aplica al finisher (X X X), al plunge (X X espera X) y al tap atras + Y aereo,
## que comparten coreografia; no afecta a los otros golpes.
@export var air_finisher_hitbox_v_scale := 1.5

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

@export_group("Y cargado suelo — launcher", "ground_charged_y_")
## Que le hace el gesto a la posicion de los cuerpos (ver data/attack_movement_profile.gd). Sube a
## los dos: `player_travel` es el ascenso del Player con su Float final incluido (no depende de
## PlayerTuning) y `enemy_travel` el del Enemy, en BEFORE_DAMAGE para que el Stun del mismo golpe ya
## lo vea en el aire — que es lo que convierte el golpe en un abre-juggle y no en un empujon.
@export var ground_charged_y: AttackMovementProfile

@export_subgroup("Coreografia", "ground_charged_y_")
## Segundos que queda activo el hitbox vertical del launcher. Lo comparte el tap atras + Y, que usa
## el mismo golpe con otro perfil.
@export var ground_charged_y_hitbox_duration := 0.18
## Si el launcher cobra daño ademas de elevar. Apagarlo lo deja como puro abre-juggle.
@export var ground_charged_y_deals_damage := true

@export_group("Y cargado aereo (DESACTIVADO)", "aerial_charged_y_")
## Que le hace el gesto a la posicion de los cuerpos: auto-launch del Player al iniciar el golpe
## (con su Float final) y spike lineal descendente del Enemy en ON_HIT — aca el Stun no necesita
## verlo en el aire, asi que el Mover puede salir despues del dano.
##
## El rebote de este move depende del "bouncer", que todavia no existe: hasta entonces sostener Y
## en el aire cae al combo aereo normal y este perfil no se usa. Ver obsidian/Espada.
@export var aerial_charged_y: AttackMovementProfile

# ============================================================================
@export_category("Taps direccionales (lock-on)")
# ============================================================================

@export_group("Tap X adelante — vueltas estaticas", "tap_forward_x_")
## Que le hace el gesto a la posicion de los cuerpos, con su variante RT adentro como porcentajes
## (ver data/attack_movement_profile.gd). Adelante X son vueltas puras: en suelo no mueve a nadie
## (perfil en null), en aire solo cuelga. No dispara proyectil ni con RT.
@export var tap_forward_x_ground: AttackMovementProfile
@export var tap_forward_x_air: AttackMovementProfile

@export_subgroup("Coreografia, input y dano RT", "tap_forward_x_")
## Segundos para pulsar X despues de un tap que se acerca al objetivo lockeado. 0 desactiva
## el gesto. En suelo y aire solo hace vueltas; nunca dispara proyectil.
@export var tap_forward_x_window := 0.15
## Cantidad de vueltas de la variante normal, tanto en suelo como en aire.
@export_range(1, 8, 1) var tap_forward_x_spins := 2
## Cantidad de vueltas al pagar RT.
@export_range(1, 8, 1) var tap_forward_x_meter_spins := 3
## Bono % al dano del golpe al pagar RT, por tramo. 0 = RT no pega mas fuerte, solo mas veces.
## El dano NO va en el AttackMovementProfile: ese Resource responde solo que le hace el golpe a la
## POSICION de los cuerpos, y meter dano ahi obligaria a que adelante X en suelo —que no mueve a
## nadie y por eso esta en null— tuviera perfil solo para llevar un numero. Ver obsidian/Armas.
@export_range(-100.0, 300.0, 1.0) var tap_forward_x_ground_meter_damage_bonus := 0.0
@export_range(-100.0, 300.0, 1.0) var tap_forward_x_air_meter_damage_bonus := 0.0

@export_group("Tap X atras — retroceso", "tap_back_x_")
## Que le hace el gesto a la posicion de los cuerpos, con su variante RT adentro como porcentajes
## (ver data/attack_movement_profile.gd). Atras X retrocede al Player con `player_travel` orientado
## PLAYER_BACK y con RT ademas dispara proyectil al cerrar ese recorrido. En aire el recorrido es
## `rt_only`: sin barra son vueltas en el sitio.
@export var tap_back_x_ground: AttackMovementProfile
@export var tap_back_x_air: AttackMovementProfile

@export_subgroup("Coreografia, input y dano RT", "tap_back_x_")
## Segundos para pulsar X despues de un tap que se aleja del objetivo lockeado. 0 desactiva
## el gesto. En suelo y aire retrocede horizontalmente al Player.
@export var tap_back_x_window := 0.15
## Cantidad de vueltas de la variante normal aerea.
@export_range(1, 8, 1) var tap_back_x_air_spins := 1
## Cantidad de vueltas de la variante aerea con RT.
@export_range(1, 8, 1) var tap_back_x_meter_air_spins := 2
## Bono % al dano del golpe al pagar RT, por tramo. 0 = RT no pega mas fuerte, solo retrocede mas
## y dispara. Mismo criterio que en adelante X: el dano no es posicion, asi que no va en el perfil.
@export_range(-100.0, 300.0, 1.0) var tap_back_x_ground_meter_damage_bonus := 0.0
@export_range(-100.0, 300.0, 1.0) var tap_back_x_air_meter_damage_bonus := 0.0

@export_group("Tap X direccional + RT — meter y brillo", "tap_x_meter_")
## Barras que cuesta combinar RT con tap adelante/atras + X. 0 desactiva el coste.
@export_range(0.0, 5.0, 0.05) var tap_x_meter_cost := 0.5
## Fogonazo aditivo del Player al pagar el gesto. Duracion en segundos.
@export var tap_x_meter_flash_color := Color(1.0, 0.16, 0.015)
@export_range(0.0, 12.0, 0.1) var tap_x_meter_flash_energy := 5.0
@export_range(0.0, 2.0, 0.01) var tap_x_meter_flash_duration := 0.45

@export_group("Tap X direccional — proyectil", "tap_x_meter_projectile_")
## Valores visuales y ofensivos compartidos. Cada ataque que dispara define su launcher junto a
## sus propios perfiles; el proyectil no decide cuanto eleva al Enemy.
## Velocidad del proyectil, en m/s.
@export var tap_x_meter_projectile_speed := 22.0
## Grados por segundo de homing hacia el target bloqueado. 0 = recto.
@export var tap_x_meter_projectile_turn_rate := 180.0
## Daño del proyectil ofensivo. El stun reutiliza el `stun` de la Espada.
@export var tap_x_meter_projectile_damage := 3.0
## Segundos antes de destruir el proyectil si no impacta.
@export var tap_x_meter_projectile_lifetime := 1.5
## Radio de colision y del mesh esferico del proyectil, en metros.
@export var tap_x_meter_projectile_radius := 0.22
## Avance y altura del origen respecto al Player, en metros.
@export var tap_x_meter_projectile_forward_offset := 1.1
@export var tap_x_meter_projectile_height := 1.0
## Color HDR y energia del proyectil. El RGB se escala con la energia para producir bloom.
@export var tap_x_meter_projectile_color := Color(0.2, 0.9, 1.0)
@export_range(0.0, 12.0, 0.1) var tap_x_meter_projectile_energy := 3.0

@export_group("Tap Y adelante — avance con vuelta", "tap_forward_y_")
## Que le hace el gesto a la posicion de los cuerpos (ver data/attack_movement_profile.gd). Avance
## del Player hacia el objetivo, con `player_direction` en PLAYER_FORWARD: el gesto ya fijo el facing
## al lockeado, asi que el perfil se clona y se orienta en runtime sin mutar el .tres. Al Enemy no lo
## mueve un Mover: en aire lo desplaza el push (WeaponTuning), por eso `enemy_travel` esta vacio.
@export var tap_forward_y: AttackMovementProfile

@export_subgroup("Coreografia e input", "tap_forward_y_")
## Segundos para pulsar Y despues de un tap que se acerca al objetivo lockeado. 0 desactiva
## el gesto. Reusa la vuelta final de la rama espera; en aire ademas arma el push del Enemy.
@export var tap_forward_y_window := 0.15

@export_group("Tap Y atras — launcher / plunge", "tap_back_y_")
## Que le hace el gesto a la posicion de los cuerpos, por tramo (ver
## data/attack_movement_profile.gd). En suelo solo sube al Enemy (BEFORE_DAMAGE, como el cargado):
## el Player se queda, por eso su slot esta vacio. En aire hunde a los dos en WINDOW_END —arrancar
## la caida durante el swing sacaria al objetivo del alcance del propio hachazo— y alinea al enemigo
## a tu altura antes de bajar, que es lo que hace que se sienta "bajamos juntos".
@export var tap_back_y_ground: AttackMovementProfile
@export var tap_back_y_air: AttackMovementProfile

@export_subgroup("Coreografia e input", "tap_back_y_")
## Segundos para pulsar Y despues de un tap que se aleja del objetivo lockeado. 0 desactiva
## el gesto. Es gratis (no gasta barra): en suelo eleva solo al Enemy, en aire hunde a los dos.
@export var tap_back_y_window := 0.15
