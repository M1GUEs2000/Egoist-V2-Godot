class_name Projectile extends Area3D
## Proyectil aislado: viaja, homing opcional, ignora al tirador y aplica dano.

var _speed := 0.0
var _turn_rate := 0.0
var _damage := 0.0
var _stun: StunSettings
var _player_stun_push_speed := 0.0
var _player_stun_push_vertical_speed := 0.0
var _die_at := -999.0
var _velocity := Vector3.ZERO
var _target: Node3D
var _shooter: Node3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = World.LAYER_PLAYER | World.LAYER_ENEMY | World.LAYER_HURTBOX | World.LAYER_WORLD
	monitorable = false
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func launch(origin: Vector3, direction: Vector3, target: Node3D, shooter: Node3D,
		speed: float, turn_rate: float, damage: float, lifetime: float, stun: StunSettings = null,
		player_stun_push_speed := 0.0, player_stun_push_vertical_speed := 0.0) -> void:
	global_position = origin
	_target = target
	_shooter = shooter
	_speed = speed
	_turn_rate = turn_rate
	_damage = damage
	_stun = stun
	_player_stun_push_speed = player_stun_push_speed
	_player_stun_push_vertical_speed = player_stun_push_vertical_speed
	_velocity = direction.normalized() * speed
	_die_at = World.now() + lifetime
	if _velocity.length_squared() > 0.0001:
		look_at(global_position + _velocity.normalized(), Vector3.UP)

func _physics_process(delta: float) -> void:
	if World.now() >= _die_at:
		queue_free()
		return
	if _target != null and _turn_rate > 0.0:
		var desired := (_target.global_position + Vector3.UP * 0.8) - global_position
		if desired.length_squared() > 0.0001:
			var new_dir := _velocity.normalized().slerp(desired.normalized(), clampf(deg_to_rad(_turn_rate) * delta, 0.0, 1.0))
			_velocity = new_dir.normalized() * _speed
	global_position += _velocity * delta
	if _velocity.length_squared() > 0.0001:
		look_at(global_position + _velocity.normalized(), Vector3.UP)

func _on_body_entered(body: Node3D) -> void:
	if _is_shooter(body):
		return
	if body.has_method("take_damage"):
		body.call("take_damage", _damage)
		if _stun != null and body.has_method("receive_stun"):
			if body is Player:
				var impact_dir := _velocity
				impact_dir.y = 0.0
				body.receive_stun(
						_stun,
						PlayerStun.Mode.PUSH,
						impact_dir.normalized() if impact_dir.length_squared() > 0.0001 else _velocity.normalized(),
						_player_stun_push_speed,
						_player_stun_push_vertical_speed)
			else:
				body.call("receive_stun", _stun)
		queue_free()
	elif body is EnemyBase:
		(body as EnemyBase).take_hit_from_enemy(1.0, _velocity.normalized(), _stun)
		queue_free()
	else:
		var collider := body as CollisionObject3D
		if collider != null and collider.collision_layer & World.LAYER_WORLD:
			queue_free()

func _on_area_entered(area: Area3D) -> void:
	if _is_shooter(area):
		return
	var hurtbox := area as Hurtbox
	if hurtbox == null:
		return
	var amount := 1.0 if hurtbox.owner_node is EnemyBase else _damage
	hurtbox.receive_hit(_shooter, amount, _velocity.normalized(), _stun)
	queue_free()

func _is_shooter(node: Node) -> bool:
	if _shooter == null or node == null:
		return false
	return node == _shooter or _shooter.is_ancestor_of(node)
