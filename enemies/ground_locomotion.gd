class_name GroundLocomotion extends Node
## Locomocion reutilizable de agente de suelo (ex GroundLocomotion.cs): chase y roam.

@export var chase_range := 8.0
@export var chase_speed := 3.0
@export var roam_speed := 1.5
@export var roam_radius := 5.0
@export var gravity := -25.0
## Segundos moliendo contra geometria antes de dar por trabado al agente y disparar el rodeo.
@export var stuck_time_threshold := 0.5
## Fraccion de la velocidad esperada por debajo de la cual el frame cuenta como trabado. Trabado
## no es "quieto": un cuerpo que resbala contra un muro en diagonal igual avanza un poco.
@export_range(0.0, 1.0) var stuck_speed_fraction := 0.25
## Segundos que dura el rodeo lateral una vez disparado el stuck-check.
@export var stuck_sidestep_time := 0.6

var is_busy := false

var _body: CharacterBody3D
var _suspended: Callable
var _spawn_position := Vector3.ZERO
var _roam_target := Vector3.ZERO
var _roam_timer := 0.0
var _last_position := Vector3.ZERO
var _sidestep_until := -999.0
var _sidestep_dir := Vector3.ZERO
var _attempted_move := false  # este frame el agente EMPUJO hacia algun lado (no llego y freno)

func setup(body: CharacterBody3D, suspended: Callable) -> void:
	_body = body
	_suspended = suspended
	_spawn_position = body.global_position
	_roam_target = _spawn_position
	_last_position = _spawn_position

func home_position() -> Vector3:
	return _spawn_position

func run_jump_physics(_delta: float) -> void:
	pass

func execute_intent(blackboard: EnemyAIBlackboard, delta: float) -> void:
	if blackboard == null:
		return
	match blackboard.navigation_intent_kind:
		EnemyAIBlackboard.IntentKind.MOVE_TO:
			if blackboard.navigation_speed_profile == EnemyAIBlackboard.SpeedProfile.ROAM:
				roam(delta)
			else:
				move_to(blackboard.navigation_intent_point, delta)
		EnemyAIBlackboard.IntentKind.SEARCH_AT:
			search_last_known(blackboard.navigation_intent_point, delta)
		EnemyAIBlackboard.IntentKind.FLEE_FROM:
			flee_from(blackboard.navigation_intent_point, delta)
		EnemyAIBlackboard.IntentKind.HOLD:
			stop(delta)
		EnemyAIBlackboard.IntentKind.FACE:
			face_target(blackboard.navigation_intent_point)
			stop(delta)
		_:
			stop(delta)
	_update_stuck_timer(blackboard, delta)

func move_to(world_pos: Vector3, delta: float) -> void:
	if _is_suspended() or _body == null:
		return
	var to := world_pos - _body.global_position
	to.y = 0.0
	if to.length_squared() < 0.01:
		_stop_horizontal(delta)
		return
	_apply_move(to.normalized(), chase_speed, delta)

func roam(delta: float) -> void:
	if _is_suspended() or _body == null:
		return
	_roam_timer -= delta
	if _roam_timer <= 0.0 or _body.global_position.distance_to(_roam_target) < 0.5:
		var angle := randf() * TAU
		var radius := randf() * roam_radius
		_roam_target = _spawn_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_roam_timer = randf_range(2.0, 5.0)
	var to := _roam_target - _body.global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		_apply_move(to.normalized(), roam_speed, delta)
	else:
		_stop_horizontal(delta)

func search_last_known(last_known: Vector3, delta: float) -> void:
	if _body == null:
		return
	var to := last_known - _body.global_position
	to.y = 0.0
	if to.length() > 0.6:
		_apply_move(to.normalized(), chase_speed, delta)
	else:
		face_target(last_known)
		_stop_horizontal(delta)

func flee_from(world_pos: Vector3, delta: float) -> void:
	if _is_suspended() or _body == null:
		return
	var away := _body.global_position - world_pos
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = _body.global_basis.z
	_apply_move(away.normalized(), chase_speed, delta)

