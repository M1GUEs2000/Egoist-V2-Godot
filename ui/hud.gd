class_name HUD extends CanvasLayer
## HUD nuevo desde cero: mundo actual, vida, meter en barras y estado global.
## Solo escucha senales: no decide gameplay.

@onready var _world_label: Label = $Root/VBox/WorldLabel
@onready var _health_label: Label = $Root/VBox/HealthRow/HealthLabel
@onready var _health_bar: ProgressBar = $Root/VBox/HealthRow/HealthBar
@onready var _meter_bars: HBoxContainer = $Root/VBox/MeterBars
@onready var _state_label: Label = $Root/VBox/StateLabel
@onready var _loadout_menu: ActionLoadoutMenu = $ActionLoadoutMenu

var _health: Health
var _meter: PlayerMeter
var _meter_segments: Array[ProgressBar] = []

func _ready() -> void:
	layer = 10
	WorldManager.world_changed.connect(_on_world_changed)
	GameManager.state_changed.connect(_on_state_changed)
	_on_world_changed(WorldManager.current)
	_on_state_changed(GameManager.state)
	call_deferred("_bind_player")

func _bind_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return

	_health = player.health
	_meter = player.meter
	if not _health.damaged.is_connected(_on_health_damaged):
		_health.damaged.connect(_on_health_damaged)
	if not _health.died.is_connected(_on_health_died):
		_health.died.connect(_on_health_died)
	if not _meter.bars_changed.is_connected(_on_meter_changed):
		_meter.bars_changed.connect(_on_meter_changed)

	_update_health()
	_on_meter_changed(_meter.meter(), _meter.bars())
	if _loadout_menu != null:
		_loadout_menu.setup(player)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_loadout_menu"):
		_loadout_menu.toggle()
		get_viewport().set_input_as_handled()

func _on_world_changed(world: World.Kind) -> void:
	_world_label.text = "Mundo: %s" % World.Kind.keys()[world]

func _on_state_changed(state: int) -> void:
	_state_label.text = "Estado: %s" % GameManager.State.keys()[state]

func _on_health_damaged(_amount: float) -> void:
	_update_health()

func _on_health_died() -> void:
	_update_health()

func _update_health() -> void:
	if _health == null:
		return
	_health_bar.max_value = _health.max_health
	_health_bar.value = _health.current
	_health_label.text = "Vida: %d / %d" % [int(ceil(_health.current)), int(ceil(_health.max_health))]

func _on_meter_changed(current: float, max_bars: int) -> void:
	var safe_max := maxi(1, max_bars)
	if _meter_segments.size() != safe_max:
		_rebuild_meter(safe_max)
	for index in range(_meter_segments.size()):
		_meter_segments[index].value = clampf(current - float(index), 0.0, 1.0)

func _rebuild_meter(max_bars: int) -> void:
	for child in _meter_bars.get_children():
		child.queue_free()
	_meter_segments.clear()

	for index in range(max_bars):
		var segment := ProgressBar.new()
		segment.name = "MeterSegment%d" % (index + 1)
		segment.min_value = 0.0
		segment.max_value = 1.0
		segment.value = 0.0
		segment.show_percentage = false
		segment.custom_minimum_size = Vector2(58.0, 14.0)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_meter_bars.add_child(segment)
		_meter_segments.append(segment)
