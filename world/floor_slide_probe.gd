extends Node3D
## Probe temporal del floor slide: pone al player sobre una plataforma plana con un nodo
## FloorSlideSurface (hielo: friccion baja, steer_control 0), lo lanza con momentum y verifica
## que engancha una sola vez (transitions ~2) y que se DESLIZA muchos frames sin frenar de golpe.

var _player: Player
var _frames := 0
var _transitions := 0
var _slide_frames := 0
var _was := false
var _seeded := false

func _ready() -> void:
	_add_slide_floor(Vector3(0.0, -0.5, 0.0), Vector3(400.0, 1.0, 60.0))

	_player = (load("res://player/player.tscn") as PackedScene).instantiate()
	add_child(_player)
	_player.global_position = Vector3(-180.0, 2.0, 0.0)

func _physics_process(_delta: float) -> void:
	_frames += 1
	# Una vez apoyado, lo empujamos con momentum en +X (sin input: hielo puro sin volante).
	if not _seeded and _player.is_on_floor():
		_player.set_momentum(Vector3(15.0, 0.0, 0.0))
		_seeded = true

	var sliding: bool = _player.floor_slide.is_sliding
	if sliding:
		_slide_frames += 1
	if sliding != _was:
		_transitions += 1
		_was = sliding

	if _frames >= 240:
		print("PROBE frames=%d slide_frames=%d transitions=%d" % [_frames, _slide_frames, _transitions])
		get_tree().quit()

func _add_slide_floor(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = World.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	var surface := FloorSlideSurface.new()
	surface.name = "FloorSlideSurface"
	surface.tuning = load("res://data/floor_slide_ice.tres") as FloorSlideTuning
	body.add_child(surface)

	body.position = pos
	add_child(body)
