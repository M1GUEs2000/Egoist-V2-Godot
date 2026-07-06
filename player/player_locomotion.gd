class_name PlayerLocomotion extends Node
## Bloque (ex PlayerLocomotion.cs): movimiento por input relativo a cámara + attack lunge
## (avance corto en cada golpe). Expone los helpers de dirección (camera_relative /
## movement_direction) que reusan dash y swing. El ajuste hacia el target lockeado
## llega con LockOn (batch 6) — los hooks ya están marcados.

var last_move_dir := Vector3.ZERO

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
	# TODO batch 6 (LockOn): si hay target visible y el ángulo <= lock_move_snap_angle, snap hacia él
	return camera_dir

## Devuelve la velocidad horizontal del frame y maneja el facing.
func tick(_delta: float) -> Vector3:
	var input := read_move_input()
	var camera_dir := camera_relative(input)
	# TODO batch 6 (LockOn): aim_with_input(input, camera_dir)
	var dir := movement_direction(input, camera_dir)
	# Durante un golpe (lunge) no giramos por input: mantenemos la mira del ataque.
	if dir != Vector3.ZERO and World.now() >= _lunge_until:
		set_facing(dir)
	return dir * _body.tuning.move_speed

## Lunge: el jugador encara la dirección de ataque y avanza un poco durante el golpe.
func attack_step(duration: float) -> void:
	# TODO batch 6 (LockOn): encarar al target lockeado si existe
	var dir := _body.forward()
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	set_facing(dir)
	_lunge_velocity = dir * (_body.tuning.attack_step_distance / maxf(0.01, duration))
	_lunge_start = World.now()
	_lunge_until = World.now() + duration

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
