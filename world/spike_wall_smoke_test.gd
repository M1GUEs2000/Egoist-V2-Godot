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

	# FlyingEnemy: el spike conserva la reaccion aerea base y tiene los nodos que cierran
	# el aterrizaje en ragdoll; no puede degradar a la patrulla durante el push.
	var flying_enemy := (load("res://enemies/flying_enemy.tscn") as PackedScene).instantiate() as FlyingEnemy
	add_child(flying_enemy)
	await get_tree().physics_frame
	wall._on_body_entered(flying_enemy)
	assert(flying_enemy.is_stunned())
	assert(flying_enemy.is_airborne())
	assert(flying_enemy.ragdoll_body != null)
	assert(flying_enemy.ground_sense != null)
	flying_enemy.use_ragdoll = true  # apagado por default (feel): este bloque prueba la fase fisica
	flying_enemy._set_lying(true)
	flying_enemy._start_ragdoll()
	assert(flying_enemy._ragdolling)
	assert(flying_enemy.ragdoll_body.visible)

	print("SPIKE WALL SMOKE OK")
	get_tree().quit()
