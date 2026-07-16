class_name MeleeAttack extends Node3D
## Combo melee fÃ­sico: usa la misma mano orbital de la Espada. `attack_range` solo decide
## cuÃ¡ndo la IA empieza a atacar; el daÃ±o existe exclusivamente si BladeHitbox toca un Hurtbox.

@export var attack_range := 1.8
@export var attack_damage := 10.0
@export var attack_cooldown := 1.0
@export var swing_time := 0.25
@export var between_swings := 0.08
@export var combo_steps := 4
@export var parry_window_duration := 0.10
@export var stun: StunSettings
## Radio de la mano orbital. Igual que WeaponTuning.hand_radius de la Espada.
@export var hand_radius := 1.0
## Altura de la mano respecto al origen del enemigo, en metros.
@export var hand_height := 0.9
## Pose lateral de reposo de la mano, en grados.
@export var hand_rest_yaw := -80.0
## Arco de los dos primeros swings del combo, en grados.
@export var combo_swing_angle := 140.0
## Metros extra que se extiende la mano durante las estocadas 3 y 4.
@export var thrust_reach := 0.8
## FracciÃ³n del swing en que la hoja empieza a poder golpear.
@export_range(0.0, 1.0) var hit_window_start := 0.30
## FracciÃ³n del swing en que la hoja deja de poder golpear.
@export_range(0.0, 1.0) var hit_window_end := 0.85
## Retroceso horizontal aplicado al player cuando este stun supera su threshold, en m/s.
@export var player_stun_push_speed := 4.0
## Impulso vertical aplicado al player durante el stun PUSH, en m/s.
@export var player_stun_push_vertical_speed := 0.0

var is_attacking := false
## True solo mientras la hoja esta barriendo. Entre swing y swing es false: ahi es donde la IA
## puede corregir su orientacion (ver GroundedEnemy.combo_turn_speed).
var is_in_swing := false
## El primer golpe de un reactivo sostiene esta fase tras mostrar la pose inicial. El visual usa
## esta senal para pausar su clip de ataque sin adivinar tiempos ni estados de IA.
var is_in_opening_windup := false

var _owner: EnemyBase
var _target: Node3D
var _last_attack := -999.0
var _parry_window_open := false
var _parried_this_swing := false
var _routine_id := 0
var _swing_tween: Tween
var _thrust_from := Quaternion.IDENTITY

@onready var _hand: Node3D = $Hand
@onready var _pivot: Node3D = $Hand/Pivot
@onready var _blade_hitbox: Hitbox = $Hand/Pivot/BladeHitbox

func _ready() -> void:
	_hand.position = Vector3.UP * hand_height
	_reset_hand()

func setup(owner: EnemyBase) -> void:
	_owner = owner
	_blade_hitbox.source = owner
	_blade_hitbox.damage = attack_damage
	_blade_hitbox.stun = stun
	_blade_hitbox.can_be_parried = false
	_blade_hitbox.landed.connect(_on_blade_landed)

func try_attack(target: Node3D, opening_windup := 0.0) -> bool:
	if _owner == null or not _owner.can_attack() or is_attacking:
		return false
	if World.now() - _last_attack < attack_cooldown:
		return false
	_target = target
	_run_combo(maxf(0.0, opening_windup))
	return true

## Detecta si este ataque esta en su ventana de parry (mid-swing) y, si si, lo consume: corta la
## hoja y devuelve true. NO aplica el stun — de eso se encarga EnemyBase.resolve_parry (necesita el
## arma del player para el poise). Lo llama GroundedEnemy.try_parry al recibir un golpe en ventana.
func try_parry() -> bool:
	if not is_attacking or not _parry_window_open or _parried_this_swing or _owner == null:
		return false
	_parried_this_swing = true
	_parry_window_open = false
	_blade_hitbox.end_swing()
	_reset_hand()
	return true

func _run_combo(opening_windup: float) -> void:
	is_attacking = true
	_routine_id += 1
	var id := _routine_id
	for step in range(1, combo_steps + 1):
		if not _can_continue() or id != _routine_id:
			break
		await _swing_step(step, opening_windup if step == 1 else 0.0)
		if not _can_continue() or id != _routine_id:
			break
		await get_tree().create_timer(between_swings).timeout
	_blade_hitbox.end_swing()
	_reset_hand()
	_parry_window_open = false
	_last_attack = World.now()
	is_in_swing = false
	is_attacking = false

