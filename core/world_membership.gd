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
## Presencia del otro mundo (enemigos, bloques, plataformas: todo dueño la hereda). Lo que está
## en el mundo opuesto NO desaparece — deja de ser sólido y pasa a leerse en dos capas:
##
##  - CONSTANTE: humo alrededor del contorno + afterimages (copias del mesh que quedan atrás
##    al moverse). Dice "acá hay algo, y va para allá".
##  - POR PULSOS: el borde del cuerpo se enciende y LATE (cáscara: interior vacío, contorno
##    encendido, ver other_world_shell.gdshader). Ese latido es el reloj de todo: cuando el
##    borde late, el humo también sube un poco de brillo (other_world_smoke_pulse_boost).
##
## hide_when_inactive: si true, apaga la colisión del padre al quedar inactivo (ya NO lo apaga
## visualmente: eso ahora lo resuelve la cáscara). Si false no la toca — el dueño decide, que es
## lo que hace el enemigo (EnemyBase maneja su collision_layer por su cuenta).

signal changed(active: bool)

enum Mode { FIXED, BOTH, TIMED, FOLLOWS }

const SHELL_SHADER: Shader = preload("res://visual/other_world_shell.gdshader")

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

# --- Cascara + latido del borde (la capa POR PULSOS) ---
# El cuerpo fuera de mundo ya no desaparece: se vacia y su contorno se enciende (ver
# other_world_shell.gdshader). Ese borde LATE, y el latido es el reloj de toda la presencia —
# el humo se le engancha (other_world_smoke_pulse_boost). No son dos efectos sueltos.
## Finura del contorno encendido: mas alto = anillo mas fino.
@export var other_world_rim_sharpness := 3.0
## Energia del borde en el VALLE del latido.
@export var other_world_rim_min_energy := 0.6
## Energia del borde en la CRESTA del latido.
@export var other_world_rim_max_energy := 2.4
## Velocidad del latido, en pulsos por segundo.
@export var other_world_pulse_speed := 0.8
## Relleno tenue del interior de la cascara. En 0 queda solo el borde.
@export var other_world_fill_energy := 0.03
## Cuanto del latido del borde se contagia al humo. En 0 el humo ignora el pulso y queda plano.
@export var other_world_smoke_pulse_boost := 0.35

# --- Afterimages (la capa CONSTANTE, junto con el humo) ---
# Copias del mesh que quedan atras al moverse. Son siluetas reconocibles: rompen a proposito la
# regla de "nada de siluetas exactas" (decision 2026-07-13) — la estela ES el dato.
## Deja estela al moverse. Cuesta un MeshInstance3D por copia; apagarlo no rompe nada.
@export var afterimages_enabled := true
## Segundos entre copia y copia mientras se mueve. Mas bajo = estela mas densa.
@export var afterimage_interval := 0.09
## Segundos que tarda una copia en apagarse del todo.
@export var afterimage_lifetime := 0.45
## Velocidad minima para dejar estela, en m/s. Debajo de esto no deja nada (un fantasma quieto
## no arrastra nada).
@export var afterimage_min_speed := 1.5
## Energia del borde de una copia recien nacida. De ahi baja a cero durante su vida.
@export var afterimage_rim_energy := 1.6

var is_active := true

var _shift_left := 0.0
var _other_world_echo_anchor: Node3D
var _other_world_echo: GPUParticles3D
var _other_world_echo_light: OmniLight3D
var _other_world_echo_material: StandardMaterial3D
var _other_world_echo_local_center := Vector3.UP * 0.9
var _echo_last_position := Vector3.ZERO
var _echo_has_last_position := false
var _shell_meshes: Array[MeshInstance3D] = []
var _shell_materials: Array[ShaderMaterial] = []
var _shell_on := false
var _pulse := 0.0  # 0..1: la onda del latido, compartida por el borde y el humo
var _afterimage_host: Node3D
var _afterimage_next_at := 0.0

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
	if _afterimage_host != null and is_instance_valid(_afterimage_host):
		_afterimage_host.queue_free()

## ¿El dueño esta mostrandose como cascara (vacio, contorno encendido) ahora mismo?
func is_shell_active() -> bool:
	return _shell_on

## Prepara una ShaderMaterial de cascara por cada mesh del dueño. No se aplica todavia: vive en
## `material_override`, que PISA el material real sin destruirlo — al volver a este mundo se pone
## en null y el objeto recupera su look intacto (incluido el color que EnemyBase pinta por su
## cuenta en `surface_override_material`, que ocupa otro slot y no se toca).
func _setup_shell() -> void:
	if _target == null:
		return
	for node in _target.find_children("*", "MeshInstance3D", true):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var material := ShaderMaterial.new()
		material.shader = SHELL_SHADER
		_shell_meshes.append(mesh)
		_shell_materials.append(material)

func _set_shell_active(on: bool) -> void:
	if on == _shell_on:
		return
	_shell_on = on
	for i in _shell_meshes.size():
		var mesh := _shell_meshes[i]
		if is_instance_valid(mesh):
			mesh.material_override = _shell_materials[i] if on else null

