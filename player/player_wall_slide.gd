class_name PlayerWallSlide extends Node
## Deslizamiento de pared por momentum: requiere input hacia la pared y contacto real.

## Feedback visual: el personaje brilla verde mientras está pegado a la pared.
@export var glow_color := Color(0.25, 1.0, 0.4)
@export var glow_energy := 2.0

var is_sliding := false
var wall_normal := Vector3.ZERO

var _body: Player
var _stick_until := -999.0
var _ignore_until := -999.0
var _move_lock_until := -999.0
var _grace_until := -999.0
var _wall_tangent_velocity := Vector3.ZERO
var _mesh: MeshInstance3D
var _glow_material: StandardMaterial3D
var _glow_active := false
var _dust: GPUParticles3D

const ARROW_LENGTH := 2.0
var _arrow: MeshInstance3D
var _arrow_mesh: ImmediateMesh
var _arrow_material: StandardMaterial3D

func setup(body: Player) -> void:
	_body = body
	_mesh = body.get_node_or_null("Mesh") as MeshInstance3D
	_dust = body.get_node_or_null("WallSlideDust") as GPUParticles3D
	_build_arrow()

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
	# Velocidad a lo largo del muro (steer vivo + momentum de entrada), topada por su cap propio.
	var along_wall := (steer + _wall_tangent_velocity).limit_length(t.wall_slide_max_horizontal_speed)
	# Presion constante contra la pared: sin esto el movimiento queda paralelo al muro,
	# se pierde el contacto (is_on_wall) y el estado de slide titila frame a frame.
	return along_wall - wall_normal * t.wall_slide_press_speed

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
	_update_arrow()

func try_wall_jump(_input_dir: Vector3) -> bool:
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

	var launch := _wall_jump_velocity(normal)
	_body.set_momentum(Vector3(launch.x, 0.0, launch.z))
	_body.vertical_velocity = launch.y
	_ignore_until = World.now() + _body.tuning.wall_slide_wall_jump_lock_time
	_move_lock_until = World.now() + _body.tuning.wall_slide_wall_jump_lock_time
	cancel()
	return true

## Velocidad de lanzamiento del wall jump para una normal de pared dada: xz = empuje horizontal
## (dirección + rapidez), y = subida. La usan tanto el salto real como la flecha de debug, así nunca
## difieren. Sale de la velocidad A LO LARGO de la pared (tangente): el momentum real que encadenar
## conserva y compone; el empuje contra el muro (press) no cuenta y del stick no depende.
func _wall_jump_velocity(normal: Vector3) -> Vector3:
	var t := _body.tuning
	var horizontal := _body.velocity
	horizontal.y = 0.0
	var along := horizontal.slide(normal)
	along.y = 0.0
	var along_speed := along.length()

	# Ángulo de salida medido DESDE LA CARA de la pared: cuanto más rápido vas a lo largo (respecto a
	# move_speed), más te acercás al piso `min_angle` (rasante, nunca menos, para no rozar el muro);
	# sin velocidad lateral salís perpendicular (90°, recto/para atrás).
	var along_frac := clampf(along_speed / maxf(0.001, t.move_speed), 0.0, 1.0)
	var angle := lerpf(PI * 0.5, deg_to_rad(t.wall_slide_wall_jump_min_angle), along_frac)
	var exit_dir := normal
	if along_speed > 0.001:
		# sin(angle) = componente hacia afuera del muro; cos(angle) = componente hacia tu rumbo.
		exit_dir = (normal * sin(angle) + along.normalized() * cos(angle)).normalized()

	# HORIZONTAL = max(velocidad_a_lo_largo * h_boost, h_base): tiene piso, siempre despega hacia
	# afuera. VERTICAL = velocidad_a_lo_largo * v_boost: SIN piso (a velocidad 0 no hay subida). El
	# techo horizontal lo pone momentum_max_speed dentro de set_momentum, sin cambiar la dirección.
	var h_speed := maxf(along_speed * t.wall_slide_wall_jump_h_boost, t.wall_slide_wall_jump_h_base)
	var v_speed := along_speed * t.wall_slide_wall_jump_v_boost
	return exit_dir * h_speed + Vector3.UP * v_speed

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
	_update_arrow()

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

## Flecha de debug creada por código (top_level, se dibuja en espacio de mundo). Arranca oculta.
func _build_arrow() -> void:
	_arrow_mesh = ImmediateMesh.new()
	_arrow_material = StandardMaterial3D.new()
	_arrow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arrow_material.albedo_color = Color(1.0, 0.85, 0.15)
	_arrow_material.no_depth_test = true  # visible a través de la geometría, es ayuda de tuning
	_arrow = MeshInstance3D.new()
	_arrow.mesh = _arrow_mesh
	_arrow.material_override = _arrow_material
	_arrow.top_level = true
	_arrow.visible = false
	_body.add_child(_arrow)

## Mientras deslizás (y con el toggle prendido) apunta al ángulo de lanzamiento del wall jump ahora
## mismo. Reusa _wall_jump_velocity, así la flecha muestra exactamente hacia dónde vas a salir.
func _update_arrow() -> void:
	if _arrow == null:
		return
	var show_arrow := is_sliding and _body.tuning.wall_slide_show_jump_arrow
	_arrow.visible = show_arrow
	if not show_arrow:
		return
	var launch := _wall_jump_velocity(wall_normal)
	var dir := launch.normalized() if launch.length_squared() > 0.0001 else wall_normal
	_arrow.global_position = _body.global_position + Vector3.UP
	var tip := dir * ARROW_LENGTH
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized() * 0.25
	var back := tip - dir * 0.5
	_arrow_mesh.clear_surfaces()
	_arrow_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_arrow_mesh.surface_add_vertex(Vector3.ZERO)  # arranca en el player
	_arrow_mesh.surface_add_vertex(tip)
	_arrow_mesh.surface_add_vertex(tip)           # punta de flecha
	_arrow_mesh.surface_add_vertex(back + side)
	_arrow_mesh.surface_add_vertex(tip)
	_arrow_mesh.surface_add_vertex(back - side)
	_arrow_mesh.surface_end()

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
