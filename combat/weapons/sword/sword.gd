class_name Sword extends WeaponBase
## Espada (bóveda: Armas/Espada): tap = combo de 4 + rama espera + sweet spot;
## Y cargado = golpe vertical / Y cargada aérea. X cargado = dash ofensivo (gasta 1 barra).
## Swings 100% procedurales (tweens de quaternion sobre la Hand), SIN AnimationPlayer.
## Los combos corren sobre el motor genérico de WeaponBase (run_combo_chain);
## acá vive solo la coreografía. Ángulos y ventanas se tunean en SwordTuning.
# ponytail: personalidades X/Y como funcs aquí; extraer strategy cuando exista la 2ª arma.

const STEP_COUNT := 4

# Clips UAL2 del plan de la bóveda (Animacion Espada) — nombres verificados contra el .glb.
const ANIM_REGULAR_A := &"Sword_Regular_A"
const ANIM_REGULAR_B := &"Sword_Regular_B"
const ANIM_REGULAR_C := &"Sword_Regular_C"
const ANIM_DASH := &"Sword_Dash"
const ANIM_HEAVY := &"Sword_Heavy_Combo"
# Clip propio (WIP, animaciones/) para el golpe vertical terrestre (launcher).
const ANIM_LAUNCHER := &"Sword_Launcher"
# Tramo de Sword_Heavy_Combo para la cargada Y aerea (segundos dentro del clip).
const HEAVY_AIR_Y_START := 2.40
const HEAVY_AIR_Y_END := 2.70

var _charged_dash_id := 0
var _sweet_spot_dash := false
## El X cargado termina en su primer objetivo para reposicionar al Player una sola vez.
var _charged_dash_connected := false
## Direccion capturada al empezar el dash: define el lado de salida al atravesar al objetivo.
var _charged_dash_travel_direction := Vector3.FORWARD
var _aerial_charged_y_active := false
## Rutina X direccional cuyo movimiento/vueltas aun bloquean la ejecucion del hold.
var _directional_x_routine_id := -1
var _directional_x_animation_done := true
var _directional_x_mover_pending := false
## Rama plunge elegida para el finisher aéreo en curso (la lee _finish_air_combo).
var _air_plunge_finisher := false
# Estiramiento vertical de hitboxes del finisher aéreo (ver air_finisher_hitbox_v_scale):
# la hoja agranda su caja y el disco esférico se cambia por una cápsula vertical mientras
# dura el golpe. Shapes propios capturados/creados en setup().
var _blade_shape: BoxShape3D
var _blade_base_size := Vector3.ZERO
var _disc_shape_node: CollisionShape3D
var _disc_sphere: SphereShape3D
var _disc_capsule: CapsuleShape3D

@onready var _vertical_hitbox: Hitbox = $VerticalHitbox
@onready var _charged_dash_hitbox: Hitbox = $ChargedDashHitbox
@onready var _charged_dash_shape: CollisionShape3D = $ChargedDashHitbox/CollisionShape3D

func setup(player: Player) -> void:
	super.setup(player)
	for hitbox: Hitbox in [_blade_hitbox, _air_disc_hitbox, _vertical_hitbox, _charged_dash_hitbox]:
		if hitbox != null:
			hitbox.set_debug_enabled(_t().debug_show_hitboxes)
	setup_vertical_hitbox(_vertical_hitbox, _t().ground_charged_y_deals_damage, tuning.stun)
	# El golpe vertical terrestre (cargado Y) SI se parria: clavarlo en un enemigo atacando cuenta como
	# parry (usa parry_poise_charged_y). setup_vertical_hitbox lo deja en false; lo reactivamos aca.
	_vertical_hitbox.can_be_parried = true

	# Dash cargado (cargado X): hitbox PROPIO de la espada (no comparte con el dash de movimiento del
	# dodge). Su daño/stun/tamaño salen de SwordTuning. Se parria: clavarlo en un enemigo atacando
	# cuenta como parry (usa parry_poise_charged_x).
	_charged_dash_hitbox.source = player
	_charged_dash_hitbox.damage = _t().charged_dash_damage
	_charged_dash_hitbox.stun = _t().charged_dash_stun
	_charged_dash_hitbox.can_be_parried = true
	(_charged_dash_shape.shape as SphereShape3D).radius = _t().charged_dash_hit_radius
	_charged_dash_hitbox.landed.connect(_on_charged_dash_hit)

	for hitbox: Hitbox in [_blade_hitbox, _air_disc_hitbox]:
		if hitbox != null:
			hitbox.landed.connect(_on_aerial_charged_y_hit)
			hitbox.landed.connect(_on_aerial_normal_hit)

	# Shapes propios para el estiramiento del finisher aéreo: la hoja duplica su BoxShape
	# (el .tscn comparte el recurso entre instancias) y el disco prepara su cápsula gemela.
	var blade_shape_node := _blade_hitbox.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if blade_shape_node != null and blade_shape_node.shape is BoxShape3D:
		_blade_shape = (blade_shape_node.shape as BoxShape3D).duplicate()
		blade_shape_node.shape = _blade_shape
		_blade_base_size = _blade_shape.size
	if _air_disc_hitbox != null:
		_disc_shape_node = _air_disc_hitbox.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if _disc_shape_node != null and _disc_shape_node.shape is SphereShape3D:
			_disc_sphere = _disc_shape_node.shape as SphereShape3D
			_disc_capsule = CapsuleShape3D.new()

