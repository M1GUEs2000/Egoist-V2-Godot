extends Node3D
## Probe visual y automatizado del puente GroundedEnemy -> EnemyAnimationController.
## Corre con: Godot --path . res://world/probe_animaciones_ia.tscn

const ENEMY_SCENE := preload("res://enemies/grounded_enemy.tscn")

var _enemy: GroundedEnemy
var _controller: Node
var _animation_player: AnimationPlayer
var _dummy_target: Node3D

func _ready() -> void:
	_add_stage()
	_enemy = ENEMY_SCENE.instantiate() as GroundedEnemy
	add_child(_enemy)
	_enemy.global_position = Vector3.ZERO
	_dummy_target = Node3D.new()
	add_child(_dummy_target)
	_dummy_target.global_position = Vector3(0.0, 0.0, -1.0)

	await get_tree().physics_frame
	_enemy._on_membership_changed(true)
	_enemy.health.set_max(10.0)
	# El probe decide cada fase de forma determinista; el controlador visual sigue procesando.
	_enemy.set_physics_process(false)
	_controller = _enemy.get_node_or_null("AnimationController")
	_animation_player = _find_animation_player(_enemy)
	assert(_controller != null)
	assert(_animation_player != null)
	assert(_animation_player.has_animation(_clip("idle_animation")))
	assert(_animation_player.has_animation(_clip("roam_animation")))
	assert(_animation_player.has_animation(_clip("chase_animation")))
	assert(_animation_player.has_animation(_clip("flee_animation")))
	assert(_animation_player.has_animation(_clip("evade_animation")))
	assert(_animation_player.has_animation(_clip("attack_animation")))
	assert(_animation_player.has_animation(_clip("ground_stun_animation")))
	assert(_animation_player.has_animation(_clip("air_stun_animation")))
	assert(_animation_player.has_animation(_clip("push_animation")))
	assert(_animation_player.has_animation(_clip("death_animation")))
	_assert_weapon_in_hand()
	await _run_states()

## Arma en mano: copia visual colgada del hueso y arma orbital invisible con hitbox vivo.
func _assert_weapon_in_hand() -> void:
	var skeleton := _find_skeleton(_enemy.get_node("Visual"))
	assert(skeleton != null)
	var attachment := skeleton.get_node_or_null("HandAttachment") as BoneAttachment3D
	assert(attachment != null)
	assert(attachment.bone_name == StringName(_controller.get("hand_bone_name")))
	var copy := attachment.get_node_or_null("MeleeAttackHandVisual") as Node3D
	assert(copy != null and copy.get_child_count() == 1)  # BladeMesh
	var blade := _enemy.get_node("MeleeAttack/Hand/Pivot/BladeMesh") as MeshInstance3D
	assert(blade != null and not blade.visible)
	assert(_enemy.get_node("MeleeAttack/Hand/Pivot/BladeHitbox") != null)
	print("PROBE animaciones_ia=arma_en_mano")

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

