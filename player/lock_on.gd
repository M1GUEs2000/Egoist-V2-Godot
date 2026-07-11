class_name LockOn extends Node3D
## Lock-on direccional tipo Hades + reticle (ex LockOnTargeting.cs): sin cono físico ni
## raycasts, solo math en el plano XZ sobre el grupo "enemy". La mira se cuantiza a 16
## direcciones (cada 22.5°) para que el apuntado se sienta discreto.
## El target se recalcula siempre (para que el ataque oriente desde el primer golpe);
## el reticle solo se muestra cuando el jugador tiene las armas afuera.

const DIRECTIONS := 16

var current_target: EnemyBase = null

var _body: Player
var _aim_direction := Vector3.FORWARD

@onready var _reticle: MeshInstance3D = $Reticle

func setup(body: Player) -> void:
	_body = body
	_aim_direction = body.forward()
	_reticle.visible = false

## Target visible (reticle sobre cabeza) solo con armas afuera, si el tuning lo exige.
func has_visible_target() -> bool:
	return current_target != null and _is_weapons_out()

## Setea la mira (compartida con el input de movimiento, ver PlayerLocomotion.tick).
func set_aim_direction(aim_direction: Vector3) -> void:
	aim_direction.y = 0.0
	if aim_direction.length_squared() < 0.0001:
		return
	_aim_direction = aim_direction.normalized()

## El enemigo más cercano dentro del cono de la mira (cuantizada a 16 direcciones).
func acquire_target(aim_direction: Vector3) -> EnemyBase:
	current_target = _find_best_target(aim_direction)
	return current_target

func _process(_delta: float) -> void:
	if _body == null:
		return
	acquire_target(_aim_direction)
	var show := has_visible_target()
	_reticle.visible = show
	if show:
		_reticle.global_position = _reticle_position(current_target)

func _is_weapons_out() -> bool:
	return not _body.tuning.lock_require_weapons_out or _body.combat.weapons_out()

func _find_best_target(aim_direction: Vector3) -> EnemyBase:
	var aim := _quantize(aim_direction)
	var best: EnemyBase = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as EnemyBase
		if enemy == null or not enemy.can_receive_hit():
			continue
		var to := enemy.global_position - _body.global_position
		to.y = 0.0
		var dist := to.length()
		if dist > _body.tuning.lock_max_range or dist < 0.01:
			continue
		if rad_to_deg(aim.angle_to(to)) > _body.tuning.lock_half_angle:
			continue
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best

## Cuantiza una dirección del plano XZ a la más cercana de 16 (cada 22.5°). Round-trip
## atan2/sin/cos: solo necesita ser autoconsistente, no depende de la convención de "forward".
static func _quantize(dir: Vector3) -> Vector3:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return Vector3.FORWARD
	var step := TAU / DIRECTIONS
	var angle := roundf(atan2(dir.x, dir.z) / step) * step
	return Vector3(sin(angle), 0.0, cos(angle))

## Centro sobre la cabeza: AABB combinado de los MeshInstance3D del target (fallback:
## su global_position + offset si no tiene mallas visibles).
func _reticle_position(target: EnemyBase) -> Vector3:
	var found := false
	var combined := AABB()
	for mesh in target.find_children("*", "MeshInstance3D", true):
		var mesh_instance := mesh as MeshInstance3D
		if mesh_instance == null or not mesh_instance.is_visible_in_tree():
			continue
		var box: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		combined = box if not found else combined.merge(box)
		found = true
	var height := _body.tuning.lock_reticle_height
	if found:
		var top := combined.position.y + combined.size.y
		var center := combined.get_center()
		return Vector3(center.x, top + height, center.z)
	return target.global_position + Vector3.UP * height
