class_name PlayerAnimationController extends Node
## Capa VISUAL del player (mismo patrón que EnemyAnimationController): traduce estados ya
## resueltos (locomoción, salto, wall slide y golpes de arma) a clips del maniquí UAL.
## No mueve el CharacterBody, no abre hitboxes ni decide impactos: el feel mecánico
## (swings procedurales de Hand/Pivot, ventanas de daño) conserva la autoridad.
##
## Capas por prioridad, cada physics frame:
##   1. Golpe de arma (WeaponBase.visual_clip_started): tramo de clip escalado a la
##      duración mecánica del golpe.
##   2. Wall slide: Slide_Start → Slide_Loop → Slide_Exit; el maniquí rota hacia la pared.
##   3. Aire: NinjaJump_Start → NinjaJump_Idle_Loop → NinjaJump_Land al aterrizar.
##   4. Locomoción: Idle / Walk / Sprint por velocidad horizontal.
##
## UAL2 (maniquí de la escena) aporta idle, ninja jump, slide y los clips de combate;
## UAL1 completa Walk_Loop / Sprint_Loop sobre el mismo esqueleto de 67 huesos, así que
## se copian en runtime al AnimationPlayer de UAL2 (igual que en el piloto de enemigos).

const UAL1_SCENE := preload("res://assets/animations/Universal Animation Library[Standard]/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb")
const UAL1_ANIMATIONS := [&"Idle", &"Walk", &"Sprint"]

# Nombres REALES de los .glb importados (verificados con Godot listando get_animation_list):
# la bóveda planeaba sufijos _Loop (Walk_Loop, NinjaJump_Idle_Loop…) que no existen en el
# import. Idle_No_Loop tampoco existe: se usa Idle de UAL1, el mismo del enemigo.
@export var idle_animation: StringName = &"Idle"
@export var walk_animation: StringName = &"Walk"
@export var sprint_animation: StringName = &"Sprint"
@export var jump_start_animation: StringName = &"NinjaJump_Start"
@export var jump_loop_animation: StringName = &"NinjaJump_Idle"
@export var jump_land_animation: StringName = &"NinjaJump_Land"
@export var slide_start_animation: StringName = &"Slide_Start"
@export var slide_loop_animation: StringName = &"Slide"
@export var slide_exit_animation: StringName = &"Slide_Exit"
# Arma en mano (opción A): una COPIA visual de los meshes del arma cuelga del hueso de la
# mano vía BoneAttachment3D y acompaña la animación; los meshes orbitales quedan invisibles
# pero sus hitboxes siguen barriendo — el daño no cambia. La copia comparte los materiales
# (el glow de carga se ve en la mano). Offset/rotación para acomodar el grip, a tunear.
## El arma orbital está autorizada en el espacio del Player (la hoja apunta a -Z, el forward
## de Godot), pero la copia cuelga del hueso — o sea DENTRO del UAL2_Standard, que lleva el
## 180° en Y que endereza al maniquí (ver bóveda Animacion/Player). La copia heredaba ese
## giro y salía apuntando hacia atrás: estos 180° lo compensan.
@export var hand_bone_name: StringName = &"hand_r"
@export var hand_attach_offset := Vector3.ZERO
@export var hand_attach_rotation_degrees := Vector3(0.0, 180.0, 0.0)
# Stun: fuera del plan original de la bóveda — espeja al enemigo (EnemyAnimationController):
# tramo del clip y pose final congelada mientras dure el stun.
@export var ground_stun_animation: StringName = &"Zombie_Scratch"
@export var air_stun_animation: StringName = &"Hit_Knockback"
@export_range(0.0, 2.0, 0.01) var ground_stun_start := 0.0
@export_range(0.0, 2.0, 0.01) var ground_stun_end := 0.4
@export_range(0.0, 2.0, 0.01) var air_stun_start := 0.15
@export_range(0.0, 2.0, 0.01) var air_stun_end := 0.25
## Velocidad horizontal (m/s) mínima para dejar el Idle y caminar.
@export var moving_speed_threshold := 0.15
## Velocidad horizontal (m/s) a partir de la cual el Walk pasa a Sprint. El player corre a
## move_speed (PlayerTuning); con stick parcial va más lento, por eso el corte queda debajo.
@export var sprint_speed_threshold := 5.0
## Crossfade (s) entre clips de locomoción/aire/slide. Los golpes de arma cortan seco.
@export_range(0.0, 0.5, 0.01) var blend_time := 0.15
## Cuánto (s) se sostiene NinjaJump_Land al aterrizar antes de ceder a la locomoción.
## Moverse lo corta antes: el aterrizaje nunca traba el feel de correr.
@export_range(0.0, 1.5, 0.01) var land_hold_time := 0.4
## El maniquí encara la pared durante el wall slide (false = de espaldas a la pared).
@export var face_wall := true

