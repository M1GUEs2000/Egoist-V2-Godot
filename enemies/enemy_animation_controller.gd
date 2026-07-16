extends Node
## Traduce el estado ya decidido por GroundedEnemy a los clips del maniqui UAL.
## No mueve al CharacterBody ni abre hitboxes: esas responsabilidades siguen en locomocion y ataques.

const UAL1_SCENE := preload("res://assets/animations/Universal Animation Library[Standard]/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb")
const UAL1_ANIMATIONS := [&"Idle", &"Walk", &"Jog_Fwd", &"Sprint", &"Roll", &"Death01"]

@export var moving_speed_threshold := 0.15
@export var idle_animation: StringName = &"Idle"
@export var roam_animation: StringName = &"Walk"
@export var chase_animation: StringName = &"Jog_Fwd"
@export var flee_animation: StringName = &"Sprint"
@export var evade_animation: StringName = &"Roll"
@export var defend_animation: StringName = &"Sword_Block"
@export var attack_animation: StringName = &"Sword_Regular_Combo"
@export var ground_stun_animation: StringName = &"Zombie_Scratch"
@export var air_stun_animation: StringName = &"Hit_Knockback"
@export var push_animation: StringName = &"Hit_Knockback"
@export var ragdoll_recovery_animation: StringName = &"LayToIdle"
@export var death_animation: StringName = &"Death01"
## Deja respirar la pose inicial antes de congelar el clip durante el windup real del melee.
@export_range(0.0, 0.5, 0.01) var windup_preview_time := 0.10
@export_range(0.0, 2.0, 0.01) var ground_stun_start := 0.0
@export_range(0.0, 2.0, 0.01) var ground_stun_end := 0.4
@export_range(0.0, 2.0, 0.01) var air_stun_start := 0.15
@export_range(0.0, 2.0, 0.01) var air_stun_end := 0.25
## Arma en mano (misma opcion A que el player, ver boveda Animacion/Player): una COPIA
## visual del arma cuelga del hueso de la mano y acompaña el clip; el mesh orbital que
## barre con la Hand procedural queda invisible pero su Hitbox sigue intacto — el daño no
## cambia. Offset/rotacion para acomodar el grip.
## Los 180° en Y compensan el giro del maniqui: el arma orbital apunta a -Z (forward de
## Godot) pero la copia cuelga del hueso, dentro del UAL2_Standard ya rotado 180° — sin
## esto la hoja sale apuntando hacia atras. Mismo caso que el player.
@export var hand_bone_name: StringName = &"hand_r"
@export var hand_attach_offset := Vector3.ZERO
@export var hand_attach_rotation_degrees := Vector3(0.0, 180.0, 0.0)

var _enemy: GroundedEnemy
var _animation_player: AnimationPlayer
var _was_attacking := false
var _death_started := false
var _attack_preview_ends_at := -INF
var _attack_animation_frozen := false
var _stun_visual_active := false
var _stun_animation_frozen := false
var _stun_segment_end := 0.0
var _stun_segment_ends_at := -INF
var _getup_animation_active := false
var _getup_animation_ends_at := -INF

func _ready() -> void:
	_enemy = get_parent() as GroundedEnemy
	if _enemy == null:
		push_warning("EnemyAnimationController necesita ser hijo de GroundedEnemy.")
		set_physics_process(false)
		return
	_animation_player = _find_animation_player(_enemy)
	if _animation_player == null:
		push_warning("No se encontro AnimationPlayer bajo Visual; se conserva el enemigo sin animacion.")
		set_physics_process(false)
		return
	_import_ual1_animations()
	var health := _enemy.get_node_or_null("Health") as Health
	if health != null and not health.died.is_connected(_on_enemy_died):
		health.died.connect(_on_enemy_died)
	if not _enemy.stun_started.is_connected(_on_stun_started):
		_enemy.stun_started.connect(_on_stun_started)
	if not _enemy.push_started.is_connected(_on_push_started):
		_enemy.push_started.connect(_on_push_started)
	if not _enemy.ragdoll_recovered.is_connected(_on_ragdoll_recovered):
		_enemy.ragdoll_recovered.connect(_on_ragdoll_recovered)
	_setup_hand_attachment()
	_play_loop(idle_animation)

