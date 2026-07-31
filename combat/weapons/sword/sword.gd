class_name Sword extends WeaponBase
## Espada (bóveda: Armas/Espada): tap = combo de 4 + rama espera + sweet spot;
## Y cargado = golpe vertical / Y cargada aérea. X cargado = dash ofensivo (gasta 1 barra).
## Swings 100% procedurales (tweens de quaternion sobre la Hand), SIN AnimationPlayer.
## Los combos son DATOS: SwordTuning.ground_combo / air_combo los declaran paso por paso y el motor
## de WeaponBase (run_attack_sequence) los recorre. Acá quedan los especiales y los arcos de mano.
# ponytail: personalidades X/Y como funcs aquí; extraer strategy cuando exista la 2ª arma.

# Clips UAL2 del plan de la bóveda (Animacion Espada) — nombres verificados contra el .glb.
const ANIM_REGULAR_A := &"Sword_Regular_A"
const ANIM_REGULAR_B := &"Sword_Regular_B"
const ANIM_REGULAR_C := &"Sword_Regular_C"
const ANIM_DASH := &"Sword_Dash"
const ANIM_HEAVY := &"Sword_Heavy_Combo"
# Clip propio (WIP, animaciones/) para el golpe vertical terrestre (launcher).
const ANIM_LAUNCHER := &"Sword_Launcher"
# El recorte 2.40-2.70 de Sword_Heavy_Combo para el plunge dejo de ser constante: es el
# start_time/end_time del AttackClip de su paso (data/sword_tap_back_y_air.tres).

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

	# El spike del Enemy en la Y cargada aerea ya no se engancha acá: es `enemy_travel` en ON_HIT
	# dentro de su perfil, y lo cobra WeaponBase._on_hit para cualquier golpe del arma.
	for hitbox: Hitbox in [_blade_hitbox, _air_disc_hitbox]:
		if hitbox != null:
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
	reset_hit_profile()
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
	reset_hit_profile()
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
	reset_hit_profile()
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
	reset_hit_profile()
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
##
## La forma de las dos cadenas —cuántos golpes, con qué clip, cuánto pega cada uno, dónde ramifican
## y qué Mover sale en qué beat— vive en SwordTuning.ground_combo / air_combo. Acá quedan solo los
## arcos procedurales de la mano, que son lo único que todavía no es dato.
func _tap_combo() -> void:
	# Entrada de ataque: devuelve el hitbox a su daño base. Sin esto, el bono de daño de un tap
	# direccional RT previo (ver _apply_tap_x_meter_damage) seguiría vivo en el combo siguiente.
	reset_hit_profile()
	var airborne := _player.is_airborne()
	var kind: StringName = &"air" if airborne else &"ground"
	if try_queue_combo(kind):
		return
	run_attack_sequence(kind, _t().air_combo if airborne else _t().ground_combo)

## Lo único que un paso NO puede declarar como dato: mecánicas propias de la Espada. El dibujo del
## golpe salió entero de acá — lo pone el AttackClip del paso.
##
## `step.choreography` quedó como etiqueta de FAMILIA de golpe, no como nombre de un tween: dice si
## el paso es terrestre (sostiene al Player en el aire mientras dura el combo, para que un combo
## empezado en el borde no te tire) o si es el finisher aéreo (estira los hitboxes en V).
func on_sequence_step(step: AttackStep, _chain_step: int, _finisher: bool,
		_duration: float) -> void:
	match step.choreography:
		&"ground_swing_l", &"ground_swing_r", &"ground_thrust", &"ground_spin":
			_player.hold_airborne_for_attack()
		&"air_finisher":
			_run_finisher_v_stretch()

## El dash cargado es un paso de AttackSequence, pero no usa hoja/disco: su dano viene del
## ChargedDashHitbox. El clip sigue declarando exactamente cuando abre y cierra esa hitbox.
func begin_sequence_step_damage_window(step: AttackStep, duration: float,
		runs_profile_hooks: bool, clip: AttackClip) -> void:
	if step.choreography != &"charged_dash":
		super.begin_sequence_step_damage_window(step, duration, runs_profile_hooks, clip)
		return
	_begin_charged_dash_window(duration, clip)

