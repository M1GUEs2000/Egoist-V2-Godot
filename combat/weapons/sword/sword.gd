class_name Sword extends WeaponBase
## Espada (bóveda: Armas/Espada): tap = combo de 4 + rama espera + sweet spot;
## Y cargado = launcher / Y cargada aérea. X cargado = dash ofensivo (gasta 1 barra).
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
# Tramos de Sword_Heavy_Combo para los cargados Y (segundos dentro del clip).
const HEAVY_GROUND_Y_START := 0.90
const HEAVY_GROUND_Y_END := 1.30
const HEAVY_AIR_Y_START := 2.40
const HEAVY_AIR_Y_END := 2.70

var _charged_dash_id := 0
## Duración del dash cargado en curso, derivada del recorrido (distancia/velocidad de charged_dash_mover):
## la usan la animación y la ventana de daño para durar exactamente lo que dura el Mover.
var _charged_dash_time := 0.0
## El dash cargado en curso salio en sweet spot: junta lo que atraviesa para explotarlo.
var _sweet_spot_dash := false
var _sweet_spot_hits: Array[Hurtbox] = []
var _aerial_charged_y_active := false
var _aerial_charged_meet_y := 0.0
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

@onready var _launcher_hitbox: Hitbox = $LauncherHitbox
@onready var _charged_dash_hitbox: Hitbox = $ChargedDashHitbox
@onready var _charged_dash_shape: CollisionShape3D = $ChargedDashHitbox/CollisionShape3D

func setup(player: Player) -> void:
	super.setup(player)
	setup_launcher_hitbox(_launcher_hitbox, _t().launcher_deals_damage, tuning.stun)
	# El launcher Y terrestre (cargado Y) SI se parria: clavarlo en un enemigo atacando cuenta como
	# parry (usa parry_poise_charged_y). setup_launcher_hitbox lo deja en false; lo reactivamos aca.
	_launcher_hitbox.can_be_parried = true

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
	return _aerial_charged_y_active

func tap(_slot: World.Slot) -> void:
	_tap_combo()

func hold(slot: World.Slot, _level: int) -> void:
	if slot == World.Slot.X:
		_hold_x()
	else:
		_hold_y()

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

	# Soltar dentro de la ventana de sweet spot: el dash cuesta menos barra y todo lo que
	# atraviesa explota despues, lanzado hacia arriba (bóveda Espada, "X cargado sweet spot").
	_sweet_spot_dash = sweet_spot
	_sweet_spot_hits.clear()
	if _player.meter.spend_charged(1, true, tuning.meter_cost_scale(_sweet_spot_dash)):
		# X cargado = Mover EXCLUSIVO hacia adelante (perfil en SwordTuning.charged_dash_mover, ex
		# force_dash): atraviesa enemigos, frena en pared, con boost/partículas/inercia — todo tuneado en
		# el recurso. direction se fija acá al forward del jugador; la duración del golpe sale del propio
		# recorrido (distancia/velocidad). El daño lo pone ChargedDashHitbox (_run_charged_dash_window).
		var dash: MoverSettings = _t().charged_dash_mover.duplicate()
		dash.direction = _player.forward()
		_charged_dash_time = dash.distance / maxf(0.01, dash.speed)
		play_visual_clip(ANIM_DASH, 0.0, -1.0, _charged_dash_time)
		_player.dash_mover(dash)
		_run_charged_dash_window()
	else:
		# ponytail: sin barra no hay dash — cae a un swing cargado normal.
		# "sweet spot degradado sin meter" es diseño futuro, ver bóveda Combate.
		swing(_t().charged_fallback_angle)
		_player.hold_airborne_for_attack()
		begin_damage_window(tuning.swing_time)
	ComboTracker.register_hit()

# ---- Personalidad Y: launcher / cargada aérea ----

