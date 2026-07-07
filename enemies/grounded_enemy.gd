class_name GroundedEnemy extends EnemyBase
## GLUE del enemigo de suelo: Perception + GroundLocomotion + ataques hijos.

enum AIState {
	IDLE,
	ROAM,
	ACTIVITY,
	ALERT,
	CHASE,
	GUARD,
	SEARCH,
	ATTACK_MELEE,
	ATTACK_RANGED,
	ATTACK_GROUP,
	EVADE,
	DEFEND,
	CALL_HELP,
	FLEE,
	HIDE,
}

const ALL_STATE_FLAGS := (
	(1 << AIState.IDLE)
	| (1 << AIState.ROAM)
	| (1 << AIState.ACTIVITY)
	| (1 << AIState.ALERT)
	| (1 << AIState.CHASE)
	| (1 << AIState.GUARD)
	| (1 << AIState.SEARCH)
	| (1 << AIState.ATTACK_MELEE)
	| (1 << AIState.ATTACK_RANGED)
	| (1 << AIState.ATTACK_GROUP)
	| (1 << AIState.EVADE)
	| (1 << AIState.DEFEND)
	| (1 << AIState.CALL_HELP)
	| (1 << AIState.FLEE)
	| (1 << AIState.HIDE)
)

@export var use_simple_fsm := true
@export var chase_delay_after_world_switch := 1.0
@export_flags("IDLE", "ROAM", "ACTIVITY", "ALERT", "CHASE", "GUARD", "SEARCH", "ATTACK_MELEE", "ATTACK_RANGED", "ATTACK_GROUP", "EVADE", "DEFEND", "CALL_HELP", "FLEE", "HIDE") var allowed_state_flags := ALL_STATE_FLAGS
@export var passive_remembers_attackers := false
@export_range(0.0, 1.0) var low_health_threshold := 0.30
@export_range(0.0, 1.0) var passive_flee_chance := 0.50
@export_range(0.0, 1.0) var reactive_flee_chance := 0.25
@export_range(0.0, 1.0) var aggressive_flee_chance := 0.05

var ai_state := AIState.IDLE

var _player: Player
var _attacks: Array[Node] = []
var _base_hostility := Hostility.AGGRESSIVE
var _forced_target: Node3D
var _can_chase_at := 0.0
var _passive_provoked_until := -999.0
var _low_health_checked := false
var _flee_requested := false
var _hide_unlocked := false

@onready var perception: Perception = get_node_or_null("Perception") as Perception
@onready var locomotion: GroundLocomotion = get_node_or_null("GroundLocomotion") as GroundLocomotion

func _ready() -> void:
	super._ready()
	_base_hostility = hostility
	_player = get_tree().get_first_node_in_group("player") as Player
	if perception != null:
		perception.setup(self)
	if locomotion != null:
		locomotion.setup(self, func() -> bool: return is_airborne() or is_stunned())
	if health != null and not health.damaged.is_connected(_on_damaged):
		health.damaged.connect(_on_damaged)
	_collect_attacks()

func _physics_process(delta: float) -> void:
	if not tick_base(delta):
		return
	if locomotion == null or perception == null:
		return
	locomotion.run_jump_physics(delta)
	_update_passive_memory()
	var effective_hostility := _effective_hostility()
	perception.tick(_acquire_target(), effective_hostility, World.now() >= _can_chase_at)
	if not use_simple_fsm:
		return
	_update_fsm(delta, effective_hostility)

func start_combo_attack(preferred_state := AIState.ATTACK_MELEE) -> void:
	if locomotion != null and locomotion.is_busy:
		return
	var target := perception.target if perception != null else _player
	if target == null:
		return
	var distance := _flat_distance_to(target.global_position)
	var attack := _select_attack(distance, preferred_state)
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

