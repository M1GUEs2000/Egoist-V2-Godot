extends Node3D
## Smoke test headless de los módulos core (batches 1-2). Corre con:
##   $GODOT --headless --path . res://world/smoke_test.tscn
## Falla con assert si algo se rompe; imprime SMOKE OK si todo bien.

class PushProbe extends Node3D:
	var pushes := 0
	var last_settings: PushSettings
	var last_direction := Vector3.ZERO

	func push(direction: Vector3, settings: PushSettings) -> void:
		pushes += 1
		last_direction = direction
		last_settings = settings

class EnemyBounceProbe extends StaticBody3D:
	var pushes := 0
	var last_settings: PushSettings
	var last_direction := Vector3.ZERO

	func push(direction: Vector3, settings: PushSettings) -> void:
		pushes += 1
		last_direction = direction
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
	momentum_player.free()  # nunca entro al arbol: sin esto queda huerfano y ensucia stderr al salir

	# EnemyBounce: gracia, stomp, doble salto intacto, cooldown por enemigo y techo global.
	player.launcher.cancel()
	player.dash.cancel()
	player.air_state = Player.AirState.AIRBORNE
	player.tuning.enemy_bounce_up_speed = 7.2
	player.tuning.enemy_bounce_away_speed = 4.8
	player.tuning.enemy_bounce_along_speed = 2.0
	player.tuning.enemy_bounce_grace = 0.1
	player.tuning.enemy_bounce_cooldown = 0.25
	player.tuning.enemy_bounce_momentum_keep = 0.0
	player.tuning.enemy_bounce_push = null
	# Sin input: la salida es la normal pura, escalada por away_speed.
	var bounce_enemy_a := _make_enemy_bounce_probe(World.LAYER_ENEMY)
	assert(player.enemy_bounce._remember_contact_if_enemy(bounce_enemy_a, Vector3.RIGHT, 6.0))
	assert(player.enemy_bounce.try_bounce(Vector3.ZERO))
	assert(player.vertical_velocity == player.tuning.enemy_bounce_up_speed)
	assert(player.bump_velocity.is_equal_approx(Vector3.RIGHT * player.tuning.enemy_bounce_away_speed))
	# El rebote lateral manda: bloquea el input de movimiento mientras dura el lock.
	assert(player.enemy_bounce.blocks_move_input())

	# Con input lateral: se suma along_speed perpendicular a la normal.
	var along_enemy := _make_enemy_bounce_probe(World.LAYER_ENEMY)
	player.enemy_bounce._remember_contact_if_enemy(along_enemy, Vector3.RIGHT, 6.0)
	assert(player.enemy_bounce.try_bounce(Vector3.FORWARD))
	assert(player.bump_velocity.is_equal_approx(Vector3(
			player.tuning.enemy_bounce_away_speed, 0.0, -player.tuning.enemy_bounce_along_speed)))

	var stale_enemy := _make_enemy_bounce_probe(World.LAYER_ENEMY)
	player.enemy_bounce._remember_contact_if_enemy(stale_enemy, Vector3.RIGHT, 6.0)
	player.enemy_bounce._last_contact_time = World.now() - player.tuning.enemy_bounce_grace * 2.0
	assert(not player.enemy_bounce.try_bounce(Vector3.FORWARD))

	# Cooldown: el ultimo enemigo rebotado (along_enemy) esta bloqueado; otro no.
	player.enemy_bounce._remember_contact_if_enemy(along_enemy, Vector3.RIGHT, 6.0)
	assert(not player.enemy_bounce.try_bounce(Vector3.FORWARD))
	var bounce_enemy_b := _make_enemy_bounce_probe(World.LAYER_ENEMY)
	player.enemy_bounce._remember_contact_if_enemy(bounce_enemy_b, Vector3.RIGHT, 6.0)
	assert(player.enemy_bounce.try_bounce(Vector3.FORWARD))

	player._can_double_jump = true
	var bounce_enemy_c := _make_enemy_bounce_probe(World.LAYER_ENEMY)
	player.enemy_bounce._remember_contact_if_enemy(bounce_enemy_c, Vector3.RIGHT, 6.0)
	assert(player.enemy_bounce.try_bounce(Vector3.FORWARD))
	assert(player._can_double_jump)
	player._can_double_jump = false
	var bounce_enemy_d := _make_enemy_bounce_probe(World.LAYER_ENEMY)
	player.enemy_bounce._remember_contact_if_enemy(bounce_enemy_d, Vector3.RIGHT, 6.0)
	assert(player.enemy_bounce.try_bounce(Vector3.FORWARD))
	assert(not player._can_double_jump)

	player.enemy_bounce.cancel()
	var inactive_enemy := _make_enemy_bounce_probe(0)
	assert(not player.enemy_bounce._remember_contact_if_enemy(inactive_enemy, Vector3.RIGHT, 6.0))
	assert(not player.enemy_bounce.try_bounce(Vector3.FORWARD))

	player.tuning.enemy_bounce_momentum_keep = 1.0
	player.tuning.momentum_max_speed = 18.0
	var bounce_enemy_e := _make_enemy_bounce_probe(World.LAYER_ENEMY)
	player.enemy_bounce._remember_contact_if_enemy(bounce_enemy_e, Vector3.RIGHT, 100.0)
	assert(player.enemy_bounce.try_bounce(Vector3.FORWARD))
	assert(player.bump_velocity.length() <= player.tuning.momentum_max_speed)

	player.tuning.enemy_bounce_push = PushSettings.new()
	var bounce_enemy_f := _make_enemy_bounce_probe(World.LAYER_ENEMY)
	player.enemy_bounce._remember_contact_if_enemy(bounce_enemy_f, Vector3.RIGHT, 6.0)
	assert(player.enemy_bounce.try_bounce(Vector3.FORWARD))
	assert(bounce_enemy_f.pushes == 1)
	assert(bounce_enemy_f.last_direction == Vector3.LEFT)
	assert(bounce_enemy_f.last_settings == player.tuning.enemy_bounce_push)

	# Stomp: solo vertical, sin reaccion del enemigo y sin bloquear el input (no hay
	# impulso horizontal que proteger). El cancel() limpia el lock del rebote anterior.
	player.enemy_bounce.cancel()
	var stomp_enemy := _make_enemy_bounce_probe(World.LAYER_ENEMY)
	player.bump_velocity = Vector3.RIGHT * 4.0
	player.enemy_bounce._remember_contact_if_enemy(stomp_enemy, Vector3.UP, 6.0)
	assert(player.enemy_bounce.try_bounce(Vector3.FORWARD))
	assert(player.bump_velocity == Vector3.ZERO)
	assert(player.vertical_velocity == player.tuning.enemy_bounce_up_speed)
	assert(stomp_enemy.pushes == 0)
	assert(not player.enemy_bounce.blocks_move_input())

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

	# Enemy stun: las fuentes de golpe reducen solo grounded; airborne conserva el juggle.
	var sword_tuning := load("res://data/sword_tuning.tres") as SwordTuning
	assert(is_equal_approx(sword_tuning.stun.grounded, 0.35))
	assert(is_equal_approx(sword_tuning.stun.airborne, 1.0))
	assert(is_equal_approx(sword_tuning.charged_dash_stun.grounded, 0.35))
	assert(is_equal_approx(sword_tuning.charged_dash_stun.airborne, 1.0))
	assert(is_equal_approx(player.tuning.dash_stun.grounded, 0.35))
	assert(is_equal_approx(player.tuning.dash_stun.airborne, 1.0))
	var mace_tuning := load("res://data/mace_tuning.tres") as MaceTuning
	assert(is_equal_approx(mace_tuning.stun.grounded, 0.35))
	assert(is_equal_approx(mace_tuning.stun.airborne, 0.9))
	assert(is_equal_approx(mace_tuning.charged_freeze_stun.grounded, 1.4))
	assert(is_equal_approx(mace_tuning.air_freeze_stun.grounded, 1.2))
	assert(mace_tuning.ground_y_dash_distance > 0.0)
	assert(mace_tuning.ground_y_launcher_size.length() > 0.0)
	assert(mace_tuning.air_y_aoe_radius > 0.0)

	var mace := (load("res://combat/weapons/mace/mace.tscn") as PackedScene).instantiate() as Mace
	add_child(mace)
	mace.setup(player)
	player.launcher.cancel()
	mace.run_launcher_window(mace._launcher_hitbox, 2.0, 0.1, 0.01, 0.01, false)
	await get_tree().create_timer(0.04).timeout
	assert(not player.launcher.is_launched)

	player.meter.gain_bars(2.0)
	var meter_before_y := player.meter.meter()
	player.air_state = Player.AirState.AIRBORNE
	player._can_double_jump = true
	mace._hold_y()
	await get_tree().physics_frame
	assert(is_equal_approx(player.meter.meter(), meter_before_y))
	assert(player._can_double_jump)
	assert(player.vertical_velocity < 0.0)
	assert(player.bump_velocity.length() > 0.0)
	mace.cancel_routines()
	await get_tree().physics_frame

	var stunned_enemy := (load("res://enemies/grounded_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	add_child(stunned_enemy)
	await get_tree().process_frame
	stunned_enemy._last_hit_direction = Vector3.RIGHT
	stunned_enemy.apply_stun(0.5)
	assert(stunned_enemy.is_stunned())
	assert(is_equal_approx(stunned_enemy.velocity.x, stunned_enemy.stun_knockback_speed))
	assert(stunned_enemy.stun_light != null and stunned_enemy.stun_light.visible)
	var stunned_mesh := stunned_enemy.visual.get_node("Mesh") as MeshInstance3D
	var stunned_material := stunned_mesh.get_surface_override_material(0) as StandardMaterial3D
	assert(stunned_material.emission_enabled)
	stunned_enemy._stunned_until = World.now() - 0.1
	stunned_enemy.tick_base(0.1)
	assert(not stunned_enemy.is_stunned())
	assert(not stunned_enemy.stun_light.visible)
	assert(stunned_enemy.visual.rotation.is_equal_approx(Vector3.ZERO))

	var airborne_enemy := (load("res://enemies/grounded_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	add_child(airborne_enemy)
	await get_tree().process_frame
	airborne_enemy.air_state = EnemyBase.AirState.AIRBORNE
	airborne_enemy._last_hit_direction = Vector3.RIGHT
	airborne_enemy.velocity = Vector3.FORWARD * 12.0
	airborne_enemy.apply_stun(0.5)
	assert(airborne_enemy._airborne_until >= airborne_enemy._stunned_until)
	var airborne_x_before := airborne_enemy.velocity.x
	airborne_enemy.tick_base(0.1)
	assert(absf(airborne_enemy.velocity.x) < absf(airborne_x_before))
	stunned_enemy.queue_free()
	airborne_enemy.queue_free()

	# LockOn (batch 6): adquiere el enemigo más cercano dentro de rango/ángulo, ignora el lejano
	var enemy_near := EnemyBase.new()
	add_child(enemy_near)
	enemy_near.global_position = Vector3(0.0, 0.0, -3.0)  # adelante (forward = -Z), cerca
	var enemy_far := EnemyBase.new()
	add_child(enemy_far)
	enemy_far.global_position = Vector3(0.0, 0.0, -(3.0 + player.tuning.lock_max_range * 2.0))  # fuera de rango
	await get_tree().process_frame
	assert(player.lock_on.acquire_target(Vector3.FORWARD) == enemy_near)
	player.tuning.lock_require_weapons_out = true
	player.combat._last_attack_time = World.now() - player.tuning.weapons_out_duration * 2.0
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
	# Misma jerarquía que sword.tscn/mace.tscn: la mano orbita al player y el pivot
	# solo aleja la hoja un radio (ver la convención en WeaponBase).
	var hand := Node3D.new()
	hand.name = "Hand"
	weapon.add_child(hand)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	hand.add_child(pivot)
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

func _make_enemy_bounce_probe(layer: int) -> EnemyBounceProbe:
	var probe := EnemyBounceProbe.new()
	probe.collision_layer = layer
	add_child(probe)
	return probe

func _make_hurtbox(target: Node) -> Hurtbox:
	var hurtbox := Hurtbox.new()
	target.add_child(hurtbox)
	hurtbox.owner_node = target
	return hurtbox
