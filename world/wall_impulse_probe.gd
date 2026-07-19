extends Node3D
## Verifica el contrato estructural de Wall Impulse: una pared marcada captura el
## primer input tangencial, bloquea su rumbo y acelera al player mientras sigue en slide.

var _player: Player
var _frames := 0
var _captured_direction := Vector3.ZERO

func _ready() -> void:
	_add_box(Vector3(0.0, -0.5, 0.0), Vector3(60.0, 1.0, 60.0), false)
	_add_box(Vector3(3.0, 20.0, 0.0), Vector3(1.0, 44.0, 20.0), true)
	_player = (load("res://player/player.tscn") as PackedScene).instantiate()
	add_child(_player)
	_player.global_position = Vector3(1.2, 30.0, 0.0)
	# move_right tiene componente hacia la pared y otra tangencial: engancha y define impulso.
	Input.action_press("move_right")

func _physics_process(_delta: float) -> void:
	_frames += 1
	if _player.wall_slide.is_impulsing and _captured_direction == Vector3.ZERO:
		_captured_direction = _player.wall_slide.impulse_direction
		assert(_captured_direction.length_squared() > 0.9,
				"Wall Impulse debe capturar una direccion horizontal valida")
	# Cambiar el stick no puede cambiar la direccion ya capturada.
	if _captured_direction != Vector3.ZERO and _frames == 120:
		Input.action_release("move_right")
		Input.action_press("move_left")
	if _captured_direction != Vector3.ZERO and _frames > 135:
		assert(_player.wall_slide.impulse_direction.is_equal_approx(_captured_direction),
				"Wall Impulse debe conservar solo el primer input tangencial")
		print("WALL IMPULSE PROBE OK")
		get_tree().quit()
	if _frames >= 300:
		assert(false, "Wall Impulse no capturo un input durante el wall slide")

func _add_box(pos: Vector3, size: Vector3, is_impulse: bool) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = World.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	if is_impulse:
		var surface := WallImpulseSurface.new()
		surface.tuning = load("res://data/wall_impulse_default.tres") as WallImpulseTuning
		body.add_child(surface)
	body.position = pos
	add_child(body)
