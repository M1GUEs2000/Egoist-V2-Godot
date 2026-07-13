extends Node3D
## Smoke aislado de Combate. Corre con:
##   $GODOT --headless --path . res://world/combat_smoke_test.tscn
## Verifica el contrato de stun: la fuente manda potencia y el receptor decide por threshold.

func _ready() -> void:
	var player := (load("res://player/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	await get_tree().physics_frame
	player.tuning = player.tuning.duplicate(true) as PlayerTuning
	player.tuning.stun_threshold = 1.0

	var below_threshold := StunSettings.new()
	below_threshold.power = 0.99
	below_threshold.grounded = 0.35
	assert(not player.receive_stun(below_threshold))
	assert(not player.is_stunned())

	var meets_threshold := StunSettings.new()
	meets_threshold.power = 1.0
	meets_threshold.grounded = 0.35
	assert(player.receive_stun(meets_threshold))
	assert(player.is_stunned())
	player.stun.cancel()

	var melee_enemy := (load("res://enemies/grounded_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	add_child(melee_enemy)
	await get_tree().physics_frame
	var melee := melee_enemy.get_node("MeleeAttack") as MeleeAttack
	assert(melee.stun != null and is_equal_approx(melee.stun.power, 1.0))
	assert(not melee.has_method("_deal_damage"))  # no queda ningun impacto por rango/target
	var blade := melee.get_node("Hand/Pivot/BladeHitbox") as Hitbox
	assert(blade.source == melee_enemy)
	blade.begin_swing()
	blade._on_area_entered(player.get_node("Hurtbox") as Hurtbox)
	assert(player.is_stunned())
	assert(player.stun.mode == PlayerStun.Mode.PUSH)
	assert(is_equal_approx(player.bump_velocity.length(), melee.player_stun_push_speed))
	player.stun.cancel()

	var ranged_enemy := (load("res://enemies/ranged_dead.tscn") as PackedScene).instantiate() as RangedDead
	add_child(ranged_enemy)
	await get_tree().physics_frame
	var ranged := ranged_enemy.get_node("RangedAttack") as RangedAttack
	assert(ranged.stun != null and is_equal_approx(ranged.stun.power, 1.0))
	var projectile := Projectile.new()
	projectile.position = Vector3.UP * 100.0  # fuera del player antes de activar su Area3D
	add_child(projectile)
	projectile.launch(Vector3.UP * 100.0, Vector3.FORWARD, player, ranged_enemy, 1.0, 0.0, 0.0, 1.0,
			ranged.stun, ranged.player_stun_push_speed, ranged.player_stun_push_vertical_speed)
	projectile._on_body_entered(player)
	assert(player.is_stunned())
	assert(player.stun.mode == PlayerStun.Mode.PUSH)
	assert(is_equal_approx(player.bump_velocity.length(), ranged.player_stun_push_speed))

	print("COMBAT SMOKE OK")
	get_tree().quit()
