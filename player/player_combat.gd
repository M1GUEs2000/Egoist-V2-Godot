class_name PlayerCombat extends Node
## Enruta el input de ataque al arma del slot (ex PlayerCombat.cs). El daño lo aplica
## el arma (las personalidades viven ahí); acá viven el InputBuffer, el estado "armas
## afuera" (gatillará el lock-on, batch 6) y la pose de descanso de las armas.
## En v1 slot X y slot Y podían ser armas distintas; hoy ambos apuntan a la Espada.

@export var slot_x: WeaponBase
@export var slot_y: WeaponBase

var _body: Player
var _last_attack_time := -999.0
var _rest_rotations := {}  # WeaponBase → Quaternion

@onready var buffer: InputBuffer = $InputBuffer

func setup(body: Player) -> void:
	_body = body
	for weapon in _weapons():
		weapon.setup(body)
		_rest_rotations[weapon] = weapon.quaternion

## El jugador tiene las armas afuera si atacó hace poco.
func weapons_out() -> bool:
	return World.now() - _last_attack_time < _body.tuning.weapons_out_duration

func _unhandled_input(event: InputEvent) -> void:
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
	# ActionWorldSwitchModifier.fire_action() — llega con la maldición amarilla (batch 6)
	_last_attack_time = World.now()
	if weapon == null:
		return
	weapon.quaternion = _rest_rotations[weapon]
	buffer.press_then_charge(weapon.tap.bind(slot), weapon.hold.bind(slot, 1))
	# TODO juice: glow de carga en la hoja con buffer.charge_progress() cuando haya materiales

## Armas guardadas: rotan a la pose inactiva (hoja hacia abajo) al pasar el rato.
func _process(delta: float) -> void:
	if _body == null or weapons_out():
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