enum AirPhase { NONE, START, LOOP }

var _player: Player
var _animation_player: AnimationPlayer
var _visual: Node3D
var _air_phase := AirPhase.NONE
var _air_start_ends_at := -INF
var _was_airborne := false
var _prev_vertical_velocity := 0.0
var _land_until := -INF
var _slide_active := false
var _slide_loop_starts_at := -INF
var _slide_exit_until := -INF
var _override_active := false
var _override_ends_at := -INF
var _stun_visual_active := false
var _stun_animation_frozen := false
var _stun_segment_end := 0.0
var _stun_segment_ends_at := -INF
var _hand_attachment: BoneAttachment3D
var _hand_copies := {}  # WeaponBase → Node3D (copia visual en la mano)

func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_warning("PlayerAnimationController necesita ser hijo de Player.")
		set_physics_process(false)
		return
	_visual = _player.get_node_or_null("Visual") as Node3D
	_animation_player = _find_animation_player(_visual)
	if _animation_player == null:
		push_warning("No se encontró AnimationPlayer bajo Visual; el player queda sin animación.")
		set_physics_process(false)
		return
	_import_ual1_animations()
	_connect_weapons()
	# Un arma equipada después (menú de loadout) también tiene que avisar sus clips.
	var combat := _player.get_node_or_null("Combat") as PlayerCombat
	if combat != null and not combat.slots_changed.is_connected(_on_slots_changed):
		combat.slots_changed.connect(_on_slots_changed)
	# La señal (no solo el polling) cubre la EXTENSIÓN del stun: cada golpe que extiende
	# re-dispara el tramo, igual que stun_started en el enemigo. Por path y no por
	# _player.stun: los @onready del Player todavía no corrieron (hijo antes que padre).
	var stun := _player.get_node_or_null("Stun") as PlayerStun
	if stun != null and not stun.stunned_started.is_connected(_on_stunned_started):
		stun.stunned_started.connect(_on_stunned_started)
	# Diferido: espera a que los _ready de las armas corran (glow de carga incluido) para
	# que las copias en mano compartan sus materiales ya preparados.
	_setup_hand_attachment.call_deferred()
	_play_loop(idle_animation)

func _on_slots_changed(_slot_x: WeaponBase, _slot_y: WeaponBase) -> void:
	_connect_weapons()
	_build_missing_hand_copies()

## Señal hacia arriba: cada arma avisa qué tramo de clip muestra su golpe.
func _connect_weapons() -> void:
	for child in _player.get_children():
		var weapon := child as WeaponBase
		if weapon == null:
			continue
		if not weapon.visual_clip_started.is_connected(_on_weapon_clip_started):
			weapon.visual_clip_started.connect(_on_weapon_clip_started)
		if not weapon.visual_clip_ended.is_connected(_release_override):
			weapon.visual_clip_ended.connect(_release_override)

func _physics_process(_delta: float) -> void:
	if _player == null or _animation_player == null:
		return
	_sync_hand_copies_visibility()
	# Stun o dash cancelan el golpe en curso: soltamos el override. El stun tiene capa
	# propia (abajo); el dash no tiene clip en el plan y cae a aire/locomoción.
	if _player.is_stunned() or _player.dash.is_dashing:
		_release_override()
	if _player.is_stunned():
		_update_stun_visual()
		return
	_stop_stun_visual()
	if _override_active:
		if World.now() < _override_ends_at:
			return
		_release_override()
	if _update_slide_visual():
		return
	if _update_air_visual():
		return
	_update_locomotion_animation()

