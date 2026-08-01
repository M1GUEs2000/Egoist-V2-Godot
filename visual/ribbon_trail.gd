class_name RibbonTrail extends MeshInstance3D
## Cinta procedural generica en espacio de mundo. Muestrea dos markers y reconstruye una tira de
## triangulos; la cola queda dibujada donde paso el dueño aun despues de que este se mueva.

@export var tuning: RibbonTrailTuning
@export var base_marker: NodePath
@export var tip_marker: NodePath
@export var shader: Shader = preload("res://visual/sword_trail.gdshader")

var _emitting := false
var _time := 0.0
var _base := PackedVector3Array()
var _tip := PackedVector3Array()
var _born := PackedFloat32Array()
var _immediate: ImmediateMesh
var _material: ShaderMaterial
var _base_node: Node3D
var _tip_node: Node3D

func _ready() -> void:
	_immediate = ImmediateMesh.new()
	mesh = _immediate
	top_level = true
	transform = Transform3D.IDENTITY
	_base_node = get_node_or_null(base_marker) as Node3D
	_tip_node = get_node_or_null(tip_marker) as Node3D
	if _base_node == null or _tip_node == null:
		push_warning("%s no resolvio sus markers: la cinta queda apagada." % name)
	_build_material()
	set_process(false)

func _process(delta: float) -> void:
	_time += delta
	if _emitting:
		_sample()
	_expire()
	_rebuild()
	if not _emitting and _born.is_empty():
		set_process(false)

## Inicia una cinta nueva. Limpia la anterior para no tender una banda entre dos usos separados.
func emit() -> void:
	if tuning == null or _base_node == null or _tip_node == null:
		return
	_clear()
	_emitting = true
	set_process(true)

## Detiene solo el muestreo; la cola existente se disuelve por lifetime.
func stop() -> void:
	_emitting = false

func is_emitting() -> bool:
	return _emitting

## Tinte runtime para feedback dependiente de estado (p. ej. nivel de sprint).
func set_tint(color: Color) -> void:
	if _material != null:
		_material.set_shader_parameter(&"tint", color)

func _sample() -> void:
	var base_point := _base_node.global_position
	var tip_point := _tip_node.global_position
	if not _born.is_empty():
		var last := _base.size() - 1
		var travelled := base_point.distance_to(_base[last])
		if travelled > tuning.max_segment_length:
			_clear()
		elif travelled < tuning.min_sample_distance:
			_base[last] = base_point
			_tip[last] = tip_point
			_born[last] = _time
			return
	_base.append(base_point)
	_tip.append(tip_point)
	_born.append(_time)

func _expire() -> void:
	var dead := 0
	while dead < _born.size() and _time - _born[dead] > tuning.lifetime:
		dead += 1
	if dead == 0:
		return
	_base = _base.slice(dead)
	_tip = _tip.slice(dead)
	_born = _born.slice(dead)

func _rebuild() -> void:
	_immediate.clear_surfaces()
	if _born.size() < 2:
		return
	_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _material)
	for i in _born.size():
		var age := clampf((_time - _born[i]) / tuning.lifetime, 0.0, 1.0)
		_immediate.surface_set_uv(Vector2(age, 0.0))
		_immediate.surface_add_vertex(_base[i])
		_immediate.surface_set_uv(Vector2(age, 1.0))
		_immediate.surface_add_vertex(_tip[i])
	_immediate.surface_end()

func _clear() -> void:
	_base.clear()
	_tip.clear()
	_born.clear()

func _build_material() -> void:
	if tuning == null or shader == null:
		return
	_material = ShaderMaterial.new()
	_material.shader = shader
	if tuning.gradient != null:
		var ramp := GradientTexture1D.new()
		ramp.gradient = tuning.gradient
		_material.set_shader_parameter(&"gradient", ramp)
	_material.set_shader_parameter(&"erosion_noise", tuning.erosion_noise)
	_material.set_shader_parameter(&"erosion_scale", tuning.erosion_scale)
	_material.set_shader_parameter(&"erosion_scroll", tuning.erosion_scroll)
	_material.set_shader_parameter(&"erosion_strength", tuning.erosion_strength)
	_material.set_shader_parameter(&"erosion_softness", tuning.erosion_softness)
	_material.set_shader_parameter(&"base_fade", tuning.base_fade)
	_material.set_shader_parameter(&"brightness", tuning.brightness)
	_material.set_shader_parameter(&"tint", Color.WHITE)
