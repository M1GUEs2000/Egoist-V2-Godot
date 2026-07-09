extends Node3D
## Probe temporal: el player cae contra un enemigo y pide rebote dentro de la gracia.

var _player: Player
var _enemy: EnemyBase
var _frames := 0
var _requested := false
var _bounces := 0

func _ready() -> void:
	_add_floor()
	_enemy = _make_enemy()
	_enemy.global_position = Vector3.ZERO

	_player = (load("res://player/player.tscn") as PackedScene).instantiate()
	add_child(_player)
	_player.global_position = Vector3(0.82, 3.2, 0.0)
	_player.air_state = Player.AirState.AIRBORNE

func _physics_process(_delta: float) -> void:
	_frames += 1
	if not _requested and World.now() - _player.enemy_bounce._last_contact_time \
			<= _player.tuning.enemy_bounce_grace * 0.5:
		_requested = true
		if _player.enemy_bounce.try_bounce(Vector3.FORWARD):
			_bounces += 1
	if _frames >= 180 or _bounces > 0:
		print("PROBE enemy_bounces=%d frames=%d" % [_bounces, _frames])
		get_tree().quit()

func _add_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = World.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0.0, -1.0, 0.0)
	add_child(body)

func _make_enemy() -> EnemyBase:
	var enemy := EnemyBase.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.9, 0.0)
	enemy.add_child(shape)
	add_child(enemy)
	return enemy
