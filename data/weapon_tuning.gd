class_name WeaponTuning extends Resource
## Tuning común de cualquier arma (ex campos serializados de WeaponBase.cs).
## Cada arma concreta lo extiende (SwordTuning) y su instancia .tres vive en data/.

@export var swing_time := 0.1
@export var kills_to_upgrade := 20
@export var max_level := 3
@export var stun: StunSettings

@export_group("Combo aéreo")
@export var air_step_time := 0.12          # duración de cada golpe aéreo
@export var air_combo_window := 0.45       # ventana para encadenar el siguiente tap
@export var air_wait_branch_threshold := 0.3  # esperar esto tras el 1er golpe cambia de rama
@export var air_spike_down_speed := 30.0   # spike: velocidad hacia abajo en el finisher (rama base)
@export var air_push_speed := 8.0          # arco: velocidad horizontal constante (rama de espera)
@export var air_push_up_speed := 6.0       # arco: impulso vertical inicial
