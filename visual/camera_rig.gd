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
## LockOn.cycle_target vía Player._unhandled_input) y el yaw pasa a mirar "hacia atrás" del
## target lockeado, mientras el punto de mira se corre del jugador hacia el target según
## `tuning.lock_focus_weight` — encuadra a los dos, como en Dark Souls.

@export var target: Node3D
@export var tuning: CameraTuning

var _snapped := false
var _yaw_offset := 0.0

func _ready() -> void:
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
	_move_to(target.global_position + offset, target.global_position, delta)

## Encuadra jugador + target: la cámara orbita el punto de mira (entre ambos, ver
## `lock_focus_weight`) parada del lado opuesto al target respecto del jugador.
func _update_locked(delta: float, enemy: EnemyBase) -> void:
	var to_target := enemy.global_position - target.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		_update_free(delta)
		return
	var away := -to_target.normalized()
	var yaw := rad_to_deg(atan2(away.x, away.z))
	var offset := Basis(Vector3.UP, deg_to_rad(yaw)) \
			* (Basis(Vector3.RIGHT, deg_to_rad(-tuning.pitch)) * Vector3(0.0, 0.0, tuning.distance))
	var focus := target.global_position.lerp(enemy.global_position, tuning.lock_focus_weight)
	_move_to(focus + offset, focus, delta)

func _move_to(desired: Vector3, look_at_point: Vector3, delta: float) -> void:
	if _snapped:
		global_position = global_position.lerp(desired, clampf(tuning.damping * delta, 0.0, 1.0))
	else:
		global_position = desired  # primer frame: sin swoop desde el origen
		_snapped = true
	if global_position.distance_squared_to(look_at_point) > 0.0001:
		look_at(look_at_point, Vector3.UP)

func _update_yaw_offset(delta: float) -> void:
	var input := Input.get_axis("camera_left", "camera_right")
	if absf(input) > tuning.input_deadzone:
		# wrapf solo mantiene el número acotado (-180..180); la rotación es libre, sin tope.
		_yaw_offset = wrapf(_yaw_offset + input * tuning.yaw_speed * delta, -180.0, 180.0)