# ---- Arma en mano (BoneAttachment3D sobre el hueso de la mano) ----

## Cuelga del hueso una copia visual del arma de cada ataque melee y oculta el mesh
## orbital (su Hitbox hermano sigue barriendo: el daño no cambia).
func _setup_hand_attachment() -> void:
	var skeleton := _find_skeleton(_enemy.get_node_or_null("Visual"))
	if skeleton == null:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "HandAttachment"
	skeleton.add_child(attachment)
	attachment.bone_name = hand_bone_name
	var copies := 0
	for pivot in _weapon_pivots():
		var copy := _build_hand_copy(pivot)
		if copy != null:
			attachment.add_child(copy)
			copies += 1
	if copies == 0:
		attachment.queue_free()

## Pivots de arma de los ataques del enemigo (MeleeAttack/Hand/Pivot y familia).
func _weapon_pivots() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for child in _enemy.get_children():
		var pivot := child.get_node_or_null("Hand/Pivot") as Node3D
		if pivot != null:
			out.append(pivot)
	return out

## Copia los MeshInstance3D del pivot preservando su transform local; duplicate() comparte
## mesh y materiales por referencia.
func _build_hand_copy(pivot: Node3D) -> Node3D:
	var copy_root := Node3D.new()
	copy_root.name = pivot.get_parent().get_parent().name + "HandVisual"
	var found := false
	for child in pivot.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null:
			continue
		var mesh_copy := mesh.duplicate() as MeshInstance3D
		mesh_copy.visible = true
		copy_root.add_child(mesh_copy)
		mesh.visible = false  # el arma orbital ya no se ve; su hitbox sigue barriendo
		found = true
	if not found:
		copy_root.free()
		return null
	copy_root.position = hand_attach_offset
	copy_root.rotation_degrees = hand_attach_rotation_degrees
	return copy_root

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

func _physics_process(_delta: float) -> void:
	if _enemy == null or _animation_player == null:
		return
	if _enemy.is_dead():
		_start_death()
		return
	# El getup dura 1.53 s, pero _end_ragdoll devuelve el control a la IA al instante: si el
	# enemigo ya arranco a moverse, sostener LayToIdle lo deja patinando de lado en la pose de
	# levantarse. Moverse lo corta, igual que land_hold_time en el player.
	if _getup_animation_active:
		var getting_up_speed := Vector2(_enemy.velocity.x, _enemy.velocity.z).length()
		if World.now() < _getup_animation_ends_at and getting_up_speed < moving_speed_threshold:
			return
		_getup_animation_active = false
	if _enemy.is_stunned():
		_update_stun_visual()
		return
	_stop_stun_visual()
	var attacking := _enemy.limbo_is_attacking()
	if attacking:
		if not _was_attacking:
			_play_one_shot(attack_animation)
			_attack_preview_ends_at = World.now() + windup_preview_time
		_update_attack_windup_visual()
		_was_attacking = true
		return
	_resume_attack_animation()
	_was_attacking = false
	var horizontal_speed := Vector2(_enemy.velocity.x, _enemy.velocity.z).length()
	_update_locomotion_animation(horizontal_speed)

func _on_stun_started(is_airborne: bool) -> void:
	_resume_attack_animation()
	if is_airborne:
		_start_stun_visual(air_stun_animation, air_stun_start, air_stun_end)
	else:
		_start_stun_visual(ground_stun_animation, ground_stun_start, ground_stun_end)

func _on_push_started() -> void:
	_resume_attack_animation()
	var animation := _animation_player.get_animation(push_animation) if _has_animation(push_animation) else null
	if animation != null:
		_start_stun_visual(push_animation, 0.0, animation.length)

func _on_ragdoll_recovered() -> void:
	if not _has_animation(ragdoll_recovery_animation):
		return
	_resume_attack_animation()
	_stop_stun_visual()
	_getup_animation_active = true
	_getup_animation_ends_at = World.now() \
			+ _animation_player.get_animation(ragdoll_recovery_animation).length
	_animation_player.speed_scale = 1.0
	_play_one_shot(ragdoll_recovery_animation)

