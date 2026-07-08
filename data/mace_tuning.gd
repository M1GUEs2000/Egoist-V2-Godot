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

@export_group("Y — launcher omnidireccional")
@export var launcher_height := 4.5
@export var launcher_hang_time := 1.1
@export var launcher_hitbox_duration := 0.22
@export var launcher_deals_damage := true
## Sweet spot: ventana para conectar un segundo golpe antes de lanzar ("hace dos
## golpes para subirlos al aire").
@export var launcher_second_hit_window := 0.5

@export_group("Aéreo")
## Golpe X sin carga y Y cargado aéreo reusan `air_push` (heredado de WeaponTuning,
## mismo campo que usa el finisher aéreo de la Espada) con más alcance/altura acá:
## arma de más knockback.
## Caída forzada del X cargado aéreo (ground pound).
@export var air_smash_fall_speed := 22.0
## Sweet spot aéreo (X cargado con vuelta final / Y cargado): congela a los golpeados
## y extiende el tiempo airborne del jugador (PlayerLauncher.notify_aerial_attack).
@export var air_freeze_stun: StunSettings
@export var air_freeze_extra_hang_time := 0.5
