class_name PlayerCombat extends Node
## Enruta el input de ataque al arma del slot (ex PlayerCombat.cs). El daño lo aplica
## el arma (las personalidades viven ahí); acá viven el InputBuffer, el estado "armas
## afuera" (gatillará el lock-on, batch 6) y la pose de descanso de las armas.
## En v1 slot X y slot Y podían ser armas distintas; hoy ambos apuntan a la Espada.

@export var slot_x: WeaponBase
@export var slot_y: WeaponBase

signal slots_changed(slot_x_weapon: WeaponBase, slot_y_weapon: WeaponBase)

## Telegraph: se emite al ARRANCAR un ataque (en el press), antes de que la hoja barra.
## Es el estimulo que un enemigo percibe para DEFEND/EVADE (ver enemies/ai_spec: la
## condicion IncomingAttack lee combat.incoming_attack_until, que un receptor escribe con
## esto). NO agrega delay al ataque: los swings son procedurales y la hoja tarda en llegar,
## asi que emitir en el press ya da ventana de reaccion sin tocar el feel del player.
## El estado enemigo que lo CONSUME (DEFEND) esta pendiente; aca vive el emisor.
signal attack_telegraphed(origin: Vector3, direction: Vector3)

var _body: Player
var _last_attack_time := -999.0
var _charging_weapon: WeaponBase  # arma del último press: recibe el glow de carga
var _rest_rotations := {}  # WeaponBase → Quaternion

@onready var buffer: InputBuffer = $InputBuffer

func setup(body: Player) -> void:
	_body = body
	buffer.buffer_time = body.tuning.input_buffer_time
	buffer.hold_threshold = body.tuning.input_hold_threshold
	for weapon in _weapons():
		weapon.setup(body)
		_rest_rotations[weapon] = weapon.quaternion
	_refresh_weapon_visibility()
	slots_changed.emit(slot_x, slot_y)

func available_weapons() -> Array[WeaponBase]:
	var out: Array[WeaponBase] = []
	if _body != null:
		for child in _body.get_children():
			var weapon := child as WeaponBase
			if weapon != null and weapon not in out:
				out.append(weapon)
	for weapon in _weapons():
		if weapon != null and weapon not in out:
			out.append(weapon)
	return out

func set_slot_weapon(slot: World.Slot, weapon: WeaponBase) -> void:
	if weapon == null:
		return
	if _body != null and weapon not in _rest_rotations:
		weapon.setup(_body)
		_rest_rotations[weapon] = weapon.quaternion
	match slot:
		World.Slot.X:
			slot_x = weapon
		World.Slot.Y:
			slot_y = weapon
	_refresh_weapon_visibility()
	slots_changed.emit(slot_x, slot_y)

func weapon_label(weapon: WeaponBase) -> String:
	if weapon == null:
		return "Vacio"
	return weapon.name.capitalize()

func cancel_input() -> void:
	buffer.release()

## El jugador tiene las armas afuera si atacó hace poco.
func weapons_out() -> bool:
	return World.now() - _last_attack_time < _body.tuning.weapons_out_duration

func _input(event: InputEvent) -> void:
	if _body != null and _body.is_stunned():
		return
	if event.is_action_pressed("attack_x"):
		_on_press(slot_x, World.Slot.X)
	elif event.is_action_released("attack_x"):
		buffer.release()
	elif event.is_action_pressed("attack_y"):
		_on_press(slot_y, World.Slot.Y)
	elif event.is_action_released("attack_y"):
		buffer.release()

## Golpea en el press (tap) y carga mientras se mantiene; al soltar sale el cargado.
func _on_press(weapon: WeaponBase, slot: World.Slot) -> void:
	if weapon == null:
		return
	attack_telegraphed.emit(_body.global_position, _body.forward())
	_body.fire_action_world_switch()
	_last_attack_time = World.now()
	_charging_weapon = weapon
	weapon.quaternion = _rest_rotations[weapon]
	buffer.press_then_charge(weapon.tap.bind(slot), _fire_hold.bind(weapon, slot))

## El nivel de carga se resuelve recién al disparar el hold (no al bindear en el
## press), así el arma puede leer cuánto se sostuvo de verdad (ver Mazo.charge_level).
func _fire_hold(weapon: WeaponBase, slot: World.Slot) -> void:
	weapon.hold(slot, weapon.charge_level(buffer.held_duration()))

## Armas guardadas: rotan a la pose inactiva (hoja hacia abajo) al pasar el rato.
func _process(delta: float) -> void:
	if _body == null:
		return
	# Glow de carga: la hoja del arma presionada brilla según el progreso de carga.
	if _charging_weapon != null:
		_charging_weapon.set_charge_glow(buffer.charge_progress())
	if weapons_out():
		return
	for weapon in _weapons():
		var rest: Quaternion = _rest_rotations[weapon]
		var target := rest * Quaternion(Vector3.RIGHT, deg_to_rad(_body.tuning.inactive_weapon_angle))
		var angle := weapon.quaternion.angle_to(target)
		if angle < 0.001:
			continue
		var max_step := deg_to_rad(_body.tuning.weapon_pose_rotate_speed) * delta
		weapon.quaternion = weapon.quaternion.slerp(target, minf(1.0, max_step / angle))

## Slots únicos (X e Y pueden apuntar a la misma arma: setup y pose una sola vez).
func _weapons() -> Array[WeaponBase]:
	var out: Array[WeaponBase] = []
	for weapon in [slot_x, slot_y]:
		if weapon != null and weapon not in out:
			out.append(weapon)
	return out

func _refresh_weapon_visibility() -> void:
	var equipped := _weapons()
	for weapon in available_weapons():
		weapon.visible = weapon in equipped