## La Y cargada aérea usa el MISMO hitbox que los taps: sin este flag, su auto-launch se comería
## el corte de momentum del air-hit-stall.
func is_charged_move_active() -> bool:
	return _aerial_charged_y_active or attack_movement_overrides_air_hit()

## Los especiales aereos de tap X manejan su propio float/Mover (lo declara `overrides_air_hit` en
## su perfil). Evitan que el air-hit-stall generico reemplace el hang propio del gesto.
func register_weapon_hit(hurtbox: Hurtbox, died: bool, cuts_air_momentum := true,
		triggers_player_float := true) -> void:
	if attack_movement_overrides_air_hit():
		super.register_weapon_hit(hurtbox, died, false, false)
		return
	super.register_weapon_hit(hurtbox, died, cuts_air_momentum, triggers_player_float)

func tap(_slot: World.Slot) -> void:
	_tap_combo()

func hold(slot: World.Slot, _level: int) -> void:
	if slot == World.Slot.X:
		_hold_x()
	else:
		_hold_y()

## Preview del HUD. X cargado paga con el descuento del sweet spot (_hold_x); Y cargado cuesta la
## barra entera en aire y en suelo (_aerial_charged_y / _hold_y). El gesto tap atras + Y no pasa por
## acá: es un tap, no un cargado, y sigue siendo gratis.
func charged_meter_cost(slot: World.Slot, held_time: float) -> float:
	if _player == null:
		return 0.0
	var full := _player.tuning.meter_charged_cost
	if slot == World.Slot.X:
		return full * tuning.meter_cost_scale(tuning.in_sweet_spot(held_time))
	return full

## Tap atras relativo al target lockeado seguido de Y. No consume meter y puede salir tanto
## en suelo como en aire porque reutiliza el launcher terrestre y sus Movers.
func try_lock_back_y_launcher() -> bool:
	if _t().tap_back_y_window <= 0.0:
		return false
	cancel_routines()
	if _player.is_airborne():
		_run_air_back_y_plunge()
	else:
		_run_enemy_only_launcher()
	return true

func lock_back_y_launcher_window() -> float:
	return _t().tap_back_y_window

## Tap adelante relativo al target lockeado seguido de Y. Reusa la vuelta final de la rama
## X X espera X X y solicita su propio Mover horizontal para el Player; el push solo sale en aire.
func try_lock_forward_y_push() -> bool:
	if _t().tap_forward_y_window <= 0.0:
		return false
	cancel_routines()
	_run_forward_y_push()
	return true

func lock_forward_y_push_window() -> float:
	return _t().tap_forward_y_window

## Tap adelante relativo al target lockeado seguido de X. Hace la vuelta final sin avance,
## retroceso ni push.
func try_lock_forward_x_static_spin() -> bool:
	if _t().tap_forward_x_window <= 0.0:
		return false
	cancel_routines()
	_begin_directional_x()
	_run_forward_x_static_spin(_try_spend_tap_x_meter())
	return true

func lock_forward_x_static_spin_window() -> float:
	return _t().tap_forward_x_window

## Tap atras relativo al target lockeado seguido de X. Reusa la animacion del launcher, pero
## solo mueve al Player hacia atras: no activa hitbox vertical ni lanza al Enemy.
func try_lock_back_x_retreat() -> bool:
	if _t().tap_back_x_window <= 0.0:
		return false
	cancel_routines()
	_begin_directional_x()
	_run_back_x_retreat(_try_spend_tap_x_meter())
	return true

func lock_back_x_retreat_window() -> float:
	return _t().tap_back_x_window

func directional_special_is_active() -> bool:
	return _directional_x_routine_id == _routine_id \
			and (not _directional_x_animation_done or _directional_x_mover_pending)

func _begin_directional_x() -> void:
	_directional_x_routine_id = _routine_id
	_directional_x_animation_done = false
	_directional_x_mover_pending = false

# ---- Tap: combo de 4 compartido por X/Y ----

