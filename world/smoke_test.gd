extends Node3D
## Smoke test headless de los módulos core (batches 1-2). Corre con:
##   $GODOT --headless --path . res://world/smoke_test.tscn
## Falla con assert si algo se rompe; imprime SMOKE OK si todo bien.

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

	print("SMOKE OK")
	get_tree().quit()