func _on_passive_attacked(from: Node) -> void:
	var attacker := from as Node3D
	if attacker != null:
		_forced_target = attacker
	_passive_provoked_until = World.now() + _memory_for_hostility(Hostility.PASSIVE)
	hostility = Hostility.AGGRESSIVE

func _update_fsm(delta: float, effective_hostility: int) -> void:
	var target := perception.target
	var attack_range := _max_attack_range()
	if _any_attacking():
		_change_state(_active_attack_state())
		face_current_target()
		return
	if _should_flee(target, effective_hostility):
		_process_flee(delta, target)
		return
	if target == null:
		_process_no_target(delta, effective_hostility)
		return
	if perception.is_alerted():
		_change_state(_fallback_state(AIState.ALERT))
		face_current_target()
		return
	if perception.can_see_target:
		if attack_range > 0.0 and perception.within(attack_range):
			var attack_state := _best_attack_state_for_range(_flat_distance_to(target.global_position))
			_change_state(_fallback_state(attack_state))
			start_combo_attack(ai_state)
		else:
			_process_chase(delta, target, effective_hostility)
		return
	if perception.is_searching():
		_process_search(delta, effective_hostility)
	else:
		_process_no_target(delta, effective_hostility)

func _collect_attacks() -> void:
	_attacks.clear()
	for child in get_children():
		if child.has_method("setup") and (child.has_method("try_attack") or child.has_method("try_parry")):
			child.call("setup", self)
		if child.has_method("try_attack"):
			_attacks.append(child)

func _select_attack(distance: float, preferred_state := AIState.ATTACK_MELEE) -> Node:
	var best: Node = null
	var best_range := INF
	for attack in _attacks:
		if preferred_state == AIState.ATTACK_MELEE and not (attack is MeleeAttack):
			continue
		if preferred_state == AIState.ATTACK_RANGED and not (attack is RangedAttack):
			continue
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
	if _forced_target != null and is_instance_valid(_forced_target):
		return _forced_target
	if _base_hostility == Hostility.PASSIVE and hostility == Hostility.AGGRESSIVE:
		return null
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

func _on_damaged(_amount: float) -> void:
	if _low_health_checked or health == null or health.max_health <= 0.0:
		return
	var ratio := health.current / health.max_health
	if ratio > low_health_threshold:
		return
	_low_health_checked = true
	var chance := _flee_chance_for(_effective_hostility())
	if randf() <= chance:
		_flee_requested = true
		_hide_unlocked = true

func _should_flee(target: Node3D, effective_hostility: int) -> bool:
	if effective_hostility == Hostility.ULTRA_AGGRESSIVE:
		return false
	if not _flee_requested or target == null:
		return false
	return _state_allowed(AIState.FLEE)

func _process_flee(delta: float, target: Node3D) -> void:
	if _state_allowed(AIState.HIDE) and _hide_unlocked and not perception.can_see_target:
		_change_state(AIState.HIDE)
		locomotion.stop(delta)
		return
	_change_state(AIState.FLEE)
	locomotion.flee_from(target.global_position, delta)

func _process_no_target(delta: float, effective_hostility: int) -> void:
	if _flee_requested and _hide_unlocked and _state_allowed(AIState.HIDE) \
			and _state_legal_for_hostility(AIState.HIDE):
		_change_state(AIState.HIDE)
		locomotion.stop(delta)
		return
	match effective_hostility:
		Hostility.ULTRA_AGGRESSIVE:
			_change_state(_fallback_state(AIState.ROAM))
			locomotion.roam(delta)
		Hostility.REACTIVE:
			_change_state(_fallback_state(AIState.GUARD))
			locomotion.stop(delta)
		Hostility.AGGRESSIVE:
			_change_state(_fallback_state(AIState.ROAM))
			locomotion.roam(delta)
		_:
			_change_state(_fallback_state(AIState.ACTIVITY))
			if ai_state == AIState.ACTIVITY or ai_state == AIState.IDLE:
				locomotion.stop(delta)
			else:
				locomotion.roam(delta)

