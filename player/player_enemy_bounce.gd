class_name PlayerEnemyBounce extends Node
## Rebote manual sobre enemigos. El jugador no rebota por contacto: rebota al PEDIR salto dentro de
## una ventana breve tras entrar en la EnemyBounceHitbox del enemigo. La superficie se lee como
## impulso instantaneo.
##
## Este modulo recuerda el ultimo contacto valido y, al pedir salto, decide el impulso del jugador y
## la reaccion del enemigo. Player.\_on_jump orquesta el orden (suelo, wall jump, rebote, doble salto).

var _body: Player
var _enemy: Node
var _normal := Vector3.ZERO
var _contact_speed := 0.0
var _contact_time := -999.0
# El enemigo rebotado se recuerda por instance_id, no por referencia: muere y se libera
# (EnemyBase._die) mientras su cooldown sigue corriendo.
var _bounced_id := 0
var _bounce_time := -999.0
var _move_lock_until := -999.0

func setup(body: Player) -> void:
	_body = body

## La llama la caja del enemigo, cada frame mientras el jugador siga dentro.
func remember_contact(enemy: Node, normal: Vector3) -> void:
	if _body == null:
		return
	var speed := Vector3(_body.velocity.x, 0.0, _body.velocity.z).length()
	_remember_contact_if_enemy(enemy, normal, speed)

func try_bounce(input_dir: Vector3) -> bool:
	if not _can_bounce():
		return false
	var t := _body.tuning
	var flat := Vector3(_normal.x, 0.0, _normal.z)
	_bounced_id = _enemy.get_instance_id()
	_bounce_time = World.now()

	# Stomp: sin componente horizontal no hay impulso lateral que proteger, asi que tampoco se
	# bloquea el input de movimiento (bloquearlo solo quitaria control aereo).
	if flat.length_squared() < 0.0001:
		_body.set_momentum(Vector3.ZERO)
		_body.vertical_velocity = t.enemy_bounce_up_speed
		_body.air_state = Player.AirState.AIRBORNE
		_react(Vector3.ZERO)
		return true

	_move_lock_until = World.now() + t.enemy_bounce_lock_time
	flat = flat.normalized()
	var tangent := input_dir
	tangent.y = 0.0
	tangent = tangent.slide(flat)
	tangent = tangent.normalized() * t.enemy_bounce_along_speed \
			if tangent.length_squared() > 0.0001 else Vector3.ZERO

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
	_enemy = null
	_normal = Vector3.ZERO
	_contact_speed = 0.0
	_contact_time = -999.0
	_move_lock_until = -999.0

func _can_bounce() -> bool:
	# Un Mover EXCLUSIVO (launcher/dash) bloquea el rebote; el NO-EXCLUSIVO (plunge) NO: rebotar en
	# un enemigo es justamente la cancelacion del plunge (ver Player.cancel_plunge en _on_jump).
	if _body == null or World.on_solid_floor(_body) or _body.dash.is_dashing:
		return false
	if _body.mover.is_moving() and _body.mover.is_total():
		return false
	if World.now() - _contact_time > _body.tuning.enemy_bounce_grace:
		return false
	if not is_instance_valid(_enemy):
		return false
	# Cooldown contra el MISMO enemigo; encadenar enemigos distintos siempre se permite.
	return not (_enemy.get_instance_id() == _bounced_id \
			and World.now() - _bounce_time < _body.tuning.enemy_bounce_cooldown)

func _remember_contact_if_enemy(collider: Node, normal: Vector3, contact_speed: float) -> bool:
	var object := collider as CollisionObject3D
	if object == null or (object.collision_layer & World.LAYER_ENEMY) == 0:
		return false
	_enemy = collider
	_normal = normal
	_contact_speed = contact_speed
	_contact_time = World.now()
	return true

## Reaccion del enemigo: stun primero, push despues. Ese orden es obligatorio y es el mismo que usan
## las armas (ver EnemyBase.apply_spike_hit): `push()` solo desplaza si la reserva de poise quedo
## quebrada, asi que sin el stun previo el empujon se descarta entero y el enemigo aguanta plantado.
## El rebote pisa poise, nunca vida: no hace daño.
##
## `away` es la normal aplanada y normalizada — la direccion en la que sale el jugador. En un stomp
## viene en cero: no hay horizontal, asi que se stunea pero no se empuja.
func _react(away: Vector3) -> void:
	if not is_instance_valid(_enemy):
		return
	var stun: StunSettings = _body.tuning.enemy_bounce_stun
	if stun != null and _enemy.has_method("try_apply_stun"):
		_enemy.call("try_apply_stun", stun.duration_for(_enemy.is_airborne()), stun.poise_damage)
	if away.length_squared() < 0.0001:
		return
	var push: PushSettings = _body.tuning.enemy_bounce_push
	if push != null and _enemy.has_method("push"):
		_enemy.call("push", -away, push)
