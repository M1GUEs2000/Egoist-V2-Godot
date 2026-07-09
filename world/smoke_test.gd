extends Node3D
## Smoke test headless de los módulos core (batches 1-2). Corre con:
##   $GODOT --headless --path . res://world/smoke_test.tscn
## Falla con assert si algo se rompe; imprime SMOKE OK si todo bien.

class PushProbe extends Node3D:
	var pushes := 0
	var last_settings: PushSettings

	func push(_direction: Vector3, settings: PushSettings) -> void:
		pushes += 1
		last_settings = settings

func _ready() -> void:
	# WorldManager: switch + señal
	var fired: Array = []
	WorldManager.world_changed.connect(func(w: World.Kind) -> void: fired.append(w))
	assert(WorldManager.current == World.Kind.LIVING)
	WorldManager.switch_world()
	assert(WorldManager.current == World.Kind.DEAD)
	assert(fired == [World.Kind.DEAD])

	# WorldMembership FIXED: hijo de un cuerpo afiliado a LIVING, estamos en DEAD → inactivo
	var body := StaticBody3D.new()
	add_child(body)
	var membership := WorldMembership.new()
	membership.affiliation = World.Kind.LIVING
	body.add_child(membership)
	await get_tree().process_frame
	assert(not membership.is_active)
	assert(not body.visible)
	WorldManager.switch_world()  # de vuelta a LIVING
	assert(membership.is_active)
	assert(body.visible)

	# Health: daño, muerte, señales
	var health := Health.new()
	add_child(health)
	health.set_max(2.0)
	var deaths: Array = []
	health.died.connect(func() -> void: deaths.append(true))
	assert(not health.take_damage(1.0))
	assert(health.take_damage(1.0))
	assert(health.is_dead())
	assert(deaths.size() == 1)
	assert(not health.take_damage(1.0))  # muerto no recibe más

	# Hurtbox + WorldSwitchTrigger ON_HIT: cada golpe voltea el mundo
	var obj := StaticBody3D.new()
	add_child(obj)
	var hurtbox := Hurtbox.new()
	obj.add_child(hurtbox)
	var trigger := WorldSwitchTrigger.new()
	trigger.when = WorldSwitchTrigger.When.ON_HIT
	obj.add_child(trigger)
	await get_tree().process_frame
	var before := WorldManager.current
	hurtbox.receive_hit(self, 1.0, Vector3.FORWARD, StunSettings.new())
	assert(WorldManager.current != before)

	# InputBuffer: tap al press, buffer cuando no accionable, hold por tiempo
	var buffer := InputBuffer.new()
	add_child(buffer)
	var taps: Array = []
	buffer.press(func() -> void: taps.append("tap"), Callable())
	assert(taps == ["tap"])  # tap ejecuta en el press, no al soltar
	buffer.release()
	buffer.is_actionable = false
	buffer.press(func() -> void: taps.append("buffered"), Callable())
	assert(taps.size() == 1)  # quedó bufferizado
	buffer.is_actionable = true
	await get_tree().process_frame
	assert(taps == ["tap", "buffered"])  # salió en el primer frame libre

	# Player (batch 3): cae con gravedad y el launcher lo sube
	var player := (load("res://player/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(player.vertical_velocity < 0.0)  # gravedad actuando (no hay piso en este test)
	var y_before := player.global_position.y
	player.launch(3.0, 0.4)
	assert(player.launcher.is_launched)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(player.global_position.y > y_before)  # el launcher sube

	# Momentum: el exceso drena linealmente; 2x total tarda T, 3x total tarda 2T.
	var momentum_player := Player.new()
	momentum_player.tuning = PlayerTuning.new()
	momentum_player.tuning.move_speed = 6.0
	momentum_player.tuning.momentum_bleed_seconds_per_unit = 3.0
	momentum_player.tuning.momentum_bleed_ground = 1.0
	momentum_player.tuning.momentum_bleed_wall = 0.5
	momentum_player.tuning.momentum_bleed_air = 0.1
	momentum_player.tuning.momentum_max_speed = 18.0
	var ground_rate := momentum_player.tuning.move_speed \
			/ momentum_player.tuning.momentum_bleed_seconds_per_unit
	momentum_player.bump_velocity = Vector3.RIGHT * 6.0
	momentum_player._bleed_momentum_for_scale(3.0, ground_rate, momentum_player.tuning.momentum_bleed_ground)
	assert(momentum_player.bump_velocity == Vector3.ZERO)
	momentum_player.bump_velocity = Vector3.RIGHT * 12.0
	momentum_player._bleed_momentum_for_scale(3.0, ground_rate, momentum_player.tuning.momentum_bleed_ground)
	assert(is_equal_approx(momentum_player.bump_velocity.length(), 6.0))
	momentum_player._bleed_momentum_for_scale(3.0, ground_rate, momentum_player.tuning.momentum_bleed_ground)
	assert(momentum_player.bump_velocity == Vector3.ZERO)

	momentum_player.bump_velocity = Vector3.RIGHT * 6.0
	momentum_player._bleed_momentum_for_scale(1.0, ground_rate, momentum_player.tuning.momentum_bleed_air)
	assert(is_equal_approx(momentum_player.bump_velocity.length(), 5.8))
	momentum_player.bump_velocity = Vector3.RIGHT * 6.0
	momentum_player._bleed_momentum_for_scale(1.0, ground_rate, momentum_player.tuning.momentum_bleed_wall)
	assert(is_equal_approx(momentum_player.bump_velocity.length(), 5.0))

	momentum_player.bump_velocity = Vector3.RIGHT * 6.0
	momentum_player._bleed_momentum_for_scale(1.5, ground_rate, momentum_player.tuning.momentum_bleed_ground)
	momentum_player._bleed_momentum_for_scale(1.5, ground_rate, momentum_player.tuning.momentum_bleed_air)
	assert(is_equal_approx(momentum_player.bump_velocity.length(), 2.7))
	momentum_player._bleed_momentum_for_scale(1.35, ground_rate, momentum_player.tuning.momentum_bleed_ground)
	assert(momentum_player.bump_velocity == Vector3.ZERO)

	momentum_player.bump_velocity = Vector3.RIGHT * 0.1
	momentum_player._bleed_momentum_for_scale(1.0, ground_rate, momentum_player.tuning.momentum_bleed_ground)
	assert(momentum_player.bump_velocity == Vector3.ZERO)

	for _i in range(4):
		momentum_player.add_momentum(Vector3.RIGHT * 10.0)
	assert(is_equal_approx(momentum_player.bump_velocity.length(), momentum_player.tuning.momentum_max_speed))

	momentum_player.bump_velocity = Vector3.RIGHT * 6.0
	momentum_player._bleed_momentum(1.0, momentum_player.tuning.stun_bump_decay)
	assert(is_equal_approx(momentum_player.bump_velocity.length(), 2.5))

	# WeaponBase.arm_push: empuja hits acumulados, hits tardíos, y se desarma al cancelar
	var push_settings := PushSettings.new()
	push_settings.horizontal_speed = 7.0
	var weapon := _make_test_weapon(player, push_settings)
	var probe_a := _make_push_probe()
	var hurtbox_a := _make_hurtbox(probe_a)
	weapon.begin_routine()
	weapon._on_hit(hurtbox_a, false)
	weapon.arm_push(push_settings, 0.0)
	await get_tree().create_timer(0.03).timeout
	assert(probe_a.pushes == 1)
	assert(probe_a.last_settings == push_settings)

	var probe_b := _make_push_probe()
	var hurtbox_b := _make_hurtbox(probe_b)
	weapon.begin_routine()
	weapon.arm_push(push_settings, 0.0)
	await get_tree().create_timer(0.03).timeout
	assert(probe_b.pushes == 0)
	weapon._on_hit(hurtbox_b, false)
	assert(probe_b.pushes == 1)

	var probe_c := _make_push_probe()
	var hurtbox_c := _make_hurtbox(probe_c)
	weapon.begin_routine()
	weapon._on_hit(hurtbox_c, false)
	weapon.arm_push(push_settings, 0.05)
	weapon.begin_routine()
	await get_tree().create_timer(0.08).timeout
	assert(probe_c.pushes == 0)

	# No-regresión: la Espada con push_at default 1.0 sigue empujando el finisher aéreo espera
	var sword := (load("res://combat/weapons/sword/sword.tscn") as PackedScene).instantiate() as Sword
	add_child(sword)
	sword.setup(player)
	player.air_state = Player.AirState.AIRBORNE
	var sword_probe := _make_push_probe()
	var sword_hurtbox := _make_hurtbox(sword_probe)
	sword.begin_routine()
	sword._begin_air_step(sword.air_steps(), true, true)
	sword._on_hit(sword_hurtbox, false)
	await get_tree().create_timer(sword.tuning.air_step_time + 0.03).timeout
	assert(sword_probe.pushes == 1)

	# _hold_y es entrada de ataque: desarma el push que dejó armado el combo anterior. Sin
	# esto el launcher empujaría a sus víctimas en vez de lanzarlas (el push mata el hang).
	player.air_state = Player.AirState.GROUNDED
	sword._hold_y()
	var leak_probe := _make_push_probe()
	sword._on_hit(_make_hurtbox(leak_probe), false)
	assert(leak_probe.pushes == 0)

	# LockOn (batch 6): adquiere el enemigo más cercano dentro de rango/ángulo, ignora el lejano
	var enemy_near := EnemyBase.new()
	add_child(enemy_near)
	enemy_near.global_position = Vector3(0.0, 0.0, -3.0)  # adelante (forward = -Z), cerca
	var enemy_far := EnemyBase.new()
	add_child(enemy_far)
	enemy_far.global_position = Vector3(0.0, 0.0, -(3.0 + player.tuning.lock_max_range * 2.0))  # fuera de rango
	await get_tree().process_frame
	assert(player.lock_on.acquire_target(Vector3.FORWARD) == enemy_near)
	assert(not player.lock_on.has_visible_target())  # sin ataques recientes, sin reticle
	enemy_near.queue_free()
	enemy_far.queue_free()

	print("SMOKE OK")
	get_tree().quit()

func _make_test_weapon(player: Player, push_settings: PushSettings) -> WeaponBase:
	var tuning := WeaponTuning.new()
	tuning.push = push_settings
	tuning.stun = StunSettings.new()
	var weapon := WeaponBase.new()
	weapon.tuning = tuning
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	weapon.add_child(pivot)
	var blade := Hitbox.new()
	blade.name = "BladeHitbox"
	pivot.add_child(blade)
	add_child(weapon)
	weapon.setup(player)
	return weapon

func _make_push_probe() -> PushProbe:
	var probe := PushProbe.new()
	add_child(probe)
	return probe

func _make_hurtbox(target: Node) -> Hurtbox:
	var hurtbox := Hurtbox.new()
	target.add_child(hurtbox)
	hurtbox.owner_node = target
	return hurtbox