func _hold_y() -> void:
	# Entrada de ataque: invalida la rutina en curso y desarma su push. Sin esto, el push que
	# arma el finisher de la rama espera sobrevive y el launcher empuja en vez de lanzar.
	cancel_routines()
	# En el aire: Y cargada aérea (auto-launch + spike/rebote), no el launcher terrestre.
	# DESACTIVADO — Plan Autoridad Vertical F5 (2026-07-20): la Y cargada aérea usa slam_bounce
	# (rebote balístico del enemigo hasta meet_y), un move del "bouncer" todavía sin implementar.
	# Hasta que exista el bouncer, el input cae al combo aéreo normal en vez de correr un move a
	# medio migrar. _aerial_charged_y/_run_aerial_charged_y/_on_aerial_charged_y_hit quedan intactos
	# para re-enchufarlos. Cae por _tap_combo, que no gasta meter (a diferencia de _aerial_charged_y).
	if _player.is_airborne():
		_tap_combo()
		return
	# Launcher terrestre (ex AttackLauncher: solo desde el suelo — ya garantizado acá). El enemigo sube
	# con launcher_enemy_mover y cuelga con launcher_enemy_floater; el player se lanza a la misma altura
	# (la del Mover) leyendo su propio hang de PlayerTuning. La altura/hang escalares del player salen del
	# recurso del enemigo para no duplicar el número.
	var l_mover: MoverSettings = _t().launcher_enemy_mover
	var l_floater: FloaterSettings = _t().launcher_enemy_floater
	play_visual_clip(ANIM_HEAVY, HEAVY_GROUND_Y_START, HEAVY_GROUND_Y_END, tuning.swing_time)
	swing_up(_t().strike_angle)
	run_launcher_window(_launcher_hitbox, l_mover.distance, l_floater.duration,
			_t().launcher_hitbox_duration, 0.05, true, l_mover, l_floater)

## Y cargada en el aire: gasta 1 barra (como la X cargada). El jugador se auto-launcha
## (mismos valores que el launcher Y) y los golpeados spikean al suelo y rebotan hasta
## la altura del jugador leída al aterrizar. Sin barra → golpe Y normal.
func _aerial_charged_y() -> void:
	if not _player.meter.spend_charged():
		# ponytail: sin barra no hay move de compromiso — cae al tap aéreo normal.
		_tap_combo()
		return
	_run_aerial_charged_y()

func _run_aerial_charged_y() -> void:
	var t := _t()
	_aerial_charged_y_active = true
	_aerial_charged_meet_y = _player.global_position.y + t.aerial_charged_meet_height
	_player.launch(t.aerial_charged_player_height, t.launcher_enemy_floater.duration, t.aerial_charged_player_rise_time)
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
	if target.has_method("slam_bounce"):
		var meet_y := _aerial_charged_meet_y
		target.call("slam_bounce", _t().aerial_charged_down_speed,
				func() -> float: return meet_y,
				_t().launcher_enemy_floater.duration)

# ---- Dash cargado: ventana de daño con hitbox propio de la espada ----

## Prende el hitbox del dash cargado mientras dura el dash (la espada mueve al player vía el Mover de
## charged_dash_mover, pero el daño lo pone ESTE hitbox, no el del dodge).
func _run_charged_dash_window() -> void:
	_charged_dash_id += 1
	var id := _charged_dash_id
	_charged_dash_hitbox.begin_swing()
	await wait_seconds(_charged_dash_time)
	if id != _charged_dash_id:
		return  # otro dash cargado ya arrancó: él es dueño del hitbox
	_charged_dash_hitbox.end_swing()
	if not _sweet_spot_dash:
		return
	await wait_seconds(_t().sweet_spot_explosion_delay)
	if id != _charged_dash_id:
		return
	_explode_sweet_spot_hits()

## Stun de la explosión: el del dash cargado (mismo poise), pero con la duración AÉREA
## derivada del vuelo en vez de leída del .tres. El launch suspende al enemigo hasta
## subida + hang (EnemyBase._launch_routine); si el stun dura menos, se despierta flotando a
## mitad de camino — que es justo lo que pasaba reusando charged_dash_stun tal cual (airborne
## 0.9 contra un vuelo de 0.15 + 1.0). Atarlo al vuelo lo mantiene coherente aunque después
## se retoque la altura o el hang; el margen extra es lo único a tunear.
func _sweet_spot_explosion_stun() -> StunSettings:
	var t := _t()
	if t.charged_dash_stun == null:
		return null
	var stun: StunSettings = t.charged_dash_stun.duplicate()
	stun.airborne = World.LAUNCH_RISE_TIME + t.launcher_enemy_floater.duration + t.sweet_spot_explosion_stun_extra
	return stun

