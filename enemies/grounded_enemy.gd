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

## Cono de trayectoria del telegraph: dot minimo entre la direccion del swing y la direccion
## hacia el enemigo. Generoso porque la mano orbita al player y el arco del swing es ancho.
const EVADE_TRAJECTORY_DOT := 0.25

## Histeresis del ring: solo retrocede si esta por DEBAJO de esta fraccion del ring. Sin margen,
## el borde exacto lo deja temblando entre retroceder y orbitar frame a frame.
const RING_ENTER_MARGIN := 0.9

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

## Fallback: solo corre si el backend LimboAI no pudo cargar su arbol (GDExtension ausente).
@export var use_simple_fsm := true
## Motor de decision. LIMBO es el backend de trabajo; FSM queda como red de seguridad.
@export_enum("FSM", "LIMBO") var ai_backend: int = AIBackend.LIMBO
@export var chase_delay_after_world_switch := 1.0
@export_flags("IDLE", "ROAM", "ACTIVITY", "ALERT", "CHASE", "GUARD", "SEARCH", "ATTACK_MELEE", "ATTACK_RANGED", "ATTACK_GROUP", "EVADE", "DEFEND", "CALL_HELP", "FLEE", "HIDE") var allowed_state_flags := ALL_STATE_FLAGS
@export var passive_remembers_attackers := false
@export_range(0.0, 1.0) var low_health_threshold := 0.30
@export_range(0.0, 1.0) var passive_flee_chance := 0.50
@export_range(0.0, 1.0) var reactive_flee_chance := 0.25
@export_range(0.0, 1.0) var aggressive_flee_chance := 0.05
## Peso de la cercania en el score de target del ULTRA_AGGRESSIVE (el unico que retargetea).
@export var target_proximity_weight := 1.0
## Peso del compromiso: bonus que el target ACTUAL recibe solo por serlo. Es la histeresis, en
## unidades de cercania — 0.25 significa que para robarle el foco hay que estar un 25% mas cerca.
## En 0 vuelve el flip-flop: dos candidatos a distancia similar se turnan el target cada frame.
@export var target_commitment_weight := 0.25
## Pausa entre combos (segundos, minimo): al terminar un ataque el enemigo rodea al target
## en vez de re-atacar apenas el cooldown del arma lo deja. Con min y max en 0 ataca apenas puede.
@export var attack_pause_min := 0.8
## Pausa entre combos (segundos, maximo); la pausa real se sortea entre min y max por combo.
@export var attack_pause_max := 1.6
## Ring del MELEE: fraccion de su `attack_range` a la que se mantiene mientras espera su ventana.
## Mayor a 1 = espera FUERA de su alcance y tiene que entrar para pegar, en vez de quedarse
## encima del jugador entre combo y combo. Bajarlo lo vuelve mas asfixiante.
@export_range(0.5, 3.0) var melee_ring_fraction := 1.5
## Ring del RANGED: fraccion de su `attack_range` a la que orbita. Menor a 1 para quedar dentro
## de su alcance y poder disparar sin re-acercarse.
@export_range(0.1, 1.0) var ranged_ring_fraction := 0.75
## Fraccion del `attack_range` hasta la que AVANZA cuando decide pegar: entra un poco adentro
## del filo para no quedar al borde exacto y whiffear por un centimetro.
@export_range(0.1, 1.0) var strike_distance_fraction := 0.8
## Grados por segundo que puede corregir su orientacion ENTRE golpes del combo. El giro libre
## solo existe antes de comprometer el ataque; adentro del combo esto es todo lo que tiene.
@export var combo_turn_speed := 120.0
## Grados por segundo DURANTE el swing activo. Cerca de 0 = el golpe sale hacia donde apunto
## al lanzarlo y ya no te persigue; subirlo lo vuelve un misil teledirigido.
@export var combo_swing_turn_speed := 20.0
## Probabilidad (0-1) de esquivar cada telegraph percibido del player. Un roll por telegraph.
## 0 = nunca esquiva (off natural del pasivo); mas alto para enemigos agiles futuros.
@export_range(0.0, 1.0) var evade_chance := 0.3
## Segundos entre el telegraph y el inicio del esquive: retraso humano simulado. Los swings
## procedurales tardan en llegar, asi que la ventana es real sin tocar el feel del player.
@export var evade_reaction_time := 0.2
## Segundos que el esquive queda bloqueado tras un roll exitoso (la estamina invisible queda
## diferida por regla de 2: si jugando este cooldown no alcanza, se agrega).
@export var evade_cooldown := 4.0
## Metros que recorre el salto de esquive. Es EL knob de "no se despega lo suficiente": subilo
## hasta que el enemigo salga del arco del arma. La velocidad sale sola (distancia / duracion),
## asi que tocar esto no obliga a recalcular nada. Es distancia deseada: si choca con geometria
## o con otro enemigo, recorre menos.
@export var evade_distance := 3.0
## Segundos que dura el salto. Con la misma distancia, mas corto = mas explosivo (mas rapido).
@export var evade_duration := 0.45
## Distancia maxima (m) al origen del telegraph para considerarse amenazado por el golpe.
@export var evade_range := 3.5

