class_name PlayerArm extends Node
## Brazo: puño remoto, habilidad permanente del jugador (ver obsidian/Gameplay/Brazo). No es
## WeaponBase: no ocupa slot X/Y, no usa el motor de combos/swing orbital de las armas.
## Un solo boton (tap) con dos usos segun el target resuelto:
## - Combate: golpea al target del lock-on pasivo (lockeado si hay uno, si no el más cercano en
##   el cono de mira — mismo target que usa PlayerLocomotion para el snap del golpe normal). Daño
##   y poise bajos; genera meter propio y bajo al conectar. Gasta una carga de una reserva de
##   `max_taps` que se regenera sola de a una cada `cooldown_duration` (ver _refresh_regen). No pega
##   mas rapido que `tuning.tap_cadence`: mashear no acelera, encola los taps de mas en vez de
##   perderlos (hasta agotar max_taps).
## - Traversal: si no hay enemigo en el cono de combate, marca el bloque de dash (verde) más
##   cercano en su propio cono/rango (`tuning.traversal_lock_*`) y, al tap, teletransporta al
##   jugador encima y lo activa (mismo efecto que golpearlo). No gasta tap ni entra en el
##   cooldown de combate, pero tiene su propio cooldown corto (`traversal_cooldown_duration`).

@export var tuning: ArmTuning

## Cambio en la reserva de golpes de combate disponibles. Lo escucha el HUD para dibujar un icono
## por golpe. Se emite al gastar uno y al regenerarse uno, nunca al encolar (ver taps_available).
signal taps_changed(available: int, max_taps: int)

var _taps_used := 0
## Instante en que vuelve el proximo golpe. No es un bloqueo tras agotarse: arranca apenas
## `_taps_used` sube de 0 y se re-arma solo mientras queden golpes por devolver (ver _refresh_regen).
var _regen_at := -999.0
var _traversal_cooldown_until := -999.0
var _swing_id := 0
var _player: Player

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
## LockOn._process). Prioriza enemigo (igual que _try_tap); si no hay, marca el bloque de dash.
func _process(_delta: float) -> void:
	_refresh_regen()
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

## Golpes de combate que quedan en la reserva. Cuenta SOLO los ya gastados
## (`_taps_used`, que sube cuando el puño sale de verdad), NO los encolados: el HUD tiene que
## apagarse al ritmo de los golpes que se ven, no al del boton. Con una cadencia larga los
## encolados salen bastante despues del apreton y descontarlos aca desfasaba la UI del gameplay.
func taps_available() -> int:
	return maxi(0, tuning.max_taps - _taps_used)

func max_taps() -> int:
	return tuning.max_taps

## Regeneracion de golpes: NO es un bloqueo que empieza al quedarte en cero. Basta con no estar
## completo para que corra el reloj, y cada `cooldown_duration` vuelve UN golpe; si todavia falta
## alguno, el reloj se re-arma solo. Gastar mientras corre no lo reinicia (el reloj es de la carga
## que se esta regenerando, no del ultimo apreton).
## Vive en _process y NO dentro de _tap_enemy: el guard de _try_tap corta antes de llegar a pegar
## cuando no hay margen, asi que si la recuperacion dependiera de un tap el brazo quedaria muerto
## para siempre al agotarse.
func _refresh_regen() -> void:
	if _taps_used <= 0 or World.now() < _regen_at:
		return
	_taps_used -= 1
	if _taps_used > 0:
		_regen_at = World.now() + tuning.cooldown_duration
	_notify_taps()

func _notify_taps() -> void:
	taps_changed.emit(taps_available(), tuning.max_taps)

## Flush de la cola de taps bufferizados, al ritmo de `tuning.tap_cadence`. El stun descarta la
## cola entera: _input ya no deja encolar mientras estas aturdido, pero sin esto los taps que
## entraron ANTES del golpe seguian saliendo durante el stun.
func _flush_tap_buffer() -> void:
	if _player.is_stunned():
		_pending_taps = 0
		return
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

func setup(player: Player) -> void:
	_player = player
	_hitbox.source = player
	_hitbox.damage = tuning.damage
	_hitbox.stun = tuning.stun
	_hitbox.landed.connect(_on_hit)
	_setup_aura()