## Sweet spot del X cargado: cada enemigo que atravesó el dash estalla en su lugar y sale
## disparado hacia arriba como un launcher. El orden importa: primero el launch (así el daño
## de la explosión ya lo ve en el aire, mismo criterio que about_to_hit del launcher Y),
## después el daño, y las motas al final para que salgan aunque el estallido lo mate.
func _explode_sweet_spot_hits() -> void:
	var t := _t()
	var stun := _sweet_spot_explosion_stun()
	var exploded := false
	for hurtbox in _sweet_spot_hits:
		if not is_instance_valid(hurtbox) or not hurtbox.can_receive_hit():
			continue
		var target: Node = hurtbox.owner_node
		if t.sweet_spot_explosion_height > 0.0 and target.has_method("launch"):
			target.call("launch", t.sweet_spot_explosion_height, t.launcher_enemy_floater.duration, stun)
		var died := hurtbox.receive_hit(_player, t.sweet_spot_explosion_damage,
				_player.forward(), stun)
		World.spawn_color_burst(_player.get_parent(), hurtbox.global_position,
				tuning.sweet_spot_particle_color, tuning.sweet_spot_particle_emission,
				t.sweet_spot_burst_amount, t.sweet_spot_burst_speed,
				t.sweet_spot_burst_particle_gravity, t.sweet_spot_burst_lifetime,
				t.sweet_spot_burst_size)
		register_weapon_hit(hurtbox, died, false)
		exploded = true
	_sweet_spot_hits.clear()
	# Hang extra para mirar el estallido. Va DESPUÉS del loop: un solo Floater aunque explote
	# media pantalla, y solo si algo explotó de verdad (whiff = caés normal). El perfil (duración +
	# fall_scale) vive en SwordTuning.sweet_spot_player_floater.
	var f: FloaterSettings = t.sweet_spot_player_floater
	if exploded and f != null and f.duration > 0.0:
		_player.request_float(f.duration, f.fall_scale)

## Solo alimenta el meter (sin _window_hits: no es parte de un combo aéreo). Un kill en la
## ventana del cargado devuelve la barra completa (gain_on_kill lo resuelve).
## El dash cargado no frena el momentum del jugador: el desplazamiento ES el move.
func _on_charged_dash_hit(hurtbox: Hurtbox, died: bool) -> void:
	register_weapon_hit(hurtbox, died, false)
	# Si el dash salió en sweet spot, lo atravesado queda anotado para estallar después.
	# Lo que murió con el dash mismo no explota: el hurtbox ya no recibe golpes.
	if _sweet_spot_dash and not died and hurtbox not in _sweet_spot_hits:
		_sweet_spot_hits.append(hurtbox)

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
##                      juntos al piso (plunge_player_mover / plunge_enemy_mover); un rebote
##                      en enemigo lo cancela. Misma coreografía/clip que el hachazo.
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
			_player.air_hop(tuning.air_wait_spin_hop)
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
## arriba tuyo, el enemigo baja a tu Y) y caen a la MISMA velocidad que vos (slam con
## plunge_enemy_mover) en vez del spike normal — bajan a la par hasta el piso, lo
## que deja el rebote en enemigo servido para cancelar el plunge.
func _finish_air_combo(wait_branch: bool) -> void:
	if _air_plunge_finisher and not wait_branch:
		# Recién acá cae el jugador: el swing ya cerró con su ventana de daño completa.
		# En whiff también caés (move de compromiso, como el dash cargado). El plunge del jugador y el
		# slam del enemigo salen de sus perfiles del tuning (bajan a la par: mismo speed).
		var enemy_mover: MoverSettings = _t().plunge_enemy_mover
		_player.plunge(_t().plunge_player_mover)
		for hurtbox in _window_hits.duplicate():
			var target: Node = hurtbox.owner_node
			if not target.has_method("slam"):
				continue
			# Alinear solo si el slam va a entrar (aéreo y stuneado): sin este guard, un
			# enemigo parado en el piso se teletransportaría a tu altura sin caer.
			if _plunge_can_take(target) and target is Node3D:
				(target as Node3D).global_position.y = _player.global_position.y
			target.call("slam", enemy_mover.speed, enemy_mover)
		return
	super._finish_air_combo(wait_branch)

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

## Mismas condiciones que EnemyBase.slam, por duck typing (el dummy no tiene todas).
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
