class_name CameraVerticalZone extends Area3D
## Área que sobreescribe `CameraTuning.vertical_follow_limit` mientras el jugador está adentro
## (ver CameraRig.push_vertical_limit/pop_vertical_limit). Uso: tramos donde se sube mucho
## (Brazo, launcher, bloques) y la cámara necesita un tope distinto al default global — o ninguno
## (`vertical_follow_limit <= 0`) si el tramo pide que la cámara siga sin fin.

@export var vertical_follow_limit := 10.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = World.LAYER_PLAYER  # solo el jugador dispara la zona
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body is not Player:
		return
	var rig := get_tree().get_first_node_in_group("camera_rig") as CameraRig
	if rig != null:
		rig.push_vertical_limit(vertical_follow_limit)

func _on_body_exited(body: Node3D) -> void:
	if body is not Player:
		return
	var rig := get_tree().get_first_node_in_group("camera_rig") as CameraRig
	if rig != null:
		rig.pop_vertical_limit(vertical_follow_limit)
