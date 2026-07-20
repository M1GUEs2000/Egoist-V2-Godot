class_name CameraRig extends Node3D
## Cámara isométrica con follow + damping + rotación horizontal por stick (ex CameraFollow.cs).
## pitch/distance/damping viven en `tuning` (CameraTuning): arrastrás los valores en el .tres
## (incluso en play) y ves el cambio al instante. La proyección (orto/perspectiva) se decide en
## la Camera3D hija, este script no la pisa.
##
## Rotación: el yaw real es `tuning.center_yaw + _yaw_offset`. El stick (camera_left/right)
## mueve `_yaw_offset` libremente (360°, sin clamp): la cámara puede rodear por completo al
## personaje y se queda donde el jugador la dejó — no hay recentrado automático.
##
## Lock-on: mientras `target.lock_on.is_locked`, el stick deja de rotar la cámara (lo usa
## LockOn.cycle_target vía Player._unhandled_input) y el yaw se congela en el que ya tenía (no
## orbita a la espalda del jugador); la distancia hace zoom in/out según la separación
## jugador-target (`lock_zoom_min_distance`/`lock_zoom_max_distance` entre
## `lock_zoom_near_separation`/`lock_zoom_far_separation`), mientras el punto de mira se corre
## del jugador hacia el target según `tuning.lock_focus_weight` — encuadra a los dos, como en
## Dark Souls.
##
## Wall slide: mientras el jugador está pegado a una pared el stick no rota la cámara; el yaw se
## acomoda solo a la normal del muro corrida `wall_slide_yaw_offset` grados hacia el lado que va
## quedando atrás, para ver a lo largo del carril en vez de la pared de frente (ver `_update_wall_yaw`).
##
## Seguimiento vertical: el punto de mira sigue al target en Y solo dentro de
## `tuning.vertical_follow_limit` metros desde la última altura "asentada" (`_vertical_anchor`,
## que mide siempre la altura del JUGADOR — también con lock activo — y se re-ancla solo mientras
## el target está dentro del tope). Pasado el tope se congela: el
## jugador sale de cuadro en vertical en vez de que la cámara lo persiga sin fin. `CameraVerticalZone`
## puede apilar un tope distinto por área (`push_vertical_limit`/`pop_vertical_limit`).

@export var target: Node3D
@export var tuning: CameraTuning

var _snapped := false
var _yaw_offset := 0.0
var _vertical_anchor := 0.0
var _vertical_anchor_set := false
var _vertical_overrides: Array[float] = []
## Lado del muro hacia el que se corre la cámara en wall slide (-1/+1; 0 = todavía sin rumbo).
var _wall_side := 0.0
## Cuán vertical es el movimiento sobre la pared (0 = lateral, 1 = caída seca → encuadre 2D).
var _wall_vertical_blend := 0.0

## Rapidez mínima a lo largo del muro para (re)definir el lado del encuadre de wall slide.
const WALL_SIDE_MIN_SPEED := 0.5

func _ready() -> void:
	add_to_group("camera_rig")  # CameraVerticalZone me encuentra por grupo
	# El export de nodo puede llegar null (referencia rota / escena instanciada por código):
	# fallback al grupo "player", que es el cableado nativo de Godot.
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Node3D

func _physics_process(delta: float) -> void:
	if target == null or tuning == null:
		return
	var player := target as Player
	var enemy: EnemyBase = null
	if player != null and player.lock_on.is_locked:
		enemy = player.lock_on.current_target
	if enemy != null:
		_update_locked(delta, enemy)
	else:
		_update_free(delta, player)

func _update_free(delta: float, player: Player) -> void:
	if not _update_wall_yaw(delta, player):
		_update_yaw_offset(delta)
	var yaw := tuning.center_yaw + _yaw_offset
	var offset := Basis(Vector3.UP, deg_to_rad(yaw)) \
			* (Basis(Vector3.RIGHT, deg_to_rad(-tuning.pitch)) * Vector3(0.0, 0.0, tuning.distance))
	var follow_point := target.global_position
	follow_point.y = _clamp_vertical(follow_point.y, delta)
	_move_to(follow_point + offset, follow_point, delta)

