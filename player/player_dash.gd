class_name PlayerDash extends Node3D
## Bloque (ex PlayerDash.cs): dash terrestre/aéreo + boost de momentum + dash ofensivo.
## El daño vive AQUÍ (Hitbox esférico hijo), no en el glue: el dash es la única mecánica
## de movimiento que toca combate, así que ese acoplamiento queda contenido en este bloque.
## v2: SOLO el dash ofensivo (force_dash, ej. el cargado de la espada) atraviesa enemigos
## quitando la capa enemy del collision_mask (reemplaza el hack de Physics.IgnoreCollision
## de v1). El dodge de esquivar choca con enemigos y objetos, no los traspasa.

signal airdash_changed(available: bool)

var is_dashing := false

var _body: Player
var _loco: PlayerLocomotion
var _cancel_controlled_movement: Callable
var _can_airdash := true
var _dash_dir := Vector3.ZERO
var _timer := 0.0
var _active_distance := 0.01
var _active_duration := 0.01
var _iframe_timer := 0.0
var _exit_bop_velocity := Vector3.ZERO
var _exit_bop_vertical_speed := 0.0

@onready var _hitbox: Hitbox = $DashHitbox
@onready var _hitbox_shape: CollisionShape3D = $DashHitbox/CollisionShape3D
@onready var _particles: GPUParticles3D = get_node_or_null("DashParticles") as GPUParticles3D

func setup(body: Player, loco: PlayerLocomotion, cancel_controlled_movement: Callable) -> void:
	_body = body
	_loco = loco
	_cancel_controlled_movement = cancel_controlled_movement
	var t := body.tuning
	_hitbox.source = body
	_hitbox.damage = t.dash_damage
	var no_stun := StunSettings.new()
	no_stun.grounded = 0.0
	no_stun.airborne = 0.0
	_hitbox.stun = no_stun
	_hitbox.can_be_parried = false  # el dash nunca se parria (solo la espada)
	(_hitbox_shape.shape as SphereShape3D).radius = t.dash_hit_radius
	_hitbox.landed.connect(_on_dash_hit)
	_tint_particles_from_world()

## El color del dash vive en World (COLOR_TRAVERSAL_DASH), no en el .tscn: el material del
## emisor trae solo un preview de editor y acá se pinta desde la fuente única (ver Colores de mundo).
func _tint_particles_from_world() -> void:
	if _particles == null:
		return
	var mesh := _particles.draw_pass_1 as PrimitiveMesh
	if mesh == null:
		return
	var mat := mesh.material as StandardMaterial3D
	if mat == null:
		return
	mat.albedo_color = World.COLOR_TRAVERSAL_DASH
	if mat.emission_enabled:
		mat.emission = World.COLOR_TRAVERSAL_DASH_EMISSION

func restore_airdash() -> void:
	_set_airdash_available(true)

func can_airdash() -> bool:
	return _can_airdash

func cancel() -> void:
	if is_dashing:
		_end_dash()

## Esquiva del jugador (el dueño ya soltó el swing si lo había).
func dodge() -> void:
	_body.fire_action_world_switch()
	# En el aire: un solo airdash por salto. En el piso: dash libre.
	if not _body.is_on_floor():
		if not _can_airdash:
			return
		_set_airdash_available(false)
	# El dodge golpea SOLO si había barra: spend_dash devuelve si alcanzaba el coste
	# (igual mueve sin barra, solo que sin daño).
	var had_bar := _body.meter != null and _body.meter.spend_dash()

	var input := _loco.read_move_input()
	var camera_dir := _loco.camera_relative(input)
	if _loco.has_move_input(input):
		_dash_dir = _loco.movement_direction(input, camera_dir).normalized()
	else:
		_dash_dir = _body.forward()
	# Dodge: choca con enemigos y objetos (pass_through_enemies = false).
	_start_dash(_dash_dir, _body.tuning.dash_distance, _body.tuning.dash_duration, true, false,
			had_bar and _body.tuning.dash_deals_damage, false)
	# Clampeado a _active_duration: el timer de tick() solo corre mientras is_dashing, así que
	# un i-frame más largo que el dash nunca se apagaría solo.
	_iframe_timer = minf(_body.tuning.dodge_iframe_duration, _active_duration)

## Dash dirigido por otra mecánica (dash cargado de la espada, paso del Mazo, bloque verde).
## Por defecto SOLO movimiento; con `deals_damage` prende el DashHitbox propio del player y
## daña al atravesar (lo usa el bloque verde). Espada/Mazo lo dejan en false: su daño, si lo
## hay, lo pone su propio hitbox (ver Sword._run_charged_dash_window).
func force_dash(dir: Vector3, distance: float, duration: float, boost_bump_momentum: bool,
		deals_damage := false) -> void:
	if dir.length_squared() < 0.0001:
		dir = _body.forward()
	# Conserva Y: los bloques de traversal pueden orientar el dash hacia arriba o abajo.
	# Dash ofensivo: atraviesa enemigos, choca con objetos (pass_through_enemies = true).
	_start_dash(dir.normalized(), distance, duration, boost_bump_momentum, true, deals_damage, true)

## Impulso extra para el final del dash (ej. el bop de salida del bloque verde).
func set_exit_bop(dir: Vector3, forward_speed: float, vertical_speed: float) -> void:
	var horizontal_dir := Vector3(dir.x, 0.0, dir.z)
	_exit_bop_velocity = Vector3.ZERO
	if horizontal_dir.length_squared() > 0.0001:
		_exit_bop_velocity = horizontal_dir.normalized() * forward_speed
	_exit_bop_vertical_speed = vertical_speed

