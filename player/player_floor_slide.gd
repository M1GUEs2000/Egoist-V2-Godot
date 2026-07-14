class_name PlayerFloorSlide extends Node
## Deslizamiento de suelo por plataforma. Se engancha al pisar una plataforma que tenga un
## nodo FloorSlideSurface (con su FloorSlideTuning) llevando suficiente velocidad. En plataforma
## plana es hielo (baja friccion, poco control segun steer_control); si esta inclinada empuja
## cuesta abajo como un tobogan. Modulo inyectable hermano de PlayerWallSlide: mismo contrato
## setup(body) y mismas dos fases (apply_slide_velocity antes de move_and_slide, update_after_move
## despues). Mientras desliza el modulo es el dueño del horizontal del jugador.

var is_sliding := false

var _body: Player
var _tuning: FloorSlideTuning
var _slide_velocity := Vector3.ZERO
var _floor_normal := Vector3.UP

func setup(body: Player) -> void:
	_body = body

## Antes de move_and_slide: mientras desliza integra pendiente + steering + friccion y devuelve
## la velocidad horizontal a usar este frame (reemplaza al horizontal normal). Si no desliza,
## deja pasar el horizontal sin tocar.
func apply_slide_velocity(horizontal_velocity: Vector3, input_dir: Vector3, delta: float) -> Vector3:
	if _body == null or not is_sliding or _tuning == null:
		return horizontal_velocity

	# Pendiente: la componente horizontal de la normal apunta cuesta arriba, asi que -ella es
	# cuesta abajo. En plataforma plana la normal es vertical y esto se anula solo.
	var downhill := Vector3(_floor_normal.x, 0.0, _floor_normal.z)
	if downhill.length_squared() > 0.0001:
		_slide_velocity += downhill.normalized() * _tuning.slope_accel * delta

	# Volante: el input arrastra el slide hacia move_speed en su direccion, escalado por
	# steer_control (0 = el input no pesa nada = hielo puro).
	if input_dir.length_squared() > 0.0001 and _tuning.steer_control > 0.0:
		var drive := input_dir.normalized() * _body.tuning.move_speed
		_slide_velocity = _slide_velocity.move_toward(
				drive, _tuning.steer_accel * _tuning.steer_control * delta)

	_slide_velocity = _slide_velocity.move_toward(Vector3.ZERO, _tuning.friction * delta)
	_slide_velocity = _slide_velocity.limit_length(_tuning.max_speed)
	_slide_velocity.y = 0.0
	return _slide_velocity

## Despues de move_and_slide: engancha/desengancha segun el suelo real bajo el jugador.
func update_after_move(horizontal_velocity: Vector3, _input_dir: Vector3) -> void:
	if _body == null:
		return
	if not _body.is_on_floor():
		_end_slide(true)
		return
	var surface := _surface_under_floor()
	if surface == null or surface.tuning == null:
		_end_slide(true)
		return

	_tuning = surface.tuning
	_floor_normal = _body.get_floor_normal()

	if not is_sliding:
		var speed := Vector2(horizontal_velocity.x, horizontal_velocity.z).length()
		if speed < _tuning.min_enter_speed:
			return
		_slide_velocity = Vector3(horizontal_velocity.x, 0.0, horizontal_velocity.z)
		is_sliding = true

## Salto desde el slide: conserva jump_momentum_keep del slide como momentum en el aire. Lo
## llama Player._on_jump cuando el jugador salta estando en slide.
func launch_into_jump() -> void:
	if is_sliding and _tuning != null:
		_body.set_momentum(_slide_velocity * _tuning.jump_momentum_keep)
	cancel()

## Fin natural del slide (se acabo la plataforma o despego sin saltar): vuelca el EXCESO sobre
## move_speed como momentum para no frenar de golpe. cancel() directo (los cortes externos por
## stun/dash/launch/bump) no arrastra momentum: esos setean el suyo.
func _end_slide(carry: bool) -> void:
	if is_sliding and carry and _tuning != null:
		var excess := _slide_velocity.length() - _body.tuning.move_speed
		if excess > 0.0:
			_body.set_momentum(_slide_velocity.normalized() * excess)
	cancel()

func cancel() -> void:
	is_sliding = false
	_slide_velocity = Vector3.ZERO
	_tuning = null
	_floor_normal = Vector3.UP

func _surface_under_floor() -> FloorSlideSurface:
	for index in range(_body.get_slide_collision_count()):
		var collision := _body.get_slide_collision(index)
		if collision == null:
			continue
		if collision.get_normal().y <= 0.5:  # solo colisiones de suelo, no paredes
			continue
		var collider := collision.get_collider()
		if collider == null:
			continue
		for child in (collider as Node).get_children():
			if child is FloorSlideSurface:
				return child
	return null