# ---- Capa 1: golpes de arma ----

## end_time < 0 = hasta el final del clip. duration <= 0 = el tramo dura su tiempo natural.
## El tramo se escala a la duración mecánica del golpe (speed_scale): la animación acompaña
## a la ventana de daño, nunca la manda.
func _on_weapon_clip_started(clip: StringName, start_time: float, end_time: float,
		duration: float) -> void:
	if not _has_animation(clip):
		return
	# El stun manda (capa de prioridad máxima). PlayerStun.apply NO cancela las rutinas de
	# arma en vuelo: sin este guard, el golpe que despierta a mitad del stun pisa la pose
	# congelada por la espalda — y como _stun_animation_frozen ya es true, _update_stun_visual
	# sale temprano y nunca la restaura (el maniquí sigue atacando stuneado).
	if _player.is_stunned():
		return
	_stop_slide_rotation()
	var clip_length := _animation_player.get_animation(clip).length
	var start := clampf(start_time, 0.0, clip_length)
	var end := clip_length if end_time < 0.0 else clampf(end_time, start, clip_length)
	var span := maxf(0.01, end - start)
	var visual_duration := duration if duration > 0.0 else span
	_animation_player.speed_scale = span / visual_duration
	_animation_player.play(clip)
	_animation_player.seek(start, true)
	_override_active = true
	_override_ends_at = World.now() + visual_duration

func _release_override() -> void:
	if not _override_active:
		return
	_override_active = false
	_animation_player.speed_scale = 1.0

# ---- Arma en mano (BoneAttachment3D sobre el hueso de la mano) ----

## Construye el attachment y una copia visual por arma. Los meshes orbitales (los que
## barren con la Hand procedural) quedan invisibles: sus Hitbox hermanos siguen intactos.
func _setup_hand_attachment() -> void:
	var skeleton := _find_skeleton(_visual)
	if skeleton == null:
		push_warning("Sin Skeleton3D bajo Visual: el arma no se adjunta a la mano.")
		return
	_hand_attachment = BoneAttachment3D.new()
	_hand_attachment.name = "HandAttachment"
	skeleton.add_child(_hand_attachment)
	_hand_attachment.bone_name = hand_bone_name
	_build_missing_hand_copies()

## Un arma equipada después (menú de loadout) también gana su copia en mano.
func _build_missing_hand_copies() -> void:
	if _hand_attachment == null:
		return
	for child in _player.get_children():
		var weapon := child as WeaponBase
		if weapon == null or weapon in _hand_copies:
			continue
		var copy := _build_hand_copy(weapon)
		if copy != null:
			_hand_attachment.add_child(copy)
			_hand_copies[weapon] = copy
	_sync_hand_copies_visibility()

## Copia solo los MeshInstance3D del Pivot (BladeMesh / HandleMesh+HeadMesh), preservando
## sus transforms locales — el grip queda en el origen del hueso. duplicate() comparte mesh
## y materiales por referencia: el glow de carga del arma se ve en la copia.
func _build_hand_copy(weapon: WeaponBase) -> Node3D:
	var pivot := weapon.get_node_or_null("Hand/Pivot")
	if pivot == null:
		return null
	var copy_root := Node3D.new()
	copy_root.name = weapon.name + "HandVisual"
	var found := false
	for child in pivot.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null:
			continue
		var mesh_copy := mesh.duplicate() as MeshInstance3D
		mesh_copy.visible = true
		copy_root.add_child(mesh_copy)
		mesh.visible = false  # la hoja orbital ya no se ve; su hitbox sigue barriendo
		found = true
	if not found:
		copy_root.free()
		return null
	copy_root.position = hand_attach_offset
	copy_root.rotation_degrees = hand_attach_rotation_degrees
	return copy_root

## La copia en mano sigue la visibilidad del arma (PlayerCombat muestra solo la activa).
func _sync_hand_copies_visibility() -> void:
	for weapon: WeaponBase in _hand_copies:
		var copy: Node3D = _hand_copies[weapon]
		if is_instance_valid(weapon) and is_instance_valid(copy) \
				and copy.visible != weapon.visible:
			copy.visible = weapon.visible

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

