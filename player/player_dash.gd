class_name PlayerDash extends Node3D
## Bloque (ex PlayerDash.cs): dash terrestre/aéreo + boost de momentum + dash ofensivo.
## El daño vive AQUÍ (Hitbox esférico hijo), no en el glue: el dash es la única mecánica
## de movimiento que toca combate, así que ese acoplamiento queda contenido en este bloque.
## v2: atravesar enemigos = quitar la capa enemy del collision_mask durante el dash
## (reemplaza el hack de Physics.IgnoreCollision de v1).

var is_dashing := false

var _body: Player
var _loco: PlayerLocomotion
var _register_air_hit_stall: Callable
var _cancel_controlled_movement: Callable
var _can_airdash := true
var _dash_dir := Vector3.ZERO
var _timer := 0.0
var _active_distance := 0.01
var _active_duration := 0.01

@onready var _hitbox: Hitbox = $DashHitbox
@onready var _hitbox_shape: CollisionShape3D = $DashHitbox/CollisionShape3D

func setup(body: Player, loco: PlayerLocomotion, register_air_hit_stall: Callable,
		cancel_controlled_movement: Callable) -> void:
	_body = body
	_loco = loco
	_register_air_hit_stall = register_air_hit_stall
	_cancel_controlled_movement = cancel_controlled_movement
	var t := body.tuning
	_hitbox.source = body
	_hitbox.damage = t.dash_damage
	_hitbox.stun = t.dash_stun
	_hitbox.can_be_parried = false  # el dash nunca se parria (solo la espada)
	(_hitbox_shape.shape as SphereShape3D).radius = t.dash_hit_radius
	_hitbox.landed.connect(_on_dash_hit)

func restore_airdash() -> void:
	_can_airdash = true

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
		_can_airdash = false
	# El dodge golpea SOLO si había barra: spend_dash devuelve si alcanzaba el coste
	# (igual mueve sin barra, solo que sin daño).
	var had_bar := _body.meter != null and _body.meter.spend_dash()

	var input := _loco.read_move_input()
	var camera_dir := _loco.camera_relative(input)
	if _loco.has_move_input(input):
		_dash_dir = _loco.movement_direction(input, camera_dir).normalized()
	else:
		_dash_dir = _body.forward()
	_start_dash(_dash_dir, _body.tuning.dash_distance, _body.tuning.dash_duration, true, false,
			had_bar and _body.tuning.dash_deals_damage)

## Dash dirigido por otra mecánica (ej: el dash cargado de la espada). SOLO movimiento: el
## daño de esos dashes lo pone su propio hitbox (no el del dodge). Ver Sword._run_charged_dash_window.
func force_dash(dir: Vector3, distance: float, duration: float, boost_bump_momentum: bool) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = _body.forward()
	_start_dash(dir.normalized(), distance, duration, boost_bump_momentum, true, false)

func tick(delta: float) -> void:
	_timer -= delta
	var speed := _active_distance / _active_duration
	# El hitbox acompaña el dash: offset vertical + adelante en la dirección del dash (local).
	_hitbox.position = Vector3.UP * _body.tuning.dash_hit_vertical_offset \
			+ _body.global_basis.inverse() * (_dash_dir * _body.tuning.dash_hit_forward_offset)
	_body.velocity = _dash_dir * speed + _body.bump_velocity
	_body.move_and_slide()
	if _timer <= 0.0:
		_end_dash()

func _start_dash(dir: Vector3, distance: float, duration: float, boost_bump_momentum: bool,
		cancel_controlled: bool, deal_damage: bool) -> void:
	if cancel_controlled:
		_cancel_controlled_movement.call()
	_dash_dir = dir
	_active_distance = maxf(0.01, distance)
	_active_duration = maxf(0.01, duration)
	if boost_bump_momentum:
		_boost_bump_momentum()
	is_dashing = true
	_timer = _active_duration
	_body.collision_mask &= ~World.LAYER_ENEMY  # atraviesa enemigos durante el dash
	if deal_damage:
		_hitbox.begin_swing()

func _end_dash() -> void:
	is_dashing = false
	_hitbox.end_swing()
	_body.collision_mask |= World.LAYER_ENEMY

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
	_body.bump_velocity = _dash_dir * boosted

func _on_dash_hit(hurtbox: Hurtbox, _died: bool) -> void:
	if hurtbox.triggers_air_hit_stall:
		_register_air_hit_stall.call()
