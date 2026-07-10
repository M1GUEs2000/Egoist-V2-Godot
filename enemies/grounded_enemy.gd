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

enum AIBackend { FSM, LIMBO }

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
@export_enum("FSM", "LIMBO") var ai_backend := AIBackend.FSM
@export var chase_delay_after_world_switch := 1.0
@export_flags("IDLE", "ROAM", "ACTIVITY", "ALERT", "CHASE", "GUARD", "SEARCH", "ATTACK_MELEE", "ATTACK_RANGED", "ATTACK_GROUP", "EVADE", "DEFEND", "CALL_HELP", "FLEE", "HIDE") var allowed_state_flags := ALL_STATE_FLAGS
@export var passive_remembers_attackers := false
@export_range(0.0, 1.0) var low_health_threshold := 0.30
@export_range(0.0, 1.0) var passive_flee_chance := 0.50
@export_range(0.0, 1.0) var reactive_flee_chance := 0.25
@export_range(0.0, 1.0) var aggressive_flee_chance := 0.05

var ai_state := AIState.IDLE
var blackboard := EnemyAIBlackboard.new()

var _player: Player
var _attacks: Array[Node] = []
var _base_hostility := Hostility.AGGRESSIVE
var _forced_target: Node3D
var _can_chase_at := 0.0
var _passive_provoked_until := -999.0
var _low_health_checked := false
var _flee_requested := false
var _hide_unlocked := false
var _limbo_ready := false

@onready var perception: Perception = get_node_or_null("Perception") as Perception
@onready var locomotion: GroundLocomotion = get_node_or_null("GroundLocomotion") as GroundLocomotion
@onready var _bt_player: Node = get_node_or_null("BTPlayer")

func _ready() -> void:
	super._ready()
	_base_hostility = hostility
	_player = get_tree().get_first_node_in_group("player") as Player
	if perception != null:
		perception.setup(self)
	if locomotion != null:
		locomotion.setup(self, func() -> bool: return is_airborne() or is_stunned() or is_ragdolling())
	if health != null and not health.damaged.is_connected(_on_damaged):
		health.damaged.connect(_on_damaged)
	_collect_attacks()
	_setup_limbo_backend()

func _physics_process(delta: float) -> void:
	if not tick_base(delta):
		return
	if locomotion == null or perception == null:
		return
	locomotion.run_jump_physics(delta)
	_update_passive_memory()
	var effective_hostility := _effective_hostility()
	perception.tick(_acquire_target(), effective_hostility, World.now() >= _can_chase_at)
	_sync_blackboard()
	if ai_backend == AIBackend.LIMBO:
		if _tick_limbo(delta):
			return
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
		blackboard.search_at(perception.last_known_position)
		locomotion.execute_intent(blackboard, delta)

func execute_ai_intent(delta: float) -> void:
	if locomotion != null:
		locomotion.execute_intent(blackboard, delta)

func limbo_has_target() -> bool:
	return blackboard.perception_target != null

func limbo_can_see_target() -> bool:
	return blackboard.perception_can_see_target

func limbo_is_searching() -> bool:
	return blackboard.perception_is_searching

func limbo_is_alerted() -> bool:
	return blackboard.perception_is_alerted

func limbo_is_attacking() -> bool:
	return _any_attacking()

func limbo_keep_attack_state() -> bool:
	if not _any_attacking():
		return false
	_change_state(_active_attack_state())
	face_current_target()
	return true

func limbo_should_flee() -> bool:
	return _should_flee(blackboard.perception_target, _effective_hostility())

func limbo_can_hide() -> bool:
	return _state_allowed(AIState.HIDE) and _hide_unlocked and not blackboard.perception_can_see_target

func limbo_face_target() -> bool:
	var target := blackboard.perception_target
	if target == null:
		return false
	blackboard.face(target.global_position)
	execute_ai_intent(get_physics_process_delta_time())
	return true

func limbo_stop_moving(delta: float) -> bool:
	_change_state(_fallback_state(AIState.HIDE))
	blackboard.hold()
	execute_ai_intent(delta)
	return true

func limbo_flee_from_target(delta: float) -> bool:
	var target := blackboard.perception_target
	if target == null:
		return false
	_change_state(_fallback_state(AIState.FLEE))
	blackboard.flee_from(target.global_position)
	execute_ai_intent(delta)
	return true

