class_name PlayerLegacyArm extends Node
## Brazo: puño remoto, habilidad permanente del jugador (ver obsidian/Gameplay/Brazo). No es
## WeaponBase: no ocupa slot X/Y, no usa el motor de combos/swing orbital de las armas.
## Un solo boton (tap) con dos usos segun el target resuelto:
## - Combate: golpea al target del lock-on pasivo (lockeado si hay uno, si no el más cercano en
##   el cono de mira — mismo target que usa PlayerLegacyLocomotion para el snap del golpe normal). Daño
##   y poise bajos; genera meter propio y bajo al conectar. Gasta tap y entra en cooldown. No pega
##   mas rapido que `tuning.tap_cadence`: mashear no acelera, encola los taps de mas en vez de
##   perderlos (hasta agotar max_taps).
## - Traversal: si no hay enemigo en el cono de combate, marca el bloque de dash (verde) más
##   cercano en su propio cono/rango (`tuning.traversal_lock_*`) y, al tap, teletransporta al
##   jugador encima y lo activa (mismo efecto que golpearlo). No gasta tap ni entra en el
##   cooldown de combate, pero tiene su propio cooldown corto (`traversal_cooldown_duration`).

@export var tuning: ArmTuning

var _taps_used := 0
var _cooldown_until := -999.0
var _traversal_cooldown_until := -999.0
var _swing_id := 0
var _player: PlayerLegacy

## Cola de taps de combate que llegaron mas rapido que `tuning.tap_cadence`: no se pierden,
## salen apenas la cadencia lo permite (ver _process). Capada por el margen que quede antes de
## max_taps, no por tiempo: mashear no acelera la cadencia, solo llena la cola hasta el limite.
var _pending_taps := 0
var _next_tap_ready_at := -999.0

@onready var _hitbox: Hitbox = $ArmHitbox
@onready var _marker: MeshInstance3D = $ArmMarker

func _ready() -> void:
	if tuning == null:
		tuning = ArmTuning.new()
	_marker.visible = false

## Punto morado sobre quien recibiria el golpe/teletransporte AHORA (lock-on pasivo del Brazo):
## no depende de armas afuera ni de estar atacando, a diferencia del reticle de combate (ver
## LegacyLockOn._process). Prioriza enemigo (igual que _try_tap); si no hay, marca el bloque de dash.
func _process(_delta: float) -> void:
	if _player == null:
		return
	_flush_tap_buffer()
	var target := _resolve_target()
	if target != null:
		_marker.visible = true
		_marker.global_position = _player.lock_on.head_position(target)
		return
	var block := _nearest_dash_block()
	_marker.visible = block != null
	if block != null:
		_marker.global_position = block.global_position + Vector3.UP * tuning.traversal_marker_height

## Flush de la cola de taps bufferizados, al ritmo de `tuning.tap_cadence`.
func _flush_tap_buffer() -> void:
	if _pending_taps <= 0 or World.now() < _next_tap_ready_at:
		return
	_pending_taps -= 1
	var target := _resolve_target()
	if target != null:
		_fire_tap(target)  # si el target ya no existe, el tap en cola se pierde (no hay a quien pegarle)

func _input(event: InputEvent) -> void:
	if _player != null and _player.is_stunned():
		return
	if event.is_action_pressed("arm_attack"):
		_try_tap()

func setup(player: PlayerLegacy) -> void:
	_player = player
	_hitbox.source = player
	_hitbox.damage = tuning.damage
	_hitbox.stun = tuning.stun
	_hitbox.landed.connect(_on_hit)

## Un tap de combate no pega mas rapido que `tuning.tap_cadence`: si todavia no toca, se guarda
## en `_pending_taps` en vez de perderse (ver _flush_tap_buffer), capado por el margen que quede
## antes de max_taps. El traversal (bloques) no pasa por la cola: no tiene sentido encolar
## teletransportes, ya tiene su propio cooldown corto.
func _try_tap() -> void:
	var target := _resolve_target()
	if target != null:
		if _taps_used + _pending_taps >= tuning.max_taps:
			return  # sin margen: se pierde (ya esta o va a estar en cooldown)
		if _pending_taps == 0 and World.now() >= _next_tap_ready_at:
			_fire_tap(target)
		else:
			_pending_taps += 1
		return
	var block := _nearest_dash_block()
	if block != null:
		_teleport_and_activate(block)
	# sin enemigo ni bloque marcado: apreton gratis, no gasta tap ni entra en cooldown

