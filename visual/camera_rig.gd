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
## Seguimiento vertical: el punto de mira sigue al target en Y solo dentro de
## `tuning.vertical_follow_limit` metros desde la última altura "asentada" (`_vertical_anchor`,
## que se re-ancla solo mientras el target está dentro del tope). Pasado el tope se congela: el
## jugador sale de cuadro en vertical en vez de que la cámara lo persiga sin fin. `CameraVerticalZone`
## puede apilar un tope distinto por área (`push_vertical_limit`/`pop_vertical_limit`).

@export var target: Node3D
@export var tuning: CameraTuning

var _snapped := false
var _yaw_offset := 0.0
var _vertical_anchor := 0.0
var _vertical_anchor_set := false
var _vertical_overrides: Array[float] = []

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
		_update_free(delta)

func _update_free(delta: float) -> void:
	_update_yaw_offset(delta)
	var yaw := tuning.center_yaw + _yaw_offset
	var offset := Basis(Vector3.UP, deg_to_rad(yaw)) \
			* (Basis(Vector3.RIGHT, deg_to_rad(-tuning.pitch)) * Vector3(0.0, 0.0, tuning.distance))
	var follow_point := target.global_position
	follow_point.y = _clamp_vertical(follow_point.y)
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
	focus.y = _clamp_vertical(focus.y)
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

## Sigue a `true_y` mientras esté a `limit` metros o menos del ancla; más allá, congela el ancla
## y clampea — la cámara deja de subir/bajar hasta que el target vuelva a estar cerca de esa altura.
func _clamp_vertical(true_y: float) -> float:
	if not _vertical_anchor_set:
		_vertical_anchor = true_y
		_vertical_anchor_set = true
	var limit := _current_vertical_limit()
	if limit <= 0.0:
		_vertical_anchor = true_y
		return true_y
	if absf(true_y - _vertical_anchor) <= limit:
		_vertical_anchor = true_y
	return clampf(true_y, _vertical_anchor - limit, _vertical_anchor + limit)

## Apila un tope distinto (lo usa `CameraVerticalZone` al entrar el jugador). Con zonas anidadas
## manda la más reciente; al salir de la de más adentro, vuelve a la anterior.
func push_vertical_limit(limit: float) -> void:
	_vertical_overrides.append(limit)

func pop_vertical_limit(limit: float) -> void:
	_vertical_overrides.erase(limit)

func _update_yaw_offset(delta: float) -> void:
	var input := Input.get_axis("camera_left", "camera_right")
	if absf(input) > tuning.input_deadzone:
		# wrapf solo mantiene el número acotado (-180..180); la rotación es libre, sin tope.
		_yaw_offset = wrapf(_yaw_offset + input * tuning.yaw_speed * delta, -180.0, 180.0)