var ai_state := AIState.IDLE
var blackboard := EnemyAIBlackboard.new()

var _player: Player
var _attacks: Array[Node] = []
var _base_hostility := Hostility.AGGRESSIVE
var _forced_target: Node3D
var _current_target: Node3D
var _can_chase_at := 0.0
var _passive_provoked_until := -999.0
var _low_health_checked := false
var _flee_requested := false
var _hide_unlocked := false
var _limbo_ready := false
var _next_attack_at := 0.0
var _was_attacking := false
var _evade_starts_at := INF
var _evade_ends_at := -999.0
var _last_evade_at := -999.0
var _evade_from := Vector3.ZERO

@onready var perception: Perception = get_node_or_null("Perception") as Perception
@onready var locomotion: GroundLocomotion = get_node_or_null("GroundLocomotion") as GroundLocomotion
## Opcional: sin el, el enemigo usa todos sus ataques (comportamiento historico).
@onready var attack_loadout: AttackLoadout = get_node_or_null("AttackLoadout") as AttackLoadout
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
	_connect_player_telegraph()
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
	_update_attack_cadence()
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

## Encarar con el ataque ya comprometido: el giro deja de ser libre. Entre golpes puede corregir
## a `combo_turn_speed`; durante el swing, solo a `combo_swing_turn_speed`. Asi el combo apunta a
## donde estabas cuando lo lanzo, y esquivarlo de costado sirve.
func face_target_committed(delta: float) -> void:
	if locomotion == null:
		return
	var target := perception.target if perception != null else _player
	if target == null:
		return
	var turn_speed := combo_swing_turn_speed if _any_swinging() else combo_turn_speed
	locomotion.face_target_clamped(target.global_position, turn_speed, delta)

## True mientras alguna hoja esta barriendo (no entre golpe y golpe del combo). Solo el melee
## tiene fases de swing: preguntarle `is_in_swing` a un RangedAttack devuelve null, no false.
func _any_swinging() -> bool:
	for attack in _attacks:
		var melee := attack as MeleeAttack
		if melee != null and melee.is_in_swing:
			return true
	return false

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

func limbo_keep_attack_state(delta: float) -> bool:
	if not _any_attacking():
		return false
	_change_state(_active_attack_state())
	face_target_committed(delta)
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
	var radius := _engage_radius()
	return radius > 0.0 and perception != null and perception.within(radius)

func limbo_engage_target(delta: float) -> bool:
	var target := blackboard.perception_target
	if target == null:
		return false
	_process_engage(delta, target, _max_attack_range())
	return true

func limbo_evade_window(delta: float) -> bool:
	if not _evade_window_active():
		return false
	_change_state(AIState.EVADE)
	blackboard.evade_from(_evade_from, _evade_speed())
	execute_ai_intent(delta)
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

func try_parry(player_ref: Player, hit_direction: Vector3 = Vector3.ZERO) -> bool:
	for attack in _attacks:
		if attack.has_method("try_parry") and attack.call("try_parry"):
			# El ataque estaba en ventana: EnemyBase resuelve el outcome (poise del player → cian+stun
			# o fogonazo blanco). El poise sale del arma/ataque con que el player pego (player_ref).
			resolve_parry(player_ref, hit_direction)
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
	var attack_range := _engage_radius()
	if _any_attacking():
		_change_state(_active_attack_state())
		face_target_committed(delta)
		return
	if _should_flee(target, effective_hostility):
		_process_flee(delta, target)
		return
	if _evade_window_active():
		_change_state(AIState.EVADE)
		blackboard.evade_from(_evade_from, _evade_speed())
		execute_ai_intent(delta)
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
			_process_engage(delta, target, _max_attack_range())
		else:
			_process_chase(delta, target, effective_hostility)
		return
	if perception.is_searching():
		_process_search(delta, effective_hostility)
	else:
		_process_no_target(delta, effective_hostility)

## Registra los ataques que la IA puede usar. `AttackLoadout` (si existe) filtra por familia: un
## ataque no registrado nunca recibe `try_attack`, asi que su Hitbox jamas prende (queda inerte).
## Ademas se le apaga la malla — un enemigo solo-ranged no pasea con una espada colgando.
func _collect_attacks() -> void:
	_attacks.clear()
	for child in get_children():
		if child.has_method("setup") and (child.has_method("try_attack") or child.has_method("try_parry")):
			child.call("setup", self)
		if not child.has_method("try_attack"):
			continue
		var equipped := attack_loadout == null or attack_loadout.allows(child)
		if child is Node3D:
			(child as Node3D).visible = equipped
		if equipped:
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