func _fire_tap(target: EnemyBase) -> void:
	_next_tap_ready_at = World.now() + tuning.tap_cadence
	_tap_enemy(target)

func _tap_enemy(target: EnemyBase) -> void:
	if _taps_used >= tuning.max_taps:
		if World.now() < _cooldown_until:
			return  # en cooldown: el apreton no hace nada
		_taps_used = 0  # cooldown cumplido: vuelve a habilitarse

	# Se gasta el tap ACA (antes del await): si no, taps mas rapidos que travel_time se
	# colarian todos antes de que el primero llegue a incrementar el contador.
	_taps_used += 1
	if _taps_used >= tuning.max_taps:
		_cooldown_until = World.now() + tuning.cooldown_duration

	_swing_id += 1
	var id := _swing_id
	_hitbox.global_position = target.global_position
	_hitbox.begin_swing()
	await get_tree().create_timer(maxf(0.01, tuning.travel_time)).timeout
	if id == _swing_id:
		_hitbox.end_swing()

## Empuja al jugador hacia el bloque de dash marcado (dash forzado, ver PlayerLegacyDash.force_dash,
## a lo largo de `tuning.teleport_duration` segundos) y lo activa al llegar (mismo efecto que
## golpearlo). No gasta taps ni entra en el cooldown de combate (es traversal, no combate), pero
## tiene su propio cooldown corto (`tuning.traversal_cooldown_duration`) para no encadenar
## bloques verdes uno atras de otro.
func _teleport_and_activate(block: TraversalBlock) -> void:
	if World.now() < _traversal_cooldown_until:
		return  # en cooldown: el apreton no hace nada
	_traversal_cooldown_until = World.now() + tuning.traversal_cooldown_duration
	var landing := block.global_position + Vector3.UP * tuning.teleport_height_offset
	var to_landing := landing - _player.global_position
	if to_landing.length_squared() > 0.0001:
		_player.force_dash(to_landing.normalized(), to_landing.length(), tuning.teleport_duration)
	else:
		_player.global_position = landing
	await get_tree().create_timer(maxf(0.01, tuning.teleport_duration)).timeout
	block.activate(_player)

## Bloque de dash (verde) más cercano dentro del cono/rango propio del brazo para traversal
## (`tuning.traversal_lock_*`, separado del rango de combate para no atarlos entre sí).
## Solo candidatos: `TraversalBlock` con `enable_dash` (se registran en el grupo al nacer).
func _nearest_dash_block() -> TraversalBlock:
	var dir := _player.forward()
	var best: TraversalBlock = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("arm_dash_target"):
		var block := node as TraversalBlock
		if block == null:
			continue
		var to := block.global_position - _player.global_position
		var horiz := to
		horiz.y = 0.0
		var horiz_dist := horiz.length()
		if horiz_dist < 0.01 or horiz_dist > tuning.traversal_lock_max_range:
			continue
		if rad_to_deg(dir.angle_to(horiz)) > tuning.traversal_lock_half_angle:
			continue
		var vertical_angle := rad_to_deg(atan2(to.y, horiz_dist))
		if absf(vertical_angle) > tuning.traversal_lock_vertical_half_angle:
			continue
		var dist := to.length()
		if dist < best_dist:
			best_dist = dist
			best = block
	return best

## Mismo target que el snap del golpe normal sin lock (ver PlayerLegacyLocomotion): lockeado si hay
## uno, si no el enemigo mas centrado en el cono de mira.
func _resolve_target() -> EnemyBase:
	if _player.lock_on.is_locked:
		return _player.lock_on.current_target
	return _player.lock_on.nearest_in_cone(_player.forward())

func _on_hit(_hurtbox: Hurtbox, _died: bool) -> void:
	if _player.meter != null:
		_player.meter.gain_bars(tuning.meter_gain_on_hit)