## Combo terrestre (bóveda Armas): tap tap tap tap → swing, swing, estocada, estocada.
## tap tap (espera) tap tap → los golpes 3-4 pasan a vueltas completas.
func _tap_combo() -> void:
	# En el aire: combo aéreo (motor genérico en WeaponBase), no el terrestre.
	if _player.is_airborne():
		play_aerial_combo()
		return
	if try_queue_combo(&"ground"):
		return
	run_combo_chain(&"ground", STEP_COUNT, tuning.swing_time, _t().combo_window,
			2, _t().ground_wait_branch_threshold, _begin_ground_step)

func _begin_ground_step(step: int, finisher: bool, wait_branch: bool) -> void:
	_play_combo_step(step, wait_branch)
	if finisher and wait_branch:
		arm_push(tuning.push, tuning.swing_time * tuning.push_at)
	_player.attack_step(tuning.swing_time)  # avanza hacia el lockeado / al frente
	_player.hold_airborne_for_attack()

# ---- Personalidad X: cargado (dash sweet spot) ----

## X cargado: dash ofensivo (sweet spot). Gasta 1 barra; el daño lo pone el hitbox PROPIO
## de la espada (no el del dash de movimiento) → un kill en la ventana del cargado devuelve
## la barra completa.
func _hold_x() -> void:
	# Move de compromiso: interrumpe el combo en curso y dashea.
	cancel_routines()

	# Soltar dentro de la ventana de sweet spot abarata el dash y encadena un launcher al conectar.
	_sweet_spot_dash = sweet_spot
	_charged_dash_connected = false
	if _player.meter.spend_charged(1, true, tuning.meter_cost_scale(_sweet_spot_dash)):
		_charged_dash_travel_direction = _charged_dash_direction(_sweet_spot_dash).normalized()
		play_visual_clip(ANIM_DASH, 0.0, -1.0, _t().charged_dash_duration)
		_player.force_dash(_charged_dash_travel_direction, _t().charged_dash_distance,
				_t().charged_dash_duration, true)
		_run_charged_dash_window()
	else:
		# ponytail: sin barra no hay dash — cae a un swing cargado normal.
		# "sweet spot degradado sin meter" es diseño futuro, ver bóveda Combate.
		swing(_t().charged_fallback_angle)
		_player.hold_airborne_for_attack()
		begin_damage_window(tuning.swing_time)
	ComboTracker.register_hit()

# ---- Personalidad Y: golpe vertical / cargada aérea ----

func _hold_y() -> void:
	# Entrada de ataque: invalida la rutina en curso y desarma su push. Sin esto, el push que
	# arma el finisher de la rama espera sobrevive y el golpe vertical empuja en vez de mover.
	cancel_routines()
	# En el aire: Y cargada aérea (movimiento propio + spike/rebote), no el golpe terrestre.
	if _player.is_airborne():
		_aerial_charged_y()
		return
	# Golpe vertical terrestre (ex AttackLauncher: solo desde el suelo — ya garantizado acá).
	# Cuesta 1 barra como cualquier cargado: elevar al enemigo abre el juggle entero, no puede ser
	# el único cargado gratis del arma.
	if not _player.meter.spend_charged():
		# ponytail: sin barra no hay launcher — cae al tap terrestre normal, igual que la Y aérea.
		_tap_combo()
		return
	_run_ground_launcher()

## Launcher cargado: eleva al Player y al Enemy.
func _run_ground_launcher() -> void:
	_begin_launcher()
	run_vertical_window(_vertical_hitbox, _t().ground_charged_y_player_mover,
			_t().ground_charged_y_enemy_mover, _t().ground_charged_y_hitbox_duration)

## Tap atras + Y: comparte el golpe, pero solo el Enemy recibe el Mover vertical (por eso no hay
## perfil de Player). Usa el suyo propio, separado del Y cargado terrestre, para tunearlo aparte.
func _run_enemy_only_launcher() -> void:
	_begin_launcher()
	run_vertical_window(_vertical_hitbox, null,
			_t().tap_back_y_enemy_mover, _t().ground_charged_y_hitbox_duration, 0.05, false)

## En aire, tap atras + Y es un plunge: el hachazo conserva alcance y, al cerrarse, ambos cuerpos
## usan los mismos Movers DOWN de X X espera X. En whiff el Player tambien cae (move de compromiso).
func _run_air_back_y_plunge() -> void:
	var id := begin_routine()
	_face_locked_target()
	_player.locomotion.lock_facing(tuning.swing_time)
	_player.locomotion.lock_movement(tuning.swing_time)
	_player.bump_velocity = Vector3.ZERO
	_run_finisher_v_stretch()
	play_visual_clip(ANIM_HEAVY, HEAVY_AIR_Y_START, HEAVY_AIR_Y_END, tuning.swing_time)
	var half := _t().air_finisher_angle
	_play_swing(Quaternion(Vector3.RIGHT, deg_to_rad(-half)), Quaternion(Vector3.RIGHT, deg_to_rad(half)))
	begin_damage_window(tuning.swing_time)
	ComboTracker.register_hit()
	await wait_seconds(tuning.swing_time)
	if not is_routine_current(id):
		return
	_start_air_plunge_from_hits(_t().tap_back_y_air_player_mover, _t().tap_back_y_air_enemy_mover)

