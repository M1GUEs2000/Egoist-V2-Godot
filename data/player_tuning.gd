class_name PlayerTuning extends Resource
## TODOS los valores tuneables del jugador en un solo Resource (regla v2: los refactors
## nunca más resetean el tuning). Los defaults son los valores tuneados a mano en la v1.
## La instancia editable es data/player_tuning.tres.

@export_group("Locomotion")
@export var move_speed := 6.0
@export var move_input_deadzone := 0.15
@export var lock_move_snap_angle := 45.0   # snap hacia el target lockeado (LockOn, batch 6)
@export var attack_step_distance := 0.7    # avance (lunge) por golpe del combo

@export_group("Jump")
@export var jump_force := 8.0

@export_group("Wall slide")
@export var wall_slide_min_push_speed := 2.0
@export_range(0.0, 1.0) var wall_slide_input_dot := 0.35
@export var wall_slide_stick_time := 0.16
@export var wall_slide_stick_fall_speed := 0.35
@export var wall_slide_max_fall_speed := 3.4
@export_range(0.0, 1.0) var wall_slide_gravity_scale := 0.35
@export var wall_slide_momentum_decay := 4.0
@export var wall_slide_wall_jump_up_speed := 7.2
@export var wall_slide_wall_jump_away_speed := 4.8
@export var wall_slide_wall_jump_along_speed := 2.0
@export var wall_slide_wall_jump_lock_time := 0.12

@export_group("Motor")
@export var gravity := -20.0
@export var bump_decay := 8.0
@export var grounded_bump_decay := 12.0
@export var landing_momentum_grace := 0.18

@export_group("Stun")
@export var default_stun_duration := 0.45
@export var stun_threshold := 1.0
@export var armor_stun_threshold := 2.0
@export_range(0.0, 2.0) var stun_gravity_scale := 1.0
@export var stun_bump_decay := 3.5

@export_group("Dodge")
## Si el golpe en curso ya pasó esta fracción (0-1), el dodge NO lo corta: se buferea
## y sale apenas termina. Antes del umbral, cancela el ataque y dashea ya.
@export_range(0.0, 1.0) var dodge_cancel_attack_threshold := 0.5

@export_group("Dash")
@export var dash_distance := 4.0
@export var dash_duration := 0.12
@export var dash_bump_momentum_multiplier := 1.5
@export var dash_bump_dash_speed_multiplier := 1.0
@export var dash_bump_max_speed := 24.0
@export var dash_deals_damage := true
@export var dash_damage := 1.0
@export var dash_hit_radius := 0.8
@export var dash_hit_forward_offset := 0.8
@export var dash_hit_vertical_offset := 0.6
@export var dash_stun: StunSettings

@export_group("Launcher")
@export var launcher_float_duration := 0.15
@export var launcher_float_gravity := 0.30
@export var launcher_fall_duration := 0.30
@export var launcher_fall_gravity := 0.85

@export_group("Meter")
@export var meter_max_bars := 2            # hasta 5 con mejoras (futuro)
@export var meter_start_bars := 0.0        # arranca vacío; subir para testear cargados
@export var meter_gain_on_hit := 0.1       # pegar a un enemigo
@export var meter_gain_on_kill := 0.5      # matarlo
@export var meter_dash_cost := 0.15        # ~15% de una barra por dash (dodge)
@export var meter_charged_cost := 1.0      # 1 barra por ataque cargado (sweet spot)
@export var meter_charged_kill_window := 0.6  # ventana tras el cargado para el kill especial

@export_group("Input feel")
## Input durante animación se guarda esto y dispara en el primer frame libre (InputBuffer).
@export var input_buffer_time := 0.15
## Tap ejecuta al PRESS; si sigue presionado más que esto → hold (InputBuffer).
@export var input_hold_threshold := 0.18

@export_group("Combat")
## Cuánto duran las "armas afuera" tras el último ataque (gatilla el lock-on, batch 6).
@export var weapons_out_duration := 3.0
@export var inactive_weapon_angle := 75.0  # pose de descanso del arma guardada
@export var weapon_pose_rotate_speed := 720.0

@export_group("Air hit stall")
@export var air_stall_base := 0.08
@export var air_stall_per_hit := 0.04
@export var air_stall_max := 0.28
@export var air_stall_combo_window := 0.75
## Conectando golpes en el aire la caída se RALENTIZA; atacando sin conectar cae MÁS fuerte.
@export var air_stall_float_gravity := 0.15
@export var aerial_whiff_fall_gravity := 1.6