## Encuadra jugador + target: mantiene el yaw libre actual (no orbita a la espalda del jugador)
## y hace zoom in/out según la separación jugador-target, orbitando el punto de mira entre ambos
## (ver `lock_focus_weight`).
func _update_locked(delta: float, enemy: EnemyBase) -> void:
	var separation := enemy.global_position.distance_to(target.global_position)
	var zoom_t := clampf(inverse_lerp(tuning.lock_zoom_near_separation, tuning.lock_zoom_far_separation, separation), 0.0, 1.0)
	var lock_distance := lerpf(tuning.lock_zoom_min_distance, tuning.lock_zoom_max_distance, zoom_t)
	var yaw := tuning.center_yaw + _yaw_offset
	var offset := Basis(Vector3.UP, deg_to_rad(yaw)) \
			* (Basis(Vector3.RIGHT, deg_to_rad(-tuning.pitch)) * Vector3(0.0, 0.0, lock_distance))
	var focus := target.global_position.lerp(enemy.global_position, tuning.lock_focus_weight)
	# El ancla vertical mide SIEMPRE la altura del jugador, nunca la del punto de mira: si se
	# anclara al lerp, un target alto la dejaría arriba y al soltar el lock el jugador quedaría
	# fuera del tope con el ancla ya congelada (la cámara no volvía a bajar nunca).
	focus.y += _clamp_vertical(target.global_position.y, delta) - target.global_position.y
	_move_to(focus + offset, focus, delta)

func _move_to(desired: Vector3, look_at_point: Vector3, delta: float) -> void:
	if _snapped:
		global_position = global_position.lerp(desired, clampf(tuning.damping * delta, 0.0, 1.0))
	else:
		global_position = desired  # primer frame: sin swoop desde el origen
		_snapped = true
	if global_position.distance_squared_to(look_at_point) > 0.0001:
		look_at(look_at_point, Vector3.UP)

## Tope de seguimiento vertical activo: el de la zona más reciente si hay alguna apilada,
## si no el default del tuning.
func _current_vertical_limit() -> float:
	return _vertical_overrides.back() if not _vertical_overrides.is_empty() else tuning.vertical_follow_limit

## Sigue a `true_y` mientras esté a `limit` metros o menos del ancla; más allá, la cámara deja de
## subir/bajar y el target se va de cuadro en vertical. Pasado el tope el ancla no se congela seca:
## deriva hacia `true_y` a `vertical_recover_speed` m/s, así un tramo corto (launcher, Brazo) se
## frena igual pero una caída larga termina recuperando el encuadre en vez de dejar la cámara
## clavada para siempre. Con `vertical_recover_speed = 0` vuelve a congelarse sin retorno.
func _clamp_vertical(true_y: float, delta: float) -> float:
	if not _vertical_anchor_set:
		_vertical_anchor = true_y
		_vertical_anchor_set = true
	var limit := _current_vertical_limit()
	if limit <= 0.0:
		_vertical_anchor = true_y
		return true_y
	var excursion := true_y - _vertical_anchor
	if absf(excursion) <= limit:
		_vertical_anchor = true_y
	elif tuning.vertical_recover_speed > 0.0:
		# Se cede solo lo que sobra del tope: el ancla nunca adelanta al target ni cruza de lado.
		var slack := absf(excursion) - limit
		_vertical_anchor += signf(excursion) * minf(tuning.vertical_recover_speed * delta, slack)
	return clampf(true_y, _vertical_anchor - limit, _vertical_anchor + limit)

## Apila un tope distinto (lo usa `CameraVerticalZone` al entrar el jugador). Con zonas anidadas
## manda la más reciente; al salir de la de más adentro, vuelve a la anterior.
func push_vertical_limit(limit: float) -> void:
	_vertical_overrides.append(limit)

func pop_vertical_limit(limit: float) -> void:
	_vertical_overrides.erase(limit)

## Fuerza el yaw libre para que la camara quede detras del jugador en el sentido opuesto a
## `direction` (lo usa TraversalBlock al activar launch/dash, para que el jugador siempre vea
## hacia donde lo mandan). Solo mueve `_yaw_offset`; `_move_to` interpola la posicion con el
## damping de siempre, no es un teletransporte de camara.
func snap_behind(direction: Vector3) -> void:
	var horizontal := Vector3(-direction.x, 0.0, -direction.z)
	if horizontal.length_squared() < 0.0001 or tuning == null:
		return
	var yaw := rad_to_deg(atan2(horizontal.x, horizontal.z))
	_yaw_offset = wrapf(yaw - tuning.center_yaw, -180.0, 180.0)