## Tap adelante + Y: la misma vuelta final de la rama espera. En aire arma PushSettings; en suelo
## solo avanza el Player. El Mover se clona porque direction es mundo y no debe mutar el .tres.
func _run_forward_y_push() -> void:
	_face_locked_target()
	_player.locomotion.lock_facing(tuning.swing_time)
	_player.locomotion.lock_movement(tuning.swing_time)
	_player.bump_velocity = Vector3.ZERO
	play_visual_clip(ANIM_REGULAR_C, 0.0, -1.0, tuning.swing_time)
	_play_spin()
	if _player.is_airborne():
		arm_push(tuning.push, tuning.swing_time * tuning.push_at)
	_request_tap_forward_y_mover()
	begin_damage_window(tuning.swing_time)
	ComboTracker.register_hit()

func _request_tap_forward_y_mover() -> void:
	var profile := _t().tap_forward_y_player_mover
	if profile == null:
		return
	var mover := profile.duplicate() as MoverSettings
	var direction := _player.forward()
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	mover.direction = direction.normalized()
	_player.request_mover(mover)

## Tap adelante + X: vueltas puras, sin Mover ni proyectil. En aire sostiene a ambos cuerpos
## con el Floater propio. RT solo usa la cantidad mejorada.
func _run_forward_x_static_spin(with_meter := false) -> void:
	var id := _routine_id
	var airborne := _player.is_airborne()
	_face_locked_target()
	_player.locomotion.lock_facing(tuning.swing_time)
	_player.locomotion.lock_movement(tuning.swing_time)
	_player.bump_velocity = Vector3.ZERO
	_player.mover.cancel_mover(Mover.CancelReason.ATTACK_RULE)
	_run_directional_x_movement(_forward_x_profile(airborne, with_meter), id)
	var spins: int = _t().tap_forward_x_meter_spins if with_meter \
			else _t().tap_forward_x_spins
	spins = maxi(spins, 1)
	play_visual_clip(ANIM_REGULAR_C, 0.0, -1.0, tuning.swing_time * float(spins))
	_play_spin()
	begin_damage_window(tuning.swing_time * float(spins))
	ComboTracker.register_hit()
	for spin_index in range(1, spins):
		await wait_seconds(tuning.swing_time)
		if not is_routine_current(id):
			return
		_play_spin()
	await wait_seconds(tuning.swing_time)
	if is_routine_current(id):
		_finish_directional_x(id)

## Tap atras + X: en suelo conserva el clip del launcher y retrocede. En aire hace vueltas y
## retrocede horizontalmente: el normal usa un Mover corto; RT usa uno mas largo y dispara.
func _run_back_x_retreat(with_meter := false) -> void:
	if _player.is_airborne():
		_run_air_back_x_retreat(with_meter)
		return
	_face_locked_target()
	_player.locomotion.lock_facing(tuning.swing_time)
	_player.locomotion.lock_movement(tuning.swing_time)
	_player.bump_velocity = Vector3.ZERO
	play_visual_clip(ANIM_LAUNCHER, 0.2, 0.8, tuning.swing_time)
	swing_up(_t().strike_angle)
	_run_directional_x_movement(_back_x_profile(false, with_meter), _routine_id)
	begin_damage_window(tuning.swing_time)
	ComboTracker.register_hit()
	_finish_directional_x_after(tuning.swing_time, _routine_id)

func _run_air_back_x_retreat(with_meter: bool) -> void:
	var id := _routine_id
	_face_locked_target()
	_player.locomotion.lock_facing(tuning.swing_time)
	_player.locomotion.lock_movement(tuning.swing_time)
	_player.bump_velocity = Vector3.ZERO
	var spins: int = _t().tap_back_x_meter_air_spins if with_meter \
			else _t().tap_back_x_air_spins
	spins = maxi(spins, 1)
	_run_directional_x_movement(_back_x_profile(true, with_meter), id)
	play_visual_clip(ANIM_REGULAR_C, 0.0, -1.0, tuning.swing_time * float(spins))
	_play_spin()
	begin_damage_window(tuning.swing_time * float(spins))
	ComboTracker.register_hit()
	for spin_index in range(1, spins):
		await wait_seconds(tuning.swing_time)
		if not is_routine_current(id):
			return
		_play_spin()
	await wait_seconds(tuning.swing_time)
	if is_routine_current(id):
		_finish_directional_x(id)

func _forward_x_profile(airborne: bool, with_meter: bool) -> AttackMovementProfile:
	if airborne:
		return _t().tap_forward_x_air_meter if with_meter else _t().tap_forward_x_air
	return _t().tap_forward_x_ground_meter if with_meter else _t().tap_forward_x_ground

