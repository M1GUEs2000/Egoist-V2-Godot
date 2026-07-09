class_name WeaponTuning extends Resource
## Tuning común de cualquier arma (ex campos serializados de WeaponBase.cs).
## Cada arma concreta lo extiende (SwordTuning) y su instancia .tres vive en data/.

@export var swing_time := 0.1
@export var kills_to_upgrade := 20
@export var max_level := 3
@export var stun: StunSettings

@export_group("Combo aéreo")
## Duración de cada golpe aéreo.
@export var air_step_time := 0.12
## Ventana para encadenar el siguiente tap aéreo.
@export var air_combo_window := 0.45
## Esperar esto tras el 1er golpe cambia de rama.
@export var air_wait_branch_threshold := 0.3
## Spike: velocidad hacia abajo en el finisher aéreo de la rama base.
@export var air_spike_down_speed := 30.0
## Arco del empujón (velocidad + altura + cierre), inyectable por arma. Lo usa cualquier
## ataque que arme un push, en tierra o en el aire.
@export var push: PushSettings
## La 1ra vuelta de la rama espera eleva un poco al jugador.
@export var air_wait_spin_hop := 4.0

@export_group("Push")
## Fracción del swing a la que se cobra el push (0.5 = a mitad del golpe).
@export_range(0.0, 1.0, 0.05) var push_at := 1.0
## Cuánto sostiene en el aire un golpe de esta arma. >1 = pocos golpes pesados.
@export var air_stall_scale := 1.0
