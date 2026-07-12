class_name FlyingEnemy extends EnemyBase
## Prototipo aereo: patrulla horizontalmente y anima alas sin usar la IA de suelo.

## Semiextension horizontal desde el punto de aparicion, en metros.
@export var patrol_half_width := 4.0
## Velocidad de patrulla horizontal, en metros por segundo.
@export var patrol_speed := 2.5
## Oscilacion vertical alrededor de la altura inicial, en metros.
@export var hover_height := 0.35
## Ciclos por segundo de la oscilacion vertical.
@export var hover_frequency := 1.2
## Ciclos por segundo del aleteo.
@export var wing_flap_frequency := 5.0
## Angulo maximo de cada ala durante el aleteo, en grados.
@export var wing_flap_angle := 28.0
## Velocidad con la que regresa al punto de aparicion despues de caer por un push.
@export var return_speed := 5.0
## Distancia al punto de aparicion a la que termina el retorno y retoma la patrulla.
@export var return_arrive_distance := 0.08

var _home_position := Vector3.ZERO
var _patrol_direction := 1.0
var _elapsed := 0.0
var _returning_to_home := false

@onready var _left_wing: Node3D = get_node_or_null("Visual/LeftWingPivot") as Node3D
@onready var _right_wing: Node3D = get_node_or_null("Visual/RightWingPivot") as Node3D

func _ready() -> void:
	super._ready()
	_home_position = global_position

func _physics_process(delta: float) -> void:
	var was_airborne := is_airborne()
	var can_patrol := tick_base(delta)
	if was_airborne and not is_airborne():
		_returning_to_home = true
	if is_stunned() and not is_airborne():
		_elapsed += delta
		_update_wings()
		return
	if not can_patrol:
		return
	_elapsed += delta
	if _returning_to_home:
		_return_to_home(delta)
		_update_wings()
		return
	_update_patrol(delta)
	_update_wings()

func apply_stun(duration: float) -> void:
	super.apply_stun(duration)
	if not is_stunned():
		return
	# El enemigo volador se queda suspendido: no usa el retroceso ni la inclinacion de suelo.
	velocity = Vector3.ZERO
	if _stun_tween != null:
		_stun_tween.kill()
	if visual != null:
		visual.quaternion = Quaternion.IDENTITY
		visual.position = Vector3.ZERO

func _update_patrol(delta: float) -> void:
	var next_x := global_position.x + patrol_speed * _patrol_direction * delta
	var min_x := _home_position.x - patrol_half_width
	var max_x := _home_position.x + patrol_half_width
	if next_x >= max_x:
		next_x = max_x
		_patrol_direction = -1.0
	elif next_x <= min_x:
		next_x = min_x
		_patrol_direction = 1.0
	global_position = Vector3(
		next_x,
		_home_position.y + sin(_elapsed * TAU * hover_frequency) * hover_height,
		_home_position.z)
	if visual != null:
		visual.rotation.y = 0.0 if _patrol_direction > 0.0 else PI

func _return_to_home(delta: float) -> void:
	var to_home := _home_position - global_position
	global_position = global_position.move_toward(_home_position, return_speed * delta)
	if visual != null and absf(to_home.x) > 0.01:
		visual.rotation.y = 0.0 if to_home.x > 0.0 else PI
	if global_position.distance_to(_home_position) <= return_arrive_distance:
		global_position = _home_position
		_returning_to_home = false
		_patrol_direction = 1.0

func _update_wings() -> void:
	var flap := sin(_elapsed * TAU * wing_flap_frequency) * deg_to_rad(wing_flap_angle)
	if _left_wing != null:
		_left_wing.rotation.z = flap
	if _right_wing != null:
		_right_wing.rotation.z = -flap