func _back_x_profile(airborne: bool, with_meter: bool) -> AttackMovementProfile:
	if airborne:
		return _t().tap_back_x_air_meter if with_meter else _t().tap_back_x_air
	return _t().tap_back_x_ground_meter if with_meter else _t().tap_back_x_ground

## run_attack_movement mas el bookkeeping del gesto direccional: si el perfil desplaza al Player,
## el gesto sigue contando como activo (retiene el hold de carga) hasta que ese recorrido cierre.
func _run_directional_x_movement(profile: AttackMovementProfile, routine_id: int) -> void:
	run_attack_movement(profile, routine_id)
	if profile == null or profile.player_travel == null:
		return
	if _directional_x_routine_id == routine_id:
		_directional_x_mover_pending = true

## `meter_button` (RT) solo mejora el tap si esta presionado cuando llega X dentro de la ventana
## direccional. El gasto ocurre antes de iniciar la rutina: si no alcanza el meter, el gesto conserva
## su variante normal y gratis.
##
## Es el MISMO boton que carga el sprint (ver PlayerSprint): sostenerlo moviendose cobra las dos
## cosas, el drenaje del sprint y este costo. Es coherente —el boton significa "gasto meter"— pero
## nadie lo tuneo como costo unico todavia.
func _try_spend_tap_x_meter() -> bool:
	if not Input.is_action_pressed("meter_button"):
		return false
	var cost := _t().tap_x_meter_cost
	if not _player.meter.spend_bars(cost):
		return false
	_player.play_combat_flash(_t().tap_x_meter_flash_color,
			_t().tap_x_meter_flash_energy, _t().tap_x_meter_flash_duration)
	return true

## El recorrido del Player cerro (bien o cancelado): el gesto direccional deja de retenerlo. El
## hang diferido y el disparo del proyectil los cobra WeaponBase desde el perfil activo.
func _on_attack_movement_ended() -> void:
	_complete_directional_x_mover(_routine_id)

func _fire_attack_projectile(enemy_mover: MoverSettings) -> void:
	_fire_tap_x_meter_projectile(enemy_mover)

func _finish_directional_x_after(duration: float, routine_id: int) -> void:
	await wait_seconds(duration)
	_finish_directional_x(routine_id)

func _finish_directional_x(routine_id: int) -> void:
	if _directional_x_routine_id != routine_id or not is_routine_current(routine_id):
		return
	_directional_x_animation_done = true
	if not _directional_x_mover_pending:
		_directional_x_routine_id = -1

func _complete_directional_x_mover(routine_id: int) -> void:
	if _directional_x_routine_id != routine_id or not is_routine_current(routine_id):
		return
	_directional_x_mover_pending = false
	if _directional_x_animation_done:
		_directional_x_routine_id = -1

func _fire_tap_x_meter_projectile(enemy_mover: MoverSettings) -> void:
	var radius := _t().tap_x_meter_projectile_radius
	if radius <= 0.0 or _t().tap_x_meter_projectile_lifetime <= 0.0:
		return
	var projectile := Projectile.new()
	projectile.name = "SwordSprintProjectile"
	projectile.parryable = false
	projectile.enemy_mover = enemy_mover
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	projectile.add_child(shape)
	var mesh := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	mesh.mesh = sphere_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = _t().tap_x_meter_projectile_color
	material.emission_energy_multiplier = _t().tap_x_meter_projectile_energy
	mesh.material_override = material
	projectile.add_child(mesh)
	var parent := get_tree().current_scene
	if parent == null:
		parent = _player.get_parent()
	if parent == null:
		return
	parent.add_child(projectile)
	var direction := _player.forward()
	direction.y = 0.0
	var target: Node3D
	if _player.lock_on.has_visible_target():
		target = _player.lock_on.current_target
	if target != null and is_instance_valid(target):
		direction = target.global_position - _player.global_position
	if direction.length_squared() < 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var origin := _player.global_position + direction * _t().tap_x_meter_projectile_forward_offset \
			+ Vector3.UP * _t().tap_x_meter_projectile_height
	projectile.launch(origin, direction, target, _player, _t().tap_x_meter_projectile_speed,
			_t().tap_x_meter_projectile_turn_rate, _t().tap_x_meter_projectile_damage,
			_t().tap_x_meter_projectile_lifetime, tuning.stun)

## Parte visual y de control comun a ambas variantes del launcher.
func _begin_launcher() -> void:
	_face_locked_target()
	_player.locomotion.lock_facing(tuning.swing_time)
	_player.locomotion.lock_movement(tuning.swing_time)
	_player.bump_velocity = Vector3.ZERO
	# Tramo 0.2-0.8 de Sword_Launcher (clip propio, WIP en animaciones/).
	play_visual_clip(ANIM_LAUNCHER, 0.2, 0.8, tuning.swing_time)
	swing_up(_t().strike_angle)

