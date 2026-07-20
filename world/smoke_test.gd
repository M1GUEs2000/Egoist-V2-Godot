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
	# Fuera de mundo el cuerpo NO desaparece: queda visible como cascara (contorno encendido).
	assert(body.visible)
	membership._update_other_world_echo(0.1)
	assert(membership.is_shell_active())
	var echo_smoke := membership._other_world_echo
	var echo_light := membership._other_world_echo_light
	assert(echo_smoke != null and echo_smoke.visible and echo_smoke.emitting)
	assert(echo_light != null and echo_light.visible)
	var echo_energy_at_rest := echo_light.light_energy
	body.global_position += Vector3.RIGHT * 0.4
	membership._update_other_world_echo(0.1)
	assert(echo_light.light_energy > echo_energy_at_rest)
	WorldManager.switch_world()  # de vuelta a LIVING
	assert(membership.is_active)
	assert(body.visible)
	assert(not echo_smoke.visible and not echo_light.visible)
	membership._update_other_world_echo(0.1)
	assert(not membership.is_shell_active())  # de vuelta en su mundo recupera su material real

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
	assert(player.mover.is_moving())  # el launch ahora es un Mover ascendente (F2)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(player.global_position.y > y_before)  # el Mover sube

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

	# Inercia aerea: en el aire el input ya no manda directo — la velocidad de input se
	# conserva y solo se acerca a su target a air_acceleration (m/s²). Sin stick (headless
	# no aprieta nada) el target es ZERO: frena gradualmente en vez de cortarse en seco.
	player.cancel_launch()
	player.dash.cancel()
	player.tuning.air_acceleration = 10.0
	player.locomotion.set_air_velocity(Vector3.RIGHT * 6.0)
	var air_step := player.locomotion.tick(0.1)
	assert(air_step.is_equal_approx(Vector3.RIGHT * 5.0))
	air_step = player.locomotion.tick(0.1)
	assert(air_step.is_equal_approx(Vector3.RIGHT * 4.0))

	# EnemyBounce: gracia, stomp, doble salto intacto, cooldown por enemigo y techo global.
	player.cancel_launch()
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

	# Bloque verde: force_dash con deals_damage prende el DashHitbox del player (daña al
	# atravesar); sin el flag el mismo dash forzado es solo movimiento.
	player.dash.cancel()
	player.force_dash(Vector3.RIGHT, 4.0, 0.12, false, true)
	assert(player.dash._hitbox.monitoring)
	player.dash.cancel()
	assert(not player.dash._hitbox.monitoring)
	player.force_dash(Vector3.RIGHT, 4.0, 0.12, false, false)
	assert(not player.dash._hitbox.monitoring)
	player.dash.cancel()
	# El bloque verde puede inclinarse: force_dash debe conservar su direccion 3D.
	var tilted_dash_dir := Vector3(0.0, 1.0, 1.0).normalized()
	player.force_dash(tilted_dash_dir, 4.0, 0.12, false, false)
	assert(player.dash._dash_dir.is_equal_approx(tilted_dash_dir))
	player.dash.cancel()
	var dash_block := TraversalBlock.new()
	player.bump_velocity = Vector3.ZERO
	dash_block.dash_bop_forward_speed = 2.0
	dash_block.dash_vertical_bop_speed = 3.0
	dash_block._apply_dash(player)
	assert(player.bump_velocity == Vector3.ZERO)
	assert(is_zero_approx(player.vertical_velocity))
	player.dash._end_dash(true)
	assert(player.bump_velocity.is_equal_approx(Vector3.FORWARD * dash_block.dash_bop_forward_speed))
	assert(is_equal_approx(player.vertical_velocity, dash_block.dash_vertical_bop_speed))

	# Carga aerea: cuelga al jugador con un Floater (sin desgaste por uso — cada carga abre la
	# misma ventana). AirKillReset ya solo devuelve doble salto y airdash.
	player.air_state = Player.AirState.AIRBORNE
	player.tuning.air_charge_float_duration = 0.35
	player.tuning.air_charge_float_fall_scale = 0.15
	player.floater.cancel_float()
	player.vertical_velocity = -20.0
	player.apply_air_charge_float()
	assert(player.floater.is_floating())
	assert(is_equal_approx(player.floater.fall_scale(), 0.15))

	player._can_double_jump = false
	player.dash._can_airdash = false
	player.apply_air_kill_reset()
	assert(player._can_double_jump)
	assert(player.dash._can_airdash)

	# WeaponBase.arm_push: empuja hits acumulados, hits tardíos, y se desarma al cancelar
	var push_settings := PushSettings.new()
	push_settings.distance = 7.0
	var weapon := _make_test_weapon(player, push_settings)
	player._can_double_jump = false
	player.dash._can_airdash = false
	weapon.register_weapon_hit(_make_hurtbox(_make_push_probe()), true)
	assert(player._can_double_jump)
	assert(player.dash._can_airdash)

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

	# Enemy stun: INVARIANTE de diseño, no valores de feel (esos se tunean y no van al smoke,
	# ver obsidian/Smoke Test). Toda fuente de golpe conserva MÁS juggle en el aire que en el
	# suelo (airborne >= grounded); el freeze del sweet spot del Mazo dura más que su stun normal.
	var sword_tuning := load("res://data/sword_tuning.tres") as SwordTuning
	assert(sword_tuning.stun.airborne >= sword_tuning.stun.grounded)
	assert(sword_tuning.charged_dash_stun.airborne >= sword_tuning.charged_dash_stun.grounded)
	assert(player.tuning.dash_stun.airborne >= player.tuning.dash_stun.grounded)
	var mace_tuning := load("res://data/mace_tuning.tres") as MaceTuning
	assert(mace_tuning.stun.airborne >= mace_tuning.stun.grounded)
	assert(mace_tuning.charged_freeze_stun.grounded > mace_tuning.stun.grounded)
	assert(mace_tuning.air_freeze_stun.grounded > mace_tuning.stun.grounded)

	var mace := (load("res://combat/weapons/mace/mace.tscn") as PackedScene).instantiate() as Mace
	add_child(mace)
	mace.setup(player)
	# El AOE aereo es un cilindro dimensionado desde tuning (radio + altura), no una esfera.
	assert(mace._air_slam_shape.shape is CylinderShape3D)
	assert(is_equal_approx((mace._air_slam_shape.shape as CylinderShape3D).radius, mace_tuning.air_y_aoe_radius))
	player.cancel_launch()
	mace.run_launcher_window(mace._launcher_hitbox, 2.0, 0.1, 0.01, 0.01, false)
	await get_tree().create_timer(0.04).timeout
	assert(not player.mover.is_moving())  # launches_player=false: el Mover del player no arranca

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

	# Y aereo: al clavar un enemigo EN EL AIRE el jugador rebota arriba+adelante ("grados de
	# rebote", la direccion de la caida), no se queda clavado ni se lanza recto, y NO gasta el
	# doble salto. Esa es la ventana para perseguir a los enemigos que el AOE rebota a tu altura.
	player.cancel_launch()
	player.air_state = Player.AirState.AIRBORNE
	player.vertical_velocity = -20.0
	player.set_momentum(Vector3.RIGHT * 12.0)
	player._can_double_jump = true
	var burst_id := mace.begin_routine()
	mace._burst_air_slam(burst_id, true)
	assert(player.vertical_velocity > 0.0)  # rebota hacia arriba
	assert(player.bump_velocity.length() > 0.0)  # con componente horizontal (adelante)
	assert(player._can_double_jump)  # el rebote no cobra el doble salto
	mace._air_slam_hitbox.end_swing()
	mace.cancel_routines()
	await get_tree().physics_frame

	# Aereo tap X: es un combo de 2 (jab con el mango + cabezazo con push), no un solo golpe.
	player.air_state = Player.AirState.AIRBORNE
	mace.tap(World.Slot.X)
	assert(mace._combo_playing)
	assert(mace._combo_kind == &"air")
	mace.cancel_routines()
	mace._blade_hitbox.end_swing()
	mace._air_disc_hitbox.end_swing()
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
	# (F3) El hang del juggle lo sostiene el Floater: stunear en el aire tiene que dejarlo flotando.
	assert(airborne_enemy.floater.is_floating())
	var airborne_x_before := airborne_enemy.velocity.x
	airborne_enemy.tick_base(0.1)
	assert(absf(airborne_enemy.velocity.x) < absf(airborne_x_before))
	stunned_enemy.queue_free()
	airborne_enemy.queue_free()

	# INVARIANTE: con poise de sobra NO se lo mueve de ninguna forma. El gate es la reserva
	# quebrada, no la armadura: un armado con reserva rota SI se mueve (resistencia, no inmunidad).
	var poise_enemy := (load("res://enemies/grounded_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	add_child(poise_enemy)
	await get_tree().process_frame
	poise_enemy._last_hit_direction = Vector3.RIGHT
	var weak_stun := StunSettings.new()
	weak_stun.poise_damage = 1.0  # muy por debajo de poise_max: nunca quiebra de un golpe
	assert(not poise_enemy.is_stunned())
	assert(not poise_enemy.launch(3.0, 0.5, weak_stun))  # aguanta: no se lo lanza
	assert(not poise_enemy.is_airborne())
	poise_enemy.push(Vector3.RIGHT, PushSettings.new())
	assert(not poise_enemy.is_airborne())                # aguanta: no se lo empuja
	assert(not poise_enemy._lying)
	# El mismo golpe con poise suficiente para quebrar la reserva SI lo lanza.
	var breaking_stun := StunSettings.new()
	breaking_stun.poise_damage = poise_enemy.poise_max + poise_enemy.armor_poise_bonus
	assert(poise_enemy.launch(3.0, 0.5, breaking_stun))
	assert(poise_enemy.is_airborne())
	poise_enemy.queue_free()

	# Ranged Dead: el prefab Dead conserva la IA comun y equipa solo RangedAttack. Ya no lo logra
	# una subclase propia sino su AttackLoadout — el mismo modulo que hace hibrido a cualquier otro.
	var ranged_dead := (load("res://enemies/ranged_dead.tscn") as PackedScene).instantiate() as GroundedEnemy
	add_child(ranged_dead)
	await get_tree().process_frame
	assert(ranged_dead.membership.affiliation == World.Kind.DEAD)
	assert(ranged_dead._attacks.size() == 1)
	assert(ranged_dead._attacks[0] is RangedAttack)
	ranged_dead.queue_free()

	# Hibrido: el mismo cuerpo con las DOS familias equipadas. La IA elige por distancia, y su
	# WorldSwitchTrigger (hijo, ortogonal al loadout) voltea el mundo de todos al morir.
	var hybrid := (load("res://enemies/hybrid_enemy.tscn") as PackedScene).instantiate() as GroundedEnemy
	add_child(hybrid)
	await get_tree().process_frame
	assert(hybrid._attacks.size() == 2)
	assert(hybrid.attack_loadout.allows(hybrid.get_node("MeleeAttack")))
	assert(hybrid.attack_loadout.allows(hybrid.get_node("RangedAttack")))
	assert(hybrid.is_world_switch())
	hybrid.queue_free()

	# FlyingEnemy: patrulla a izquierda/derecha y bate ambas alas en sentidos opuestos.
	var flying_enemy := (load("res://enemies/flying_enemy.tscn") as PackedScene).instantiate() as FlyingEnemy
	add_child(flying_enemy)
	var flying_x := flying_enemy.global_position.x
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(not is_equal_approx(flying_enemy.global_position.x, flying_x))
	var left_wing := flying_enemy.get_node("Visual/LeftWingPivot") as Node3D
	var right_wing := flying_enemy.get_node("Visual/RightWingPivot") as Node3D
	assert(not is_zero_approx(left_wing.rotation.z))
	assert(is_equal_approx(left_wing.rotation.z, -right_wing.rotation.z))
	var stunned_x := flying_enemy.global_position.x
	var wing_before_stun: float = left_wing.rotation.z
	flying_enemy.apply_stun(0.2)
	await get_tree().physics_frame
	assert(is_equal_approx(flying_enemy.global_position.x, stunned_x))
	assert(not is_equal_approx(left_wing.rotation.z, wing_before_stun))
	assert(flying_enemy.visual.quaternion.is_equal_approx(Quaternion.IDENTITY))
	flying_enemy.global_position += Vector3(2.0, -1.0, 0.0)
	flying_enemy._returning_to_home = true
	var return_distance_before := flying_enemy.global_position.distance_to(flying_enemy._home_position)
	flying_enemy._return_to_home(0.1)
	assert(flying_enemy.global_position.distance_to(flying_enemy._home_position) < return_distance_before)
	flying_enemy.queue_free()

	# Ragdoll de aterrizaje: un push (o stun aereo) deja al enemigo acostado; al tocar el piso el
	# cuerpo pasa a RigidBody y se para tras ragdoll_getup_delay. La trayectoria previa no cambia.
	var lying_enemy := (load("res://enemies/grounded_enemy.tscn") as PackedScene).instantiate() as EnemyBase
	add_child(lying_enemy)
	await get_tree().process_frame
	lying_enemy.use_ragdoll = true  # apagado por default (feel): este bloque prueba la fase fisica
	lying_enemy._last_hit_direction = Vector3.RIGHT
	lying_enemy.apply_stun(0.5)         # sin la reserva quebrada no se lo mueve (ver bloque de poise)
	lying_enemy.push(Vector3.RIGHT, PushSettings.new())
	assert(lying_enemy._lying)          # el push lo acuesta
	assert(lying_enemy.is_airborne())   # sigue su arco en el aire (rigid body solo en el piso)
	lying_enemy._start_ragdoll()        # simula el toque de la esfera con el suelo
	assert(lying_enemy._ragdolling)
	assert(lying_enemy.ragdoll_body != null and lying_enemy.ragdoll_body.visible)
	assert(not lying_enemy.visual.visible)  # el cuerpo cede la vista al ragdoll
	lying_enemy.apply_stun(0.5)
	assert(lying_enemy.is_stunned())
	assert(lying_enemy.ragdoll_body.freeze)
	var ragdoll_mesh := lying_enemy.ragdoll_body.get_node("Mesh") as MeshInstance3D
	var ragdoll_material := ragdoll_mesh.get_surface_override_material(0) as StandardMaterial3D
	assert(ragdoll_material.emission_enabled)
	assert(lying_enemy.stun_light != null and lying_enemy.stun_light.visible)
	lying_enemy._ragdoll_until = World.now() - 0.1  # vencido: el proximo tick lo para
	lying_enemy._stunned_until = World.now() - 0.1
	lying_enemy.tick_base(0.1)
	assert(not lying_enemy._ragdolling)     # se paro
	assert(not lying_enemy._lying)
	assert(not lying_enemy.is_stunned())
	assert(lying_enemy.visual.visible)
	lying_enemy.queue_free()

	# LockOn (rework Dark Souls): toggle_lock() ancla el enemigo más centrado en cámara dentro
	# de rango/cono, ignora el lejano, y el lock persiste (no se recalcula solo cada frame).
	# Los enemigos van RELATIVOS a la posición/forward actuales del player: los tests previos lo
	# dejan desplazado del origen, y un enemigo en coordenadas absolutas caería detrás del cono.
	var lock_origin := player.global_position
	var lock_fwd := player.forward()
	var enemy_near := EnemyBase.new()
	add_child(enemy_near)
	enemy_near.global_position = lock_origin + lock_fwd * 3.0  # adelante, cerca
	var enemy_far := EnemyBase.new()
	add_child(enemy_far)
	enemy_far.global_position = lock_origin + lock_fwd * (3.0 + player.tuning.lock_max_range * 2.0)  # fuera de rango
	await get_tree().process_frame
	assert(not player.lock_on.is_locked)
	player.lock_on.toggle_lock()
	assert(player.lock_on.is_locked)
	assert(player.lock_on.current_target == enemy_near)

	# El target landing indicator reusa LandingIndicator: se enciende junto con el reticle
	# y sigue al target actual del lock-on.
	await get_tree().process_frame  # deja correr un _process para que reticle/target_landing se asienten
	assert(player.lock_on._target_landing.enabled)
	assert(player.lock_on._target_landing.source == enemy_near)

	# El lock persiste sin recalcularse: mover al target fuera de rango lo suelta solo,
	# sin necesidad de volver a tocar el botón.
	enemy_near.global_position = lock_origin + lock_fwd * (3.0 + player.tuning.lock_max_range * 2.0)
	await get_tree().process_frame
	assert(not player.lock_on.is_locked)
	assert(player.lock_on.current_target == null)
	enemy_near.queue_free()
	enemy_far.queue_free()
	await get_tree().process_frame  # confirma el free antes de la siguiente ronda de targets

	# Lock-on vertical: el cono de adquisición es UNO SOLO y 3D (`lock_half_angle`), medido como
	# distancia angular al centro de pantalla; ya no hay filtro vertical separado. Un enemigo aéreo
	# dentro de ese cono se lockea igual que uno a ras de piso. Sin Camera3D en el smoke, el cono
	# nace en el player y se mide contra su forward (fallback de `_best_camera_target`).
	var inside_angle := maxf(player.tuning.lock_half_angle - 10.0, 1.0)
	var enemy_aerial_ok := EnemyBase.new()
	add_child(enemy_aerial_ok)
	enemy_aerial_ok.global_position = lock_origin + lock_fwd * 3.0 + Vector3.UP * (3.0 * tan(deg_to_rad(inside_angle)))
	await get_tree().process_frame
	player.lock_on.toggle_lock()
	assert(player.lock_on.current_target == enemy_aerial_ok)
	player.lock_on.toggle_lock()  # suelta para la siguiente ronda
	enemy_aerial_ok.queue_free()
	await get_tree().process_frame

	# Un enemigo demasiado arriba queda fuera del cono: el lock-on no lo toma.
	var too_high_angle := player.tuning.lock_half_angle + 15.0
	var enemy_aerial_too_high := EnemyBase.new()
	add_child(enemy_aerial_too_high)
	enemy_aerial_too_high.global_position = lock_origin + lock_fwd * 3.0 + Vector3.UP * (3.0 * tan(deg_to_rad(too_high_angle)))
	await get_tree().process_frame
	player.lock_on.toggle_lock()
	assert(not player.lock_on.is_locked)  # nada en cono: toggle no ancla nada
	enemy_aerial_too_high.queue_free()
	await get_tree().process_frame

	# Ciclado (camera_left/camera_right) mientras hay lock: salta al vecino en rango, izquierda
	# y derecha respecto al forward de cámara (aquí igual al del player: no hay Camera3D en el
	# smoke, `_camera_forward()` cae al fallback `_body.forward()`).
	# El offset lateral sale del cono para que ambos entren con margen: a ±2m fijos quedaban a 33.7°
	# contra un cono de 35, o sea que cualquier recalibración del lock los sacaba y el test moría.
	var side_offset := 3.0 * tan(deg_to_rad(maxf(player.tuning.lock_half_angle - 15.0, 1.0)))
	var enemy_left := EnemyBase.new()
	add_child(enemy_left)
	enemy_left.global_position = lock_origin + lock_fwd * 3.0 + player.global_basis.x * -side_offset
	var enemy_right := EnemyBase.new()
	add_child(enemy_right)
	enemy_right.global_position = lock_origin + lock_fwd * 3.0 + player.global_basis.x * side_offset
	await get_tree().process_frame
	player.lock_on.toggle_lock()
	assert(player.lock_on.current_target != null)
	player.lock_on.cycle_target(1)
	var after_right := player.lock_on.current_target
	player.lock_on.cycle_target(-1)
	assert(player.lock_on.current_target != after_right)  # el ciclo va y vuelve entre los dos
	player.lock_on.toggle_lock()
	enemy_left.queue_free()
	enemy_right.queue_free()
	await get_tree().process_frame

	# El reticle es una dona (shader) que se vacia con la vida del target: fill sigue a
	# health.current / health.max_health en tiempo real.
	var enemy_hit := EnemyBase.new()
	var hit_health := Health.new()
	hit_health.name = "Health"  # el @onready de EnemyBase busca el hijo por este nombre
	hit_health.max_health = 10.0
	enemy_hit.add_child(hit_health)  # hijo agregado ANTES de entrar al arbol: el onready de
	# EnemyBase corre al entrar al arbol y necesita encontrar "Health" ya presente.
	add_child(enemy_hit)
	enemy_hit.global_position = lock_origin + lock_fwd * 3.0
	await get_tree().process_frame
	player.lock_on.toggle_lock()
	assert(player.lock_on.current_target == enemy_hit)
	await get_tree().process_frame
	assert(is_equal_approx(player.lock_on._reticle_material.get_shader_parameter("fill"), 1.0))
	hit_health.take_damage(6.0)  # 40% de vida restante
	await get_tree().process_frame
	assert(is_equal_approx(player.lock_on._reticle_material.get_shader_parameter("fill"), 0.4))

	# Sin reticle (armas guardadas, sin ataques recientes) el ring del target tampoco se muestra,
	# aunque el lock siga anclado (has_visible_target exige armas afuera, is_locked no).
	player.tuning.lock_require_weapons_out = true
	player.combat._last_attack_time = World.now() - player.tuning.weapons_out_duration * 2.0
	await get_tree().process_frame
	assert(player.lock_on.is_locked)
	assert(not player.lock_on.has_visible_target())
	assert(not player.lock_on._target_landing.enabled)
	player.lock_on.toggle_lock()
	enemy_hit.queue_free()

	# Enemigo de la grieta: el primer golpe arranca su reloj; al cumplirse se va al otro mundo
	# (voltea SU afiliacion, no la de nadie mas) y deja una grieta. Irse NO cambia el mundo.
	var rift_enemy := (load("res://enemies/rift_enemy.tscn") as PackedScene).instantiate() as GroundedEnemy
	# Afiliado al mundo actual ANTES de entrar al arbol: los tests de arriba dejan a WorldManager en
	# un mundo cualquiera, y un enemigo fuera de mundo es intocable (su hurtbox rechaza el golpe).
	(rift_enemy.get_node("WorldMembership") as WorldMembership).affiliation = WorldManager.current
	add_child(rift_enemy)
	await get_tree().process_frame
	var spawner := rift_enemy.get_node("RiftSpawner") as RiftSpawner
	spawner.delay = 0.05  # el smoke no espera los 3s reales del prefab
	assert(not spawner.is_armed())  # sin golpes el reloj no corre
	var enemy_world_before := rift_enemy.membership.affiliation
	var world_before_shift := WorldManager.current
	var dropped: Array[WorldRift] = []
	spawner.shifted.connect(func(r: WorldRift) -> void: dropped.append(r))
	rift_enemy.hurtbox.receive_hit(self, 1.0, Vector3.FORWARD, null)
	assert(spawner.is_armed())
	# Segundo golpe antes de que venza: NO reinicia el reloj (si lo reiniciara, el await de abajo
	# encontraria al enemigo todavia sin irse).
	rift_enemy.hurtbox.receive_hit(self, 1.0, Vector3.FORWARD, null)
	assert(not spawner.has_shifted())
	await get_tree().create_timer(spawner.delay + 0.05).timeout
	assert(spawner.has_shifted())
	assert(rift_enemy.membership.affiliation == World.opposite_world(enemy_world_before))
	assert(WorldManager.current == world_before_shift)  # irse al otro mundo no voltea el de todos
	assert(dropped.size() == 1)

	# La grieta: cruzarla voltea el mundo de todos. Es de UN SOLO uso — cruzarla de nuevo no hace nada.
	var rift := dropped[0]
	assert(not rift.is_consumed())
	rift._on_body_entered(player)
	assert(rift.is_consumed())
	assert(WorldManager.current != world_before_shift)
	var world_after_cross := WorldManager.current
	rift._on_body_entered(player)
	assert(WorldManager.current == world_after_cross)  # ya gastada: no vuelve a voltear
	rift_enemy.queue_free()

	# Grieta vencida: si nadie la cruza dentro de su ventana se cierra sola y NO cambia el mundo.
	var short_tuning := WorldRiftTuning.new()
	short_tuning.lifetime = 0.05
	var stale_rift := WorldRift.spawn(Vector3.ZERO, self, short_tuning)
	assert(not stale_rift.is_consumed())
	await get_tree().create_timer(short_tuning.lifetime + 0.05).timeout
	assert(stale_rift.is_consumed())               # se cerro sola
	assert(WorldManager.current == world_after_cross)  # sin tocar el mundo de nadie

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
