class_name PlayerEnemyBounce extends Node
## Rebote manual desde contactos fisicos con enemigos. Player orquesta el input; este modulo
## recuerda el ultimo contacto valido y decide el impulso cuando el jugador pide salto.

var _body: Player
var _last_enemy: Node
var _last_normal := Vector3.ZERO
var _contact_speed := 0.0
var _last_contact_time := -999.0
# El enemigo rebotado se recuerda por instance_id, no por referencia: muere y se libera
# (EnemyBase._die) mientras el cooldown sigue corriendo.
var _last_bounced_id := 0
var _last_bounce_time := -999.0
var _move_lock_until := -999.0

func setup(body: Player) -> void:
	_body = body

func update_after_move(horizontal_velocity: Vector3) -> void:
	if _body == null:
		return
	var contact_speed := Vector3(horizontal_velocity.x, 0.0, horizontal_velocity.z).length()
	for index in range(_body.get_slide_collision_count()):
		var collision := _body.get_slide_collision(index)
		if collision == null:
			continue
		var collider := collision.get_collider() as Node
		if _remember_contact_if_enemy(collider, collision.get_normal(), contact_speed):
			return

func try_bounce(input_dir: Vector3) -> bool:
	# Un Mover EXCLUSIVO (launcher/dash) bloquea el rebote; el NO-EXCLUSIVO (plunge) NO: rebotar en un
	# enemigo es justamente la cancelación del plunge (ver Player.cancel_plunge en _on_jump).
	if _body == null or World.on_solid_floor(_body) or _body.dash.is_dashing:
		return false
	if _body.mover.is_moving() and _body.mover.is_exclusive():
		return false
	if World.now() - _last_contact_time > _body.tuning.enemy_bounce_grace:
		return false
	if not is_instance_valid(_last_enemy):
		return false
	if _last_enemy.get_instance_id() == _last_bounced_id \
			and World.now() - _last_bounce_time < _body.tuning.enemy_bounce_cooldown:
		return false

	var t := _body.tuning
	var flat := Vector3(_last_normal.x, 0.0, _last_normal.z)
	_mark_bounced()

	# Stomp: no hay impulso horizontal que proteger, asi que tampoco se bloquea el input.
	if flat.length_squared() < 0.0001:
		_body.set_momentum(Vector3.ZERO)
		_body.vertical_velocity = t.enemy_bounce_up_speed
		_body.air_state = Player.AirState.AIRBORNE
		return true

	_move_lock_until = World.now() + t.enemy_bounce_lock_time
	flat = flat.normalized()
	var tangent := input_dir
	tangent.y = 0.0
	tangent = tangent.slide(flat)
	if tangent.length_squared() > 0.0001:
		tangent = tangent.normalized() * t.enemy_bounce_along_speed
	else:
		tangent = Vector3.ZERO

	var dir := flat * t.enemy_bounce_away_speed + tangent
	var carried := dir.normalized() * (_contact_speed * t.enemy_bounce_momentum_keep)
	_body.set_momentum(dir + carried)
	_body.vertical_velocity = t.enemy_bounce_up_speed
	_body.air_state = Player.AirState.AIRBORNE
	_react(flat)
	return true

func blocks_move_input() -> bool:
	return _body != null and World.now() < _move_lock_until and not _body.is_on_floor()

func cancel() -> void:
	_last_enemy = null
	_last_normal = Vector3.ZERO
	_contact_speed = 0.0
	_last_contact_time = -999.0
	_move_lock_until = -999.0

func _remember_contact_if_enemy(collider: Node, normal: Vector3, contact_speed: float) -> bool:
	var collision_object := collider as CollisionObject3D
	if collision_object == null or (collision_object.collision_layer & World.LAYER_ENEMY) == 0:
		return false
	_last_enemy = collider
	_last_normal = normal
	_contact_speed = contact_speed
	_last_contact_time = World.now()
	return true

func _mark_bounced() -> void:
	_last_bounced_id = _last_enemy.get_instance_id()
	_last_bounce_time = World.now()

## `away` es la normal aplanada y normalizada: la direccion en la que sale el jugador.
func _react(away: Vector3) -> void:
	var settings: PushSettings = _body.tuning.enemy_bounce_push
	if settings == null:
		return
	if is_instance_valid(_last_enemy) and _last_enemy.has_method("push"):
		_last_enemy.call("push", -away, settings)