## El launcher no hereda el facing del tap atras: con lock-on siempre barre hacia el objetivo.
## Se proyecta al suelo porque look_at no debe inclinar al Player aunque el enemigo este arriba.
func _face_locked_target() -> void:
	if not _player.lock_on.has_visible_target():
		return
	var target := _player.lock_on.current_target
	if target == null or not is_instance_valid(target):
		return
	var toward_target := target.global_position - _player.global_position
	toward_target.y = 0.0
	if toward_target.length_squared() > 0.0001:
		_player.locomotion.set_facing(toward_target)

## Y cargada en el aire: gasta 1 barra (como la X cargada). El Player sube con su perfil y los
## enemigos golpeados reciben un spike lineal al suelo. El rebote sigue fuera de esta ruta.
func _aerial_charged_y() -> void:
	if not _player.meter.spend_charged():
		# ponytail: sin barra no hay move de compromiso — cae al tap aéreo normal.
		_tap_combo()
		return
	_run_aerial_charged_y()

func _run_aerial_charged_y() -> void:
	var t := _t()
	_aerial_charged_y_active = true
	_player.request_mover(t.aerial_charged_y_player_mover)
	play_visual_clip(ANIM_HEAVY, HEAVY_AIR_Y_START, HEAVY_AIR_Y_END, tuning.swing_time)
	swing_up(t.strike_angle)
	begin_damage_window(tuning.swing_time)
	ComboTracker.register_hit()
	await wait_seconds(tuning.swing_time)
	_aerial_charged_y_active = false

func _on_aerial_charged_y_hit(hurtbox: Hurtbox, _died: bool) -> void:
	if not _aerial_charged_y_active:
		return
	var target: Node = hurtbox.owner_node
	var spike := _t().aerial_charged_y_enemy_spike_mover
	if spike == null:
		return
	if target is EnemyBase:
		(target as EnemyBase).request_mover(spike)
	elif target.has_method("request_mover"):
		target.call("request_mover", spike)

## Golpe aéreo NORMAL (no cargado) conectado: suspende al enemigo en el aire con un hold puro
## (Floater, sin recorrido) mientras dura el juggle — simétrico al air-hit-float del jugador. Sin
## esto, pegarle en plena caída no lo frena: solo lo sostenía el Mover/hang del launcher, ya vencido
## (ver obsidian/Plan Autoridad Vertical). Cada golpe renueva el tiempo (el Floater usa max), así el
## enemigo queda "pegado" durante el combo y cae al dejar de golpearlo. request_float ya exige que el
## enemigo esté aéreo y quebrado, así que un golpe en tierra o a un objetivo entero no hace nada.
func _on_aerial_normal_hit(hurtbox: Hurtbox, _died: bool) -> void:
	# Un gesto direccional con hang propio lo aplica y corta acá; si no define uno, cae al hold
	# genérico de abajo igual que cualquier golpe aéreo normal.
	if request_profile_enemy_hang(hurtbox):
		return
	# El hold depende de que el ENEMIGO esté en el aire (lo valida request_float), no de dónde esté
	# el jugador: el juggle común es pegarle al enemigo cayendo desde el piso. Solo se excluye el
	# cargado Y, que ya le da su propio spike/Mover al enemigo. Un golpe a un enemigo en tierra no
	# hace nada: request_float exige aéreo + quebrado.
	if _aerial_charged_y_active:
		return
	var f := _t().air_hit_enemy_floater
	if f == null or f.duration <= 0.0:
		return
	var target: Node = hurtbox.owner_node
	if target is EnemyBase:
		(target as EnemyBase).request_float(f.duration, f.fall_scale)
	elif target.has_method("request_float"):
		target.call("request_float", f.duration, f.fall_scale)

# ---- Dash cargado: ventana de daño con hitbox propio de la espada ----

## Prende el hitbox del dash cargado mientras dura el dash (la espada mueve al player vía
## PlayerDash.force_dash, pero el daño lo pone ESTE hitbox, no el del dodge).
func _run_charged_dash_window() -> void:
	_charged_dash_id += 1
	var id := _charged_dash_id
	_charged_dash_hitbox.begin_swing()
	await wait_seconds(_t().charged_dash_duration)
	if id != _charged_dash_id:
		return  # otro dash cargado ya arrancó: él es dueño del hitbox
	_charged_dash_hitbox.end_swing()

## Solo alimenta el meter (sin _window_hits: no es parte de un combo aéreo). Un kill en la
## ventana del cargado devuelve la barra completa (gain_on_kill lo resuelve).
## El primer objetivo corta el dash, reposiciona al Player al otro lado de la trayectoria y apaga
## el hitbox inmediatamente para que no haya contactos extra tras el teletransporte.
func _on_charged_dash_hit(hurtbox: Hurtbox, died: bool) -> void:
	if _charged_dash_connected:
		return
	_charged_dash_connected = true
	_charged_dash_hitbox.end_swing()
	_player.dash.cancel()
	var target := hurtbox.owner_node as Node3D
	if target != null and is_instance_valid(target):
		_place_behind_target(target)
	register_weapon_hit(hurtbox, died, false)
	if _sweet_spot_dash:
		_run_ground_launcher()