func _swing_step(step: int, windup: float) -> void:
	_parried_this_swing = false
	_parry_window_open = false
	is_in_swing = true
	_set_combo_start_pose(step)
	is_in_opening_windup = windup > 0.0
	var windup_elapsed := 0.0
	while windup_elapsed < windup:
		if not _can_continue():
			break
		await get_tree().physics_frame
		windup_elapsed += get_physics_process_delta_time()
	is_in_opening_windup = false
	if not _can_continue():
		is_in_swing = false
		return
	_play_combo_step(step)
	var hitbox_active := false
	var elapsed := 0.0
	while elapsed < swing_time:
		if not _can_continue():
			break
		var progress := elapsed / maxf(0.01, swing_time)
		_parry_window_open = absf(progress - 0.5) <= (parry_window_duration / swing_time) * 0.5
		if not _parried_this_swing and not hitbox_active and progress >= hit_window_start:
			hitbox_active = true
			_blade_hitbox.begin_swing()
		if hitbox_active and (progress >= hit_window_end or _parried_this_swing):
			_blade_hitbox.end_swing()
			hitbox_active = false
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	_blade_hitbox.end_swing()
	_parry_window_open = false
	is_in_swing = false

func _can_continue() -> bool:
	return _owner != null and _owner.can_attack() and _owner.can_receive_hit()

## La IA usa este rango solo para empezar el ataque. El impacto lo decide BladeHitbox.
func _target_in_range() -> bool:
	if _target == null or _owner == null:
		return false
	var to := _target.global_position - _owner.global_position
	to.y = 0.0
	return to.length() <= attack_range + 0.5

func _on_blade_landed(hurtbox: Hurtbox, _died: bool) -> void:
	# Hurtbox ya aplicÃ³ el daÃ±o. El player necesita el modo PUSH de esta fuente para que el
	# knockback sea igual al stun de EnemyBase, pero solo si el StunSettings supera su threshold.
	var player := hurtbox.owner_node as Player
	if player == null or stun == null or _owner == null:
		return
	var away := player.global_position - _owner.global_position
	away.y = 0.0
	player.receive_stun(
			stun,
			PlayerStun.Mode.PUSH,
			away.normalized() if away.length_squared() > 0.0001 else -_owner.global_basis.z,
			player_stun_push_speed,
			player_stun_push_vertical_speed)

## Misma coreografÃ­a terrestre de Sword: swing, swing, estocada, estocada.
func _play_combo_step(step: int) -> void:
	var half := deg_to_rad(combo_swing_angle * 0.5)
	match step:
		1:
			_play_swing(Quaternion(Vector3.UP, -half), Quaternion(Vector3.UP, half))
		2:
			_play_swing(Quaternion(Vector3.UP, half), Quaternion(Vector3.UP, -half))
		_:
			_play_thrust()

func _set_combo_start_pose(step: int) -> void:
	if step == 1:
		_hand.quaternion = Quaternion(Vector3.UP, -deg_to_rad(combo_swing_angle * 0.5))
	elif step == 2:
		_hand.quaternion = Quaternion(Vector3.UP, deg_to_rad(combo_swing_angle * 0.5))
	else:
		_hand.quaternion = _hand_rest()
		_set_hand_radius(hand_radius)

func _play_thrust() -> void:
	_kill_swing_tween()
	_thrust_from = _hand_rest()
	_swing_tween = create_tween()
	_swing_tween.tween_method(_set_thrust_progress, 0.0, 1.0, swing_time)
	_swing_tween.tween_callback(_reset_hand)

func _set_thrust_progress(progress: float) -> void:
	_hand.quaternion = _thrust_from.slerp(Quaternion.IDENTITY, minf(1.0, progress * 2.0))
	_set_hand_radius(hand_radius + thrust_reach * sin(progress * PI))

func _play_swing(from: Quaternion, to: Quaternion) -> void:
	_kill_swing_tween()
	_hand.quaternion = from
	_swing_tween = create_tween()
	_swing_tween.tween_property(_hand, "quaternion", to, swing_time)
	_swing_tween.tween_callback(_reset_hand)

func _hand_rest() -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(hand_rest_yaw))

func _set_hand_radius(radius: float) -> void:
	_pivot.position = Vector3(0.0, 0.0, -radius)

func _reset_hand() -> void:
	_hand.quaternion = _hand_rest()
	_set_hand_radius(hand_radius)

func _kill_swing_tween() -> void:
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
