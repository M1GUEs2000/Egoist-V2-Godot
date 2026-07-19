@tool
class_name TraversalBlock extends Node3D
## Bloque componible de traversal. Cada instancia activa una o varias funciones por export.
## @tool solo para previsualizar en el viewport del editor la flecha del dash verde y la
## trayectoria completa de dash/launch; el gameplay corre normal (ver la guarda
## `Engine.is_editor_hint()` en `_ready` y `_process`).

@export var tuning: TraversalBlockTuning

@export_group("Caracteristicas")
## Al togglearlo en el editor, la parabola de preview (roja) aparece/desaparece en el viewport.
@export var enable_launch := false:
	set(value):
		enable_launch = value
		if Engine.is_editor_hint() and is_node_ready():
			_refresh_editor_previews()
## Al togglearlo en el editor, la flecha y la trayectoria de preview (verde) aparecen/desaparecen.
@export var enable_dash := false:
	set(value):
		enable_dash = value
		if Engine.is_editor_hint() and is_node_ready():
			_refresh_editor_previews()
@export var enable_meter := false
@export var enable_action_curse := false
@export var enable_world_switch := false

@export_group("Launch / bump")
@export var horizontal_speed := 15.0:
	set(value):
		horizontal_speed = value
		if Engine.is_editor_hint() and is_node_ready():
			_refresh_editor_previews()
@export var vertical_speed := 20.0:
	set(value):
		vertical_speed = value
		if Engine.is_editor_hint() and is_node_ready():
			_refresh_editor_previews()

@export_group("Dash")
@export var dash_distance := 4.0:
	set(value):
		dash_distance = value
		if Engine.is_editor_hint() and is_node_ready():
			_refresh_editor_previews()
@export var dash_duration := 0.12
## Empujon horizontal extra al salir, en la proyeccion de la flecha. 0 = sin empujon.
@export var dash_bop_forward_speed := 4.0:
	set(value):
		dash_bop_forward_speed = value
		if Engine.is_editor_hint() and is_node_ready():
			_refresh_editor_previews()
## Pequeno impulso vertical que queda al terminar el dash. 0 = sin rebote.
@export var dash_vertical_bop_speed := 4.0:
	set(value):
		dash_vertical_bop_speed = value
		if Engine.is_editor_hint() and is_node_ready():
			_refresh_editor_previews()
@export var boost_existing_bump_momentum := false
## Si el dash forzado por el bloque verde prende el DashHitbox del player y daña al atravesar.
@export var dash_deals_damage := true
@export var hit_cooldown := 0.1

@export_group("Meter")
@export var meter_bars := 1.0

@export_group("Rotura")
## 0 = indestructible; >0 = cantidad de golpes antes de romperse.
@export var hits_to_break := 0

const INDESTRUCTIBLE_HEALTH := 999999.0

var _last_dash_hit_time := -999.0
var _segment_materials: Array[StandardMaterial3D] = []
var _light: OmniLight3D
var _down_lights: Array[SpotLight3D] = []
var _down_particles: Array[GPUParticles3D] = []
var _down_particle_materials: Array[StandardMaterial3D] = []
var _dash_arrow: Node3D
var _dash_trajectory: Node3D
var _launch_trajectory: Node3D

@onready var _health: Health = $Health
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _break_on_death: BreakOnDeath = $BreakOnDeath
@onready var _glow_segments: Node3D = $GlowSegments

func _ready() -> void:
	if tuning == null:
		tuning = TraversalBlockTuning.new()
	if Engine.is_editor_hint():
		# En el editor solo dibujamos los previews (flecha + trayectorias); nada de wiring de
		# gameplay (Health, Hurtbox, WorldManager) que en modo @tool no tiene sentido y romperia.
		# Las trayectorias se hornean en espacio global (top_level), asi que necesitan
		# reconstruirse cuando el bloque se mueve o rota en el editor, no solo al tocar un
		# export: sin esto quedaban congeladas en la posicion de cuando se instancio el bloque.
		set_notify_transform(true)
		_refresh_editor_previews()
		return
	_configure_health()
	_hurtbox.hit.connect(_on_hit)
	_health.died.connect(_on_died)
	WorldManager.world_changed.connect(_on_world_changed)
	_setup_light()
	_rebuild_glow_segments()
	_update_glow()
	if enable_dash:
		_build_dash_arrow()
		add_to_group("arm_dash_target")  # PlayerArm me encuentra por acá para el lock-on de traversal

