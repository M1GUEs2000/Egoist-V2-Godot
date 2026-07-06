class_name GroundedEnemy extends EnemyBase
## GLUE del enemigo de suelo: Perception + GroundLocomotion + ataques hijos.

enum AIState { IDLE, ROAM, ALERT, CHASE, ATTACK, SEARCH }

@export var use_simple_fsm := true
@export var chase_delay_after_world_switch := 1.0

var ai_state := AIState.IDLE

var _player: Player
var _attacks: Array[Node] = []
var _can_chase_at := 0.0

@onready var perception: Perception = get_node_or_null("Perception") as Perception
@onready var locomotion: GroundLocomotion = get_node_or_null("GroundLocomotion") as GroundLocomotion

func _ready() -> void:
	super._ready()
	_player = get_tree().get_first_node_in_group("player") as Player
	if perception != null:
		perception.setup(self)
	if locomotion != null:
		locomotion.setup(self, func() -> bool: return is_airborne() or is_stunned())
	_collect_attacks()

func _physics_process(delta: float) -> void:
	if not tick_base(delta):
		return
	if locomotion == null or perception == null:
		return
	locomotion.run_jump_physics(delta)
	perception.tick(_acquire_target(), hostility, World.now() >= _can_chase_at)
	if not use_simple_fsm:
		return
	_update_fsm(delta)

func start_combo_attack() -> void:
	if locomotion != null and locomotion.is_busy:
		return
	var target := perception.target if perception != null else _player
	if target == null:
		return
	var distance := _flat_distance_to(target.global_position)
	var attack := _select_attack(distance)
	if attack != null and attack.has_method("try_attack"):
		attack.call("try_attack", target)

func face_current_target() -> void:
	if locomotion == null:
		return
	var target := perception.target if perception != null else _player
	if target != null:
		locomotion.face_target(target.global_position)

func search_last_known(delta: float) -> void:
	if perception != null and locomotion != null:
		locomotion.search_last_known(perception.last_known_position, delta)

func on_world_changed() -> void:
	if membership != null and membership.mode == WorldMembership.Mode.FOLLOWS:
		_can_chase_at = World.now() + chase_delay_after_world_switch

func try_parry(_player_ref: Player, _hit_direction: Vector3 = Vector3.ZERO) -> bool:
	for attack in _attacks:
		if attack.has_method("try_parry") and attack.call("try_parry"):
			return true
	return false

func _update_fsm(delta: float) -> void:
	var target := perception.target
	var attack_range := _max_attack_range()
	if _any_attacking():
		ai_state = AIState.ATTACK
		face_current_target()
		return
	if target == null:
		ai_state = AIState.ROAM
		locomotion.roam(delta)
		return
	if perception.is_alerted():
		ai_state = AIState.ALERT
		face_current_target()
		return
	if perception.can_see_target:
		if attack_range > 0.0 and perception.within(attack_range):
			ai_state = AIState.ATTACK
			start_combo_attack()
		else:
			ai_state = AIState.CHASE
			locomotion.move_toward(target.global_position, delta)
		return
	if perception.is_searching():
		ai_state = AIState.SEARCH
		search_last_known(delta)
	else:
		ai_state = AIState.ROAM
		locomotion.roam(delta)

func _collect_attacks() -> void:
	_attacks.clear()
	for child in get_children():
		if child.has_method("setup") and (child.has_method("try_attack") or child.has_method("try_parry")):
			child.call("setup", self)
		if child.has_method("try_attack"):
			_attacks.append(child)

func _select_attack(distance: float) -> Node:
	var best: Node = null
	var best_range := INF
	for attack in _attacks:
		var atk_range := float(attack.get("attack_range"))
		if atk_range < distance:
			continue
		if atk_range < best_range:
			best = attack
			best_range = atk_range
	return best

func _max_attack_range() -> float:
	var max_range := 0.0
	for attack in _attacks:
		max_range = maxf(max_range, float(attack.get("attack_range")))
	return max_range

func _any_attacking() -> bool:
	for attack in _attacks:
		if bool(attack.get("is_attacking")):
			return true
	return false

func _acquire_target() -> Node3D:
	if hostility != Hostility.ULTRA_AGGRESSIVE:
		return _player
	var best: Node3D = _player
	var best_sqr := INF
	if _player != null:
		best_sqr = global_position.distance_squared_to(_player.global_position)
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as EnemyBase
		if enemy == null or enemy == self or not enemy.is_active_in_current_world():
			continue
		var sqr := global_position.distance_squared_to(enemy.global_position)
		if sqr < best_sqr:
			best = enemy
			best_sqr = sqr
	return best

func _flat_distance_to(world_pos: Vector3) -> float:
	var to := world_pos - global_position
	to.y = 0.0
	return to.length()