## Solo el sweet spot aereo puede orientar el dash en los tres ejes hacia el lock-on.
## El cargado normal conserva la trayectoria recta, igual que la version terrestre.
func _charged_dash_direction(is_sweet_spot: bool) -> Vector3:
	if not is_sweet_spot or not _player.is_airborne() or not _player.lock_on.is_locked:
		return _player.forward()
	var target := _player.lock_on.current_target
	if target == null or not is_instance_valid(target):
		return _player.forward()
	var to_target := target.global_position - _player.global_position
	return to_target.normalized() if to_target.length_squared() > 0.0001 else _player.forward()

## El lado de salida sigue la trayectoria que llevaba el Player, no la orientacion del enemigo.
func _place_behind_target(target: Node3D) -> void:
	var exit_direction := _charged_dash_travel_direction
	if exit_direction.length_squared() < 0.0001:
		exit_direction = target.global_position - _player.global_position
	exit_direction = exit_direction.normalized()
	_player.global_position = target.global_position + exit_direction * _t().charged_dash_behind_offset
	var toward_target := target.global_position - _player.global_position
	toward_target.y = 0.0
	if toward_target.length_squared() > 0.0001:
		_player.look_at(_player.global_position + toward_target, Vector3.UP)

# ---- Coreografía (swing/swing_up/_play_swing/_play_spin viven en WeaponBase) ----

## Combo terrestre: swing, swing, estocada, estocada (o vueltas en la rama espera).
## Maniquí (bóveda Animacion Espada): A, B, A, B sin espera · A, B, C, C con espera.
func _play_combo_step(step: int, spin: bool) -> void:
	play_visual_clip(_ground_step_clip(step, spin), 0.0, -1.0, tuning.swing_time)
	var half := _t().combo_swing_angle
	match step:
		1:  # izquierda → derecha
			_play_swing(Quaternion(Vector3.UP, deg_to_rad(-half)), Quaternion(Vector3.UP, deg_to_rad(half)))
		2:  # derecha → izquierda
			_play_swing(Quaternion(Vector3.UP, deg_to_rad(half)), Quaternion(Vector3.UP, deg_to_rad(-half)))
		3, 4:
			if spin:
				_play_spin()  # vuelta completa
			else:
				_play_thrust()  # estocada

func _ground_step_clip(step: int, spin: bool) -> StringName:
	match step:
		1:
			return ANIM_REGULAR_A
		2:
			return ANIM_REGULAR_B
		_:
			if spin:
				return ANIM_REGULAR_C
			return ANIM_REGULAR_A if step == 3 else ANIM_REGULAR_B

## Combo AÉREO (bóveda Armas): golpe 1 siempre diagonal; según las esperas:
##   X X X            → diagonal, diagonal, hachazo vertical (spikea al suelo)
##   X (espera) X X   → diagonal, vuelta, vuelta (empuja hacia adelante)
##   X X (espera) X   → diagonal, diagonal, PLUNGE: vos y el enemigo golpeado bajan
##                      juntos al piso; un rebote en enemigo
##                      lo cancela. Misma coreografía/clip que el hachazo.
func air_steps() -> int:
	return 3

## Maniquí: espejo del terrestre — A, B y tramo aéreo de Heavy para el hachazo;
## las vueltas de la rama espera usan C (el mismo clip que las vueltas terrestres).
func play_air_step(step: int, finisher: bool, wait_branch: bool) -> void:
	if step == 1:
		_air_plunge_finisher = false
		play_visual_clip(ANIM_REGULAR_A, 0.0, -1.0, tuning.swing_time)
		_play_air_diagonal(-1.0)  # arriba-izq → abajo-der
		return
	if wait_branch:
		play_visual_clip(ANIM_REGULAR_C, 0.0, -1.0, tuning.swing_time)
		if step == 2:  # primera vuelta: eleva un poco al jugador (juice)
			_player.request_mover(_t().air_wait_spin_player_mover)
		_play_spin()  # vuelta completa (golpe 2 y finisher)
		return
	if finisher:  # hachazo vertical — con espera previa (X X espera X) es plunge
		# El plunge del jugador NO arranca acá: caer durante el swing te saca de rango y el
		# hitbox no llega al enemigo. Arranca en _finish_air_combo, al cerrar el golpe.
		_air_plunge_finisher = chain_wait_before_step >= tuning.air_wait_branch_threshold
		_run_finisher_v_stretch()
		play_visual_clip(ANIM_HEAVY, HEAVY_AIR_Y_START, HEAVY_AIR_Y_END, tuning.swing_time)
		var half := _t().air_finisher_angle
		_play_swing(Quaternion(Vector3.RIGHT, deg_to_rad(-half)), Quaternion(Vector3.RIGHT, deg_to_rad(half)))
	else:
		play_visual_clip(ANIM_REGULAR_B, 0.0, -1.0, tuning.swing_time)
		_play_air_diagonal(1.0)  # arriba-der → abajo-izq