## Luz real (no solo emision del material) para que el bloque ilumine el entorno.
## El color y el encendido se ajustan en _repaint_segments y _update_glow.
func _setup_light() -> void:
	_light = OmniLight3D.new()
	_light.position = Vector3(0.0, 0.55, 0.0)  # centro del cuerpo del bloque
	_light.shadow_enabled = false
	add_child(_light)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_update_glow()

## set_notify_transform(true) en _ready pide este aviso cuando el bloque se mueve/rota en el
## editor (gizmo o inspector). Las trayectorias estan horneadas en global, asi que sin esto se
## quedaban pegadas en la posicion vieja hasta cerrar y reabrir la escena.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint() and is_node_ready():
		_refresh_editor_previews()

func _configure_health() -> void:
	if hits_to_break > 0:
		_health.set_max(float(hits_to_break))
		_break_on_death.free_owner = true
	else:
		_health.set_max(INDESTRUCTIBLE_HEALTH)
		_break_on_death.free_owner = false

func _on_hit(from: Node, _damage: float) -> void:
	_burst_impact()  # estallido de color en cada golpe, aunque este sea el golpe que lo rompe
	activate(from)

## Dispara todas las features activas del bloque sobre quien lo activa. Mismo efecto sea por
## golpe de arma (`_hurtbox.hit` -> `_on_hit`) o por el Brazo, que teletransporta al jugador
## encima del bloque de dash marcado y activa directo, sin pegarle (ver PlayerArm).
func activate(from: Node) -> void:
	if enable_world_switch:
		WorldManager.switch_world(global_position)  # la onda del scan nace en el bloque activado
	var player := _resolve_player(from)
	if player == null:
		return
	if enable_launch:
		_apply_launch(player)
	if enable_dash:
		_apply_dash(player)
	if enable_meter and player.meter != null:
		player.meter.gain_bars(meter_bars)

func _on_died() -> void:
	if not enable_action_curse:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.activate_action_world_switch()

func _on_world_changed(_world: World.Kind) -> void:
	_repaint_segments()

func _resolve_player(from: Node) -> Player:
	var player := from as Player
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	return player

func _apply_launch(player: Player) -> void:
	var dir := player.locomotion.last_move_dir
	if dir.length_squared() < 0.0001:
		dir = player.forward()
	player.bump(dir, horizontal_speed, vertical_speed)
	player.restore_double_jump()
	player.restore_airdash()

## Empuja siempre hacia la cara -Z del bloque (misma convencion que Player.forward()), sin
## importar por donde llego el jugador: rotarlo en el editor cambia el rumbo, incluida Y.
func _apply_dash(player: Player) -> void:
	if World.now() - _last_dash_hit_time < hit_cooldown:
		return
	_last_dash_hit_time = World.now()
	var dash_dir := -global_transform.basis.z
	player.force_dash(dash_dir, dash_distance, dash_duration,
			boost_existing_bump_momentum, dash_deals_damage)
	# El dash conserva la inclinacion; el bop se aplica solo cuando termina.
	player.set_dash_exit_bop(dash_dir, dash_bop_forward_speed, dash_vertical_bop_speed)

## Estallido de motas al recibir un golpe: una explosion one-shot por feature, cada una del
## color puro de esa feature (mismo criterio que el derrame hacia abajo).
func _burst_impact() -> void:
	if not tuning.burst_enabled or tuning.burst_amount <= 0:
		return
	var colors := _feature_colors()
	var emissions := _feature_emissions()
	for i in range(mini(colors.size(), emissions.size())):
		_spawn_burst(colors[i], emissions[i])

## Un estallido del centro del bloque, colgado del PADRE (no de self): si el golpe rompe el
## bloque (BreakOnDeath), la explosion sobrevive hasta apagarse.
func _spawn_burst(color: Color, emission: Color) -> void:
	var host := get_parent()
	if host == null:
		host = self
	World.spawn_color_burst(host, global_position + Vector3(0.0, 0.55, 0.0), color, emission,
			tuning.burst_amount, tuning.burst_speed, tuning.burst_gravity,
			tuning.burst_lifetime, tuning.burst_size)

