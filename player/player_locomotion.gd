class_name PlayerLocomotion extends Node
## Bloque (ex PlayerLocomotion.cs): movimiento por input relativo a cámara + attack lunge
## (avance corto en cada golpe). En el suelo el input manda directo; en el aire la velocidad
## de input se conserva (inercia) y el stick solo la empuja a tuning.air_acceleration.
## Expone los helpers de dirección (camera_relative / movement_direction) que reusan dash y
## swing. El snap hacia el target lockeado (LockOn) ajusta movimiento y encare del golpe;
## el reticle en sí lo dueña LockOn.

var last_move_dir := Vector3.ZERO

var _air_velocity := Vector3.ZERO

var _body: Player
var _cam: Camera3D
var _lunge_velocity := Vector3.ZERO
var _lunge_start := 0.0
var _lunge_until := 0.0

func setup(body: Player, cam: Camera3D) -> void:
	_body = body
	_cam = cam

## Hay un golpe terrestre en curso (ventana de lunge activa) y qué tan avanzado está (0-1).
## Lo usa el glue para decidir si el dodge cancela el ataque o se buferea hasta que termine.
func is_attacking() -> bool:
	return World.now() < _lunge_until

func attack_progress() -> float:
	if _lunge_until <= _lunge_start:
		return 1.0
	return clampf((World.now() - _lunge_start) / (_lunge_until - _lunge_start), 0.0, 1.0)

func read_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_down", "move_up")

func has_move_input(input: Vector2) -> bool:
	var dz := _body.tuning.move_input_deadzone
	return input.length_squared() >= dz * dz

## Dirección de input relativa a la cámara, proyectada al plano del suelo.
func camera_relative(input: Vector2) -> Vector3:
	if _cam == null:
		# ponytail: fallback a isométrico fijo 45° si no hay cámara
		return Vector3(input.x, 0.0, -input.y).rotated(Vector3.UP, deg_to_rad(-45.0))
	var fwd := -_cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := _cam.global_basis.x
	right.y = 0.0
	right = right.normalized()
	return fwd * input.y + right * input.x

func movement_direction(input: Vector2, camera_dir: Vector3) -> Vector3:
	if not has_move_input(input):
		return Vector3.ZERO
	var target := _lock_target()
	if target == null:
		return camera_dir
	var to_target := _direction_to(target.global_position)
	if to_target == Vector3.ZERO:
		return camera_dir
	if rad_to_deg(camera_dir.angle_to(to_target)) <= _body.tuning.lock_move_snap_angle:
		return to_target
	return camera_dir

## Devuelve la velocidad horizontal del frame y maneja el facing. En el suelo el input tiene
## autoridad instantánea; en el aire manda la inercia: la velocidad se conserva y el input
## solo la empuja hacia su target a air_acceleration (ya no se invierte el rumbo en un frame).
func tick(delta: float) -> Vector3:
	var input := read_move_input()
	var camera_dir := camera_relative(input)
	var dir := movement_direction(input, camera_dir)
	# Durante un golpe (lunge) no giramos por input: mantenemos la mira del ataque.
	if dir != Vector3.ZERO and World.now() >= _lunge_until:
		set_facing(dir)
	var target := dir * _body.tuning.move_speed
	if _body.is_on_floor():
		# En tierra, un golpe en curso bloquea el input de movimiento: solo manda el lunge del
		# ataque. La dirección ya quedó fijada al entrar (attack_step, hacia el lock/forward).
		if is_attacking():
			_air_velocity = Vector3.ZERO
			return Vector3.ZERO
		_air_velocity = target  # despegar (salto o caída) arranca con la velocidad de carrera
		return target
	# En aire, un golpe en curso tampoco deja steerear con el input, pero preserva el momentum
	# aéreo tal cual (no lo frena a cero): el platforming depende de conservar esa inercia.
	if is_attacking():
		return _air_velocity
	_air_velocity = _air_velocity.move_toward(target, _body.tuning.air_acceleration * delta)
	return _air_velocity

## Reemplaza la inercia aérea del input (solo el plano horizontal). La llaman los módulos que
## toman el control del movimiento (dash, wall jump, rebote, stun): al devolver el input no
## debe reaparecer una velocidad vieja — el impulso real de esas mecánicas vive en bump_velocity.
func set_air_velocity(v: Vector3) -> void:
	_air_velocity = Vector3(v.x, 0.0, v.z)

## Lunge: el jugador encara la dirección de ataque (target lockeado si existe, si no su
## forward) y avanza un poco durante el golpe.
func attack_step(duration: float) -> void:
	var dir := _attack_direction()
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	set_facing(dir)
	_lunge_velocity = dir * (_body.tuning.attack_step_distance / maxf(0.01, duration))
	_lunge_start = World.now()
	_lunge_until = World.now() + duration

## Con lock activo, el golpe encara al target lockeado. Sin lock, snapea al enemigo más
## cercano en cono sobre el forward actual (comportamiento previo, sin persistir el target).
func _attack_direction() -> Vector3:
	var target: EnemyBase = _body.lock_on.current_target if _body.lock_on.is_locked \
			else _body.lock_on.nearest_in_cone(_body.forward())
	if target != null:
		var to_target := _direction_to(target.global_position)
		if to_target != Vector3.ZERO:
			return to_target
	var dir := _body.forward()
	dir.y = 0.0
	return dir

func lunge_velocity() -> Vector3:
	return _lunge_velocity if World.now() < _lunge_until else Vector3.ZERO

func cancel_lunge() -> void:
	_lunge_until = 0.0

func set_facing(dir: Vector3) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	flat = flat.normalized()
	_body.look_at(_body.global_position + flat, Vector3.UP)
	last_move_dir = flat

func _lock_target() -> EnemyBase:
	if not _body.lock_on.has_visible_target():
		return null
	return _body.lock_on.current_target

func _direction_to(world_position: Vector3) -> Vector3:
	var dir := world_position - _body.global_position
	dir.y = 0.0
	return dir.normalized() if dir.length_squared() > 0.0001 else Vector3.ZERO
