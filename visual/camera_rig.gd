class_name CameraRig extends Node3D
## Cámara isométrica con follow + damping (ex CameraFollow.cs). pitch/yaw/distance se
## recalculan cada frame: arrastrás los valores en el inspector (incluso en play) y ves
## el cambio al instante. La proyección (orto/perspectiva) se decide en la Camera3D hija,
## este script no la pisa.

@export var target: Node3D
@export var pitch := 30.0    # inclinación isométrica
@export var yaw := 45.0      # giro diagonal
@export var distance := 18.0 # qué tan lejos del target
@export var damping := 5.0   # suavizado del follow

var _snapped := false

func _ready() -> void:
	# El export de nodo puede llegar null (referencia rota / escena instanciada por código):
	# fallback al grupo "player", que es el cableado nativo de Godot.
	if target == null:
		target = get_tree().get_first_node_in_group("player") as Node3D

func _physics_process(delta: float) -> void:
	if target == null:
		return
	var offset := Basis(Vector3.UP, deg_to_rad(yaw)) \
			* (Basis(Vector3.RIGHT, deg_to_rad(-pitch)) * Vector3(0.0, 0.0, distance))
	var desired := target.global_position + offset
	if _snapped:
		global_position = global_position.lerp(desired, clampf(damping * delta, 0.0, 1.0))
	else:
		global_position = desired  # primer frame: sin swoop desde el origen
		_snapped = true
	if global_position.distance_squared_to(target.global_position) > 0.0001:
		look_at(target.global_position, Vector3.UP)
