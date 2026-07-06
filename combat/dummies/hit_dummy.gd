class_name HitDummy extends Node3D
## Dummy golpeable para probar armas antes de que EnemyBase exista completo.
## Implementa los verbos duck-typed que la espada invoca: launch, slam, push y slam_bounce.

@export var launch_rise_time := World.LAUNCH_RISE_TIME
@export var gravity := -24.0
@export var ground_y := 0.0

var _vertical_velocity := 0.0
var _horizontal_velocity := Vector3.ZERO
var _airborne_until := 0.0

func launch(height: float, hang_time: float) -> bool:
	_vertical_velocity = height / maxf(0.01, launch_rise_time)
	_airborne_until = World.now() + launch_rise_time + hang_time
	return true

func slam(down_speed: float) -> void:
	_vertical_velocity = -absf(down_speed)
	_airborne_until = World.now() + 4.0
	_horizontal_velocity = Vector3.ZERO

func push(direction: Vector3, horizontal_speed: float, up_speed: float) -> void:
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		_horizontal_velocity = direction.normalized() * horizontal_speed
	_vertical_velocity = absf(up_speed)
	_airborne_until = World.now() + 4.0

func slam_bounce(down_speed: float, target_world_y: Callable, hang_time: float) -> void:
	slam(down_speed)
	await _landed()
	if not is_inside_tree():
		return
	var target_y := float(target_world_y.call())
	var height := target_y - global_position.y
	if height > 0.1:
		launch(height, hang_time)

func _physics_process(delta: float) -> void:
	if World.now() >= _airborne_until and global_position.y <= ground_y:
		_horizontal_velocity = Vector3.ZERO
		_vertical_velocity = 0.0
		return

	_vertical_velocity += gravity * delta
	global_position += (_horizontal_velocity + Vector3.UP * _vertical_velocity) * delta
	if global_position.y <= ground_y:
		global_position.y = ground_y
		_horizontal_velocity = Vector3.ZERO
		_vertical_velocity = 0.0
		_airborne_until = 0.0

func _landed() -> void:
	while is_inside_tree() and global_position.y > ground_y:
		await get_tree().physics_frame
