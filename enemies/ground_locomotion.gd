class_name GroundLocomotion extends Node
## Locomocion reutilizable de agente de suelo (ex GroundLocomotion.cs): chase y roam.

@export var chase_range := 8.0
@export var chase_speed := 3.0
@export var roam_speed := 1.5
@export var roam_radius := 5.0
@export var gravity := -25.0

var is_busy := false

var _body: CharacterBody3D
var _suspended: Callable
var _spawn_position := Vector3.ZERO
var _roam_target := Vector3.ZERO
var _roam_timer := 0.0

func setup(body: CharacterBody3D, suspended: Callable) -> void:
	_body = body
	_suspended = suspended
	_spawn_position = body.global_position
	_roam_target = _spawn_position

func run_jump_physics(_delta: float) -> void:
	pass

func move_toward(world_pos: Vector3, delta: float) -> void:
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
