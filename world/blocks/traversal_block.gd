class_name TraversalBlock extends Node3D
## Bloque componible de traversal. Cada instancia activa una o varias funciones por export.

@export var tuning: TraversalBlockTuning

@export_group("Caracteristicas")
@export var enable_launch := false
@export var enable_dash := false
@export var enable_meter := false
@export var enable_action_curse := false
@export var enable_world_switch := false

@export_group("Launch / bump")
@export var horizontal_speed := 15.0
@export var vertical_speed := 20.0

@export_group("Dash")
@export var dash_distance := 4.0
@export var dash_duration := 0.12
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

@onready var _health: Health = $Health
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _break_on_death: BreakOnDeath = $BreakOnDeath
@onready var _glow_segments: Node3D = $GlowSegments

func _ready() -> void:
	if tuning == null:
		tuning = TraversalBlockTuning.new()
	_configure_health()
	_hurtbox.hit.connect(_on_hit)
	_health.died.connect(_on_died)
	WorldManager.world_changed.connect(_on_world_changed)
	_setup_light()
	_rebuild_glow_segments()
	_update_glow()

## Luz real (no solo emision del material) para que el bloque ilumine el entorno.
## El color y el encendido se ajustan en _repaint_segments y _update_glow.
func _setup_light() -> void:
	_light = OmniLight3D.new()
	_light.position = Vector3(0.0, 0.55, 0.0)  # centro del cuerpo del bloque
	_light.shadow_enabled = false
	add_child(_light)

func _process(_delta: float) -> void:
	_update_glow()

func _configure_health() -> void:
	if hits_to_break > 0:
		_health.set_max(float(hits_to_break))
		_break_on_death.free_owner = true
	else:
		_health.set_max(INDESTRUCTIBLE_HEALTH)
		_break_on_death.free_owner = false

func _on_hit(from: Node, _damage: float) -> void:
	if enable_world_switch:
		WorldManager.switch_world()
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

func _apply_dash(player: Player) -> void:
	if World.now() - _last_dash_hit_time < hit_cooldown:
		return
	_last_dash_hit_time = World.now()
	player.force_dash(player.forward(), dash_distance, dash_duration, boost_existing_bump_momentum,
			dash_deals_damage)

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
		segment.position = Vector3(-0.51 + (float(i) + 0.5) * 1.02 / float(count), 0.55, 0.0)
		var material := StandardMaterial3D.new()
		material.emission_enabled = true
		segment.set_surface_override_material(0, material)
		_glow_segments.add_child(segment)
		_segment_materials.append(material)
	_repaint_segments()

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
