extends Node3D
## Probe visual y automatizado del puente Player -> PlayerAnimationController, incluyendo
## la capa de arma (Espada y Mazo via WeaponBase.visual_clip_started).
## Corre con: Godot --path . res://world/probe_animaciones_player.tscn
##
## Mismo patron que probe_animaciones_ia: el probe decide cada fase de forma determinista
## (apaga el physics del Player y fuerza velocity/air_state/wall_slide a mano) y tickea el
## controlador directo antes de cada assert, asi ningun assert depende del orden de frames.

const PLAYER_SCENE := preload("res://player/player.tscn")

const SECTION_COUNT := 6

var _player: Player
var _controller: Node
var _animation_player: AnimationPlayer
var _visual: Node3D
var _sword: Sword
var _mace: Mace
var _sections_done := 0

func _ready() -> void:
	_add_stage()  # la camara tiene que existir ANTES del Player (Locomotion/LockOn la piden en _ready)
	_player = PLAYER_SCENE.instantiate() as Player
	add_child(_player)
	_player.global_position = Vector3.ZERO

	await get_tree().physics_frame
	# El probe maneja el estado a mano; el controlador visual sigue procesando.
	_player.set_physics_process(false)
	_controller = _player.get_node_or_null("AnimationController")
	_visual = _player.get_node_or_null("Visual") as Node3D
	_animation_player = _find_animation_player(_visual)
	_sword = _player.get_node_or_null("Sword") as Sword
	_mace = _player.get_node_or_null("Maso") as Mace
	assert(_controller != null)
	assert(_visual != null)
	assert(_animation_player != null)
	assert(_sword != null)
	assert(_mace != null)
	_assert_clips()
	await _run_locomotion()
	await _run_jump()
	await _run_wall_slide()
	await _run_sword()
	await _run_mace()
	await _run_interruptions()
	# Un assert fallido aborta su sección pero el await de _ready continúa: el veredicto
	# solo es OK si TODAS las secciones llegaron al final.
	if _sections_done == SECTION_COUNT:
		print("PROBE animaciones_player=OK")
	else:
		print("PROBE animaciones_player=FALLO (secciones completas: %d/%d)"
				% [_sections_done, SECTION_COUNT])
	if DisplayServer.get_name() == "headless":
		get_tree().quit()

## Nombres de clip verificados contra el maniqui real: si UAL2 no trae alguno (o fallo la
## copia de Walk/Sprint desde UAL1) el probe explota aca, antes de cualquier fase.
func _assert_clips() -> void:
	for property: StringName in [&"idle_animation", &"walk_animation", &"sprint_animation",
			&"jump_start_animation", &"jump_loop_animation", &"jump_land_animation",
			&"slide_start_animation", &"slide_loop_animation", &"slide_exit_animation",
			&"ground_stun_animation", &"air_stun_animation"]:
		assert(_animation_player.has_animation(_clip(property)))
	for clip: StringName in [Sword.ANIM_REGULAR_A, Sword.ANIM_REGULAR_B, Sword.ANIM_REGULAR_C,
			Sword.ANIM_DASH, Sword.ANIM_HEAVY]:
		assert(_animation_player.has_animation(clip))
	assert(_animation_player.has_animation(Mace.ANIM_HEAVY))
	print("PROBE animaciones_player=clips_presentes")

# ---- Locomocion: Idle / Walk / Sprint por velocidad ----

func _run_locomotion() -> void:
	_ground(Vector3.ZERO)
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"idle_animation"))
	print("PROBE animaciones_player=idle")
	await _hold(0.6)

	var walk_speed: float = (float(_controller.get(&"moving_speed_threshold"))
			+ float(_controller.get(&"sprint_speed_threshold"))) * 0.5
	_ground(Vector3(walk_speed, 0.0, 0.0))
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"walk_animation"))
	print("PROBE animaciones_player=walk")
	await _hold(0.6)

	_ground(Vector3(float(_controller.get(&"sprint_speed_threshold")) + 2.0, 0.0, 0.0))
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"sprint_animation"))
	print("PROBE animaciones_player=sprint")
	await _hold(0.6)

	_ground(Vector3.ZERO)
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"idle_animation"))
	print("PROBE animaciones_player=regreso_a_idle")
	_sections_done += 1

# ---- Salto: Start -> Idle_Loop -> (doble salto re-dispara) -> Land -> corte por moverse ----