## Radio en el que ya esta "en combate" y deja de perseguir. Incluye el ring, no solo el alcance:
## si el melee espera su ventana MAS lejos de lo que pega, un radio igual al alcance lo dejaria
## saliendo del engage apenas retrocede, y volveria a entrar persiguiendo — un yo-yo.
func _engage_radius() -> float:
	var radius := 0.0
	for attack in _attacks:
		var attack_range := float(attack.get("attack_range"))
		var fraction := ranged_ring_fraction if attack is RangedAttack else melee_ring_fraction
		radius = maxf(radius, maxf(attack_range, attack_range * fraction))
	return radius

func _any_attacking() -> bool:
	for attack in _attacks:
		if bool(attack.get("is_attacking")):
			return true
	return false

## Fuera de mundo no hay pelea posible: su hurtbox deja de ser monitorable y su collision_layer
## queda en 0 (ver EnemyBase._on_membership_changed), asi que ni el conecta un golpe ni se lo
## conectan. Sin target cae solo en la rama de _process_no_target que le toque por hostilidad
## (el agresivo sigue vagando, el reactivo monta guardia) en vez de perseguir a un intocable.
func _acquire_target() -> Node3D:
	if not _is_active:
		return null
	if _forced_target != null and is_instance_valid(_forced_target):
		return _forced_target
	if _base_hostility == Hostility.PASSIVE and hostility == Hostility.AGGRESSIVE:
		return null
	if hostility != Hostility.ULTRA_AGGRESSIVE:
		return _player
	_current_target = _best_target_by_utility()
	return _current_target

## Target del ULTRA_AGGRESSIVE por score de utility: proximidad + compromiso (ver
## ai_spec/leaf_tasks.yaml#target_selection). El termino de compromiso ES la histeresis — el
## target actual arranca con ventaja, asi que solo lo desbanca alguien claramente mas cercano,
## no un empate. Sin el, comparar distancias crudas cada tick hacia oscilar el target frame a
## frame entre dos candidatos equidistantes. Es la semilla de la capa utility que ATTACK_GROUP
## reusara; no crece a mas consideraciones hasta que haya un segundo caso real (regla de 2).
func _best_target_by_utility() -> Node3D:
	if not is_instance_valid(_current_target):
		_current_target = null
	var vision_range := perception.vision_range if perception != null else 12.0
	var best: Node3D = null
	var best_score := -INF
	for candidate in _target_candidates():
		var score := _target_score(candidate, vision_range)
		if score > best_score:
			best = candidate
			best_score = score
	return best

## Todo lo que este berserker considera golpeable: el jugador y cualquier otro enemigo vivo del
## mundo actual. Los muertos ya salieron del grupo "enemy" (EnemyBase._die), asi que no aparecen.
func _target_candidates() -> Array[Node3D]:
	var candidates: Array[Node3D] = []
	if _player != null:
		candidates.append(_player)
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as EnemyBase
		if enemy == null or enemy == self or not enemy.is_active_in_current_world():
			continue
		candidates.append(enemy)
	return candidates

func _target_score(candidate: Node3D, vision_range: float) -> float:
	var proximity := 1.0 - clampf(
			_flat_distance_to(candidate.global_position) / maxf(0.01, vision_range), 0.0, 1.0)
	var commitment := 1.0 if candidate == _current_target else 0.0
	return target_proximity_weight * proximity + target_commitment_weight * commitment

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

## Combate en rango. El ciclo del melee es: entra, pega, SALE retrocediendo de cara, orbita
## esperando su ventana, vuelve a entrar. El ranged no retrocede — se queda dentro de su alcance
## y orbita, que es donde ya se siente bien.
##
## Sin EVADE en allowed_state_flags no hay reposicionamiento: espera quieto mirando al target.
func _process_engage(delta: float, target: Node3D, attack_range: float) -> void:
	var distance := _flat_distance_to(target.global_position)
	var attack_state := _best_attack_state_for_range(distance)
	var reference_range := _range_of_attack_state(attack_state, attack_range)
	var is_melee := attack_state == AIState.ATTACK_MELEE
	var ring := reference_range * (melee_ring_fraction if is_melee else ranged_ring_fraction)

	if World.now() >= _next_attack_at:
		# Ventana de ataque abierta: si ya esta a tiro pega; si espera afuera del ring, entra.
		if distance <= reference_range:
			_change_state(_fallback_state(attack_state))
			start_combo_attack(ai_state)
			if _any_attacking():
				return
		elif _state_allowed(AIState.CHASE):
			_change_state(_fallback_state(AIState.CHASE))
			blackboard.move_to(
					target.global_position,
					EnemyAIBlackboard.SpeedProfile.CHASE,
					reference_range * strike_distance_fraction)
			execute_ai_intent(delta)
			return

	if not _state_allowed(AIState.EVADE):
		face_current_target()
		return

	_change_state(AIState.EVADE)
	# Dentro del ring y con la ventana cerrada: primero gana distancia de frente, y recien
	# afuera orbita. El margen evita el temblor entre retroceder y orbitar justo en el borde.
	if is_melee and distance < ring * RING_ENTER_MARGIN:
		blackboard.backpedal_from(target.global_position, ring)
	else:
		blackboard.strafe_around(target.global_position, ring)
	execute_ai_intent(delta)

