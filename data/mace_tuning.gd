class_name MaceTuning extends WeaponTuning
## Tuning del Mazo (bóveda: Armas/Mazo). Instancia editable: data/mace_tuning.tres.
## Arma de más daño, más knockback, más lenta que la Espada (ver SwordTuning para
## el mismo patrón). Tamaños de hitboxes (cabeza, smash, launcher) viven como shapes
## en mace.tscn, igual que en sword.tscn.
##
## Reconstruido sobre el contrato Mover/Floater (obsidian/Plan Autoridad Vertical):
## el Y cargado aereo (caida diagonal + AOE + rebote balistico) no forma parte de este
## build porque depende de un "bouncer" que todavia no existe. En el aire, Y cargado
## cae al combo aereo normal, como cualquier cargado sin barra. Si el bouncer se
## implementa mas adelante, ese move se diseña de nuevo desde cero.

@export_group("Combo X")
@export var combo_window := 0.7
## Rama "espera": tardar al menos esto (dentro de la ventana) en encadenar el 3er golpe
## agrega los 2 smashes extra (bóveda: "tres smash verticales" en vez de uno solo).
@export var ground_wait_branch_threshold := 0.35

# El grupo "Swings (ángulos)" (combo_swing_angle, smash_angle, strike_angle) se borró con el swing
# procedural: el arco de cada golpe lo dibuja su tramo de Sword_Heavy_Combo, no un ángulo. Los
# tramos siguen hardcodeados como constantes en mace.gd; el Mazo pasa a datos (AttackSequence)
# cuando salga de E2.

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
## Duracion del hitbox del launcher terrestre, en segundos.
@export var ground_y_launcher_duration := 0.22
## Si el launcher terrestre tambien hace dano ademas de elevar.
@export var ground_y_launcher_deals_damage := true
## Recorrido vertical que pide el ENEMIGO golpeado (Mover UP + Floater del hang). El jugador
## no recibe perfil propio: "eleva enemigos pero no al jugador" (bóveda Mazo).
@export var ground_y_launcher_enemy_mover: MoverSettings

@export_group("Aéreo")
# El golpe 2 del tap X aereo arma el `push` heredado de WeaponTuning (mismo campo que usa el
# finisher aereo de la Espada), con mas alcance/altura aca: arma de mas knockback. El golpe 1
# es un jab con el mango, sin push. El golpe final del X cargado usa su propio charged_final_push.
# air_handle_reach (el alcance del jab con el mango) murio con la estocada procedural: el golpe 1
# del combo aereo reusa por ahora un tramo del combo terrestre (ver Mace._begin_air_step).
## Caída forzada del X cargado aéreo (ground pound). Escritura directa de vertical_velocity
## sancionada por el plan (obsidian/Plan Autoridad Vertical, fase F5): es una caida recta, no
## un arco balistico, y no depende del bouncer.
@export var air_smash_fall_speed := 22.0
## Sweet spot aéreo (X cargado con vuelta final): congela a los golpeados y extiende el
## tiempo airborne del jugador mediante su Floater.
@export var air_freeze_stun: StunSettings
@export var air_freeze_extra_hang_time := 0.5