func _run_jump() -> void:
	_player.air_state = Player.AirState.AIRBORNE
	_player.vertical_velocity = 8.0
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"jump_start_animation"))
	print("PROBE animaciones_player=salto_despegue")
	await _hold(_length(_clip(&"jump_start_animation")) + 0.1)
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"jump_loop_animation"))
	print("PROBE animaciones_player=salto_loop")

	# Doble salto: la velocidad vertical pasa de caida a impulso -> re-dispara el despegue.
	_player.vertical_velocity = -2.0
	_tick_controller()
	_player.vertical_velocity = 8.0
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"jump_start_animation"))
	print("PROBE animaciones_player=doble_salto_redispara")
	await _hold(_length(_clip(&"jump_start_animation")) + 0.1)

	# Aterrizaje quieto: Land se sostiene land_hold_time.
	_ground(Vector3.ZERO)
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"jump_land_animation"))
	print("PROBE animaciones_player=aterrizaje")

	# Moverse corta el aterrizaje: manda la locomocion.
	_ground(Vector3(2.0, 0.0, 0.0))
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"walk_animation"))
	print("PROBE animaciones_player=aterrizaje_cortado_por_moverse")
	_ground(Vector3.ZERO)
	_tick_controller()
	await _hold(0.4)
	_sections_done += 1

# ---- Wall slide: Start -> Loop -> Exit (y desprenderse en el aire NO deja pose pegada) ----

func _run_wall_slide() -> void:
	_player.air_state = Player.AirState.AIRBORNE
	_player.vertical_velocity = -1.0
	_player.wall_slide.is_sliding = true
	_player.wall_slide.wall_normal = Vector3(1.0, 0.0, 0.0)
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"slide_start_animation"))
	assert(absf(_visual.rotation.y) > 0.1)  # el maniqui roto hacia la pared, no al forward
	print("PROBE animaciones_player=slide_entrada_rotado")
	await _hold(_length(_clip(&"slide_start_animation")) + 0.1)
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"slide_loop_animation"))
	print("PROBE animaciones_player=slide_loop")

	# Aterrizar deslizando: sale por Slide_Exit y la rotacion del maniqui vuelve a cero.
	_player.wall_slide.is_sliding = false
	_ground(Vector3.ZERO)
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"slide_exit_animation"))
	assert(absf(_visual.rotation.y) < 0.01)
	print("PROBE animaciones_player=slide_salida")
	await _hold(_length(_clip(&"slide_exit_animation")) + 0.1)
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"idle_animation"))

	# Desprenderse en el aire: nada de Slide_Exit ni pose pegada, cae directo al loop de aire.
	_player.air_state = Player.AirState.AIRBORNE
	_player.vertical_velocity = -1.0
	_player.wall_slide.is_sliding = true
	_tick_controller()
	await _hold(_length(_clip(&"slide_start_animation")) + 0.1)
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"slide_loop_animation"))
	_player.wall_slide.is_sliding = false
	_player.vertical_velocity = -3.0
	_tick_controller()
	_tick_controller()  # 1er tick sale del slide; 2do re-entra a la capa de aire
	assert(_animation_player.current_animation == _clip(&"jump_loop_animation"))
	print("PROBE animaciones_player=slide_desprendido_en_aire")
	_settle_on_ground()
	_sections_done += 1

# ---- Espada: combo tap por la ruta real + tramos cargados ----