func _rebuild_glow_segments() -> void:
	for child in _glow_segments.get_children():
		child.queue_free()
	_segment_materials.clear()
	var colors := _feature_colors()
	if colors.is_empty():
		return
	var count := colors.size()
	for i in range(count):
		var segment := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		# Cada segmento cubre TODO el alto/fondo del bloque y una fraccion del ancho, para
		# que se prenda el bloque entero (no solo una franja arriba). 1.02 = un pelin mas
		# grande que el cuerpo (1x1) para envolverlo sin z-fighting.
		mesh.size = Vector3(1.02 / float(count), 1.02, 1.02)
		segment.mesh = mesh
		# Tileado a lo ancho en x; y=0.55 = centro del cuerpo del bloque (Mesh del .tscn).
		segment.position = Vector3(_segment_x(i, count), 0.55, 0.0)
		var material := StandardMaterial3D.new()
		material.emission_enabled = true
		segment.set_surface_override_material(0, material)
		_glow_segments.add_child(segment)
		_segment_materials.append(material)
	_rebuild_down_emitters(count)
	_repaint_segments()

## Centro en x del segmento i, con el bloque partido en `count` franjas iguales.
func _segment_x(i: int, count: int) -> float:
	return -0.51 + (float(i) + 0.5) * 1.02 / float(count)

## Derrame hacia abajo: un cono de luz + una columna de particulas POR FEATURE, alineados con
## la franja de color que le toca en el cuerpo. Asi el bloque marca el piso debajo y se lee
## desde lejos, incluso flotando. La OmniLight del centro sigue existiendo aparte.
func _rebuild_down_emitters(count: int) -> void:
	for light in _down_lights:
		light.queue_free()
	for particles in _down_particles:
		particles.queue_free()
	_down_lights.clear()
	_down_particles.clear()
	_down_particle_materials.clear()
	if count == 0:
		return
	var width := 1.02 / float(count)
	for i in range(count):
		var x := _segment_x(i, count)
		_down_lights.append(_make_down_light(x))
		if tuning.particles_enabled and tuning.particle_amount > 0:
			_down_particles.append(_make_down_particles(x, width))

func _make_down_light(x: float) -> SpotLight3D:
	var light := SpotLight3D.new()
	# Justo debajo del cuerpo (que va de y=0.04 a y=1.06), mirando al piso.
	light.position = Vector3(x, 0.0, 0.0)
	light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	light.shadow_enabled = false
	light.spot_range = tuning.down_light_range
	light.spot_angle = tuning.down_light_angle_degrees
	add_child(light)
	return light

