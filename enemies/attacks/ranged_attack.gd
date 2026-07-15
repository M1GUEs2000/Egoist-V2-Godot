class_name RangedAttack extends Node3D
## Ataque a distancia componible (ex RangedAttack.cs): apunta y dispara Projectile.

@export var attack_range := 10.0
@export var attack_cooldown := 2.0
@export var windup := 0.4
@export var projectile_speed := 10.0
@export var homing_turn_rate := 120.0
@export var projectile_damage := 10.0
@export var projectile_lifetime := 5.0
@export var muzzle_forward_offset := 0.8
@export var muzzle_height := 1.0
@export var projectile_scene: PackedScene
## Stun que recibe el objetivo al impactar. El receptor decide si entra por su threshold.
@export var stun: StunSettings
## Retroceso horizontal aplicado al player cuando este stun supera su threshold, en m/s.
@export var player_stun_push_speed := 4.0
## Impulso vertical aplicado al player durante el stun PUSH, en m/s.
@export var player_stun_push_vertical_speed := 0.0

var is_attacking := false

var _owner: EnemyBase
var _target: Node3D
var _last_attack := -999.0
var _routine_id := 0

func setup(owner: EnemyBase) -> void:
	_owner = owner

func try_attack(target: Node3D) -> void:
	if _owner == null or not _owner.can_attack() or is_attacking:
		return
	if World.now() - _last_attack < attack_cooldown:
		return
	_target = target
	_fire_routine()

func try_parry() -> bool:
	return false

func _fire_routine() -> void:
	is_attacking = true
	_routine_id += 1
	var id := _routine_id
	var elapsed := 0.0
	while elapsed < windup:
		if id != _routine_id or _owner == null or not _owner.can_attack():
			is_attacking = false
			return
		_face_target()
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
	if id == _routine_id:
		_fire()
	_last_attack = World.now()
	is_attacking = false

func _face_target() -> void:
	if _owner == null or _target == null:
		return
	var to := _target.global_position - _owner.global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		_owner.look_at(_owner.global_position + to.normalized(), Vector3.UP)

func _fire() -> void:
	if _owner == null:
		return
	var projectile := _build_projectile()
	var origin := _owner.global_position - _owner.global_basis.z * muzzle_forward_offset + Vector3.UP * muzzle_height
	var dir := -_owner.global_basis.z
	if _target != null:
		dir = ((_target.global_position + Vector3.UP * 0.8) - origin).normalized()
	var parent := get_tree().current_scene
	if parent == null:
		parent = _owner.get_parent()
	parent.add_child(projectile)
rr	projectile.launch(origin, dir, _target, _owner, projectile_speed, homing_turn_rate,
			projectile_damage, projectile_lifetime, stun, player_stun_push_speed,
			player_stun_push_vertical_speed)

func _build_projectile() -> Projectile:
	if projectile_scene != null:
		var inst := projectile_scene.instantiate() as Projectile
		if inst != null:
			return inst
	var projectile := Projectile.new()
	projectile.name = "Projectile"
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	shape.shape = sphere
	projectile.add_child(shape)
	var mesh := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.25
	sphere_mesh.height = 0.5
	mesh.mesh = sphere_mesh
	projectile.add_child(mesh)
	return projectile