## Encuadre de wall slide: mientras el jugador está pegado a una pared, el yaw deja de salir del
## stick y se planta en la normal del muro corrida `wall_slide_yaw_offset` grados hacia el lado que
## el jugador va DEJANDO ATRÁS — así la pared queda en diagonal y ve hacia donde se mueve, en vez
## de tener el muro plano de frente. El lado sale de la velocidad a lo largo del muro (en Wall
## Impulse, del rumbo capturado); si no hay tangente clara todavía se conserva el último lado, así
## el encuadre no salta de un lado al otro al arrancar. Devuelve false si no aplica (yaw normal).
func _update_wall_yaw(delta: float, player: Player) -> bool:
	if player == null or not tuning.wall_slide_frame_enabled or not player.wall_slide.is_sliding:
		_wall_side = 0.0
		_wall_vertical_blend = 0.0
		return false
	var normal := player.wall_slide.wall_normal
	if normal.length_squared() < 0.0001:
		return false
	var wall_tangent := Vector3.UP.cross(normal)
	wall_tangent.y = 0.0
	if wall_tangent.length_squared() < 0.0001:
		return false
	wall_tangent = wall_tangent.normalized()

	var horizontal := player.velocity
	horizontal.y = 0.0
	var side_speed := horizontal.slide(normal).dot(wall_tangent)
	# Movimiento sobre el plano de la pared: cuánto de lo que hacés es recorrido lateral y cuánto
	# es pura caída/subida. Por debajo del mínimo el encuadre se sostiene como está (un tramo casi
	# quieto no debe hacer bailar el ángulo).
	var motion := Vector2(absf(side_speed), absf(player.velocity.y))
	if motion.length() > tuning.wall_slide_motion_min_speed:
		if absf(side_speed) > WALL_SIDE_MIN_SPEED:
			_wall_side = signf(side_speed)
		# 0 = recorrido puramente lateral → `wall_slide_yaw_offset`.
		# 1 = caída/subida vertical seca → `wall_slide_vertical_yaw_offset` (encuadre 2D).
		_wall_vertical_blend = clampf(motion.angle() / (PI * 0.5), 0.0, 1.0)
	if _wall_side == 0.0:
		# Todavía sin rumbo (típico de una caída seca recién enganchada): se elige el lado que
		# menos giro exige desde donde está la cámara, así el encuadre entra sin latigazo.
		var alignment := wall_tangent.dot(_camera_direction())
		_wall_side = -signf(alignment) if not is_zero_approx(alignment) else 1.0

	var offset_angle := deg_to_rad(lerpf(tuning.wall_slide_yaw_offset,
			tuning.wall_slide_vertical_yaw_offset, _wall_vertical_blend))
	# La cámara se para sobre la normal y se corre hacia -movimiento: queda detrás del recorrido.
	var camera_dir := (normal * cos(offset_angle)
			- wall_tangent * _wall_side * sin(offset_angle)).normalized()
	var target_offset := wrapf(rad_to_deg(atan2(camera_dir.x, camera_dir.z)) - tuning.center_yaw,
			-180.0, 180.0)
	# Por el camino corto: la diferencia se envuelve antes de interpolar, si no un cruce por ±180
	# manda la cámara a dar la vuelta larga alrededor del jugador.
	var diff := wrapf(target_offset - _yaw_offset, -180.0, 180.0)
	_yaw_offset = wrapf(_yaw_offset + diff * clampf(tuning.wall_slide_yaw_damping * delta, 0.0, 1.0),
			-180.0, 180.0)
	return true

## Dirección horizontal en la que está parada la cámara respecto al target, según el yaw actual.
func _camera_direction() -> Vector3:
	var yaw := deg_to_rad(tuning.center_yaw + _yaw_offset)
	return Vector3(sin(yaw), 0.0, cos(yaw))

func _update_yaw_offset(delta: float) -> void:
	var input := Input.get_axis("camera_left", "camera_right")
	if absf(input) > tuning.input_deadzone:
		# wrapf solo mantiene el número acotado (-180..180); la rotación es libre, sin tope.
		_yaw_offset = wrapf(_yaw_offset + input * tuning.yaw_speed * delta, -180.0, 180.0)
