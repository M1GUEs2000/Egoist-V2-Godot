extends Node3D
## Smoke de hazards: valida que SpikeWall afecta por igual a player y enemigos.

func _ready() -> void:
	var player := (load("res://player/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	await get_tree().physics_frame
	player.tuning = player.tuning.duplicate(true) as PlayerTuning

	var enemy := (load("res://enemies/grounded_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	add_child(enemy)
	await get_tree().physics_frame

	var wall := (load("res://world/blocks/spike_wall.tscn") as PackedScene).instantiate() as SpikeWall
	var wall_membership := wall.get_node("WorldMembership") as WorldMembership
	wall_membership.mode = WorldMembership.Mode.BOTH
	wall.position = Vector3.UP * 100.0  # evita un body_entered automatico antes del assert
	add_child(wall)
	await get_tree().physics_frame
	wall_membership.is_active = true  # fixture aislado: no depende de la onda de WorldManager

	var player_health_before := player.health.current
	wall._on_body_entered(player)
	assert(player.health.current < player_health_before)
	assert(player.is_stunned())
	assert(player.stun.mode == PlayerStun.Mode.PUSH)
	assert(player._stun_feedback_color.is_equal_approx(wall.hazard_stun_color))
	player.stun.cancel()

	var enemy_health_before := enemy.health.current
	wall._on_body_entered(enemy)
	assert(enemy.health.current < enemy_health_before)
	assert(enemy.is_stunned())
	assert(enemy.is_airborne())
	assert(enemy._stun_feedback_color.is_equal_approx(wall.hazard_stun_color))

	print("SPIKE WALL SMOKE OK")
	get_tree().quit()