func _on_enemy_died() -> void:
	_start_death()

func _start_death() -> void:
	if _death_started:
		return
	_death_started = true
	_getup_animation_active = false
	_resume_attack_animation()
	_stop_stun_visual()
	_play_one_shot(death_animation)

## Reproduce un tramo y sostiene su pose final hasta que EnemyBase abandona STUNNED.
func _start_stun_visual(animation: StringName, start_time: float, end_time: float) -> void:
	if not _has_animation(animation):
		return
	var clip := _animation_player.get_animation(animation)
	var start := clampf(start_time, 0.0, clip.length)
	_stun_segment_end = clampf(maxf(start, end_time), start, clip.length)
	_stun_segment_ends_at = World.now() + (_stun_segment_end - start)
	_stun_visual_active = true
	_stun_animation_frozen = false
	_animation_player.speed_scale = 1.0
	_animation_player.play(animation)
	_animation_player.seek(start, true)

func _update_stun_visual() -> void:
	if not _stun_visual_active:
		_on_stun_started(_enemy.is_airborne())
		return
	if World.now() < _stun_segment_ends_at or _stun_animation_frozen:
		return
	_animation_player.seek(_stun_segment_end, true)
	_animation_player.speed_scale = 0.0
	_stun_animation_frozen = true

func _stop_stun_visual() -> void:
	if not _stun_visual_active:
		return
	if _stun_animation_frozen:
		_animation_player.speed_scale = 1.0
	_stun_visual_active = false
	_stun_animation_frozen = false

func _update_locomotion_animation(horizontal_speed: float) -> void:
	match _enemy.ai_state:
		GroundedEnemy.AIState.EVADE:
			_play_one_shot(evade_animation)
		GroundedEnemy.AIState.FLEE:
			_play_loop(flee_animation)
		GroundedEnemy.AIState.DEFEND:
			_play_loop(defend_animation)
		GroundedEnemy.AIState.ROAM:
			_play_loop(roam_animation if horizontal_speed >= moving_speed_threshold else idle_animation)
		GroundedEnemy.AIState.CHASE, GroundedEnemy.AIState.SEARCH:
			_play_loop(chase_animation if horizontal_speed >= moving_speed_threshold else idle_animation)
		_:
			_play_loop(chase_animation if horizontal_speed >= moving_speed_threshold else idle_animation)

func _update_attack_windup_visual() -> void:
	var melee := _enemy.get_node_or_null("MeleeAttack") as MeleeAttack
	if melee == null or not melee.is_in_opening_windup:
		_resume_attack_animation()
		return
	if World.now() >= _attack_preview_ends_at and not _attack_animation_frozen:
		_animation_player.speed_scale = 0.0
		_attack_animation_frozen = true

func _resume_attack_animation() -> void:
	if _animation_player != null and _attack_animation_frozen:
		_animation_player.speed_scale = 1.0
	_attack_animation_frozen = false

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

## UAL2 aporta el combate; UAL1 completa locomocion, esquive y muerte sobre el mismo esqueleto.
func _import_ual1_animations() -> void:
	var source_root := UAL1_SCENE.instantiate()
	var source_player := _find_animation_player(source_root)
	if source_player == null:
		source_root.free()
		return
	var library := _animation_player.get_animation_library(&"")
	if library != null:
		for animation_name in UAL1_ANIMATIONS:
			if _has_animation(animation_name):
				continue
			var source_animation := source_player.get_animation(animation_name)
			if source_animation != null:
				library.add_animation(animation_name, source_animation.duplicate(true))
	source_root.free()

func _play_loop(animation: StringName) -> void:
	if not _has_animation(animation):
		return
	if _animation_player.current_animation == animation and _animation_player.is_playing():
		return
	_animation_player.play(animation)

func _play_one_shot(animation: StringName) -> void:
	if not _has_animation(animation):
		return
	if _animation_player.current_animation == animation and _animation_player.is_playing():
		return
	_animation_player.play(animation)

func _has_animation(animation: StringName) -> bool:
	return _animation_player != null and _animation_player.has_animation(animation)
