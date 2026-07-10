class_name MaceTuning extends WeaponTuning
## Tuning del Mazo (bóveda: Armas/Mazo). Instancia editable: data/mace_tuning.tres.
## Arma de más daño, más knockback, más lenta que la Espada (ver SwordTuning para
## el mismo patrón). Tamaños de hitboxes (cabeza, smash, launcher) viven como shapes
## en mace.tscn, igual que en sword.tscn.

@export_group("Combo X")
@export var combo_window := 0.7
## Rama "espera": tardar al menos esto (dentro de la ventana) en encadenar el 3er golpe
## agrega los 2 smashes extra (bóveda: "tres smash verticales" en vez de uno solo).
@export var ground_wait_branch_threshold := 0.35

@export_group("Swings (ángulos)")
## Medio arco de los swings 1-2 del combo terrestre.
@export var combo_swing_angle := 65.0
## Medio arco de cada smash vertical (finisher terrestre y sus repeticiones en la rama espera).
@export var smash_angle := 100.0
## Barrido del golpe Y básico (tap y launcher).
@export var strike_angle := 130.0

@export_group("X cargado (vueltas, 3 niveles)")
## Segundos sostenidos MÁS ALLÁ de hold_threshold que suman un nivel de carga.
@export var charge_level_step := 0.35
@export var max_charge_level := 3
## Duración de cada vuelta durante la carga (independiente de swing_time del golpe final).
@export var charged_spin_time := 0.32
## Daño del golpe final de la secuencia de vueltas (arma de más daño que la Espada).
@export var charged_hit_damage := 3.0
## Sweet spot (llegar al nivel máximo): las vueltas intermedias congelan en vez de
## empujar — stun largo, mode STILL (ver Combate: "enemigos congelados hasta la última vuelta").
@export var charged_freeze_stun: StunSettings
## Golpe final del X cargado: el daño/knockback real.
@export var charged_final_stun: StunSettings
## Golpe final del X cargado: además del daño real, siempre manda a volar con arco propio.
@export var charged_final_push: PushSettings

@export_group("Y cargado terrestre")
## Distancia del dash corto de alcance antes del launcher, en metros. Es un paso, no un dash ofensivo.
@export var ground_y_dash_distance := 2.6
## Duracion del dash corto del Y terrestre, en segundos.
@export var ground_y_dash_duration := 0.12
## Tiempo entre terminar el dash corto y prender el launcher de area, en segundos.
@export var ground_y_launcher_delay := 0.04
## Tamano del hitbox del launcher terrestre, en metros (X/Y/Z).
@export var ground_y_launcher_size := Vector3(3.0, 2.0, 3.0)
## Altura a la que el launcher terrestre manda enemigos, en metros.
@export var ground_y_launcher_height := 4.5
## Tiempo que los enemigos quedan suspendidos tras el launcher terrestre, en segundos.
@export var ground_y_launcher_hang_time := 1.1
## Duracion del hitbox del launcher terrestre, en segundos.
@export var ground_y_launcher_duration := 0.22
## Si el launcher terrestre tambien hace dano ademas de elevar.
@export var ground_y_launcher_deals_damage := true

@export_group("Aéreo")
# El tap X sin carga y el Y cargado sin sweet spot arman el `push` heredado de WeaponTuning
# (mismo campo que usa el finisher aéreo de la Espada), con más alcance y altura acá: arma
# de más knockback. El golpe final del X cargado usa su propio charged_final_push.
## Caída forzada del X cargado aéreo (ground pound).
@export var air_smash_fall_speed := 22.0
## Angulo de caida del Y cargado aereo, en grados bajo el horizonte. 90 = vertical puro.
@export_range(1.0, 89.0) var air_y_fall_angle := 58.0
## Velocidad total de la caida diagonal del Y cargado aereo, en m/s.
@export var air_y_fall_speed := 24.0
## Radio del AOE launcher que se dispara al impactar enemigo o suelo, en metros.
@export var air_y_aoe_radius := 2.2
## Altura a la que el AOE aereo manda enemigos, en metros.
@export var air_y_launcher_height := 4.5
## Tiempo que los enemigos quedan suspendidos tras el AOE aereo, en segundos.
@export var air_y_launcher_hang_time := 1.1
## Duracion del AOE aereo una vez impacta enemigo o suelo, en segundos.
@export var air_y_aoe_duration := 0.18
## Tiempo maximo que puede durar la caida diagonal antes de apagarse sola, en segundos.
@export var air_y_max_fall_time := 1.2
## Hang PROPIO del Y aereo, en segundos: al conectar contra un enemigo la caida se frena en
## seco y el jugador queda suspendido este tiempo. Es la ventana para gastar el doble salto y
## seguir al enemigo que el AOE acaba de lanzar. No aplica si el slam termina contra el suelo.
@export var air_y_player_hang_time := 0.35
## Sweet spot aéreo (X cargado con vuelta final / Y cargado): congela a los golpeados
## y extiende el tiempo airborne del jugador (PlayerLauncher.notify_aerial_attack).
@export var air_freeze_stun: StunSettings
@export var air_freeze_extra_hang_time := 0.5
