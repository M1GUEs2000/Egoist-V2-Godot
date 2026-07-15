class_name CameraRig extends Node3D
## Cámara isométrica con follow + damping + rotación horizontal por stick (ex CameraFollow.cs).
## pitch/distance/damping viven en `tuning` (CameraTuning): arrastrás los valores en el .tres
## (incluso en play) y ves el cambio al instante. La proyección (orto/perspectiva) se decide en
## la Camera3D hija, este script no la pisa.
##
## Rotación: el yaw real es `tuning.center_yaw + _yaw_offset`. El stick (camera_left/right)
## mueve `_yaw_offset` libremente (360°, sin clamp): la cámara puede rodear por completo al
## personaje y se queda donde el jugador la dejó — no hay recentrado automático.

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
	_update_yaw_offset(delta)
	var yaw := tuning.center_yaw + _yaw_offset
	var offset := Basis(Vector3.UP, deg_to_rad(yaw)) \
			* (Basis(Vector3.RIGHT, deg_to_rad(-tuning.pitch)) * Vector3(0.0, 0.0, tuning.distance))
	var desired := target.global_position + offset
	if _snapped:
		global_position = global_position.lerp(desired, clampf(tuning.damping * delta, 0.0, 1.0))
	else:
		global_position = desired  # primer frame: sin swoop desde el origen
		_snapped = true
	if global_position.distance_squared_to(target.global_position) > 0.0001:
		look_at(target.global_position, Vector3.UP)

func _update_yaw_offset(delta: float) -> void:
	var input := Input.get_axis("camera_left", "camera_right")
	if absf(input) > tuning.input_deadzone:
		# wrapf solo mantiene el número acotado (-180..180); la rotación es libre, sin tope.
		_yaw_offset = wrapf(_yaw_offset + input * tuning.yaw_speed * delta, -180.0, 180.0)