## El latido del borde. Es el reloj de toda la presencia: esta misma onda tambien empuja el humo.
func _update_shell(color: Color) -> void:
	_pulse = 0.5 + 0.5 * sin(World.now() * other_world_pulse_speed * TAU)
	var rim_energy := lerpf(other_world_rim_min_energy, other_world_rim_max_energy, _pulse)
	for material in _shell_materials:
		material.set_shader_parameter("rim_color", color)
		material.set_shader_parameter("rim_energy", rim_energy)
		material.set_shader_parameter("rim_sharpness", other_world_rim_sharpness)
		material.set_shader_parameter("fill_energy", other_world_fill_energy)

## Estela: copias del mesh que quedan CLAVADAS donde pasó el cuerpo (por eso cuelgan de un host
## fijo en la escena y no del dueño — si fueran hijas suyas lo seguirian y no habria estela).
## Cada copia nace con el borde encendido y se apaga sola; al llegar a cero se libera.
func _spawn_afterimage(color: Color) -> void:
	if _afterimage_host == null:
		return
	for mesh in _shell_meshes:
		if not is_instance_valid(mesh) or not mesh.is_visible_in_tree():
			continue
		var material := ShaderMaterial.new()
		material.shader = SHELL_SHADER
		material.set_shader_parameter("rim_color", color)
		material.set_shader_parameter("rim_energy", afterimage_rim_energy)
		material.set_shader_parameter("rim_sharpness", other_world_rim_sharpness)
		material.set_shader_parameter("fill_energy", 0.0)  # la estela es contorno puro
		var ghost := MeshInstance3D.new()
		ghost.mesh = mesh.mesh
		ghost.material_override = material
		_afterimage_host.add_child(ghost)
		ghost.global_transform = mesh.global_transform  # despues de entrar al arbol
		var fade := ghost.create_tween()
		fade.tween_property(material, "shader_parameter/rim_energy", 0.0, afterimage_lifetime)
		fade.tween_callback(ghost.queue_free)

## El eco se vuelve hermano del dueño en la escena, no hijo suyo: asi sigue siendo visible cuando
## hide_when_inactive apaga la estructura real. Es la misma lectura abstracta para enemigos y mundo.
func _setup_other_world_echo() -> void:
	if _target == null or not _target.is_inside_tree() or not other_world_echo_enabled:
		return
	var contour_radius := _infer_other_world_echo_shape()
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	_setup_shell()
	# Las copias de la estela quedan clavadas donde nacieron, asi que necesitan un host que NO
	# siga al dueño (el ancla del humo si lo sigue).
	_afterimage_host = Node3D.new()
	_afterimage_host.name = "OtherWorldAfterimages"
	host.add_child(_afterimage_host)
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

## Las dos capas de la presencia del otro mundo:
##   CONSTANTE — humo (siempre que este fuera de mundo) + afterimages (solo si se mueve).
##   POR PULSOS — el borde de la cascara late, y ese mismo latido le sube un poco el brillo al
##                humo (other_world_smoke_pulse_boost). El pulso manda; el humo lo acompaña.
func _update_other_world_echo(delta: float) -> void:
	if _other_world_echo_anchor == null or _target == null:
		return
	_other_world_echo_anchor.global_position = _target.to_global(_other_world_echo_local_center)
	var is_other_world := other_world_echo_enabled and mode != Mode.BOTH and mode != Mode.FOLLOWS \
			and not is_active
	_other_world_echo.visible = is_other_world
	_other_world_echo.emitting = is_other_world
	_other_world_echo_light.visible = is_other_world
	_set_shell_active(is_other_world)
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
	var color := World.world_emission(affiliation)

	_update_shell(color)  # escribe _pulse: el reloj del que cuelga todo lo de abajo

	var motion := clampf(speed / maxf(0.01, other_world_echo_motion_speed), 0.0, 1.0)
	# El humo respira con el latido del borde en vez de quedarse plano.
	var energy := lerpf(other_world_echo_min_energy, other_world_echo_max_energy, motion) \
			+ _pulse * other_world_smoke_pulse_boost
	_other_world_echo_material.albedo_color = color
	_other_world_echo_material.emission = color
	_other_world_echo_material.emission_energy_multiplier = energy
	_other_world_echo_light.light_color = color
	_other_world_echo_light.light_energy = energy

	if afterimages_enabled and speed >= afterimage_min_speed and World.now() >= _afterimage_next_at:
		_afterimage_next_at = World.now() + afterimage_interval
		_spawn_afterimage(color)

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
	# El cuerpo fuera de mundo YA NO desaparece: se queda visible y se VACIA en una cascara de
	# contorno encendido (ver _set_shell_active). Solo se esconde de verdad si el eco esta apagado,
	# porque ahi no hay cascara que mostrar y dejarlo solido lo confundiria con algo golpeable.
	_target.visible = is_active or other_world_echo_enabled
	# ponytail: no tocamos la colisión de un CharacterBody3D — perdería el movimiento
	# (mismo guard que con el CharacterController en v1). Los que se ocultan no son agentes.
	if _target is CharacterBody3D:
		return
	for shape in _target.find_children("*", "CollisionShape3D", false):
		shape.set_deferred("disabled", not is_active)
