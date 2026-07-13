class_name WorldMembership extends Node
## Módulo componible (ex WorldMembership.cs): decide en qué mundo está activo el dueño
## (dónde aparece / es golpeable) y le da un eco abstracto si está en el otro mundo; sigue
## desacoplado de qué le hace al mundo de los demás
## (eso es WorldSwitchTrigger). Nodo hijo del objeto/enemigo; absorbe las 4 subclases de v1.
##
##  - FIXED:   activo solo en su mundo (afiliación fija).           [enemigo por defecto]
##  - BOTH:    activo siempre, en ambos mundos.
##  - TIMED:   voltea su afiliación cada shift_interval segundos.
##  - FOLLOWS: su afiliación sigue al mundo actual (siempre activo).
##
## hide_when_inactive: si true, apaga visible + colisión del padre al quedar inactivo.
## Si false no toca visuales — solo emite changed y el dueño decide (el enemigo usa
## su propio ghost al 50%, así que lo pone en false).

signal changed(active: bool)

enum Mode { FIXED, BOTH, TIMED, FOLLOWS }

@export var mode := Mode.FIXED
@export var affiliation := World.Kind.LIVING
@export var hide_when_inactive := true
@export var shift_interval := 3.0  # solo Mode.TIMED
## Muestra humo abstracto del mundo opuesto cuando el dueño esta inactivo en el mundo actual.
@export var other_world_echo_enabled := true
## Particulas que componen el contorno de humo.
@export var other_world_echo_particle_amount := 44
## Radio del contorno de humo alrededor del dueño, en metros.
@export var other_world_echo_radius := 0.58
## Energia minima del humo y luz cuando el dueño no se mueve.
@export var other_world_echo_min_energy := 0.35
## Energia maxima, aun tenue, cuando alcanza other_world_echo_motion_speed.
@export var other_world_echo_max_energy := 0.9
## Velocidad que alcanza el brillo maximo del eco, en m/s.
@export var other_world_echo_motion_speed := 4.0
## Alcance de la luz tenue del eco, en metros.
@export var other_world_echo_light_range := 3.0

var is_active := true

var _shift_left := 0.0
var _other_world_echo_anchor: Node3D
var _other_world_echo: GPUParticles3D
var _other_world_echo_light: OmniLight3D
var _other_world_echo_material: StandardMaterial3D
var _other_world_echo_local_center := Vector3.UP * 0.9
var _echo_last_position := Vector3.ZERO
var _echo_has_last_position := false

@onready var _target := get_parent() as Node3D

func _ready() -> void:
	WorldManager.world_changed.connect(_on_world_changed)
	_shift_left = shift_interval
	call_deferred("_setup_other_world_echo")
	_on_world_changed(WorldManager.current)

## Re-evalúa la afiliación contra el mundo actual y vuelve a emitir `changed`. Lo llama
## el dueño cuando setea `affiliation` por código: su `_ready` corre DESPUÉS del de este
## módulo, así que sin esto el módulo se quedaría con la afiliación vieja (ver SpikeWall).
func refresh() -> void:
	_on_world_changed(WorldManager.current)

func _process(delta: float) -> void:
	_update_other_world_echo(delta)
	if mode != Mode.TIMED or shift_interval <= 0.0:
		return
	_shift_left -= delta
	if _shift_left > 0.0:
		return
	_shift_left = shift_interval
	affiliation = World.Kind.DEAD if affiliation == World.Kind.LIVING else World.Kind.LIVING
	_on_world_changed(WorldManager.current)

## No se voltea en el frame del switch: espera a que la onda del scan lo alcance (delay =
## distancia al origen / velocidad, ver WorldManager). Por eso el mundo destino "aparece" barrido
## por el frente en vez de todo junto. Sin onda el delay es 0 y esto es sincrónico, como antes.
func _on_world_changed(world: World.Kind) -> void:
	var delay := 0.0
	if _target != null:
		delay = WorldManager.scan_delay_for(_target.global_position)
	if delay <= 0.0:
		_apply_world(world)
		return
	var token := WorldManager.switch_count
	await get_tree().create_timer(delay).timeout
	# Mientras la onda venía en camino el mundo volvió a cambiar: esta onda quedó vieja y la
	# nueva ya trae su propio turno para este objeto.
	if WorldManager.switch_count != token or not is_instance_valid(_target):
		return
	_apply_world(world)

func _exit_tree() -> void:
	if _other_world_echo_anchor != null and is_instance_valid(_other_world_echo_anchor):
		_other_world_echo_anchor.queue_free()

