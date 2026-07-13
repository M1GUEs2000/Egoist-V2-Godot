extends Node3D
## Smoke aislado de Combate. Corre con:
##   $GODOT --headless --path . res://world/combat_smoke_test.tscn
## Verifica el contrato de stun: la fuente manda poise y el receptor se quiebra por ACUMULACION
## (ver combat/poise.gd), no golpe a golpe.

func _ready() -> void:
	await _test_poise_meter()

	var player := (load("res://player/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	await get_tree().physics_frame
	player.tuning = player.tuning.duplicate(true) as PlayerTuning
	player.tuning.poise_max = 6.0
	player.tuning.poise_decay_per_second = 0.0  # el smoke mide acumulacion, no el paso del tiempo
	player.setup_poise()

	# Un golpe flojo NO stunea: solo come poise. El TERCERO llega a la reserva y quiebra.
	var chip := StunSettings.new()
	chip.poise_damage = 2.0
	chip.grounded = 0.35
	assert(not player.receive_stun(chip))
	assert(not player.is_stunned())
	assert(not player.receive_stun(chip))
	assert(not player.is_stunned())
	assert(player.receive_stun(chip))
	assert(player.is_stunned())

	# Ya quebrado no hay poise que superar: el golpe entra directo. Esto sostiene el juggle.
	assert(player.receive_stun(chip))
	player.stun.cancel()

	# El golpe absorbido enciende el fogonazo BLANCO (no el amarillo del stun): el mesh queda con
	# material propio emitiendo. El que quiebra, en cambio, pinta el de stun.
	var chip_mesh := player.get_node("Mesh") as MeshInstance3D
	assert(chip_mesh.get_surface_override_material(0) == null)  # limpio antes del golpe
	assert(not player.receive_stun(chip))                       # absorbido: no stunea
	var chip_material := chip_mesh.get_surface_override_material(0) as StandardMaterial3D
	assert(chip_material != null)
	assert(chip_material.emission.is_equal_approx(player.tuning.poise_chip_color))

	# El player NO degrada (break_levels = [1.0]): tras quebrarse, su reserva sigue siendo la misma.
	assert(is_equal_approx(player.poise.effective_max(false), 6.0))

	# Los ataques reales deben stunear pase lo que pase con su poise tuneado: vaciamos la reserva
	# para probar el PIPELINE (hitbox -> hurtbox -> stun en modo PUSH), no el valor.
	player.tuning.poise_max = 0.0
	player.setup_poise()

	var melee_enemy := (load("res://enemies/grounded_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	add_child(melee_enemy)
	await get_tree().physics_frame
	var melee := melee_enemy.get_node("MeleeAttack") as MeleeAttack
	assert(melee.stun != null)
	assert(not melee.has_method("_deal_damage"))  # no queda ningun impacto por rango/target
	var blade := melee.get_node("Hand/Pivot/BladeHitbox") as Hitbox
	assert(blade.source == melee_enemy)
	blade.begin_swing()
	blade._on_area_entered(player.get_node("Hurtbox") as Hurtbox)
	assert(player.is_stunned())
	assert(player.stun.mode == PlayerStun.Mode.PUSH)
	assert(is_equal_approx(player.bump_velocity.length(), melee.player_stun_push_speed))
	player.stun.cancel()

	var ranged_enemy := (load("res://enemies/ranged_dead.tscn") as PackedScene).instantiate() as GroundedEnemy
	add_child(ranged_enemy)
	await get_tree().physics_frame
	var ranged := ranged_enemy.get_node("RangedAttack") as RangedAttack

	# AttackLoadout: este enemigo equipa SOLO la familia ranged. El MeleeAttack que hereda de la
	# escena base no se registra en la IA, asi que nunca recibe try_attack — y sin try_attack su
	# Hitbox jamas prende el monitoring. Inerte, no invisible-pero-peligroso.
	var loadout := ranged_enemy.attack_loadout
	assert(loadout != null)
	var inherited_melee := ranged_enemy.get_node("MeleeAttack") as MeleeAttack
	assert(not loadout.allows(inherited_melee))
	assert(not inherited_melee.visible)  # el dueño le apaga la malla: no pasea con una espada
	assert(not (inherited_melee.get_node("Hand/Pivot/BladeHitbox") as Hitbox).monitoring)
	assert(loadout.allows(ranged))

	assert(ranged.stun != null)
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

## El medidor solo, sin escenas: acumulacion, armadura, degradacion y drenaje.
func _test_poise_meter() -> void:
	var poise := Poise.new()
	poise.poise_max = 6.0
	poise.armor_bonus = 6.0
	poise.decay_per_second = 0.0
	poise.break_levels = [1.0, 0.8, 0.0]
	poise.reset()

	# La armadura SUMA reserva (12), no es un umbral aparte: tres golpes de 4 no alcanzan, el cuarto si.
	assert(is_equal_approx(poise.effective_max(true), 12.0))
	assert(is_equal_approx(poise.effective_max(false), 6.0))
	assert(not poise.take_poise_damage(4.0, true))
	assert(not poise.take_poise_damage(4.0, true))
	assert(not poise.take_poise_damage(4.0, true))
	assert(poise.take_poise_damage(4.0, true))
	assert(poise.break_index() == 1)

	# Quebrado una vez, la reserva baja un escalon (80%): sin armadura ahora son 4.8, no 6.
	assert(is_equal_approx(poise.effective_max(false), 4.8))

	# Armadura = resistencia, nunca inmunidad: un golpe suficientemente fuerte quiebra igual.
	assert(poise.take_poise_damage(999.0, true))
	assert(poise.break_index() == 2)

	# Ultimo escalon (0.0): reserva nula, cualquier golpe stunea...
	assert(is_equal_approx(poise.effective_max(true), 0.0))
	assert(poise.take_poise_damage(0.1))
	assert(poise.break_index() == 2)  # ya no baja mas: se queda en el ultimo escalon
	# ...pero un golpe SIN poise no staggerea nunca, ni con la reserva en cero.
	assert(not poise.take_poise_damage(0.0))

	# El drenaje se come lo acumulado: golpes espaciados no suman.
	var draining := Poise.new()
	draining.poise_max = 6.0
	draining.decay_per_second = 100.0
	draining.break_levels = [1.0]
	draining.reset()
	assert(not draining.take_poise_damage(5.0))
	assert(draining.accumulated() > 4.9)  # recien golpeado: casi intacto
	await get_tree().create_timer(0.2).timeout
	assert(is_equal_approx(draining.accumulated(), 0.0))  # 100/s se lo comio todo
	assert(not draining.take_poise_damage(5.0))           # arranca de cero otra vez: no quiebra

	# Recuperacion: sin golpes por recovery_time, la reserva vuelve al 100% (escalon 0).
	var recovering := Poise.new()
	recovering.poise_max = 2.0
	recovering.decay_per_second = 0.0
	recovering.break_levels = [1.0, 0.5]
	recovering.recovery_time = 0.15
	recovering.reset()
	assert(recovering.take_poise_damage(2.0))
	assert(recovering.break_index() == 1)
	assert(is_equal_approx(recovering.effective_max(false), 1.0))  # degradado al 50%
	await get_tree().create_timer(0.25).timeout
	assert(recovering.break_index() == 0)                          # se recompuso solo
	assert(is_equal_approx(recovering.effective_max(false), 2.0))