func _run_states() -> void:
	await _expect_phase("idle", _clip("idle_animation"), 1.5)

	_enemy.ai_state = GroundedEnemy.AIState.ROAM
	_enemy.velocity = Vector3(2.0, 0.0, 0.0)
	_tick_controller()
	await _expect_phase("roam", _clip("roam_animation"), 1.0)

	_enemy.ai_state = GroundedEnemy.AIState.CHASE
	_tick_controller()
	await _expect_phase("chase", _clip("chase_animation"), 1.0)

	_enemy.ai_state = GroundedEnemy.AIState.FLEE
	_tick_controller()
	await _expect_phase("flee", _clip("flee_animation"), 1.0)

	_enemy.ai_state = GroundedEnemy.AIState.EVADE
	_tick_controller()
	await _expect_phase("evade", _clip("evade_animation"), 0.8)

	_enemy.ai_state = GroundedEnemy.AIState.IDLE
	_enemy.velocity = Vector3.ZERO
	_tick_controller()
	await _expect_phase("regreso a idle", _clip("idle_animation"), 1.0)

	var melee := _enemy.get_node("MeleeAttack") as MeleeAttack
	assert(melee.try_attack(_dummy_target, 0.7))
	await get_tree().physics_frame
	_tick_controller()
	assert(_animation_player.current_animation == _clip("attack_animation"))
	await get_tree().create_timer(float(_controller.get("windup_preview_time")) + 0.08).timeout
	_tick_controller()
	assert(melee.is_in_opening_windup)
	assert(is_zero_approx(_animation_player.speed_scale))
	print("PROBE animaciones_ia=ataque_windup_congelado")
	await get_tree().create_timer(0.72).timeout
	_tick_controller()
	assert(not melee.is_in_opening_windup)
	assert(is_equal_approx(_animation_player.speed_scale, 1.0))
	print("PROBE animaciones_ia=ataque_reanudado")
	await get_tree().create_timer(1.4).timeout

	_enemy.health.take_damage(1.0)
	_tick_controller()
	assert(_animation_player.current_animation == _clip("idle_animation"))
	print("PROBE animaciones_ia=dano_sin_stun_no_anima")

	_enemy.apply_stun(1.0)
	_tick_controller()
	assert(_animation_player.current_animation == _clip("ground_stun_animation"))
	await get_tree().create_timer(0.45).timeout
	_tick_controller()
	assert(is_zero_approx(_animation_player.speed_scale))
	print("PROBE animaciones_ia=stun_suelo_zombie_scratch")

	_enemy.combat_state = EnemyBase.CombatState.NORMAL
	_tick_controller()
	assert(is_equal_approx(_animation_player.speed_scale, 1.0))
	_enemy.air_state = EnemyBase.AirState.AIRBORNE
	_enemy.apply_stun(1.5)
	_tick_controller()
	assert(_animation_player.current_animation == _clip("air_stun_animation"))
	await get_tree().create_timer(0.12).timeout
	_tick_controller()
	assert(is_zero_approx(_animation_player.speed_scale))
	print("PROBE animaciones_ia=stun_aire_hit_knockback")

	_enemy.push(Vector3.FORWARD, PushSettings.new())
	_tick_controller()
	assert(_animation_player.current_animation == _clip("push_animation"))
	assert(is_equal_approx(_animation_player.speed_scale, 1.0))
	await get_tree().create_timer(0.9).timeout
	_tick_controller()
	assert(is_zero_approx(_animation_player.speed_scale))
	print("PROBE animaciones_ia=push_hit_knockback_completo")

	_enemy._start_ragdoll()
	await get_tree().physics_frame
	var ragdoll := _enemy.get_node("Ragdoll") as RigidBody3D
	var old_ragdoll_mesh := ragdoll.get_node("Mesh") as MeshInstance3D
	var ragdoll_visual := ragdoll.get_node("UAL2_Ragdoll") as Node3D
	var ragdoll_player := _find_animation_player(ragdoll_visual)
	assert(ragdoll.visible)
	assert(not old_ragdoll_mesh.visible)
	assert(ragdoll_visual.visible)
	assert(ragdoll_player.has_animation(&"Hit_Knockback"))
	assert(not ragdoll_player.is_playing())
	print("PROBE animaciones_ia=ragdoll_visual_ual")

	_enemy._end_ragdoll()
	_tick_controller()
	assert(_animation_player.current_animation == _clip("ragdoll_recovery_animation"))
	print("PROBE animaciones_ia=ragdoll_lay_to_idle")

	_enemy.health.kill()
	await get_tree().physics_frame
	assert(_animation_player.current_animation == _clip("death_animation"))
	print("PROBE animaciones_ia=OK")
	if DisplayServer.get_name() == "headless":
		get_tree().quit()

func _expect_phase(label: String, animation: StringName, seconds: float) -> void:
	await get_tree().physics_frame
	assert(_animation_player.current_animation == animation)
	print("PROBE animaciones_ia=%s" % label)
	await get_tree().create_timer(seconds).timeout

func _clip(property: StringName) -> StringName:
	return StringName(_controller.get(property))

func _tick_controller() -> void:
	_controller.call("_physics_process", 0.0)

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _add_stage() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.045, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.78)
	env.ambient_light_energy = 0.45
	environment.environment = env
	add_child(environment)

	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(16.0, 16.0)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.12, 0.15, 0.22)
	floor.material_override = floor_material
	add_child(floor)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	light.light_energy = 1.5
	light.shadow_enabled = true
	add_child(light)

	var camera := Camera3D.new()
	camera.position = Vector3(4.5, 2.7, 5.5)
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