## Rango del ataque que va a usar. El ring se mide contra ESE rango, no contra el mayor: un
## hibrido con un ranged largo no debe espaciarse como si su melee alcanzara 10 m.
func _range_of_attack_state(attack_state: int, fallback: float) -> float:
	for attack in _attacks:
		var is_ranged := attack is RangedAttack
		if (attack_state == AIState.ATTACK_RANGED) == is_ranged:
			return float(attack.get("attack_range"))
	return fallback

func _connect_player_telegraph() -> void:
	if _player == null:
		return
	var player_combat := _player.get_node_or_null("Combat") as PlayerCombat
	if player_combat != null and not player_combat.attack_telegraphed.is_connected(_on_player_attack_telegraphed):
		player_combat.attack_telegraphed.connect(_on_player_attack_telegraphed)

## Receptor del telegraph del player (ver Comportamientos > "EVADE — diseño acordado"): corre
## los gates en orden barato→caro y, si todos pasan, agenda el esquive con retraso humano.
## Escribe combat_incoming_attack_until, la condicion que DEFEND tambien consumira.
## Sin i-frames: el esquive es moverse fuera de la trayectoria, no invulnerabilidad.
func _on_player_attack_telegraphed(origin: Vector3, direction: Vector3) -> void:
	if not _state_allowed(AIState.EVADE):
		return
	if World.now() - _last_evade_at < evade_cooldown:
		return
	# En recovery o mitad de su propio ataque tiene prohibido esquivar: ataca en la
	# ventana correcta y el golpe del player entra.
	if _any_attacking() or is_stunned() or is_ragdolling():
		return
	if ai_state == AIState.FLEE or ai_state == AIState.HIDE:
		return
	# Solo se esquiva lo que se percibe: por la espalda o fuera del cono no hay evade.
	if perception == null or perception.target != _player or not perception.can_see_target:
		return
	var to_me := global_position - origin
	to_me.y = 0.0
	if to_me.length() > evade_range or to_me.length_squared() < 0.0001:
		return
	var flat_dir := direction
	flat_dir.y = 0.0
	if flat_dir.length_squared() < 0.0001:
		return
	if flat_dir.normalized().dot(to_me.normalized()) < EVADE_TRAJECTORY_DOT:
		return
	# Extremos deterministas: 0 nunca esquiva (off del pasivo), 1 siempre (el smoke depende de ambos).
	if evade_chance < 1.0 and randf() >= evade_chance:
		return
	_last_evade_at = World.now()
	_evade_starts_at = World.now() + evade_reaction_time
	_evade_ends_at = _evade_starts_at + evade_duration
	_evade_from = origin
	blackboard.combat_incoming_attack_until = _evade_ends_at
	# La forma del salto (recto atras / diagonal a un lado) se sortea aca, una vez, y se sostiene
	# toda la ventana.
	if locomotion != null:
		locomotion.begin_evade()

## Velocidad del salto para recorrer `evade_distance` en `evade_duration`. El knob es la
## distancia: la velocidad es consecuencia, no algo que haya que recalcular a mano.
func _evade_speed() -> float:
	return evade_distance / maxf(0.01, evade_duration)

## Ventana de ejecucion del esquive agendado. Antes de _evade_starts_at el enemigo sigue en lo
## suyo (todavia "no reacciono"); entre starts y ends produce EVADE con intent STRAFE.
func _evade_window_active() -> bool:
	var now := World.now()
	return now >= _evade_starts_at and now < _evade_ends_at

## Al cerrar un combo sortea la pausa antes del proximo: la ventana en la que el enemigo rodea
## en vez de re-atacar. La transicion true→false de _any_attacking se detecta en el tick (no en
## _update_fsm) para que la cadencia valga igual con el backend LIMBO.
func _update_attack_cadence() -> void:
	var attacking := _any_attacking()
	if _was_attacking and not attacking:
		_next_attack_at = World.now() + randf_range(attack_pause_min, attack_pause_max)
	_was_attacking = attacking

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
