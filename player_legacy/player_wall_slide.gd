class_name PlayerLegacyWallSlide extends Node
## Deslizamiento de pared por momentum: requiere input hacia la pared y contacto real.

## Feedback visual: el personaje brilla verde mientras está pegado a la pared.
@export var glow_color := Color(0.25, 1.0, 0.4)
@export var glow_energy := 2.0

var is_sliding := false
var wall_normal := Vector3.ZERO

var _body: PlayerLegacy
var _stick_until := -999.0
var _ignore_until := -999.0
var _move_lock_until := -999.0
var _grace_until := -999.0
var _wall_tangent_velocity := Vector3.ZERO
var _mesh: MeshInstance3D
var _glow_material: StandardMaterial3D
var _glow_active := false
var _dust: GPUParticles3D

func setup(body: PlayerLegacy) -> void:
	_body = body
	_mesh = body.get_node_or_null("Mesh") as MeshInstance3D
	_dust = body.get_node_or_null("WallSlideDust") as GPUParticles3D

func apply_slide_velocity(horizontal_velocity: Vector3, input_dir: Vector3, delta: float) -> Vector3:
	if _body == null or not is_sliding:
		return horizontal_velocity
	if World.now() < _ignore_until or _body.is_on_floor():
		cancel()
		return horizontal_velocity
	# Assist: el slide ya no exige apretar HACIA la pared; solo se corta si el jugador
	# dirige el stick EN CONTRA (se despega a propósito). Input neutro mantiene el deslice.
	if _presses_away_from_wall(input_dir, wall_normal):
		cancel()
		return horizontal_velocity

	var t := _body.tuning
	# Gravedad reducida SIMÉTRICA (subiendo y cayendo): entrando con momentum hacia arriba
	# el arco sube, frena y vuelve; entrando en caída, se ralentiza y sigue bajando. Antes
	# solo se reducía al caer, así que el momentum de subida moría a gravedad completa y no
	# había arco genuino.
	_body.vertical_velocity += -t.gravity * (1.0 - t.wall_slide_gravity_scale) * delta
	if World.now() < _stick_until:
		_body.vertical_velocity = maxf(_body.vertical_velocity, -t.wall_slide_stick_fall_speed)
	else:
		_body.vertical_velocity = maxf(_body.vertical_velocity, -t.wall_slide_max_fall_speed)

	# Momentum de entrada: se conserva al enganchar y decae a cero con `wall_slide_momentum_decay`
	# (el arco lateral que se endereza con el tiempo).
	_wall_tangent_velocity = _wall_tangent_velocity.move_toward(
			Vector3.ZERO, t.wall_slide_momentum_decay * delta)
	# Steering vivo: el input a lo largo de la pared, con la autoridad recortada por
	# `wall_slide_steer_control` (0 = sin control, solo coasteas el momentum de entrada;
	# 1 = control total como el movimiento normal). Recortarlo evita sentir que "volas"
	# de lado sobre la pared.
	var steer := horizontal_velocity.slide(wall_normal)
	steer.y = 0.0
	steer *= t.wall_slide_steer_control
	# Presion constante contra la pared: sin esto el movimiento queda paralelo al muro,
	# se pierde el contacto (is_on_wall) y el estado de slide titila frame a frame.
	return steer + _wall_tangent_velocity - wall_normal * t.wall_slide_press_speed

