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
@export var hit_cooldown := 0.1

@export_group("Meter")
@export var meter_bars := 1.0

@export_group("Rotura")
## 0 = indestructible; >0 = cantidad de golpes antes de romperse.
@export var hits_to_break := 0

const INDESTRUCTIBLE_HEALTH := 999999.0

var _last_dash_hit_time := -999.0
var _segment_materials: Array[StandardMaterial3D] = []

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
	_rebuild_glow_segments()
	_update_glow()

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
	player.force_dash(player.forward(), dash_distance, dash_duration, boost_existing_bump_momentum)

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
		mesh.size = Vector3(1.02 / float(count), 0.08, 1.02)
		segment.mesh = mesh
		segment.position = Vector3(-0.51 + (float(i) + 0.5) / float(count), 1.08, 0.0)
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
		material.albedo_color = colors[i]
		material.emission = emissions[i]

func _update_glow() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var proximity := 0.0
	if player != null and tuning.proximity_radius > 0.0:
		var distance := global_position.distance_to(player.global_position)
		proximity = clampf(1.0 - distance / tuning.proximity_radius, 0.0, 1.0)
	var energy := lerpf(tuning.glow_min_energy, tuning.glow_max_energy, proximity)
	for material in _segment_materials:
		material.emission_energy_multiplier = energy

func _feature_colors() -> Array[Color]:
	var colors: Array[Color] = []
	if enable_launch:
		colors.append(World.COLOR_LIVING)
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
		colors.append(World.COLOR_LIVING_EMISSION)
	if enable_dash:
		colors.append(World.COLOR_TRAVERSAL_DASH_EMISSION)
	if enable_meter:
		colors.append(World.COLOR_TRAVERSAL_METER_EMISSION)
	if enable_action_curse:
		colors.append(World.COLOR_TRAVERSAL_CURSE_EMISSION)
	if enable_world_switch:
		colors.append(World.world_emission(World.opposite_world(WorldManager.current)))
	return colors