## El X cargado viaja con Mover. Normalmente usa el forward del Player; el sweet spot aereo con
## lock-on clona el perfil y reemplaza solo la direccion por el vector 3D hacia ese target.
func sequence_step_movement_profile(step: AttackStep) -> AttackMovementProfile:
	if step.choreography != &"charged_dash" or step.movement == null:
		return super.sequence_step_movement_profile(step)
	if not _sweet_spot_dash or not _player.is_airborne() or not _player.lock_on.is_locked:
		return step.movement
	var target := _player.lock_on.current_target
	if target == null or not is_instance_valid(target):
		return step.movement
	var direction := target.global_position - _player.global_position
	if direction.length_squared() < 0.0001:
		return step.movement
	# Apuntar a un objetivo concreto no es ninguna de las cuatro direcciones nombradas —puede estar
	# arriba o abajo—, así que se escribe el vector ya resuelto y `_resolve_mover` lo respeta.
	var resolved := step.movement.duplicate(true) as AttackMovementProfile
	var travel := resolved.player_travel.duplicate() as MoverSettings
	travel.aimed_direction = direction.normalized()
	resolved.player_travel = travel
	return resolved

# ---- Personalidad X: cargado (dash sweet spot) ----

## X cargado: dash ofensivo (sweet spot). Gasta 1 barra; el daño lo pone el hitbox PROPIO
## de la espada (no el del dash de movimiento) → un kill en la ventana del cargado devuelve
## la barra completa.
func _hold_x() -> void:
	# Move de compromiso: interrumpe el combo en curso y dashea.
	cancel_routines()
	reset_hit_profile()

	# Soltar dentro de la ventana de sweet spot abarata el dash y encadena un launcher al conectar.
	_sweet_spot_dash = sweet_spot
	_charged_dash_connected = false
	if _player.meter.spend_charged(1, true, tuning.meter_cost_scale(_sweet_spot_dash)):
		_charged_dash_travel_direction = _charged_dash_direction(_sweet_spot_dash).normalized()
		run_attack_sequence(&"charged_x_dash", _t().charged_x_dash_sequence)
	else:
		# ponytail: sin barra no hay dash — cae a un swing cargado normal.
		# "sweet spot degradado sin meter" es diseño futuro, ver bóveda Combate.
		# El clip lo pone acá y no antes del if: la rama con barra usa el del dash.
		play_visual_clip(ANIM_REGULAR_C, 0.0, -1.0, tuning.swing_time)
		_player.hold_airborne_for_attack()
		begin_damage_window(tuning.swing_time)
		ComboTracker.register_hit()

# ---- Personalidad Y: golpe vertical / cargada aérea ----

func _hold_y() -> void:
	# Entrada de ataque: invalida la rutina en curso y desarma su push. Sin esto, el push que
	# arma el finisher de la rama espera sobrevive y el golpe vertical empuja en vez de mover.
	cancel_routines()
	reset_hit_profile()
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

## Launcher cargado: eleva al Player y al Enemy. Los dos Movers salen de su perfil; la ventana los
## reparte en su momento (el del Enemy antes del dano, el del Player con el hitbox).
func _run_ground_launcher() -> void:
	_begin_launcher()
	run_vertical_window_from_profile(_vertical_hitbox, _t().ground_charged_y, _routine_id,
			_t().ground_charged_y_hitbox_duration)

## Tap atras + Y: comparte el golpe con el launcher cargado, pero su perfil deja vacio el slot del
## Player, asi que solo sube el Enemy. Es perfil aparte para poder tunearlo sin arrastrar al cargado.
func _run_enemy_only_launcher() -> void:
	_begin_launcher()
	run_vertical_window_from_profile(_vertical_hitbox, _t().tap_back_y_ground, _routine_id,
			_t().ground_charged_y_hitbox_duration)