## Aura permanente del brazo: instancia `vfx_scene` colgada de un BoneAttachment3D sobre el
## hombro izquierdo del maniqui (mismo patron que la copia de arma en mano del
## PlayerAnimationController) y la deja en loop. Solo visual.
func _setup_aura() -> void:
	if tuning.vfx_scene == null:
		return
	var skeleton := _find_skeleton(_player)
	if skeleton == null:
		push_warning("PlayerArm: sin Skeleton3D bajo el player; el aura del brazo no se adjunta.")
		return
	var attach := BoneAttachment3D.new()
	attach.name = "ArmVfxAttachment"
	skeleton.add_child(attach)
	attach.bone_name = tuning.vfx_aura_bone
	var aura := tuning.vfx_scene.instantiate()
	attach.add_child(aura)
	if aura is Node3D:
		var n := aura as Node3D
		n.position = tuning.vfx_aura_offset
		n.scale = Vector3.ONE * tuning.vfx_aura_scale
	VfxInjector.apply_look(aura, tuning.vfx_tint, tuning.vfx_primary_color,
			tuning.vfx_secondary_color, tuning.vfx_emission)
	VfxInjector.play(aura, true)

func _find_skeleton(root: Node) -> Skeleton3D:
	if root == null:
		return null
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

## Un tap de combate no pega mas rapido que `tuning.tap_cadence`: si todavia no toca, se guarda
## en `_pending_taps` en vez de perderse (ver _flush_tap_buffer), capado por el margen que quede
## antes de max_taps. El traversal (bloques) no pasa por la cola: no tiene sentido encolar
## teletransportes, ya tiene su propio cooldown corto.
func _try_tap() -> void:
	var target := _resolve_target()
	if target != null:
		if _taps_used + _pending_taps >= tuning.max_taps:
			return  # reserva agotada (o comprometida por la cola): el apreton se pierde
		if _pending_taps == 0 and World.now() >= _next_tap_ready_at:
			_fire_tap(target)
		else:
			_pending_taps += 1  # sin _notify_taps: el icono se apaga cuando el golpe SALE
		return
	var block := _nearest_dash_block()
	if block != null:
		_teleport_and_activate(block)
	# sin enemigo ni bloque marcado: apreton gratis, no gasta carga

func _fire_tap(target: EnemyBase) -> void:
	_next_tap_ready_at = World.now() + tuning.tap_cadence
	_tap_enemy(target)

func _tap_enemy(target: EnemyBase) -> void:
	if _taps_used >= tuning.max_taps:
		return  # sin margen: la recuperacion la hace _refresh_regen, no este camino

	# Se gasta el tap ACA (antes del await): si no, taps mas rapidos que travel_time se
	# colarian todos antes de que el primero llegue a incrementar el contador.
	_taps_used += 1
	if _taps_used == 1:
		# Se acaba de romper el full: arranca el reloj de regeneracion. Los gastos siguientes NO lo
		# reinician — si no, mashear congelaba la recarga y volvia a ser un bloqueo por agotamiento.
		_regen_at = World.now() + tuning.cooldown_duration
	_notify_taps()

	_swing_id += 1
	var id := _swing_id
	_hitbox.global_position = target.global_position
	_hitbox.begin_swing()
	await get_tree().create_timer(maxf(0.01, tuning.travel_time)).timeout
	if id == _swing_id:
		_hitbox.end_swing()

## Empuja al jugador hacia el bloque de dash marcado (dash forzado, ver PlayerDash.force_dash,
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
	if is_instance_valid(block):  # el bloque puede morir durante el viaje
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

## Mismo target que el snap del golpe normal sin lock (ver PlayerLocomotion): lockeado si hay
## uno, si no el enemigo mas centrado en el cono de mira.
func _resolve_target() -> EnemyBase:
	if _player.lock_on.is_locked:
		return _player.lock_on.current_target
	return _player.lock_on.nearest_in_cone(_player.forward())

func _on_hit(hurtbox: Hurtbox, _died: bool) -> void:
	# Reaccion aerea propia del Brazo: hang corto (Floater de hold total) + freno del momentum
	# horizontal (decelera cada golpe). El guard de is_on_floor vive en Player.register_arm_air_hit;
	# is_airborne evita el passthrough en el caso terrestre.
	if _player.is_airborne():
		_player.register_arm_air_hit(tuning.air_hang_duration, tuning.air_horizontal_keep)
	if _player.meter != null:
		_player.meter.gain_bars(tuning.meter_gain_on_hit)
	_spawn_impact_vfx(hurtbox)

## Mismo VFX que el aura, pero one-shot y clavado en el punto de impacto (se agrega al mundo, no
## al brazo, para que se quede quieto). Se auto-libera al terminar. Solo visual.
func _spawn_impact_vfx(hurtbox: Hurtbox) -> void:
	var at := hurtbox.global_position if hurtbox != null else _hitbox.global_position
	VfxInjector.spawn_impact(tuning.vfx_scene, _player.get_parent(), at, tuning.vfx_impact_scale,
			tuning.vfx_tint, tuning.vfx_primary_color, tuning.vfx_secondary_color,
			tuning.vfx_emission)
