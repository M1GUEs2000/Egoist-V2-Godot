class_name PlayerCombat extends Node
## Enruta el input de ataque al arma del slot (ex PlayerCombat.cs). El daño lo aplica
## el arma (las personalidades viven ahí); acá viven el InputBuffer, el estado "armas
## afuera" (gatillará el lock-on, batch 6) y la pose de descanso de las armas.
## En v1 slot X y slot Y podían ser armas distintas; hoy ambos apuntan a la Espada.

## Tipo del ataque en curso: lo lee el parry para saber cuanto poise inflige (WeaponTuning tiene un
## valor por cada uno). NORMAL = tap; CHARGED_X/CHARGED_Y = hold del slot. Aereo y suelo comparten.
enum AttackKind { NORMAL, CHARGED_X, CHARGED_Y }

@export var slot_x: WeaponBase
@export var slot_y: WeaponBase

signal slots_changed(slot_x_weapon: WeaponBase, slot_y_weapon: WeaponBase)

## Telegraph: se emite al ARRANCAR un ataque (en el press), antes de que la hoja barra.
## Es el estimulo que un enemigo percibe para DEFEND/EVADE (ver enemies/ai_spec: la
## condicion IncomingAttack lee combat.incoming_attack_until, que un receptor escribe con
## esto). NO agrega delay al ataque: los swings son procedurales y la hoja tarda en llegar,
## asi que emitir en el press ya da ventana de reaccion sin tocar el feel del player.
## Lo consume EVADE (GroundedEnemy._on_player_attack_telegraphed); DEFEND lo reusara.
signal attack_telegraphed(origin: Vector3, direction: Vector3)

## Barras que consumiría el cargado en curso si se soltara AHORA, y el color con el que brilla la
## hoja mientras carga. Lo pinta el HUD sobre el meter: las barras condenadas laten. Sale en 0 (con
## el color que traía) cuando el press deja de estar cargado.
signal charge_meter_preview_changed(bars: float, glow: Color)

var _body: Player
var _last_attack_time := -999.0
var _charging_weapon: WeaponBase  # arma del último press: recibe el glow de carga
var _charging_slot := World.Slot.X  # slot de ese press: decide cuánto meter costaría el cargado
var _charge_preview := 0.0  # último valor emitido en charge_meter_preview_changed
var _active_weapon: WeaponBase  # arma visible actualmente
var _attack_kind := AttackKind.NORMAL  # tipo del ultimo ataque iniciado (lo lee el parry)
var _press_id := 0
var _rest_rotations := {}  # WeaponBase → Quaternion
var _air_charge_fall_applied := false
## Fin de la ventana que deja un tap hacia atras relativo al lock-on antes de pulsar Y.
var _lock_back_tap_until := -999.0
## Fin de la ventana que deja un tap hacia adelante relativo al lock-on antes de pulsar Y.
var _lock_forward_tap_until := -999.0
## Ventanas equivalentes para los especiales del slot X.
var _lock_back_x_tap_until := -999.0
var _lock_forward_x_tap_until := -999.0
## El gesto direccional debe salir de neutral para que girar el stick no lo active.
var _lock_direction_tap_armed := false

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
			if weapon != null and weapon is not Mace and weapon not in out:
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
	_press_id += 1
	buffer.release()

## Sosteniendo X o Y desde el press hasta que se suelta o dispara el golpe cargado. Mismo
## progreso que ya alimenta el glow (vuelve a 0 al soltar); lo usan la locomoción (clamp de
## velocidad) y el animation controller (blend de pose al caminar cargando).
func is_charging() -> bool:
	return buffer.charge_progress() > 0.0

## Barras que consumiría el cargado en curso si se soltara AHORA. Cero mientras el press todavía no
## escaló a carga: por debajo del umbral soltar da un tap, y un tap es gratis. El monto lo decide el
## arma (charged_meter_cost), que es la única que sabe si su cargado escala por nivel o sale gratis.
func charge_meter_preview() -> float:
	if _charging_weapon == null or buffer.charge_progress() < 1.0:
		return 0.0
	return _charging_weapon.charged_meter_cost(_charging_slot, buffer.held_duration())

## El jugador tiene las armas afuera si atacó hace poco.
func weapons_out() -> bool:
	return World.now() - _last_attack_time < _body.tuning.weapons_out_duration

func _input(event: InputEvent) -> void:
	if _body != null and _body.is_stunned():
		return
	if event.is_action_pressed("attack_x"):
		_track_lock_direction_tap()
		if not _try_lock_forward_x_static_spin() and not _try_lock_back_x_retreat():
			_on_press(slot_x, World.Slot.X)
	elif event.is_action_released("attack_x"):
		buffer.release()
	elif event.is_action_pressed("attack_y"):
		_track_lock_direction_tap()
		if not _try_lock_forward_y_push() and not _try_lock_back_y_launcher():
			_on_press(slot_y, World.Slot.Y)
	elif event.is_action_released("attack_y"):
		buffer.release()