func _make_down_particles(x: float, width: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.position = Vector3(x, 0.0, 0.0)
	particles.amount = tuning.particle_amount
	particles.lifetime = tuning.particle_lifetime
	particles.local_coords = false  # las motas quedan atras si el bloque se mueve

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(width * 0.5, 0.01, 0.5)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 0.0
	process.gravity = Vector3(0.0, -tuning.particle_fall_speed, 0.0)
	process.initial_velocity_min = tuning.particle_fall_speed * 0.2
	process.initial_velocity_max = tuning.particle_fall_speed * 0.5
	process.scale_min = 0.6
	process.scale_max = 1.0
	particles.process_material = process

	var mesh := QuadMesh.new()
	mesh.size = Vector2(tuning.particle_size, tuning.particle_size)
	particles.draw_pass_1 = mesh

	# Unshaded + billboard + additive: la mota es puro color, siempre mira a la camara y suma
	# luz en vez de taparla. El color lo pone _repaint_down_emitters.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.emission_enabled = true
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	_down_particle_materials.append(material)

	add_child(particles)
	return particles

func _repaint_segments() -> void:
	var colors := _feature_colors()
	var emissions := _feature_emissions()
	for i in range(mini(_segment_materials.size(), colors.size())):
		var material := _segment_materials[i]
		# Albedo apagado: de lejos el segmento se ve tenue (se distingue el color, pero
		# está "apagado"). El encendido lo lleva la emisión, que sube por proximidad en
		# _update_glow. Si el albedo llevara el color pleno, el sol lo iluminaría al 100%
		# siempre y el "prende al acercarse" no se notaría.
		material.albedo_color = colors[i].darkened(0.8)
		material.emission = emissions[i]
	_repaint_light(colors)
	_repaint_down_emitters(colors, emissions)

## Cada cono y cada columna de particulas lleva el color PURO de su feature (no el promedio
## que usa la omni): el derrame del piso es lo que dice de que tipo es el bloque.
func _repaint_down_emitters(colors: Array[Color], emissions: Array[Color]) -> void:
	for i in range(mini(_down_lights.size(), colors.size())):
		var light := _down_lights[i]
		light.light_color = colors[i]
		light.spot_range = tuning.down_light_range
		light.spot_angle = tuning.down_light_angle_degrees
	for i in range(mini(_down_particle_materials.size(), emissions.size())):
		var material := _down_particle_materials[i]
		material.albedo_color = colors[i]
		material.emission = emissions[i]

## Tiñe la luz con el promedio de los colores de las features (una sola luz por bloque,
## aunque tenga varias features). Sin features no hay luz.
func _repaint_light(colors: Array[Color]) -> void:
	if _light == null:
		return
	if colors.is_empty():
		_light.visible = false
		return
	_light.visible = true
	var blended := Color(0.0, 0.0, 0.0)
	for color in colors:
		blended += color
	_light.light_color = blended / float(colors.size())
	_light.omni_range = tuning.light_range

## Preview del viewport (solo editor): reconstruye flecha + trayectorias cuando cambia una
## feature o un knob que las afecta, para tunear sin entrar a jugar. En runtime nada de esto
## se arma (ver _ready).
func _refresh_editor_previews() -> void:
	if tuning == null:
		tuning = TraversalBlockTuning.new()
	if _dash_arrow != null:
		_dash_arrow.queue_free()
		_dash_arrow = null
	if _dash_trajectory != null:
		_dash_trajectory.queue_free()
		_dash_trajectory = null
	if _launch_trajectory != null:
		_launch_trajectory.queue_free()
		_launch_trajectory = null
	if enable_dash:
		_build_dash_arrow()
		_build_dash_trajectory()
	if enable_launch:
		_build_launch_trajectory()

## Cono + vara semitransparente pegada a la cara -Z del bloque: marca hacia donde empuja el
## dash sin depender de por donde llegue el jugador. Vive fija en local; rotar el TraversalBlock
## en el editor la mueve junto con el empuje real (ver _apply_dash).
func _build_dash_arrow() -> void:
	_dash_arrow = Node3D.new()
	add_child(_dash_arrow)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(World.COLOR_TRAVERSAL_DASH, tuning.arrow_alpha)
	material.emission_enabled = true
	material.emission = World.COLOR_TRAVERSAL_DASH_EMISSION
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# CylinderMesh nace con el largo en +Y local; -90 en X lo acuesta apuntando a -Z (la misma
	# cara que usa _apply_dash / Player.forward()).
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = tuning.arrow_shaft_radius
	shaft_mesh.bottom_radius = tuning.arrow_shaft_radius
	shaft_mesh.height = tuning.arrow_shaft_length
	shaft.mesh = shaft_mesh
	shaft.set_surface_override_material(0, material)
	shaft.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	shaft.position = Vector3(0.0, 0.55, -0.5 - tuning.arrow_shaft_length * 0.5)
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dash_arrow.add_child(shaft)

	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.bottom_radius = tuning.arrow_head_radius  # base ancha, pegada a la vara
	head_mesh.top_radius = 0.0                          # punta, apuntando lejos del bloque
	head_mesh.height = tuning.arrow_head_length
	head.mesh = head_mesh
	head.set_surface_override_material(0, material)
	head.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	head.position = Vector3(0.0, 0.55,
			-0.5 - tuning.arrow_shaft_length - tuning.arrow_head_length * 0.5)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dash_arrow.add_child(head)

## Trayectoria completa del dash verde: tramo recto (dash_distance por la cara -Z del bloque,
## con su inclinacion si esta rotado) seguido del arco balistico del bop de salida, si tiene
## velocidad. Mismo origen y direccion que _apply_dash / _build_dash_arrow: to_global() en vez
## de sumar un offset fijo en global_position, para que respete la escala del bloque (varios
## bloques de la escena estan escalados 2x-5x; sumar un offset plano los desalineaba del todo).
func _build_dash_trajectory() -> void:
	var origin := to_global(Vector3(0.0, 0.55, -0.5))
	var dash_dir := (-global_transform.basis.z).normalized()
	var dash_end := origin + dash_dir * dash_distance
	var points := PackedVector3Array([origin, dash_end])
	# El bop de salida solo empuja horizontal (ver Player.set_exit_bop): se pierde la
	# inclinacion del dash en ese tramo, igual que en gameplay real.
	var bop_horizontal := Vector3(dash_dir.x, 0.0, dash_dir.z)
	var bop_dir := bop_horizontal.normalized() if bop_horizontal.length_squared() > 0.0001 else Vector3.ZERO
	points.append_array(_sample_ballistic_arc(dash_end, bop_dir, dash_bop_forward_speed, dash_vertical_bop_speed))
	_dash_trajectory = _build_trajectory_tube(points, World.COLOR_TRAVERSAL_DASH, World.COLOR_TRAVERSAL_DASH_EMISSION)

## Trayectoria completa del launch/bump: parabola balistica desde horizontal_speed/vertical_speed.
## La direccion real en gameplay depende del input del jugador (last_move_dir); el preview asume
## fija la cara -Z del bloque, la misma convencion que ya usa el dash, solo para poder dibujar
## algo util en el editor.
func _build_launch_trajectory() -> void:
	var origin := to_global(Vector3(0.0, 0.55, 0.0))
	var forward := -global_transform.basis.z
	var horizontal_dir := Vector3(forward.x, 0.0, forward.z)
	if horizontal_dir.length_squared() < 0.0001:
		horizontal_dir = Vector3.FORWARD
	else:
		horizontal_dir = horizontal_dir.normalized()
	var points := PackedVector3Array([origin])
	points.append_array(_sample_ballistic_arc(origin, horizontal_dir, horizontal_speed, vertical_speed))
	_launch_trajectory = _build_trajectory_tube(points, World.COLOR_TRAVERSAL_LAUNCH, World.COLOR_TRAVERSAL_LAUNCH_EMISSION)

## Muestrea una parabola balistica desde `start` hasta que vuelve a esa altura, leyendo gravedad
## y frenado de momentum en vivo de tuning.player_tuning (ver _trajectory_gravity /
## _trajectory_horizontal_decay). No incluye el punto inicial (el llamador ya lo tiene). Sin
## impulso vertical o sin PlayerTuning asignado no hay forma de cerrar la parabola, asi que no
## dibuja nada.
func _sample_ballistic_arc(start: Vector3, horizontal_dir: Vector3, h_speed: float, v_speed: float) -> PackedVector3Array:
	var points := PackedVector3Array()
	var gravity := _trajectory_gravity()
	if gravity >= 0.0 or v_speed <= 0.0:
		return points
	var t_total := -2.0 * v_speed / gravity
	var segments := maxi(tuning.trajectory_segments, 1)
	for i in range(1, segments + 1):
		var t := t_total * float(i) / float(segments)
		var vertical := v_speed * t + 0.5 * gravity * t * t
		var offset := horizontal_dir * _horizontal_distance(h_speed, t) + Vector3(0.0, vertical, 0.0)
		points.append(start + offset)
	return points

## Distancia horizontal recorrida en `t` segundos con velocidad inicial `h_speed` que frena
## linealmente a _trajectory_horizontal_decay() m/s^2 (integra Player._bleed_momentum, que usa
## move_toward: la velocidad baja pareja hasta 0 y se queda ahi, nunca reversa).
func _horizontal_distance(h_speed: float, t: float) -> float:
	var decay := _trajectory_horizontal_decay()
	if decay <= 0.0:
		return h_speed * t
	var t_stop := h_speed / decay
	if t <= t_stop:
		return h_speed * t - 0.5 * decay * t * t
	return h_speed * t_stop - 0.5 * decay * t_stop * t_stop

## 0.0 (parabola degenerada, _sample_ballistic_arc no dibuja nada) si no hay PlayerTuning
## asignado en tuning.player_tuning.
func _trajectory_gravity() -> float:
	if tuning.player_tuning == null:
		return 0.0
	return tuning.player_tuning.gravity

## Mismo calculo que Player._bleed_momentum en el aire: move_speed / momentum_bleed_seconds_per_unit
## da el rate base, escalado por momentum_bleed_air (siempre airborne durante el arco).
func _trajectory_horizontal_decay() -> float:
	var t := tuning.player_tuning
	if t == null:
		return 0.0
	var rate := t.move_speed / maxf(0.001, t.momentum_bleed_seconds_per_unit)
	return rate * t.momentum_bleed_air

## Tubo generico para dibujar una polilinea 3D en el viewport del editor: un CylinderMesh por
## segmento, mismo patron que _build_dash_arrow. `top_level = true` porque los puntos ya vienen
## en espacio global (no hay que heredar la rotacion del bloque de nuevo).
func _build_trajectory_tube(points: PackedVector3Array, color: Color, emission: Color) -> Node3D:
	var container := Node3D.new()
	add_child(container)
	container.top_level = true
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, tuning.trajectory_alpha)
	material.emission_enabled = true
	material.emission = emission
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var segment_dir := b - a
		var length := segment_dir.length()
		if length < 0.001:
			continue
		var segment := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = tuning.trajectory_line_radius
		mesh.bottom_radius = tuning.trajectory_line_radius
		mesh.height = length
		segment.mesh = mesh
		segment.set_surface_override_material(0, material)
		segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(segment)
		segment.global_transform = Transform3D(
				Basis(Quaternion(Vector3.UP, segment_dir.normalized())), a + segment_dir * 0.5)
	return container

