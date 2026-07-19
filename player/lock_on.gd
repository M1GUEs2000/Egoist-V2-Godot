class_name LockOn extends Node3D
## Lock-on por botón tipo Dark Souls (ex sistema direccional tipo Hades). `toggle_lock()`
## ancla un target persistente (el más centrado en cámara, dentro de rango/cono) que ya no se
## recalcula solo — se suelta con el mismo botón o si el target muere/sale de rango.
## `cycle_target()` cambia entre targets en rango con camera_left/camera_right mientras hay
## lock activo (ver Player._unhandled_input; CameraRig deja de rotar libre mientras is_locked).
## El reticle solo se muestra con armas afuera, igual que antes.

var current_target: EnemyBase = null
var is_locked := false

var _body: Player
var _cam: Camera3D

@onready var _reticle: MeshInstance3D = $Reticle
@onready var _reticle_material: ShaderMaterial = _reticle.get_surface_override_material(0)
@onready var _target_landing: LandingIndicator = $TargetLandingIndicator

func setup(body: Player, cam: Camera3D) -> void:
	_body = body
	_cam = cam
	_reticle.visible = false
	_reticle_material.set_shader_parameter("fill", 1.0)
	_target_landing.enabled = false

## Target visible (reticle sobre cabeza) solo con lock activo y armas afuera si el tuning lo exige.
func has_visible_target() -> bool:
	return is_locked and current_target != null and _is_weapons_out()

## Ancla/suelta el lock-on. Al anclar, elige el enemigo más centrado en cámara dentro de
## rango/cono (ver `_best_camera_target`).
func toggle_lock() -> void:
	if is_locked:
		_release()
	else:
		_acquire()

## Cambia el target lockeado al vecino en rango, ordenado izquierda→derecha respecto a cámara.
## `direction`: -1 (camera_left) o +1 (camera_right).
func cycle_target(direction: int) -> void:
	if not is_locked or current_target == null:
		return
	var candidates := _targets_in_range()
	if candidates.size() <= 1:
		return
	var cam_fwd := _camera_forward()
	var cam_right := _camera_right()
	candidates.sort_custom(func(a: EnemyBase, b: EnemyBase) -> bool:
		return _screen_angle(a, cam_fwd, cam_right) < _screen_angle(b, cam_fwd, cam_right))
	var idx := candidates.find(current_target)
	if idx == -1:
		return
	current_target = candidates[wrapi(idx + direction, 0, candidates.size())]

## Enemigo más cercano dentro del cono de `direction` (rango + ángulo horizontal/vertical),
## SIN tocar el lock activo. Lo usa PlayerLocomotion para el snap del golpe cuando no hay lock.
##
## Acá el cono SÍ nace en el jugador y se mide contra un eje del jugador (`direction`), así que los
## dos marcos coinciden y la geometría es correcta. Por eso usa sus propios tuneables
## (`attack_snap_half_angle`/`lock_vertical_half_angle`) y no los del lock-on, que vive en el marco
## de la cámara: compartirlos hacía que recalibrar uno rompiera el feel del otro.
func nearest_in_cone(direction: Vector3) -> EnemyBase:
	var dir := direction
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return null
	dir = dir.normalized()
	var best: EnemyBase = null
	var best_dist := INF
	for enemy in _targets_in_range():
		var to := enemy.global_position - _body.global_position
		var horiz := to
		horiz.y = 0.0
		var horiz_dist := horiz.length()
		if horiz_dist < 0.01:
			continue
		if rad_to_deg(dir.angle_to(horiz)) > _body.tuning.attack_snap_half_angle:
			continue
		var vertical_angle := rad_to_deg(atan2(to.y, horiz_dist))
		if absf(vertical_angle) > _body.tuning.lock_vertical_half_angle:
			continue
		var dist := to.length()
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best

func _process(_delta: float) -> void:
	if _body == null:
		return
	if is_locked and not _target_still_valid(current_target):
		_release()
	var show := has_visible_target()
	_reticle.visible = show
	# El ring de aterrizaje del target reusa LandingIndicator: solo se muestra mientras
	# hay lock-on activo (el propio LandingIndicator filtra si el target no esta en el aire).
	_target_landing.enabled = show
	_target_landing.source = current_target
	if show:
		_reticle.global_position = head_position(current_target)
		_reticle_material.set_shader_parameter("fill", _target_health_ratio(current_target))

