class_name ActionLoadoutMenu extends Control
## Overlay ligero para asignar armas a los slots X/Y sin pausar el juego.

var _player: Player
var _combat: PlayerCombat
var _selected_slot := World.Slot.X

@onready var _slot_x_button: Button = $Center/Panel/Margin/VBox/SlotRow/SlotXButton
@onready var _slot_y_button: Button = $Center/Panel/Margin/VBox/SlotRow/SlotYButton
@onready var _weapon_list: VBoxContainer = $Center/Panel/Margin/VBox/WeaponScroll/WeaponList
@onready var _status_label: Label = $Center/Panel/Margin/VBox/StatusLabel
@onready var _close_button: Button = $Center/Panel/Margin/VBox/CloseButton

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_x_button.pressed.connect(_select_x)
	_slot_y_button.pressed.connect(_select_y)
	_close_button.pressed.connect(hide_menu)
	_refresh()

func setup(player: Player) -> void:
	_player = player
	var next_combat: PlayerCombat = null
	if _player != null:
		next_combat = _player.combat
	if _combat != null and _combat.slots_changed.is_connected(_on_slots_changed):
		_combat.slots_changed.disconnect(_on_slots_changed)
	_combat = next_combat
	if _combat != null and not _combat.slots_changed.is_connected(_on_slots_changed):
		_combat.slots_changed.connect(_on_slots_changed)
	_refresh()

func toggle() -> void:
	if visible:
		hide_menu()
	else:
		show_menu()

func show_menu() -> void:
	visible = true
	_refresh()
	_slot_x_button.grab_focus()

func hide_menu() -> void:
	visible = false

func _select_x() -> void:
	_selected_slot = World.Slot.X
	_refresh()

func _select_y() -> void:
	_selected_slot = World.Slot.Y
	_refresh()

func _on_slots_changed(_slot_x_weapon: WeaponBase, _slot_y_weapon: WeaponBase) -> void:
	_refresh()

func _refresh() -> void:
	if not is_node_ready():
		return
	_refresh_slots()
	_rebuild_weapon_list()

func _refresh_slots() -> void:
	var x_label := "Vacio"
	var y_label := "Vacio"
	if _combat != null:
		x_label = _combat.weapon_label(_combat.slot_x)
		y_label = _combat.weapon_label(_combat.slot_y)
	_slot_x_button.text = "X\n%s" % x_label
	_slot_y_button.text = "Y\n%s" % y_label
	_slot_x_button.button_pressed = _selected_slot == World.Slot.X
	_slot_y_button.button_pressed = _selected_slot == World.Slot.Y
	_status_label.text = "Eligiendo Slot %s" % World.Slot.keys()[_selected_slot]

func _rebuild_weapon_list() -> void:
	for child in _weapon_list.get_children():
		_weapon_list.remove_child(child)
		child.queue_free()
	if _combat == null:
		_add_disabled_row("Sin jugador")
		return
	var weapons := _combat.available_weapons()
	if weapons.is_empty():
		_add_disabled_row("Sin armas")
		return
	for weapon in weapons:
		var button := Button.new()
		button.text = _combat.weapon_label(weapon)
		button.custom_minimum_size = Vector2(320.0, 44.0)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_equip_weapon.bind(weapon))
		_weapon_list.add_child(button)

func _add_disabled_row(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(320.0, 36.0)
	_weapon_list.add_child(label)

func _equip_weapon(weapon: WeaponBase) -> void:
	if _combat == null:
		return
	_combat.set_slot_weapon(_selected_slot, weapon)