func _update_glow() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var proximity := 0.0
	if player != null and tuning.proximity_radius > 0.0:
		var distance := global_position.distance_to(player.global_position)
		proximity = clampf(1.0 - distance / tuning.proximity_radius, 0.0, 1.0)
	var energy := lerpf(tuning.glow_min_energy, tuning.glow_max_energy, proximity)
	for material in _segment_materials:
		material.emission_energy_multiplier = energy
	# La luz real sigue la misma proximidad: apagada de lejos, prende al acercarse.
	if _light != null:
		_light.light_energy = lerpf(0.0, tuning.light_energy_max, proximity)
	# El derrame hacia abajo sigue la MISMA proximidad que la emision y la omni: apagado de
	# lejos, prende al acercarse. Las particulas dejan de emitir fuera del radio para no
	# pagar simulacion de bloques que el jugador ni ve.
	var down_energy := lerpf(tuning.down_light_min_energy, tuning.down_light_max_energy, proximity)
	for light in _down_lights:
		light.light_energy = down_energy
	for material in _down_particle_materials:
		material.emission_energy_multiplier = energy
	var emitting := proximity > 0.0
	for particles in _down_particles:
		particles.emitting = emitting

func _feature_colors() -> Array[Color]:
	var colors: Array[Color] = []
	if enable_launch:
		colors.append(World.COLOR_TRAVERSAL_LAUNCH)
	if enable_dash:
		colors.append(World.COLOR_TRAVERSAL_DASH)
	if enable_meter:
		colors.append(World.COLOR_TRAVERSAL_METER)
	if enable_action_curse:
		colors.append(World.COLOR_TRAVERSAL_CURSE)
	if enable_world_switch:
		colors.append(World.world_color(World.opposite_world(WorldManager.current)))
	return colors

func _feature_emissions() -> Array[Color]:
	var colors: Array[Color] = []
	if enable_launch:
		colors.append(World.COLOR_TRAVERSAL_LAUNCH_EMISSION)
	if enable_dash:
		colors.append(World.COLOR_TRAVERSAL_DASH_EMISSION)
	if enable_meter:
		colors.append(World.COLOR_TRAVERSAL_METER_EMISSION)
	if enable_action_curse:
		colors.append(World.COLOR_TRAVERSAL_CURSE_EMISSION)
	if enable_world_switch:
		colors.append(World.world_emission(World.opposite_world(WorldManager.current)))
	return colors