## Fraccion de vida restante del target (1 = intacto, 0 = a punto de morir). El shader del
## reticle usa esto para "vaciar" la dona a medida que se le pega (ver reticle_fill.gdshader).
func _target_health_ratio(target: EnemyBase) -> float:
	if target.health == null or target.health.max_health <= 0.0:
		return 1.0
	return clampf(target.health.current / target.health.max_health, 0.0, 1.0)

func _is_weapons_out() -> bool:
	return not _body.tuning.lock_require_weapons_out or _body.combat.weapons_out()

func _acquire() -> void:
	var best := _best_camera_target()
	if best == null:
		return
	current_target = best
	is_locked = true

func _release() -> void:
	is_locked = false
	current_target = null

func _target_still_valid(target: EnemyBase) -> bool:
	if target == null or not is_instance_valid(target) or not target.can_receive_hit():
		return false
	return (target.global_position - _body.global_position).length() <= _body.tuning.lock_max_range

## El enemigo en rango más centrado en PANTALLA: "lockea lo que estás mirando".
##
## El ángulo se mide desde la POSICIÓN de la cámara contra su forward 3D, así que equivale a la
## distancia angular al centro del viewport (la cámara hace look_at del jugador, ver CameraRig),
## y `lock_half_angle` es un cono circular alrededor de ese centro.
##
## Antes el vector nacía en el jugador pero se comparaba contra el eje de la cámara: dos marcos
## de referencia distintos mezclados. Como la cámara mira al jugador desde atrás y arriba, todo
## enemigo que apareciera a los costados o por debajo del jugador en pantalla daba >90° y se
## descartaba — con half_angle 60 quedaba lockeable solo el 34% del plano alrededor del jugador,
## y ningún valor arreglaba eso porque la magnitud medida no era "qué tan centrado está".
func _best_camera_target() -> EnemyBase:
	# Sin Camera3D (smokes/probes) se cae al marco del jugador: origen y eje coherentes entre sí.
	var origin := _cam.global_position if _cam != null else _body.global_position
	var fwd := -_cam.global_basis.z if _cam != null else _body.forward()
	var best: EnemyBase = null
	var best_angle := INF
	for enemy in _targets_in_range():
		var to := enemy.global_position - origin
		if to.length_squared() < 0.0001:
			continue
		var angle := rad_to_deg(fwd.angle_to(to))
		if angle > _body.tuning.lock_half_angle:
			continue
		if angle < best_angle:
			best_angle = angle
			best = enemy
	return best

## Enemigos vivos dentro de `lock_max_range`, sin filtro de ángulo (lo usan tanto la
## adquisición inicial como el ciclado, que sí puede saltar a algo fuera del cono original).
func _targets_in_range() -> Array[EnemyBase]:
	var result: Array[EnemyBase] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as EnemyBase
		if enemy == null or not enemy.can_receive_hit():
			continue
		if (enemy.global_position - _body.global_position).length() > _body.tuning.lock_max_range:
			continue
		result.append(enemy)
	return result

func _screen_angle(enemy: EnemyBase, cam_fwd: Vector3, cam_right: Vector3) -> float:
	var to := enemy.global_position - _body.global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return 0.0
	to = to.normalized()
	return atan2(to.dot(cam_right), to.dot(cam_fwd))

func _camera_forward() -> Vector3:
	if _cam == null:
		return _body.forward()
	var fwd := -_cam.global_basis.z
	fwd.y = 0.0
	return fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD

func _camera_right() -> Vector3:
	if _cam == null:
		return _body.global_basis.x
	var right := _cam.global_basis.x
	right.y = 0.0
	return right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT

## Centro sobre la cabeza: AABB combinado de los MeshInstance3D del target (fallback:
## su global_position + offset si no tiene mallas visibles). Publico: lo usa tambien el
## marcador liviano del Brazo (ver PlayerArm) para ubicarse en el mismo punto que el reticle.
func head_position(target: EnemyBase) -> Vector3:
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