func limbo_no_target_by_hostility(delta: float) -> bool:
	_process_no_target(delta, _effective_hostility())
	return true

func limbo_in_attack_range() -> bool:
	var attack_range := _max_attack_range()
	return attack_range > 0.0 and perception != null and perception.within(attack_range)

func limbo_start_attack() -> bool:
	var target := blackboard.perception_target
	if target == null:
		return false
	var attack_state := _best_attack_state_for_range(_flat_distance_to(target.global_position))
	_change_state(_fallback_state(attack_state))
	start_combo_attack(ai_state)
	return true

func limbo_chase_target(delta: float) -> bool:
	var target := blackboard.perception_target
	if target == null:
		return false
	_process_chase(delta, target, _effective_hostility())
	return true

func limbo_search_last_known(delta: float) -> bool:
	_process_search(delta, _effective_hostility())
	return true

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
	blackboard.clear_intent()
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
		blackboard.hold()
		execute_ai_intent(delta)
		return
	_change_state(AIState.FLEE)
	blackboard.flee_from(target.global_position)
	execute_ai_intent(delta)

func _process_no_target(delta: float, effective_hostility: int) -> void:
	if _flee_requested and _hide_unlocked and _state_allowed(AIState.HIDE) \
			and _state_legal_for_hostility(AIState.HIDE):
		_change_state(AIState.HIDE)
		blackboard.hold()
		execute_ai_intent(delta)
		return
	match effective_hostility:
		Hostility.ULTRA_AGGRESSIVE:
			_change_state(_fallback_state(AIState.ROAM))
			blackboard.roam()
			execute_ai_intent(delta)
		Hostility.REACTIVE:
			_change_state(_fallback_state(AIState.GUARD))
			blackboard.hold()
			execute_ai_intent(delta)
		Hostility.AGGRESSIVE:
			_change_state(_fallback_state(AIState.ROAM))
			blackboard.roam()
			execute_ai_intent(delta)
		_:
			_change_state(_fallback_state(AIState.ACTIVITY))
			if ai_state == AIState.ACTIVITY or ai_state == AIState.IDLE:
				blackboard.hold()
			else:
				blackboard.roam()
			execute_ai_intent(delta)

func _process_chase(delta: float, target: Node3D, effective_hostility: int) -> void:
	if effective_hostility == Hostility.PASSIVE and not _is_passive_provoked():
		_process_no_target(delta, effective_hostility)
		return
	if effective_hostility == Hostility.ULTRA_AGGRESSIVE and not _state_allowed(AIState.CHASE):
		_change_state(_fallback_state(AIState.ROAM))
		blackboard.roam()
		execute_ai_intent(delta)
		return
	_change_state(_fallback_state(AIState.CHASE))
	if ai_state == AIState.CHASE:
		blackboard.move_to(target.global_position, EnemyAIBlackboard.SpeedProfile.CHASE)
	else:
		blackboard.roam()
	execute_ai_intent(delta)

func _process_search(delta: float, effective_hostility: int) -> void:
	if effective_hostility == Hostility.ULTRA_AGGRESSIVE and not _state_allowed(AIState.SEARCH):
		_process_no_target(delta, effective_hostility)
		return
	_change_state(_fallback_state(AIState.SEARCH))
	if ai_state == AIState.SEARCH:
		search_last_known(delta)
	else:
		_process_no_target(delta, effective_hostility)

func _sync_blackboard() -> void:
	blackboard.navigation_home_position = locomotion.home_position() if locomotion != null else global_position
	blackboard.sync_perception(perception)
	blackboard.combat_attacking = _any_attacking()

func _setup_limbo_backend() -> void:
	if _bt_player == null or not ClassDB.class_exists("BehaviorTree"):
		_limbo_ready = false
		return
	var tree := EnemyLimboTreeBuilder.build_combat_tree()
	if tree == null:
		_limbo_ready = false
		return
	_bt_player.set("agent_node", NodePath(".."))
	_bt_player.set("behavior_tree", tree)
	_bt_player.set("update_mode", 2)  # BTPlayer.UpdateMode.MANUAL
	_bt_player.set("active", true)
	_bt_player.call("restart")
	_limbo_ready = true

func _tick_limbo(delta: float) -> bool:
	if not _limbo_ready or _bt_player == null:
		return false
	blackboard.clear_intent()
	_bt_player.call("update", delta)
	return true

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