## En aire, tap atras + Y es un plunge: el hachazo conserva alcance y, al cerrarse, ambos cuerpos
## bajan. Los dos recorridos son WINDOW_END en el perfil del paso, asi que los arranca el cierre de
## la ventana de dano y no esta rutina. En whiff el Player cae igual (move de compromiso): su
## recorrido no depende de haber conectado.
##
## El recorte del hachazo y el estiramiento en V de los hitboxes tambien son dato: el clip del paso y
## su `choreography`. Aca queda encarar al objetivo y los locks.
func _run_air_back_y_plunge() -> void:
	_face_locked_target()
	_player.locomotion.lock_facing(tuning.swing_time)
	_player.locomotion.lock_movement(tuning.swing_time)
	_player.bump_velocity = Vector3.ZERO
	run_attack_sequence(&"tap_back_y", _t().tap_back_y_air_sequence)

## Tap adelante + Y: la misma vuelta final de la rama espera. En suelo solo avanza el Player; en aire
## ademas empuja al Enemy. Las dos cosas viven en el `movement` del paso de cada tramo, que es por lo
## que el gesto esta partido en dos secuencias: con una sola, el empujon del aire salia tambien en
## piso. El Mover se orienta en FORWARD contra el facing que estos locks acaban de fijar.
func _run_forward_y_push() -> void:
	_face_locked_target()
	_player.locomotion.lock_facing(tuning.swing_time)
	_player.locomotion.lock_movement(tuning.swing_time)
	_player.bump_velocity = Vector3.ZERO
	var sequence: AttackSequence = _t().tap_forward_y_air_sequence if _player.is_airborne() \
			else _t().tap_forward_y_ground_sequence
	run_attack_sequence(&"tap_forward_y", sequence)

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
	if with_meter:
		_apply_tap_x_meter_damage(_forward_x_meter_damage_bonus(airborne))
	# El gesto entero es datos: clip, vueltas (`repeat`) y el perfil de movimiento viven en la
	# secuencia del tramo. Acá queda lo que no es dato — encarar al objetivo, los locks y el meter.
	#
	# Cada vuelta abre su propia ventana de daño y cuenta su register_hit. Antes era UN clip estirado
	# a `swing_time * spins` con UNA ventana: se veían las vueltas pero el enemigo cobraba una vez.
	var sequence: AttackSequence = _t().tap_forward_x_air_sequence if airborne \
			else _t().tap_forward_x_ground_sequence
	if with_meter:
		_play_tap_x_meter_flash(sequence)
	await run_attack_sequence(&"tap_forward_x", sequence, with_meter)
	if is_routine_current(id):
		_finish_directional_x(id)

## Tap atras + X: en suelo conserva el clip del launcher y retrocede siempre, mas lejos y mas rapido
## con RT. En aire son vueltas en el sitio y el retroceso es `rt_only`: solo aparece pagando barra,
## y ahi ademas cuelga al cerrarlo y dispara.
##
## Todo eso es dato desde el 2026-07-30 (clip, retroceso, vueltas, proyectil): vive en la secuencia
## del tramo. Aca queda lo que no es dato — encarar al objetivo, los locks y el meter.
func _run_back_x_retreat(with_meter := false) -> void:
	var id := _routine_id
	var airborne := _player.is_airborne()
	_face_locked_target()
	_player.locomotion.lock_facing(tuning.swing_time)
	_player.locomotion.lock_movement(tuning.swing_time)
	_player.bump_velocity = Vector3.ZERO
	if with_meter:
		_apply_tap_x_meter_damage(_back_x_meter_damage_bonus(airborne))
	var sequence: AttackSequence = _t().tap_back_x_air_sequence if airborne \
			else _t().tap_back_x_ground_sequence
	if with_meter:
		_play_tap_x_meter_flash(sequence)
	await run_attack_sequence(&"tap_back_x", sequence, with_meter)
	if is_routine_current(id):
		_finish_directional_x(id)