func _run_sword() -> void:
	# Ruta real completa: tap() -> run_combo_chain -> _begin_ground_step -> visual_clip_started.
	_sword.tap(World.Slot.X)
	_tick_controller()
	assert(_animation_player.current_animation == Sword.ANIM_REGULAR_A)
	_assert_speed(_length(Sword.ANIM_REGULAR_A), _sword.tuning.swing_time)
	print("PROBE animaciones_player=espada_tap_regular_a")
	_sword.cancel_routines()
	await _wait_override_release()

	# Mapeo paso->clip del combo terrestre (funcion pura): A,B,A,B sin espera / A,B,C,C con espera.
	assert(_sword._ground_step_clip(1, false) == Sword.ANIM_REGULAR_A)
	assert(_sword._ground_step_clip(2, false) == Sword.ANIM_REGULAR_B)
	assert(_sword._ground_step_clip(3, false) == Sword.ANIM_REGULAR_A)
	assert(_sword._ground_step_clip(4, false) == Sword.ANIM_REGULAR_B)
	assert(_sword._ground_step_clip(3, true) == Sword.ANIM_REGULAR_C)
	assert(_sword._ground_step_clip(4, true) == Sword.ANIM_REGULAR_C)
	print("PROBE animaciones_player=espada_mapeo_combo")

	# X cargado: Sword_Dash completo escalado a la duracion del dash.
	_sword.play_visual_clip(Sword.ANIM_DASH, 0.0, -1.0, 0.5)
	_tick_controller()
	assert(_animation_player.current_animation == Sword.ANIM_DASH)
	_assert_speed(_length(Sword.ANIM_DASH), 0.5)
	print("PROBE animaciones_player=espada_x_cargado_dash")
	await _hold(0.6)
	_tick_controller()

	# Y cargado terrestre: tramo 0.90-1.30 de Sword_Heavy_Combo, arranca dentro del tramo.
	_sword.play_visual_clip(Sword.ANIM_HEAVY, Sword.HEAVY_GROUND_Y_START,
			Sword.HEAVY_GROUND_Y_END, _sword.tuning.swing_time)
	_tick_controller()
	assert(_animation_player.current_animation == Sword.ANIM_HEAVY)
	assert(_animation_player.current_animation_position >= Sword.HEAVY_GROUND_Y_START - 0.02)
	_assert_speed(Sword.HEAVY_GROUND_Y_END - Sword.HEAVY_GROUND_Y_START, _sword.tuning.swing_time)
	print("PROBE animaciones_player=espada_y_cargado_tramo")
	await _wait_override_release()
	# tap() llamó hold_airborne_for_attack: sin piso con colisión, el player quedó AIRBORNE.
	_settle_on_ground()
	_sections_done += 1

# ---- Mazo: tramos de Sword_Heavy_Combo por paso + corte anticipado del Y aereo ----

func _run_mace() -> void:
	# Paso 1 del combo terrestre por la coreografia real.
	_mace._play_ground_step_visual(1, false)
	_tick_controller()
	assert(_animation_player.current_animation == Mace.ANIM_HEAVY)
	assert(_animation_player.current_animation_position <= Mace.HEAVY_STEP_1.y)
	_assert_speed(Mace.HEAVY_STEP_1.y - Mace.HEAVY_STEP_1.x, _mace.tuning.swing_time)
	print("PROBE animaciones_player=mazo_paso_1")
	await _wait_override_release()

	# Smash intermedio (rama espera) vs finisher: comparten arranque 2.10 pero el finisher
	# remata hasta el final del clip (span mas largo -> speed_scale distinto).
	_mace._play_ground_step_visual(3, false)
	_tick_controller()
	assert(_animation_player.current_animation_position >= Mace.HEAVY_SMASH_MID.x - 0.02)
	_assert_speed(Mace.HEAVY_SMASH_MID.y - Mace.HEAVY_SMASH_MID.x, _mace.tuning.swing_time)
	print("PROBE animaciones_player=mazo_smash_intermedio")
	await _wait_override_release()

	_mace._play_ground_step_visual(3, true)
	_tick_controller()
	var full_length := _length(Mace.ANIM_HEAVY)
	assert(_animation_player.current_animation_position >= Mace.HEAVY_SMASH_FINAL.x - 0.02)
	_assert_speed(full_length - Mace.HEAVY_SMASH_FINAL.x, _mace.tuning.swing_time)
	print("PROBE animaciones_player=mazo_smash_finisher")
	await _wait_override_release()

	# Vuelta del X cargado: un tramo por vuelta, a charged_spin_time.
	var t := _mace.tuning as MaceTuning
	_mace.play_visual_clip(Mace.ANIM_HEAVY, Mace.HEAVY_CHARGED_X_SPIN.x,
			Mace.HEAVY_CHARGED_X_SPIN.y, t.charged_spin_time)
	_tick_controller()
	_assert_speed(Mace.HEAVY_CHARGED_X_SPIN.y - Mace.HEAVY_CHARGED_X_SPIN.x, t.charged_spin_time)
	print("PROBE animaciones_player=mazo_x_cargado_vuelta")
	await _wait_override_release()

	# Y aereo: tramo estirado a la caida y CORTADO por end_visual_clip al estallar antes.
	_mace.play_visual_clip(Mace.ANIM_HEAVY, Mace.HEAVY_CHARGED_Y_AIR.x,
			Mace.HEAVY_CHARGED_Y_AIR.y, 2.0)
	_tick_controller()
	assert(_animation_player.current_animation == Mace.ANIM_HEAVY)
	await _hold(0.3)
	_mace.end_visual_clip()
	_tick_controller()
	assert(is_equal_approx(_animation_player.speed_scale, 1.0))
	assert(_animation_player.current_animation == _clip(&"idle_animation"))
	print("PROBE animaciones_player=mazo_y_aereo_cortado")
	_sections_done += 1