# ---- Capa de stun (prioridad máxima, mismo patrón que EnemyAnimationController) ----

func _on_stunned_started(_duration: float, _mode: PlayerStun.Mode) -> void:
	_release_override()
	# apply_stun ya canceló el wall slide: se limpia también el estado visual del slide
	# para que al salir del stun no quede una salida de slide fantasma.
	_slide_active = false
	_stop_slide_rotation()
	if _player.is_airborne():
		_start_stun_visual(air_stun_animation, air_stun_start, air_stun_end)
	else:
		_start_stun_visual(ground_stun_animation, ground_stun_start, ground_stun_end)

## Reproduce un tramo y sostiene su pose final hasta que el stun termina.
func _start_stun_visual(animation: StringName, start_time: float, end_time: float) -> void:
	if not _has_animation(animation):
		return
	var clip := _animation_player.get_animation(animation)
	var start := clampf(start_time, 0.0, clip.length)
	_stun_segment_end = clampf(maxf(start, end_time), start, clip.length)
	_stun_segment_ends_at = World.now() + (_stun_segment_end - start)
	_stun_visual_active = true
	_stun_animation_frozen = false
	_animation_player.speed_scale = 1.0
	_animation_player.play(animation)
	_animation_player.seek(start, true)

func _update_stun_visual() -> void:
	if not _stun_visual_active:
		_on_stunned_started(0.0, _player.stun.mode)
		return
	if World.now() < _stun_segment_ends_at or _stun_animation_frozen:
		return
	_animation_player.seek(_stun_segment_end, true)
	_animation_player.speed_scale = 0.0
	_stun_animation_frozen = true

func _stop_stun_visual() -> void:
	if not _stun_visual_active:
		return
	if _stun_animation_frozen:
		_animation_player.speed_scale = 1.0
	_stun_visual_active = false
	_stun_animation_frozen = false

# ---- Capa 2: wall slide ----

## True si esta capa es dueña del frame (deslizando o saliendo del slide).
func _update_slide_visual() -> bool:
	if _player.wall_slide.is_sliding:
		if not _slide_active:
			_slide_active = true
			_slide_exit_until = -INF
			_slide_loop_starts_at = World.now() + _animation_length(slide_start_animation)
			_play_one_shot(slide_start_animation)
		elif World.now() >= _slide_loop_starts_at \
				or _animation_player.current_animation != slide_start_animation:
			# Entrada terminada — o pisada por un override de arma: sostiene el loop.
			_play_loop(slide_loop_animation)
		_face_wall_normal(_player.wall_slide.wall_normal)
		return true
	if _slide_active:
		_slide_active = false
		_stop_slide_rotation()
		# La salida solo se ve si el slide terminó sin salir disparado: un wall jump ya es
		# aire (la capa de salto pisa el exit) y aterrizar corta a locomoción.
		if _player.is_airborne():
			# Re-entra limpio a la capa de aire: wall jump re-dispara el despegue y un
			# despegue perdido cae al loop (sin esto el maniquí queda pegado en Slide_Loop).
			_was_airborne = false
			_air_phase = AirPhase.NONE
			return false
		_slide_exit_until = World.now() + _animation_length(slide_exit_animation)
		_play_one_shot(slide_exit_animation)
	if World.now() < _slide_exit_until:
		if _player.is_airborne():
			_slide_exit_until = -INF
			return false
		return true
	return false

## [[Wall Slide y Wall Jump]]: el maniquí rota según la dirección de la pared, no queda
## fijo al forward del player. Solo gira el Visual: el forward de gameplay no se toca.
## El maniquí UAL (estilo Unreal) mira +Z, por eso va con 180° en Y dentro de Visual
## (en player.tscn) — y por eso acá el look_at apunta al REVÉS de lo que se quiere que
## el maniquí encare: face_wall=true → look_at hacia AFUERA de la pared.
func _face_wall_normal(wall_normal: Vector3) -> void:
	if _visual == null:
		return
	var facing := wall_normal if face_wall else -wall_normal
	facing.y = 0.0
	if facing.length_squared() < 0.0001:
		return
	_visual.look_at(_visual.global_position + facing.normalized(), Vector3.UP)