## Solo registra la primera direccion despues de neutral. Asi girar el stick de forma continua
## no abre un especial adelante/atras y el gesto sigue siendo relativo al target lockeado.
func _track_lock_direction_tap() -> void:
	if _body == null or _body.is_stunned() or not _body.lock_on.is_locked \
			or (slot_x == null and slot_y == null):
		_lock_direction_tap_armed = false
		_lock_back_tap_until = -999.0
		_lock_forward_tap_until = -999.0
		_lock_back_x_tap_until = -999.0
		_lock_forward_x_tap_until = -999.0
		return
	var input := _body.locomotion.read_move_input()
	if not _body.locomotion.has_move_input(input):
		_lock_direction_tap_armed = true
		return
	if not _lock_direction_tap_armed:
		return
	_lock_direction_tap_armed = false
	if _body.locomotion.input_is_away_from_locked_target(input):
		if slot_y != null and slot_y.lock_back_y_launcher_window() > 0.0:
			_lock_back_tap_until = World.now() + slot_y.lock_back_y_launcher_window()
		if slot_x != null and slot_x.lock_back_x_retreat_window() > 0.0:
			_lock_back_x_tap_until = World.now() + slot_x.lock_back_x_retreat_window()
	if _body.locomotion.input_is_toward_locked_target(input):
		if slot_y != null and slot_y.lock_forward_y_push_window() > 0.0:
			_lock_forward_tap_until = World.now() + slot_y.lock_forward_y_push_window()
		if slot_x != null and slot_x.lock_forward_x_static_spin_window() > 0.0:
			_lock_forward_x_tap_until = World.now() + slot_x.lock_forward_x_static_spin_window()

## Y consume el tap adelante una vez para el push propio del arma equipada.
func _try_lock_forward_y_push() -> bool:
	if _body == null or World.now() > _lock_forward_tap_until or slot_y == null:
		return false
	if slot_y.lock_forward_y_push_window() <= 0.0:
		return false
	_lock_forward_tap_until = -999.0
	return _start_lock_special(slot_y, World.Slot.Y,
			Callable(slot_y, &"try_lock_forward_y_push"))

## Y consume el gesto una vez y lo convierte en el launcher propio del arma equipada. Entra como
## ataque normal: no carga, no gasta meter y no espera a que se suelte Y.
func _try_lock_back_y_launcher() -> bool:
	if _body == null or World.now() > _lock_back_tap_until or slot_y == null:
		return false
	if slot_y.lock_back_y_launcher_window() <= 0.0:
		return false
	_lock_back_tap_until = -999.0
	return _start_lock_special(slot_y, World.Slot.Y,
			Callable(slot_y, &"try_lock_back_y_launcher"))

## X consume el tap adelante una vez para la vuelta estatica propia del arma equipada.
func _try_lock_forward_x_static_spin() -> bool:
	if _body == null or World.now() > _lock_forward_x_tap_until or slot_x == null:
		return false
	if slot_x.lock_forward_x_static_spin_window() <= 0.0:
		return false
	_lock_forward_x_tap_until = -999.0
	return _start_lock_special(slot_x, World.Slot.X,
			Callable(slot_x, &"try_lock_forward_x_static_spin"))

## X consume el tap atras una vez para el retroceso propio del arma equipada.
func _try_lock_back_x_retreat() -> bool:
	if _body == null or World.now() > _lock_back_x_tap_until or slot_x == null:
		return false
	if slot_x.lock_back_x_retreat_window() <= 0.0:
		return false
	_lock_back_x_tap_until = -999.0
	return _start_lock_special(slot_x, World.Slot.X,
			Callable(slot_x, &"try_lock_back_x_retreat"))

## El tap direccional sale al press, pero ese mismo press tambien alimenta la carga. Si se suelta
## cargado durante la rutina, el callback espera a que terminen sus vueltas/Mover antes de ejecutarse.
func _start_lock_special(weapon: WeaponBase, slot: World.Slot, start_special: Callable) -> bool:
	buffer.release()
	if _charging_weapon != null:
		_charging_weapon.set_charge_glow(0.0)
		_charging_weapon.set_sweet_spot_window(false)
	_press_id += 1
	var press_id := _press_id
	_charging_weapon = weapon
	_charging_slot = slot
	_attack_kind = AttackKind.NORMAL
	_air_charge_fall_applied = false
	if weapon.should_reset_pose_on_press():
		weapon.quaternion = _rest_rotations[weapon]
	_set_active_weapon(weapon)
	attack_telegraphed.emit(_body.global_position, _body.forward())
	_body.fire_action_world_switch()
	_last_attack_time = World.now()
	var started: bool = start_special.call()
	if not started:
		_charging_weapon = null
		return false
	# La continuidad tap -> carga pedida pertenece a los nuevos gestos X. Los especiales Y
	# conservan su contrato actual de tap puro hasta que tengan una regla de final propia.
	if slot != World.Slot.X:
		_charging_weapon = null
		return true
	buffer.press_then_charge(Callable(),
			_fire_hold_after_directional_special.bind(weapon, slot, press_id))
	return true

func _fire_hold_after_directional_special(weapon: WeaponBase, slot: World.Slot,
		press_id: int) -> void:
	while press_id == _press_id and weapon != null and weapon.directional_special_is_active():
		await get_tree().process_frame
	if press_id != _press_id or weapon == null:
		return
	_fire_hold(weapon, slot)