func _forward_x_meter_damage_bonus(airborne: bool) -> float:
	return _t().tap_forward_x_air_meter_damage_bonus if airborne \
			else _t().tap_forward_x_ground_meter_damage_bonus

func _back_x_meter_damage_bonus(airborne: bool) -> float:
	return _t().tap_back_x_air_meter_damage_bonus if airborne \
			else _t().tap_back_x_ground_meter_damage_bonus

## Bono de dano de la variante RT, sobre el 1.0 base que `reset_hit_profile()` deja en el hitbox.
## Escala hoja y disco aereo porque en aire cobran los dos. Quien lo limpia es la entrada del ataque
## SIGUIENTE, que llama `reset_hit_profile()`: por eso el bono no se puede filtrar aunque la rutina
## se cancele a mitad. Mismo recorte en 0 que los bonos del perfil (ver WeaponBase._rt_scale).
func _apply_tap_x_meter_damage(bonus_percent: float) -> void:
	var damage_scale := maxf(0.0, 1.0 + bonus_percent * 0.01)
	if is_equal_approx(damage_scale, 1.0):
		return
	_blade_hitbox.damage *= damage_scale
	if _air_disc_hitbox != null:
		_air_disc_hitbox.damage *= damage_scale

## Bookkeeping del gesto direccional: si el golpe desplaza al Player, el gesto sigue contando como
## activo (retiene el hold de carga) hasta que ese recorrido cierre. Ahora que el movimiento lo pide
## el runner de la secuencia y no el gesto, el aviso llega por este hook.
##
## Se confia en que WeaponBase solo lo llama cuando el recorrido ARRANCO, y no en
## `player_travel != null`: un perfil `rt_only` sin barra —el caso exacto de atras X aereo— o un
## facing degenerado dejan el recorrido sin salir, y esperarlo colgaria el gesto para siempre.
func on_attack_movement_started(routine_id: int) -> void:
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
	return true

## El brillo usa el mismo reloj que el runner: cambiar pasos, repeticiones o RT Animation Speed
## Bonus cambia automaticamente su duracion, sin otro slider que pueda quedar desincronizado.
func _play_tap_x_meter_flash(sequence: AttackSequence) -> void:
	_player.play_combat_flash(_t().tap_x_meter_flash_color, _t().tap_x_meter_flash_energy,
			automatic_sequence_duration(sequence, true))

## El recorrido del Player cerro (bien o cancelado): el gesto direccional deja de retenerlo. El
## hang diferido y el disparo del proyectil los cobra WeaponBase desde el perfil activo.
func _on_attack_movement_ended() -> void:
	_complete_directional_x_mover(_routine_id)

func _fire_attack_projectile(enemy_mover: MoverSettings) -> void:
	_fire_tap_x_meter_projectile(enemy_mover)

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

## Y cargada en el aire: gasta 1 barra (como la X cargada). Golpes seguidos con las animaciones del
## combo aéreo y un remate que saca al enemigo en diagonal hacia abajo — tres golpes normalmente,
## cinco si se soltó dentro del sweet spot. El precio en barra es el mismo en las dos.
func _aerial_charged_y() -> void:
	if not _player.meter.spend_charged():
		# ponytail: sin barra no hay move de compromiso — cae al tap aéreo normal.
		_tap_combo()
		return
	_run_aerial_charged_y(sweet_spot)