## El eco se vuelve hermano del dueño en la escena, no hijo suyo: asi sigue siendo visible cuando
## hide_when_inactive apaga la estructura real. Es la misma lectura abstracta para enemigos y mundo.
func _setup_other_world_echo() -> void:
	if _target == null or not _target.is_inside_tree() or not other_world_echo_enabled:
		return
	var contour_radius := _infer_other_world_echo_shape()
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	_other_world_echo_anchor = Node3D.new()
	_other_world_echo_anchor.name = "OtherWorldEcho"
	host.add_child(_other_world_echo_anchor)

	_other_world_echo = GPUParticles3D.new()
	_other_world_echo.name = "Smoke"
	_other_world_echo.amount = other_world_echo_particle_amount
	_other_world_echo.lifetime = 1.35
	_other_world_echo.randomness = 0.55
	_other_world_echo.emitting = false
	_other_world_echo_anchor.add_child(_other_world_echo)

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	process.emission_sphere_radius = contour_radius
	process.direction = Vector3.UP
	process.spread = 38.0
	process.initial_velocity_min = 0.08
	process.initial_velocity_max = 0.35
	process.gravity = Vector3(0.0, 0.16, 0.0)
	process.damping_min = 0.08
	process.damping_max = 0.25
	process.scale_min = 0.45
	process.scale_max = 1.0
	var smoke_gradient := Gradient.new()
	smoke_gradient.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	smoke_gradient.colors = PackedColorArray([
			Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, 0.5), Color(1.0, 1.0, 1.0, 0.0),
	])
	var smoke_ramp := GradientTexture1D.new()
	smoke_ramp.gradient = smoke_gradient
	process.color_ramp = smoke_ramp
	_other_world_echo.process_material = process

	_other_world_echo_material = StandardMaterial3D.new()
	_other_world_echo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_other_world_echo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_other_world_echo_material.vertex_color_use_as_albedo = true
	_other_world_echo_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_other_world_echo_material.emission_enabled = true
	var smoke_mesh := QuadMesh.new()
	smoke_mesh.size = Vector2(0.9, 0.9)
	smoke_mesh.material = _other_world_echo_material
	_other_world_echo.draw_pass_1 = smoke_mesh

	_other_world_echo_light = OmniLight3D.new()
	_other_world_echo_light.name = "Glow"
	_other_world_echo_light.position = Vector3.UP * 0.25
	_other_world_echo_light.omni_range = other_world_echo_light_range
	_other_world_echo_light.light_indirect_energy = 0.15
	_other_world_echo_light.light_volumetric_fog_energy = 0.2
	_other_world_echo_light.visible = false
	_other_world_echo_anchor.add_child(_other_world_echo_light)
	_update_other_world_echo(0.0)

func _update_other_world_echo(delta: float) -> void:
	if _other_world_echo_anchor == null or _target == null:
		return
	_other_world_echo_anchor.global_position = _target.to_global(_other_world_echo_local_center)
	var is_other_world := other_world_echo_enabled and mode != Mode.BOTH and mode != Mode.FOLLOWS \
			and not is_active
	_other_world_echo.visible = is_other_world
	_other_world_echo.emitting = is_other_world
	_other_world_echo_light.visible = is_other_world
	if not is_other_world or _other_world_echo_material == null:
		_echo_last_position = _target.global_position
		_echo_has_last_position = true
		return
	var speed := 0.0
	if _target is CharacterBody3D:
		var character := _target as CharacterBody3D
		speed = Vector2(character.velocity.x, character.velocity.z).length()
	elif _echo_has_last_position and delta > 0.0:
		speed = Vector2(_target.global_position.x - _echo_last_position.x,
				_target.global_position.z - _echo_last_position.z).length() / delta
	_echo_last_position = _target.global_position
	_echo_has_last_position = true
	var motion := clampf(speed / maxf(0.01, other_world_echo_motion_speed), 0.0, 1.0)
	var energy := lerpf(other_world_echo_min_energy, other_world_echo_max_energy, motion)
	var color := World.world_emission(affiliation)
	_other_world_echo_material.albedo_color = color
	_other_world_echo_material.emission = color
	_other_world_echo_material.emission_energy_multiplier = energy
	_other_world_echo_light.light_color = color
	_other_world_echo_light.light_energy = energy

## Los CharacterBody suelen tener el origen en los pies y las estructuras lo tienen en su centro.
## Tomamos los meshes reales para que el humo abrace volumen visible en ambos casos.
func _infer_other_world_echo_shape() -> float:
	var radius := other_world_echo_radius
	var highest_center := _other_world_echo_local_center.y
	for node in _target.find_children("*", "MeshInstance3D", true):
		var mesh_instance := node as MeshInstance3D
		var bounds := mesh_instance.get_aabb()
		var center := _target.to_local(mesh_instance.to_global(bounds.get_center()))
		var scale := mesh_instance.global_transform.basis.get_scale()
		var horizontal_radius := maxf(bounds.size.x * absf(scale.x), bounds.size.z * absf(scale.z)) * 0.5
		radius = maxf(radius, horizontal_radius)
		highest_center = maxf(highest_center, center.y)
	_other_world_echo_local_center.y = highest_center
	return radius

func _apply_world(world: World.Kind) -> void:
	if mode == Mode.FOLLOWS:
		affiliation = world
	is_active = mode == Mode.BOTH or world == affiliation
	if hide_when_inactive:
		_apply_visibility()
	_update_other_world_echo(0.0)
	changed.emit(is_active)

func _apply_visibility() -> void:
	if _target == null:
		return
	_target.visible = is_active
	# ponytail: no tocamos la colisión de un CharacterBody3D — perdería el movimiento
	# (mismo guard que con el CharacterController en v1). Los que se ocultan no son agentes.
	if _target is CharacterBody3D:
		return
	for shape in _target.find_children("*", "CollisionShape3D", false):
		shape.set_deferred("disabled", not is_active)