func update_after_move(horizontal_velocity: Vector3, input_dir: Vector3) -> void:
	if _body == null:
		return
	if World.now() < _ignore_until or _body.is_on_floor():
		cancel()
		return

	var normal := _find_wall_normal()
	var has_wall := normal.length_squared() >= 0.0001 and _body.is_on_wall()
	if not has_wall:
		# Contacto perdido: ventana de gracia (coyote) antes de cortar, así el estado no
		# titila en esquinas o micro-separaciones; se mantiene con la última normal conocida.
		if is_sliding and World.now() < _grace_until:
			return
		cancel()
		return

	# Solo corta si el jugador se dirige EN CONTRA de la pared (ver apply_slide_velocity).
	if _presses_away_from_wall(input_dir, normal):
		cancel()
		return

	var push_speed := horizontal_velocity.dot(-normal)
	# Para ENGANCHAR hace falta empuje real contra la pared; ya deslizando se mantiene solo.
	if not is_sliding and push_speed < _body.tuning.wall_slide_min_push_speed:
		return

	var was_sliding := is_sliding
	is_sliding = true
	wall_normal = normal
	_grace_until = World.now() + _body.tuning.wall_slide_release_grace
	if not was_sliding:
		_stick_until = World.now() + _body.tuning.wall_slide_stick_time
		# Semilla del momentum de entrada: la velocidad con la que se llega a la pared. Se
		# siembra SOLO al enganchar y de ahi decae a cero en apply_slide_velocity; no se
		# re-setea por frame (si se reseteara nunca decaeria y no habria arco lateral).
		var entry := horizontal_velocity.slide(wall_normal)
		entry.y = 0.0
		# Empuje horizontal al pegarse: un impulso a lo largo de la pared en la direccion
		# en que ya venias, para ensanchar el arco (evita el arco alto-y-flaco que cae
		# vertical cuando llegas lento). Solo se aplica si hay una direccion lateral clara.
		if entry.length() > 0.1:
			entry += entry.normalized() * _body.tuning.wall_slide_stick_push
		_wall_tangent_velocity = entry
		_set_glow(true)
		_set_dust(true)

func try_wall_jump(input_dir: Vector3) -> bool:
	if _body == null:
		return false
	var normal := wall_normal
	if not is_sliding:
		# El slide puede haberse cortado justo este frame: si sigue habiendo pared
		# real, el salto igual es rebote hacia afuera, nunca un impulso vertical puro.
		if World.now() < _ignore_until or _body.is_on_floor() or not _body.is_on_wall():
			return false
		normal = _find_wall_normal()
		if normal.length_squared() < 0.0001:
			return false
	# El impulso es el input reflejado en la pared: la componente hacia la pared
	# se invierte (sale por la normal) y la componente lateral del input se conserva.
	var tangent := input_dir
	tangent.y = 0.0
	tangent = tangent.slide(normal)
	if tangent.length_squared() > 0.0001:
		tangent = tangent.normalized() * _body.tuning.wall_slide_wall_jump_along_speed
	else:
		tangent = Vector3.ZERO
	_body.set_momentum(normal * _body.tuning.wall_slide_wall_jump_away_speed + tangent)
	_body.vertical_velocity = _body.tuning.wall_slide_wall_jump_up_speed
	_ignore_until = World.now() + _body.tuning.wall_slide_wall_jump_lock_time
	_move_lock_until = World.now() + _body.tuning.wall_slide_wall_jump_lock_time
	cancel()
	return true

## Durante el rebote el impulso de la pared manda: el input de movimiento queda
## bloqueado un instante para que aplastar hacia el muro no cancele el empuje.
func blocks_move_input() -> bool:
	return _body != null and World.now() < _move_lock_until and not _body.is_on_floor()

func cancel() -> void:
	is_sliding = false
	wall_normal = Vector3.ZERO
	_wall_tangent_velocity = Vector3.ZERO
	_set_glow(false)
	_set_dust(false)

func _set_glow(active: bool) -> void:
	if _mesh == null or active == _glow_active:
		return
	_glow_active = active
	if active:
		if _glow_material == null:
			_glow_material = StandardMaterial3D.new()
			_glow_material.emission_enabled = true
		_glow_material.emission = glow_color
		_glow_material.emission_energy_multiplier = glow_energy
		_mesh.set_surface_override_material(0, _glow_material)
	else:
		_mesh.set_surface_override_material(0, null)

func _set_dust(active: bool) -> void:
	if _dust != null and _dust.emitting != active:
		_dust.emitting = active

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

## True solo si el jugador dirige el stick claramente HACIA AFUERA de la pared (alineado con
## la normal). Input neutro devuelve false → el slide se mantiene sin apretar (assist).
func _presses_away_from_wall(input_dir: Vector3, normal: Vector3) -> bool:
	input_dir.y = 0.0
	if input_dir.length_squared() < 0.0001:
		return false
	return input_dir.normalized().dot(normal) >= _body.tuning.wall_slide_input_dot
