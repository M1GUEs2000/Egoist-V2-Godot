class_name Projectile extends Area3D
## Proyectil aislado: viaja, homing opcional, ignora al tirador y aplica dano.
##
## Parryable: el arma del player lo puede deflectar mid-flight (ver try_parry). El deflect es PURO —
## da vuelta el proyectil contra quien lo tiro y nada mas; no abre el estado VULNERABLE cian del
## parry melee. El castigo sale del propio impacto: al llegarle, el tirador come el dano y el stun
## de su tiro por el pipeline de poise de siempre. Knobs en data/deflect_tuning.tres.

## Variante de world switch: si pega al jugador, voltea el mundo de todos ademas del dano.
@export var world_switch_on_player_hit := false
## Si false el proyectil no se puede parriar: no arma su hurtbox y el arma del player lo atraviesa.
@export var parryable := true
## Que le pasa al proyectil al ser parriado. Si es null se carga el .tres compartido en _ready.
@export var deflect_tuning: DeflectTuning

var _speed := 0.0
var _turn_rate := 0.0
var _damage := 0.0
## Golpes que le saca a un EnemyBase (su vida se mide en hits, no en el _damage del player).
var _enemy_hits := 1.0
var _stun: StunSettings
var _player_stun_push_speed := 0.0
var _player_stun_push_vertical_speed := 0.0
var _die_at := -999.0
var _velocity := Vector3.ZERO
var _target: Node3D
var _shooter: Node3D
var _deflected := false
var _hurtbox: Hurtbox

func _ready() -> void:
	collision_layer = 0
	collision_mask = World.LAYER_PLAYER | World.LAYER_ENEMY | World.LAYER_HURTBOX | World.LAYER_WORLD
	monitorable = false
	if deflect_tuning == null:
		deflect_tuning = load("res://data/deflect_tuning.tres") as DeflectTuning
	if deflect_tuning == null:
		deflect_tuning = DeflectTuning.new()  # fallback defensivo si falta el .tres
	_resolve_hurtbox()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

## El proyectil vive en collision_layer = 0: el Hitbox del arma (mask = LAYER_HURTBOX) no lo ve.
## Para que se pueda parriar necesita su propia superficie golpeable, y se arma por codigo porque
## los proyectiles se instancian por codigo (RangedAttack._build_projectile), no desde un .tscn.
## Si un projectile_scene ya trae su Hurtbox, se respeta ese.
func _resolve_hurtbox() -> void:
	for child in get_children():
		if child is Hurtbox:
			_hurtbox = child as Hurtbox
			return
	if not parryable:
		return
	var sphere := SphereShape3D.new()
	sphere.radius = deflect_tuning.hurtbox_radius
	var shape := CollisionShape3D.new()
	shape.shape = sphere
	_hurtbox = Hurtbox.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.add_child(shape)
	add_child(_hurtbox)

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
	_face_velocity()

## Lo pregunta el Hitbox del arma antes de aplicar dano (ver Hitbox._on_area_entered): true = golpe
## parriado, el arma no hace dano y el proyectil sigue vivo, ya redirigido. Solo el player deflecta —
## la hoja de un enemigo que roce el proyectil lo deja pasar — y solo una vez por proyectil.
func try_parry(source: Node, _hit_direction: Vector3 = Vector3.ZERO) -> bool:
	if not parryable or _deflected or not (source is Player):
		return false
	_deflect(source as Player)
	return true

## Da vuelta el proyectil: el player pasa a ser el tirador (y por eso lo empieza a ignorar) y el
## enemigo que lo disparo pasa a ser el objetivo del homing. Si el tirador ya murio, el rebote sale
## igual — de vuelta por donde vino, recto — en vez de comerse el parry sin efecto.
func _deflect(player: Player) -> void:
	var shooter := _shooter
	_deflected = true
	_shooter = player
	_target = shooter if is_instance_valid(shooter) else null
	_speed *= deflect_tuning.speed_multiplier
	_damage *= deflect_tuning.damage_multiplier
	_enemy_hits *= deflect_tuning.damage_multiplier
	_turn_rate = deflect_tuning.turn_rate
	_die_at = World.now() + deflect_tuning.lifetime
	var direction := -_velocity.normalized()
	if _target != null:
		var to_shooter := _aim_point(_target) - global_position
		if to_shooter.length_squared() > 0.0001:
			direction = to_shooter.normalized()
	_velocity = direction * _speed
	_face_velocity()

func _physics_process(delta: float) -> void:
	if World.now() >= _die_at:
		queue_free()
		return
	# is_instance_valid y no != null: tras un deflect el objetivo es el tirador, que puede morir
	# (o ser liberado) mientras el rebote viaja hacia el.
	if is_instance_valid(_target) and _turn_rate > 0.0:
		var desired := _aim_point(_target) - global_position
		if desired.length_squared() > 0.0001:
			var new_dir := _velocity.normalized().slerp(desired.normalized(), clampf(deg_to_rad(_turn_rate) * delta, 0.0, 1.0))
			_velocity = new_dir.normalized() * _speed
	global_position += _velocity * delta
	_face_velocity()

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
		if world_switch_on_player_hit and body is Player:
			WorldManager.switch_world(global_position)
		queue_free()
	elif body is EnemyBase:
		(body as EnemyBase).take_hit_from_enemy(_enemy_hits, _velocity.normalized(), _stun)
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
	if hurtbox.owner_node == self:
		return  # mi propia superficie parryable: el proyectil no se dispara a si mismo
	var amount := _enemy_hits if hurtbox.owner_node is EnemyBase else _damage
	hurtbox.receive_hit(_shooter, amount, _velocity.normalized(), _stun)
	queue_free()

func _is_shooter(node: Node) -> bool:
	if not is_instance_valid(_shooter) or node == null:
		return false
	return node == _shooter or _shooter.is_ancestor_of(node)

## Se apunta al torso, no a los pies: el origen del tiro tambien sale a la altura del pecho.
func _aim_point(node: Node3D) -> Vector3:
	return node.global_position + Vector3.UP * 0.8

func _face_velocity() -> void:
	if _velocity.length_squared() > 0.0001:
		look_at(global_position + _velocity.normalized(), Vector3.UP)