## I-frames del dodge de esquiva. force_dash (dash ofensivo) nunca los pide.
func is_invulnerable() -> bool:
	return _iframe_timer > 0.0

func tick(delta: float) -> void:
	_timer -= delta
	_iframe_timer -= delta
	var speed := _active_distance / _active_duration
	# El hitbox acompaña el dash: offset vertical + adelante en la dirección del dash (local).
	_hitbox.position = Vector3.UP * _body.tuning.dash_hit_vertical_offset \
			+ _body.global_basis.inverse() * (_dash_dir * _body.tuning.dash_hit_forward_offset)
	_body.velocity = _dash_dir * speed + _body.bump_velocity
	_body.move_and_slide()
	if _timer <= 0.0:
		_end_dash(true)

func _start_dash(dir: Vector3, distance: float, duration: float, boost_bump_momentum: bool,
		cancel_controlled: bool, deal_damage: bool, pass_through_enemies: bool) -> void:
	if cancel_controlled:
		_cancel_controlled_movement.call()
	# El dash borra la caída acumulada: sin esto, Player.vertical_velocity sobrevive al dash
	# y al salir seguís cayendo a la velocidad que traías antes de entrar.
	_body.vertical_velocity = 0.0
	_exit_bop_velocity = Vector3.ZERO
	_exit_bop_vertical_speed = 0.0
	_dash_dir = dir
	_active_distance = maxf(0.01, distance)
	_active_duration = maxf(0.01, duration)
	if boost_bump_momentum:
		_boost_bump_momentum()
	is_dashing = true
	_timer = _active_duration
	if pass_through_enemies:
		_body.collision_mask &= ~World.LAYER_ENEMY  # solo el dash ofensivo atraviesa enemigos
	if deal_damage:
		_hitbox.begin_swing()
	_set_particles(true)

func _end_dash(apply_exit_bop := false) -> void:
	is_dashing = false
	_iframe_timer = 0.0
	_hitbox.end_swing()
	_body.collision_mask |= World.LAYER_ENEMY
	_set_particles(false)
	# Continuidad post-dash: la inercia aérea del input queda apuntando a la salida del dash
	# a velocidad de carrera (el exceso, si lo hubo, ya vive en bump por el boost de momentum).
	_loco.set_air_velocity(_dash_dir * _body.tuning.move_speed)
	if apply_exit_bop:
		_apply_exit_bop()
	else:
		_exit_bop_velocity = Vector3.ZERO
		_exit_bop_vertical_speed = 0.0

func _apply_exit_bop() -> void:
	var has_bop := _exit_bop_velocity.length_squared() > 0.0001 \
			or absf(_exit_bop_vertical_speed) > 0.0001
	if _exit_bop_velocity.length_squared() > 0.0001:
		_body.add_momentum(_exit_bop_velocity)
	if absf(_exit_bop_vertical_speed) > 0.0001:
		_body.vertical_velocity = _exit_bop_vertical_speed
		_body.air_state = Player.AirState.AIRBORNE
	if has_bop:
		_burst_exit_bop()
	_exit_bop_velocity = Vector3.ZERO
	_exit_bop_vertical_speed = 0.0

## Estallido verde en el momento en que el bop del bloque verde empuja al player (color del dash
## desde World, no hardcodeado). Se cuelga del padre del player para sobrevivir al frame.
func _burst_exit_bop() -> void:
	var t := _body.tuning
	if not t.dash_bop_burst_enabled:
		return
	var host := _body.get_parent()
	if host == null:
		host = _body
	World.spawn_color_burst(host, _body.global_position + Vector3.UP,
			World.COLOR_TRAVERSAL_DASH, World.COLOR_TRAVERSAL_DASH_EMISSION,
			t.dash_bop_burst_amount, t.dash_bop_burst_speed, t.dash_bop_burst_gravity,
			t.dash_bop_burst_lifetime, t.dash_bop_burst_size)

func _set_particles(active: bool) -> void:
	if _particles != null and _particles.emitting != active:
		_particles.emitting = active

func _boost_bump_momentum() -> void:
	var horizontal := Vector3(_body.bump_velocity.x, 0.0, _body.bump_velocity.z)
	if horizontal.length_squared() < 0.01:
		return
	var t := _body.tuning
	var dash_speed := _active_distance / maxf(0.01, _active_duration)
	var boosted := minf(
		t.dash_bump_max_speed,
		horizontal.length() * t.dash_bump_momentum_multiplier
			+ dash_speed * t.dash_bump_dash_speed_multiplier
	)
	_body.set_momentum(_dash_dir * boosted)

## Golpe del dash ofensivo: frena la caida, pero NO le come el momentum horizontal — el
## desplazamiento del dash es el move; el impacto pide su Float sin cortar momentum horizontal.
func _on_dash_hit(hurtbox: Hurtbox, _died: bool) -> void:
	if hurtbox.triggers_air_hit_stall:
		_body.request_float(
				_body.tuning.dash_air_hit_float_duration,
				_body.tuning.dash_air_hit_float_fall_scale)

func _set_airdash_available(available: bool) -> void:
	if _can_airdash == available:
		return
	_can_airdash = available
	airdash_changed.emit(_can_airdash)
