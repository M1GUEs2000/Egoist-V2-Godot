class_name PlayerWallSlide extends Node
## Deslizamiento de pared por momentum: requiere input hacia la pared y contacto real.

var is_sliding := false
var wall_normal := Vector3.ZERO

var _body: Player
var _stick_until := -999.0
var _ignore_until := -999.0
var _wall_tangent_velocity := Vector3.ZERO

func setup(body: Player) -> void:
	_body = body

func apply_slide_velocity(horizontal_velocity: Vector3, input_dir: Vector3, delta: float) -> Vector3:
	if _body == null or not is_sliding:
		return horizontal_velocity
	if World.now() < _ignore_until or _body.is_on_floor():
		cancel()
		return horizontal_velocity
	if not _presses_toward_wall(input_dir, wall_normal):
		cancel()
		return horizontal_velocity

	var t := _body.tuning
	if _body.vertical_velocity < 0.0:
		_body.vertical_velocity += -t.gravity * (1.0 - t.wall_slide_gravity_scale) * delta
	if World.now() < _stick_until:
		_body.vertical_velocity = maxf(_body.vertical_velocity, -t.wall_slide_stick_fall_speed)
	else:
		_body.vertical_velocity = maxf(_body.vertical_velocity, -t.wall_slide_max_fall_speed)

	_wall_tangent_velocity = _wall_tangent_velocity.move_toward(
			Vector3.ZERO, t.wall_slide_momentum_decay * delta)
	var along_wall := horizontal_velocity.slide(wall_normal)
	along_wall.y = 0.0
	return along_wall + _wall_tangent_velocity

func update_after_move(horizontal_velocity: Vector3, input_dir: Vector3) -> void:
	if _body == null:
		return
	if World.now() < _ignore_until or _body.is_on_floor():
		cancel()
		return
	if not _body.is_on_wall():
		cancel()
		return

	var normal := _find_wall_normal()
	if normal.length_squared() < 0.0001:
		cancel()
		return
	if not _presses_toward_wall(input_dir, normal):
		cancel()
		return

	var push_speed := horizontal_velocity.dot(-normal)
	if push_speed < _body.tuning.wall_slide_min_push_speed:
		cancel()
		return

	var was_sliding := is_sliding
	is_sliding = true
	wall_normal = normal
	if not was_sliding:
		_stick_until = World.now() + _body.tuning.wall_slide_stick_time

	_wall_tangent_velocity = horizontal_velocity.slide(wall_normal)
	_wall_tangent_velocity.y = 0.0

func try_wall_jump() -> bool:
	if _body == null or not is_sliding:
		return false
	var tangent := _wall_tangent_velocity
	tangent.y = 0.0
	if tangent.length_squared() > 0.0001:
		tangent = tangent.normalized() * _body.tuning.wall_slide_wall_jump_along_speed
	_body.bump_velocity = wall_normal * _body.tuning.wall_slide_wall_jump_away_speed + tangent
	_body.vertical_velocity = _body.tuning.wall_slide_wall_jump_up_speed
	_ignore_until = World.now() + _body.tuning.wall_slide_wall_jump_lock_time
	cancel()
	return true

func cancel() -> void:
	is_sliding = false
	wall_normal = Vector3.ZERO
	_wall_tangent_velocity = Vector3.ZERO

func _find_wall_normal() -> Vector3:
	for index in range(_body.get_slide_collision_count()):
		var collision := _body.get_slide_collision(index)
		if collision == null:
			continue
		var collider := collision.get_collider() as CollisionObject3D
		if collider != null and (collider.collision_layer & World.LAYER_WORLD) == 0:
			continue
		var normal := collision.get_normal()
		if absf(normal.y) > 0.2:
			continue
		normal.y = 0.0
		if normal.length_squared() >= 0.0001:
			return normal.normalized()
	return Vector3.ZERO

func _presses_toward_wall(input_dir: Vector3, normal: Vector3) -> bool:
	input_dir.y = 0.0
	if input_dir.length_squared() < 0.0001:
		return false
	return input_dir.normalized().dot(-normal) >= _body.tuning.wall_slide_input_dot