## Toda la coreografía es el .tres; acá solo queda ELEGIR cuál y sostener la bandera que le dice al
## resto del arma que este gesto está corriendo (la lee is_charged_move_active para no cortarle el
## momentum aéreo). El sweet spot cae a la secuencia normal si no declaró la suya, en vez de no
## sacar nada: un slot vacío apaga el premio, no el golpe.
##
## `_aerial_charged_y_active` se apaga aunque la secuencia la corten a mitad: run_attack_sequence
## retorna al invalidarse la rutina, y el await de acá resume igual.
func _run_aerial_charged_y(is_sweet_spot: bool) -> void:
	var t := _t()
	var sequence := t.aerial_charged_y_sequence
	if is_sweet_spot and t.aerial_charged_y_sweet_sequence != null:
		sequence = t.aerial_charged_y_sweet_sequence
	_aerial_charged_y_active = true
	await run_attack_sequence(&"charged_y_air", sequence)
	_aerial_charged_y_active = false

## Golpe aéreo NORMAL (no cargado) conectado: suspende al enemigo en el aire con un hold puro
## (Floater, sin recorrido) mientras dura el juggle — simétrico al air-hit-float del jugador. Sin
## esto, pegarle en plena caída no lo frena: solo lo sostenía el Mover/hang del launcher, ya vencido
## (ver obsidian/Plan Autoridad Vertical). Cada golpe renueva el tiempo (el Floater usa max), así el
## enemigo queda "pegado" durante el combo y cae al dejar de golpearlo. request_float ya exige que el
## enemigo esté aéreo y quebrado, así que un golpe en tierra o a un objetivo entero no hace nada.
func _on_aerial_normal_hit(hurtbox: Hurtbox, _died: bool) -> void:
	# El hold depende de que el ENEMIGO esté en el aire (lo valida request_float), no de dónde esté
	# el jugador: el juggle común es pegarle al enemigo cayendo desde el piso. Un golpe a un enemigo
	# en tierra no hace nada: request_float exige aéreo + quebrado.
	#
	# Se excluye el golpe que YA está sacando al enemigo, porque el Floater le pelearía al Mover. Se
	# pregunta por PASO y no por gesto: la Y cargada aérea son tres golpes, y los dos primeros TIENEN
	# que sostener al enemigo o el remate le pega al aire.
	if profile_moves_enemy_on_hit():
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
## Abre el ChargedDashHitbox en la fraccion del AttackClip declarada por el paso. Es el equivalente
## especializado de WeaponBase.begin_damage_window: no toca hoja/disco ni hooks de perfiles.
func _begin_charged_dash_window(duration: float, clip: AttackClip) -> void:
	_charged_dash_id += 1
	var id := _charged_dash_id
	var open_delay := 0.0 if clip == null else clip.open_delay(duration)
	var open_time := duration if clip == null else clip.open_seconds(duration)
	if open_delay > 0.001:
		await wait_seconds(open_delay)
		if id != _charged_dash_id:
			return
	_charged_dash_hitbox.begin_swing()
	await wait_seconds(open_time)
	if id != _charged_dash_id:
		return  # otro dash cargado ya arranco: el es dueño del hitbox
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
	_player.mover.cancel_mover(Mover.CancelReason.ATTACK_RULE)
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

# ---- Coreografía (la pone la animación: cada paso trae su AttackClip) ----

## Los dos combos (bóveda Armas) ahora son datos; esto queda como mapa de lo que declara el .tres:
##
##   Terrestre  X X X X            → swing, swing, estocada, estocada
##              X X (espera) X X   → los golpes 3-4 pasan a vueltas + empuje en el último
##   Aéreo      X X X              → diagonal, diagonal, hachazo (spikea al suelo)
##              X (espera) X X     → diagonal, vuelta, vuelta (empuja hacia adelante)
##              X X (espera) X     → diagonal, diagonal, PLUNGE: vos y el golpeado bajan juntos
##
## Los tres recorridos del aéreo —el hop de la primera vuelta, el spike del finisher y el plunge—
## viven en el AttackMovementProfile del paso que los emite. El spike y el plunge salen en
## WINDOW_END porque arrancarlos durante el swing saca al objetivo del alcance del propio golpe.

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

func _t() -> SwordTuning:
	return tuning as SwordTuning

func _default_tuning() -> WeaponTuning:
	return SwordTuning.new()