func _stop_slide_rotation() -> void:
	if _visual != null:
		_visual.rotation = Vector3.ZERO

# ---- Capa 3: aire (ninja jump) ----

## True si esta capa es dueña del frame (en el aire o sosteniendo el aterrizaje).
func _update_air_visual() -> bool:
	var airborne := _player.is_airborne()
	var vertical := _player.vertical_velocity
	if airborne:
		if not _was_airborne:
			# Despegue con impulso = salto; caer de un borde va directo al loop de aire.
			if vertical > 0.0:
				_start_jump()
			else:
				_air_phase = AirPhase.LOOP
				_play_loop(jump_loop_animation)
		elif _air_phase == AirPhase.START:
			# El despegue terminó — o un override de arma lo pisó: pasa al loop sostenido.
			if World.now() >= _air_start_ends_at \
					or _animation_player.current_animation != jump_start_animation:
				_air_phase = AirPhase.LOOP
				_play_loop(jump_loop_animation)
		elif _prev_vertical_velocity <= 0.0 and vertical > 0.5:
			_start_jump()  # doble salto / launcher: re-dispara el despegue
		else:
			# Estado sostenido: re-asegura el loop. Sin esto, al soltarse un override de
			# arma en el aire nadie vuelve a poner el clip y el maniquí queda congelado
			# en la pose del golpe (lo atrapó el probe).
			_play_loop(jump_loop_animation)
		_was_airborne = true
		_prev_vertical_velocity = vertical
		return true
	if _was_airborne:
		_was_airborne = false
		_air_phase = AirPhase.NONE
		_land_until = World.now() + land_hold_time
		_play_one_shot(jump_land_animation)
	_prev_vertical_velocity = vertical
	if World.now() < _land_until:
		# Moverse corta el aterrizaje (manda la locomoción); un override de arma que lo
		# pisó también lo invalida — al soltarse no hay pose de Land que sostener.
		if _horizontal_speed() >= moving_speed_threshold \
				or _animation_player.current_animation != jump_land_animation:
			_land_until = -INF
			return false
		return true
	return false

func _start_jump() -> void:
	_air_phase = AirPhase.START
	_air_start_ends_at = World.now() + _animation_length(jump_start_animation)
	_play_one_shot(jump_start_animation)

# ---- Capa 4: locomoción ----

func _update_locomotion_animation() -> void:
	var speed := _horizontal_speed()
	if speed >= sprint_speed_threshold:
		_play_loop(sprint_animation)
	elif speed >= moving_speed_threshold:
		_play_loop(walk_animation)
	else:
		_play_loop(idle_animation)

func _horizontal_speed() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()

# ---- Helpers (mismos que EnemyAnimationController) ----

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

## UAL2 aporta idle/salto/slide/combate; UAL1 completa la locomoción sobre el mismo esqueleto.
func _import_ual1_animations() -> void:
	var source_root := UAL1_SCENE.instantiate()
	var source_player := _find_animation_player(source_root)
	if source_player == null:
		source_root.free()
		return
	var library := _animation_player.get_animation_library(&"")
	if library != null:
		for animation_name in UAL1_ANIMATIONS:
			if _has_animation(animation_name):
				continue
			var source_animation := source_player.get_animation(animation_name)
			if source_animation != null:
				library.add_animation(animation_name, source_animation.duplicate(true))
	source_root.free()

func _animation_length(animation: StringName) -> float:
	if not _has_animation(animation):
		return 0.0
	return _animation_player.get_animation(animation).length

func _play_loop(animation: StringName) -> void:
	if not _has_animation(animation):
		return
	if _animation_player.current_animation == animation and _animation_player.is_playing():
		return
	_animation_player.play(animation, blend_time)

func _play_one_shot(animation: StringName) -> void:
	if not _has_animation(animation):
		return
	_animation_player.play(animation, blend_time)
	_animation_player.seek(0.0, true)

func _has_animation(animation: StringName) -> bool:
	return _animation_player != null and _animation_player.has_animation(animation)
