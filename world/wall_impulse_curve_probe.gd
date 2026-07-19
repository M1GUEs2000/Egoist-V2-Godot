extends Node3D
## Verifica que Wall Impulse NO pierda rapidez en tramos curvos: sobre un muro circular
## interior la rapidez tangencial debe alcanzar max_speed y sostenerse mientras el rumbo
## rota. Si la curvatura recorta la rapidez, este probe falla.

const RADIUS := 6.0
const SEGMENTS := 36
const WALL_HEIGHT := 44.0

var _player: Player
var _tuning: WallImpulseTuning
var _frames := 0
var _impulse_frames := 0
var _peak_speed := 0.0
var _last_speed := 0.0

func _ready() -> void:
	_tuning = load("res://data/wall_impulse_default.tres") as WallImpulseTuning
	_add_floor()
	_add_circle_wall()
	_player = (load("res://player/player.tscn") as PackedScene).instantiate()
	add_child(_player)
	# Adentro del cilindro, cerca de la cara interior en +X: el input diagonal empuja
	# contra el muro y aporta la componente tangencial que captura el carril.
	_player.global_position = Vector3(RADIUS - 1.8, 30.0, 0.0)
	Input.action_press("move_right")

func _physics_process(_delta: float) -> void:
	_frames += 1
	if _player.wall_slide.is_impulsing:
		_impulse_frames += 1
		# Rapidez a lo largo del muro (sin la presion contra la pared ni vertical).
		var tangent_velocity: Vector3 = _player.velocity.slide(_player.wall_slide.wall_normal)
		tangent_velocity.y = 0.0
		_last_speed = tangent_velocity.length()
		_peak_speed = maxf(_peak_speed, _last_speed)

	# 300 frames de carril (5 s) sobran para acelerar de initial_speed a max_speed
	# (menos de 1 s con el tuning default) y dar mas de una vuelta completa al cilindro.
	if _impulse_frames >= 300:
		print("peak=%.2f last=%.2f max_speed=%.2f" % [_peak_speed, _last_speed, _tuning.max_speed])
		assert(_peak_speed >= _tuning.max_speed * 0.95,
				"Wall Impulse debe alcanzar max_speed aun en curva (peak %.2f de %.2f)"
				% [_peak_speed, _tuning.max_speed])
		assert(_last_speed >= _tuning.max_speed * 0.9,
				"Wall Impulse debe SOSTENER max_speed en curva, no decaer (last %.2f de %.2f)"
				% [_last_speed, _tuning.max_speed])
		print("WALL IMPULSE CURVE PROBE OK")
		get_tree().quit()
	if _frames >= 900:
		assert(false, "El player nunca sostuvo el Wall Impulse sobre el muro curvo")

func _add_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = World.LAYER_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0.0, -0.5, 0.0)
	add_child(body)

## Cilindro interior hecho de segmentos rectos: la normal rota ~10 grados por segmento,
## que es exactamente el caso "pared curva" del recalculo de tangente del carril.
func _add_circle_wall() -> void:
	var segment_length := TAU * RADIUS / SEGMENTS + 0.3  # solape para no dejar ranuras
	for i in SEGMENTS:
		var angle := TAU * i / SEGMENTS
		var body := StaticBody3D.new()
		body.collision_layer = World.LAYER_WORLD
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		# Eje largo tangente al circulo; media pared de espesor hacia afuera del radio.
		box.size = Vector3(1.0, WALL_HEIGHT, segment_length)
		shape.shape = box
		body.add_child(shape)
		var surface := WallImpulseSurface.new()
		surface.tuning = _tuning
		body.add_child(surface)
		body.position = Vector3(cos(angle) * (RADIUS + 0.5), WALL_HEIGHT * 0.5 - 4.0,
				sin(angle) * (RADIUS + 0.5))
		body.rotation = Vector3(0.0, -angle, 0.0)
		add_child(body)
