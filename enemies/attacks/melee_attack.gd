class_name MeleeAttack extends Node3D
## Ataque melee componible (ex MeleeAttack.cs): combo simple con ventana de parry.

@export var attack_range := 1.8
@export var attack_damage := 10.0
@export var attack_cooldown := 1.0
@export var swing_time := 0.16
@export var between_swings := 0.08
@export var combo_steps := 2
@export var parry_window_duration := 0.10
@export var parry_stun_duration := 1.2
@export var stun: StunSettings

var is_attacking := false

var _owner: EnemyBase
var _target: Node3D
var _last_attack := -999.0
var _parry_window_open := false
var _parried_this_swing := false
var _routine_id := 0

@onready var _weapon: Node3D = get_node_or_null("Weapon") as Node3D
var _weapon_rest := Quaternion.IDENTITY

func _ready() -> void:
	if _weapon != null:
		_weapon_rest = _weapon.quaternion

func setup(owner: EnemyBase) -> void:
	_owner = owner

func try_attack(target: Node3D) -> void:
	if _owner == null or not _owner.can_attack() or is_attacking:
		return
	if World.now() - _last_attack < attack_cooldown:
		return
	_target = target
	_run_combo()

func try_parry() -> bool:
	if not is_attacking or not _parry_window_open or _parried_this_swing or _owner == null:
		return false
	_parried_this_swing = true
	_parry_window_open = false
	_owner.apply_parry_stun(parry_stun_duration)
	if _weapon != null:
		_weapon.quaternion = _weapon_rest
	return true

func _run_combo() -> void:
	is_attacking = true
	_routine_id += 1
	var id := _routine_id
	for step in range(1, combo_steps + 1):
		if not _can_continue() or id != _routine_id:
			break
		await _swing_step(step)
		if not _can_continue() or id != _routine_id:
			break
		await get_tree().create_timer(between_swings).timeout
	if _weapon != null:
		_weapon.quaternion = _weapon_rest
	_parry_window_open = false
	_last_attack = World.now()
	is_attacking = false

func _swing_step(step: int) -> void:
	var dealt := false
	_parried_this_swing = false
	_parry_window_open = false
	var elapsed := 0.0
	while elapsed < swing_time:
		if not _can_continue():
			break
		var progress := elapsed / swing_time
		_parry_window_open = absf(progress - 0.5) <= (parry_window_duration / swing_time) * 0.5
		_anim_weapon(step, progress)
		if not dealt and progress >= 0.6:
			dealt = true
			if not _parried_this_swing and _target_in_range():
				_deal_damage()
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	_parry_window_open = false

func _can_continue() -> bool:
	return _owner != null and _owner.can_attack() and _owner.can_receive_hit()

func _target_in_range() -> bool:
	if _target == null or _owner == null:
		return false
	var to := _target.global_position - _owner.global_position
	to.y = 0.0
	return to.length() <= attack_range + 0.5

func _deal_damage() -> void:
	if _target == null or _owner == null:
		return
	if _target.has_method("take_damage"):
		_target.call("take_damage", attack_damage)
		return
	var enemy := _target as EnemyBase
	if enemy != null:
		var dir := enemy.global_position - _owner.global_position
		dir.y = 0.0
		enemy.take_hit_from_enemy(1.0, dir.normalized() if dir.length_squared() > 0.0001 else -_owner.global_basis.z, stun)

func _anim_weapon(step: int, progress: float) -> void:
	if _weapon == null:
		return
	var side := -1.0 if step % 2 == 1 else 1.0
	var from := Quaternion(Vector3.UP, deg_to_rad(70.0 * side))
	var to := Quaternion(Vector3.UP, deg_to_rad(-70.0 * side))
	_weapon.quaternion = _weapon_rest * from.slerp(to, progress)
