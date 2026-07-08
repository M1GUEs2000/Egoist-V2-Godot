extends Node3D
## Probe temporal: cuenta transiciones de is_sliding mientras el player cae
## pegado a una pared con input sostenido hacia ella. Sin flicker, las
## transiciones deben ser ~2 (entra una vez, sale al aterrizar).

var _player: Player
var _frames := 0
var _transitions := 0
var _slide_frames := 0
var _was := false

func _ready() -> void:
	_add_box(Vector3(0.0, -0.5, 0.0), Vector3(60.0, 1.0, 60.0))
	_add_box(Vector3(3.0, 20.0, 0.0), Vector3(1.0, 44.0, 20.0))

	_player = (load("res://player/player.tscn") as PackedScene).instantiate()
	add_child(_player)
	_player.global_position = Vector3(1.2, 30.0, 0.0)

	# Input (1,1) con el fallback isometrico -45 de camera_relative da direccion +X: hacia la pared.
	Input.action_press("move_right")
	Input.action_press("move_up")

func _physics_process(_delta: float) -> void:
	_frames += 1
	var sliding: bool = _player.wall_slide.is_sliding
	if sliding:
		_slide_frames += 1
	if sliding != _was:
		_transitions += 1
		_was = sliding
	if _frames >= 300 or (_frames > 60 and _player.is_on_floor()):
		print("PROBE frames=%d slide_frames=%d transitions=%d" % [_frames, _slide_frames, _transitions])
		get_tree().quit()

func _add_box(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = World.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	add_child(body)