# ---- Interrupciones: stun y dash sueltan el clip de arma ----

func _run_interruptions() -> void:
	_settle_on_ground()
	# Stun en suelo: suelta el clip de arma y anima el tramo de stun; al terminar el tramo
	# la pose queda congelada mientras dure el stun (mismo patron que el enemigo).
	_sword.play_visual_clip(Sword.ANIM_DASH, 0.0, -1.0, 2.0)
	_tick_controller()
	assert(_animation_player.current_animation == Sword.ANIM_DASH)
	_player.stun.apply(1.0)
	_tick_controller()
	assert(is_equal_approx(_animation_player.speed_scale, 1.0))
	assert(_animation_player.current_animation == _clip(&"ground_stun_animation"))
	print("PROBE animaciones_player=stun_suelta_clip_y_anima")
	var stun_segment: float = float(_controller.get(&"ground_stun_end")) \
			- float(_controller.get(&"ground_stun_start"))
	await _hold(stun_segment + 0.1)
	_tick_controller()
	assert(is_zero_approx(_animation_player.speed_scale))
	print("PROBE animaciones_player=stun_pose_congelada")
	_player.stun.cancel()
	_tick_controller()
	assert(is_equal_approx(_animation_player.speed_scale, 1.0))
	assert(_animation_player.current_animation == _clip(&"idle_animation"))
	print("PROBE animaciones_player=stun_fin_vuelve_idle")

	# Stun en el aire: usa el tramo aereo (Hit_Knockback).
	_player.air_state = Player.AirState.AIRBORNE
	_player.vertical_velocity = -1.0
	_tick_controller()
	_player.stun.apply(0.5)
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"air_stun_animation"))
	print("PROBE animaciones_player=stun_aire")
	_player.stun.cancel()
	_settle_on_ground()

	_sword.play_visual_clip(Sword.ANIM_DASH, 0.0, -1.0, 2.0)
	_tick_controller()
	assert(_animation_player.current_animation == Sword.ANIM_DASH)
	_player.dash.is_dashing = true
	_tick_controller()
	assert(is_equal_approx(_animation_player.speed_scale, 1.0))
	assert(_animation_player.current_animation == _clip(&"idle_animation"))
	print("PROBE animaciones_player=dash_suelta_clip")
	_player.dash.is_dashing = false
	_tick_controller()

	# Regresión del bug atrapado por este probe: en el aire, al soltarse un override de
	# arma el maniquí tiene que VOLVER al loop de aire (no quedarse congelado en el golpe).
	_player.air_state = Player.AirState.AIRBORNE
	_player.vertical_velocity = -1.0
	_tick_controller()
	_sword.play_visual_clip(Sword.ANIM_DASH, 0.0, -1.0, 0.4)
	_tick_controller()
	assert(_animation_player.current_animation == Sword.ANIM_DASH)
	await _wait_override_release()
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"jump_loop_animation"))
	print("PROBE animaciones_player=aire_recupera_loop_tras_override")
	_settle_on_ground()
	_sections_done += 1

# ---- Helpers ----

## Estado de suelo limpio: sin slide, sin caida, con la velocidad pedida.
func _ground(velocity: Vector3) -> void:
	_player.air_state = Player.AirState.GROUNDED
	_player.vertical_velocity = 0.0
	_player.velocity = velocity

## Aterriza determinista y deja el maniqui en Idle, venga de donde venga (aire, slide,
## aterrizaje sostenido): tick de Land -> corte por moverse -> Idle. Sin timers.
func _settle_on_ground() -> void:
	_ground(Vector3.ZERO)
	_tick_controller()
	_ground(Vector3(2.0, 0.0, 0.0))
	_tick_controller()
	_ground(Vector3.ZERO)
	_tick_controller()
	assert(_animation_player.current_animation == _clip(&"idle_animation"))

## El tramo tiene que reproducirse escalado a la duracion mecanica del golpe.
func _assert_speed(span: float, duration: float) -> void:
	assert(absf(_animation_player.speed_scale - span / duration) < 0.01)

## Espera a que el override de arma expire y el controlador vuelva a locomocion.
func _wait_override_release() -> void:
	while bool(_controller.get(&"_override_active")):
		await get_tree().physics_frame
	_tick_controller()
	assert(is_equal_approx(_animation_player.speed_scale, 1.0))

func _hold(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _length(animation: StringName) -> float:
	return _animation_player.get_animation(animation).length

func _clip(property: StringName) -> StringName:
	return StringName(_controller.get(property))

func _tick_controller() -> void:
	_controller.call("_physics_process", 0.0)

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