## Golpea en el press (tap) y carga mientras se mantiene; al soltar sale el cargado.
func _on_press(weapon: WeaponBase, slot: World.Slot) -> void:
	if weapon == null:
		return
	_press_id += 1
	attack_telegraphed.emit(_body.global_position, _body.forward())
	_body.fire_action_world_switch()
	_last_attack_time = World.now()
	_charging_weapon = weapon
	_charging_slot = slot
	# Baseline: el press arranca como tap (NORMAL). Si escala a hold, _fire_hold lo pasa a cargado
	# antes de que salga el swing cargado — asi el parry lee el tipo correcto.
	_attack_kind = AttackKind.NORMAL
	_air_charge_fall_applied = false
	if weapon.should_reset_pose_on_press():
		weapon.quaternion = _rest_rotations[weapon]
	_set_active_weapon(weapon)
	buffer.press_then_charge(weapon.tap.bind(slot), _fire_hold.bind(weapon, slot))

## El nivel de carga se resuelve recién al disparar el hold (no al bindear en el
## press), así el arma puede leer cuánto se sostuvo de verdad (ver Mazo.charge_level).
func _fire_hold(weapon: WeaponBase, slot: World.Slot) -> void:
	if not _air_charge_fall_applied:
		_air_charge_fall_applied = true
		_body.apply_air_charge_float()
	_attack_kind = AttackKind.CHARGED_X if slot == World.Slot.X else AttackKind.CHARGED_Y
	# El sweet spot se resuelve con la MISMA lectura que el nivel: held_duration ya dejo de
	# contar al disparar el hold, asi que un cargado bufferizado no se gana la ventana por
	# los milisegundos que tardo en ejecutarse.
	weapon.arm_sweet_spot(buffer.held_duration())
	weapon.hold(slot, weapon.charge_level(buffer.held_duration()))

## Poise que inflige un parry hecho AHORA: sale del arma activa (su .tres) segun el tipo del
## ultimo ataque iniciado. Lo consulta EnemyBase.resolve_parry via Player.current_parry_poise().
func current_parry_poise() -> float:
	var weapon := _active_weapon
	if weapon == null or weapon.tuning == null:
		return 0.0
	match _attack_kind:
		AttackKind.CHARGED_X:
			return weapon.tuning.parry_poise_charged_x
		AttackKind.CHARGED_Y:
			return weapon.tuning.parry_poise_charged_y
		_:
			return weapon.tuning.parry_poise_normal

## Armas guardadas: rotan a la pose inactiva (hoja hacia abajo) al pasar el rato.
func _process(delta: float) -> void:
	if _body == null:
		return
	_track_lock_direction_tap()
	# Glow de carga: la hoja del arma presionada brilla según el progreso de carga.
	if _charging_weapon != null:
		var charge_progress := buffer.charge_progress()
		_charging_weapon.set_charge_glow(charge_progress)
		# Aura de la ventana de sweet spot. charge_progress vuelve a 0 al soltar, asi que esto
		# tambien la apaga cuando el press termina sin cargado.
		_charging_weapon.set_sweet_spot_window(charge_progress >= 1.0
				and _charging_weapon.tuning.in_sweet_spot(buffer.held_duration()))
		if not _air_charge_fall_applied and charge_progress >= 1.0 \
				and not _charging_weapon.directional_special_is_active():
			_air_charge_fall_applied = true
			_body.apply_air_charge_float()
	_update_charge_preview()
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

## Avisa al HUD solo cuando el monto cambia. El Mazo lo mueve a saltos mientras cargás (una barra
## por vuelta) y el sweet spot de la Espada lo abarata a mitad de carga, así que esto no es constante
## durante un mismo press.
func _update_charge_preview() -> void:
	var preview := charge_meter_preview()
	if is_equal_approx(preview, _charge_preview):
		return
	_charge_preview = preview
	var glow := _charging_weapon.charge_glow_color if _charging_weapon != null else Color.WHITE
	charge_meter_preview_changed.emit(preview, glow)

## Slots únicos (X e Y pueden apuntar a la misma arma: setup y pose una sola vez).
func _weapons() -> Array[WeaponBase]:
	var out: Array[WeaponBase] = []
	for weapon in [slot_x, slot_y]:
		if weapon != null and weapon not in out:
			out.append(weapon)
	return out

func _set_active_weapon(weapon: WeaponBase) -> void:
	if _active_weapon == weapon:
		return
	if _active_weapon != null:
		_active_weapon.visible = false
	_active_weapon = weapon
	if weapon != null:
		weapon.visible = true

## Solo se ve el arma activa (la del último ataque). Al arrancar —o si la activa dejó
## de estar equipada por un cambio de slot— cae a la del slot X: si no, el jugador
## quedaría con las manos vacías hasta el primer ataque.
func _refresh_weapon_visibility() -> void:
	if _active_weapon not in _weapons():
		_active_weapon = slot_x
	for weapon in available_weapons():
		weapon.visible = weapon == _active_weapon