func _process_chase(delta: float, target: Node3D, effective_hostility: int) -> void:
	if effective_hostility == Hostility.PASSIVE and not _is_passive_provoked():
		_process_no_target(delta, effective_hostility)
		return
	if effective_hostility == Hostility.ULTRA_AGGRESSIVE and not _state_allowed(AIState.CHASE):
		_change_state(_fallback_state(AIState.ROAM))
		locomotion.roam(delta)
		return
	_change_state(_fallback_state(AIState.CHASE))
	if ai_state == AIState.CHASE:
		locomotion.move_toward(target.global_position, delta)
	else:
		locomotion.roam(delta)

func _process_search(delta: float, effective_hostility: int) -> void:
	if effective_hostility == Hostility.ULTRA_AGGRESSIVE and not _state_allowed(AIState.SEARCH):
		_process_no_target(delta, effective_hostility)
		return
	_change_state(_fallback_state(AIState.SEARCH))
	if ai_state == AIState.SEARCH:
		search_last_known(delta)
	else:
		_process_no_target(delta, effective_hostility)

func _best_attack_state_for_range(distance: float) -> int:
	var melee := _select_attack(distance, AIState.ATTACK_MELEE)
	if melee != null and _state_allowed(AIState.ATTACK_MELEE):
		return AIState.ATTACK_MELEE
	var ranged := _select_attack(distance, AIState.ATTACK_RANGED)
	if ranged != null and _state_allowed(AIState.ATTACK_RANGED):
		return AIState.ATTACK_RANGED
	return AIState.ATTACK_MELEE

func _active_attack_state() -> int:
	for attack in _attacks:
		if not bool(attack.get("is_attacking")):
			continue
		if attack is RangedAttack:
			return AIState.ATTACK_RANGED
		return AIState.ATTACK_MELEE
	return AIState.ATTACK_MELEE

func _fallback_state(desired: int) -> int:
	if _state_allowed(desired) and _state_legal_for_hostility(desired):
		return desired
	for fallback in [AIState.ROAM, AIState.GUARD, AIState.IDLE]:
		if _state_allowed(fallback) and _state_legal_for_hostility(fallback):
			return fallback
	return AIState.IDLE

func _state_allowed(state: int) -> bool:
	return (allowed_state_flags & (1 << state)) != 0

func _state_legal_for_hostility(state: int) -> bool:
	if hostility != Hostility.ULTRA_AGGRESSIVE:
		return true
	return not (state in [AIState.FLEE, AIState.HIDE, AIState.GUARD, AIState.ATTACK_GROUP])

func _change_state(next_state: int) -> void:
	ai_state = next_state

func _effective_hostility() -> int:
	if _is_passive_provoked():
		return Hostility.AGGRESSIVE
	return hostility

func _is_passive_provoked() -> bool:
	return _base_hostility == Hostility.PASSIVE and World.now() < _passive_provoked_until

func _update_passive_memory() -> void:
	if _base_hostility != Hostility.PASSIVE or passive_remembers_attackers:
		return
	if World.now() < _passive_provoked_until:
		return
	hostility = Hostility.PASSIVE
	_forced_target = null

func _memory_for_hostility(value: int) -> float:
	if perception == null:
		return 10.0
	match value:
		Hostility.PASSIVE:
			return perception.passive_memory
		Hostility.REACTIVE:
			return perception.reactive_memory
		Hostility.AGGRESSIVE:
			return perception.aggressive_memory
		Hostility.ULTRA_AGGRESSIVE:
			return perception.ultra_aggressive_memory
	return perception.aggressive_memory

func _flee_chance_for(value: int) -> float:
	match value:
		Hostility.PASSIVE:
			return passive_flee_chance
		Hostility.REACTIVE:
			return reactive_flee_chance
		Hostility.AGGRESSIVE:
			return aggressive_flee_chance
	return 0.0
