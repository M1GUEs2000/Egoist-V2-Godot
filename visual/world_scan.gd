class_name WorldScan extends Node3D
## Visual de la onda del cambio de mundo: una cáscara esférica que nace en el trigger y crece,
## con trama de polígonos y el filo encendido, en el color del mundo DESTINO (morado = muerto,
## naranja = vivo). Al mismo tiempo una OmniLight viaja con el frente para que la onda ilumine
## de verdad el entorno, no solo se dibuje encima.
##
## Es solo la parte que se VE. Quién se voltea y cuándo lo decide WorldManager.scan_delay_for()
## con los mismos números (data/world_scan_tuning.tres), así que la cáscara y la aparición de las
## cosas van siempre juntas: lo que la onda toca, aparece.
##
## Se pone una sola vez por escena (un Node3D con este script). Se posiciona sola en cada switch.

const SHADER := preload("res://visual/world_scan.gdshader")

var _tuning: WorldScanTuning
var _material: ShaderMaterial
var _mesh: MeshInstance3D
var _light: OmniLight3D
var _elapsed := 0.0

func _ready() -> void:
	_tuning = WorldManager.tuning
	_build()
	_hide()
	WorldManager.scan_started.connect(_on_scan_started)

func _build() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER

	var sphere := SphereMesh.new()
	# Radio 1: el radio real de la onda es la escala del nodo. Segmentos bajos a propósito —
	# la silueta facetada es parte del look de scan.
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

	_light = OmniLight3D.new()
	_light.shadow_enabled = false
	add_child(_light)

func _on_scan_started(world: World.Kind, origin: Vector3) -> void:
	if _tuning.speed <= 0.0:
		return  # sin onda: el mundo cambió de golpe, no hay nada que dibujar
	global_position = origin
	var color := World.world_emission(world)
	_material.set_shader_parameter("scan_color", color)
	_material.set_shader_parameter("rim_power", _tuning.rim_power)
	_material.set_shader_parameter("grid_density", _tuning.grid_density)
	_material.set_shader_parameter("grid_width", _tuning.grid_width)
	_material.set_shader_parameter("grid_mix", _tuning.grid_mix)
	_light.light_color = color
	_elapsed = 0.0
	visible = true
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	var travel := _tuning.max_radius / _tuning.speed  # cuánto tarda el frente en llegar al final
	var radius := minf(_tuning.speed * _elapsed, _tuning.max_radius)
	# Mientras viaja va a full; una vez que llegó al radio máximo se apaga en fade_out segundos.
	var brightness := 1.0
	if _elapsed > travel:
		if _tuning.fade_out <= 0.0:
			_hide()
			return
		brightness = 1.0 - (_elapsed - travel) / _tuning.fade_out
		if brightness <= 0.0:
			_hide()
			return
	# Escala la esfera, NO el nodo raíz: el alcance de la OmniLight también se escalaría con el
	# transform y quedaría atado al radio dos veces.
	_mesh.scale = Vector3.ONE * maxf(radius, 0.01)
	_material.set_shader_parameter("energy", _tuning.energy * brightness)
	_material.set_shader_parameter("alpha_scale", _tuning.alpha * brightness)
	_light.light_energy = _tuning.light_energy * brightness
	_light.omni_range = radius * _tuning.light_range_scale

func _hide() -> void:
	visible = false
	set_process(false)