## Rama plunge: los golpeados se ALINEAN a la altura del jugador (si el golpe entró
## arriba tuyo, el enemigo baja a tu Y) y caen a la misma velocidad hasta el piso. Ambos usan
## perfiles Mover; el del Player es parcial para conservar sus contactos.
func _finish_air_combo(wait_branch: bool) -> void:
	if _air_plunge_finisher and not wait_branch:
		_start_air_plunge_from_hits()
		return
	if wait_branch:
		return
	var spike := _t().air_finisher_enemy_spike_mover
	if spike == null:
		return
	for hurtbox in _window_hits.duplicate():
		var target: Node = hurtbox.owner_node
		if target is EnemyBase:
			(target as EnemyBase).request_mover(spike)
		elif target.has_method("request_mover"):
			target.call("request_mover", spike)

## Recién después del swing inicia el plunge: el Player conserva el rango del hachazo y luego
## cae incluso en whiff. Los enemigos conectados usan el mismo perfil descendente si pueden tomarlo.
## Los perfiles son opcionales para que el finisher de la rama espera (X X espera X) y el tap
## atras + Y aéreo puedan tunearse por separado; null cae a los de la rama espera.
func _start_air_plunge_from_hits(player_mover: MoverSettings = null, enemy_mover: MoverSettings = null) -> void:
	if player_mover == null:
		player_mover = _t().air_plunge_player_mover
	if enemy_mover == null:
		enemy_mover = _t().air_plunge_enemy_mover
	_player.request_mover(player_mover)
	for hurtbox in _window_hits.duplicate():
		var target: Node = hurtbox.owner_node
		if enemy_mover == null or not target.has_method("request_mover"):
			continue
		# Un enemigo parado no se alinea: el perfil solo puede entrar sobre uno aéreo y stuneado.
		if not _plunge_can_take(target):
			continue
		if target is Node3D:
			(target as Node3D).global_position.y = _player.global_position.y
		if target is EnemyBase:
			(target as EnemyBase).request_mover(enemy_mover)
		else:
			target.call("request_mover", enemy_mover)

## Estira los hitboxes del finisher aéreo mientras dura el golpe y los restaura al cerrar.
## La restauración es incondicional e idempotente: aunque un cargado cancele el combo a
## mitad, el timer devuelve los shapes base igual (no contamina el golpe siguiente).
func _run_finisher_v_stretch() -> void:
	var s := _t().air_finisher_hitbox_v_scale
	if s <= 1.0:
		return
	if _blade_shape != null:
		_blade_shape.size.y = _blade_base_size.y * s
	if _disc_capsule != null:
		_disc_capsule.radius = _disc_sphere.radius
		_disc_capsule.height = _disc_sphere.radius * 2.0 * s
		_disc_shape_node.shape = _disc_capsule
	await wait_seconds(tuning.air_step_time)
	_restore_finisher_hitboxes()

func _restore_finisher_hitboxes() -> void:
	if _blade_shape != null:
		_blade_shape.size = _blade_base_size
	if _disc_shape_node != null and _disc_sphere != null:
		_disc_shape_node.shape = _disc_sphere

## Mismas condiciones del perfil descendente del Enemy, por duck typing (el dummy no tiene todas).
func _plunge_can_take(target: Node) -> bool:
	if target.has_method("is_airborne") and not target.call("is_airborne"):
		return false
	if target.has_method("is_stunned") and not target.call("is_stunned"):
		return false
	return true

## Diagonal descendente: la mano cruza al frente (giro en Y) mientras baja (inclinación en X).
func _play_air_diagonal(side: float) -> void:
	var yaw := _t().air_diagonal_yaw
	var pitch := _t().air_diagonal_pitch
	_play_swing(
		Quaternion(Vector3.UP, deg_to_rad(-yaw * side)) * Quaternion(Vector3.RIGHT, deg_to_rad(-pitch)),
		Quaternion(Vector3.UP, deg_to_rad(yaw * side)) * Quaternion(Vector3.RIGHT, deg_to_rad(pitch))
	)

## Estocada: la mano se lanza al frente extendiendo el brazo y vuelve. El avance real del
## cuerpo lo da attack_step del jugador.
func _play_thrust() -> void:
	thrust(_t().thrust_reach)

func _t() -> SwordTuning:
	return tuning as SwordTuning

func _default_tuning() -> WeaponTuning:
	return SwordTuning.new()