func stop(delta: float) -> void:
	if _body == null:
		return
	_stop_horizontal(delta)

func face_target(world_pos: Vector3) -> void:
	if _body == null:
		return
	var to := world_pos - _body.global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		_body.look_at(_body.global_position + to.normalized(), Vector3.UP)

func _apply_move(dir: Vector3, speed: float, delta: float) -> void:
	_attempted_move = true
	dir = _detour_direction(dir)
	face_target(_body.global_position + dir)
	_body.velocity.x = dir.x * speed
	_body.velocity.z = dir.z * speed
	if _body.is_on_floor():
		_body.velocity.y = -1.0
	else:
		_body.velocity.y += gravity * delta
	_body.move_and_slide()

func _stop_horizontal(delta: float) -> void:
	_body.velocity.x = _approach(_body.velocity.x, 0.0, chase_speed * delta)
	_body.velocity.z = _approach(_body.velocity.z, 0.0, chase_speed * delta)
	if _body.is_on_floor():
		_body.velocity.y = -1.0
	else:
		_body.velocity.y += gravity * delta
	_body.move_and_slide()

func _is_suspended() -> bool:
	return _suspended.is_valid() and _suspended.call()

func _approach(value: float, target: float, amount: float) -> float:
	if value < target:
		return minf(value + amount, target)
	return maxf(value - amount, target)

## Stuck-check (no-negociable de H1, ver ai_spec/leaf_tasks.yaml#locomotion_contract): en linea
## recta, sin navmesh, un agente que empuja un muro del greybox lo empuja para siempre. Se compara
## lo que recorrio contra lo que ESPERABA recorrer; si se queda corto el tiempo suficiente, dispara
## el rodeo. El dia que entre navmesh, esto pasa a ser un repath sin tocar la decision.
func _update_stuck_timer(blackboard: EnemyAIBlackboard, delta: float) -> void:
	if _body == null:
		return
	var moved := _body.global_position.distance_to(_last_position)
	_last_position = _body.global_position
	var attempted := _attempted_move
	_attempted_move = false
	# Solo cuenta como trabado el que EMPUJA y no avanza. Mirar el intent no alcanza: los handlers
	# frenan solos al llegar a destino (cada uno con su umbral), y un agente parado sobre su punto
	# se leeria como trabado y haria un rodeo espurio. `_apply_move` es el unico movimiento real.
	if not attempted:
		blackboard.navigation_stuck_timer = 0.0
		return
	if moved < _intent_speed(blackboard) * delta * stuck_speed_fraction:
		blackboard.navigation_stuck_timer += delta
	else:
		blackboard.navigation_stuck_timer = 0.0
	if blackboard.navigation_stuck_timer >= stuck_time_threshold:
		_begin_sidestep(blackboard)

## Rodeo: elige un costado y lo mantiene `stuck_sidestep_time`. El costado se sortea una vez y se
## sostiene — reelegirlo cada frame lo dejaria vibrando contra el muro en vez de bordearlo.
func _begin_sidestep(blackboard: EnemyAIBlackboard) -> void:
	blackboard.navigation_stuck_timer = 0.0
	var forward := -_body.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.FORWARD
	var side := Vector3.UP.cross(forward.normalized())
	_sidestep_dir = side if randf() < 0.5 else -side
	_sidestep_until = World.now() + stuck_sidestep_time

## Mientras dura el rodeo, la direccion deseada se mezcla con la perpendicular: el agente bordea
## el obstaculo sin dejar de progresar hacia su intent (una perpendicular pura lo haria orbitar).
func _detour_direction(dir: Vector3) -> Vector3:
	if World.now() >= _sidestep_until:
		return dir
	return (dir + _sidestep_dir).normalized()

func _intent_speed(blackboard: EnemyAIBlackboard) -> float:
	if blackboard.navigation_speed_profile == EnemyAIBlackboard.SpeedProfile.ROAM:
		return roam_speed
	return chase_speed
