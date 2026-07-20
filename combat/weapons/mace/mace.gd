class_name Mace extends WeaponBase
## Mazo (boveda: Armas/Mazo): tap = combo de 3 + rama espera (2 smashes extra);
## X cargado = 3 niveles con sweet spot congelante; Y cargado = continuidad de combo:
## paso corto + launcher en tierra, caida diagonal + AOE con dos ramas: launcher si
## impacta suelo, slam_arc + rebote del jugador si impacta un enemigo en aire.
## Coreografia sobre el motor generico de WeaponBase; aca vive solo la personalidad.

const STEP_COUNT := 3
const WAIT_BRANCH_EXTRA_STEPS := 2
const AIR_STEP_COUNT := 2

# El Mazo no tiene clips propios: todo sale de tramos de Sword_Heavy_Combo (bóveda
# Animacion Mazo). Vector2(inicio, fin) en segundos dentro del clip; fin < 0 = hasta el
# final (4.333 s).
const ANIM_HEAVY := &"Sword_Heavy_Combo"
const HEAVY_STEP_1 := Vector2(0.00, 0.70)
const HEAVY_STEP_2 := Vector2(1.50, 2.10)
# Rama espera: el plan lista 4 tramos para 5 pasos → los smashes intermedios (pasos 3-4)
# COMPARTEN el tramo corto y el finisher (paso 3 sin espera / paso 5 con espera) remata
# hasta el final del clip. Así WAIT_BRANCH_EXTRA_STEPS no cambia.
const HEAVY_SMASH_MID := Vector2(2.10, 3.10)
const HEAVY_SMASH_FINAL := Vector2(2.10, -1.0)
const HEAVY_CHARGED_X_SPIN := Vector2(1.30, 2.00)
const HEAVY_CHARGED_X_AIR := Vector2(2.40, 2.70)
const HEAVY_CHARGED_Y_GROUND := Vector2(0.90, 1.30)
const HEAVY_CHARGED_Y_AIR := Vector2(2.40, 3.00)

var _air_y_hit_enemy_in_air := false
# Move de compromiso en curso (vueltas del X cargado terrestre): mientras esta activo,
# tap/hold se ignoran para que pegar NO cancele las vueltas a mitad. Ver boveda Armas/Mazo.
var _uninterruptible := false
# Cargado en curso sobre el hitbox de la hoja (vueltas X terrestres / X aereo). Solo exime del corte
# de momentum del air-hit-stall; NO bloquea input (eso lo hace _uninterruptible, que es otra cosa).
var _charged_move_active := false

@onready var _launcher_hitbox: Hitbox = $LauncherHitbox
@onready var _air_slam_hitbox: Hitbox = $AirSlamHitbox
@onready var _launcher_shape: CollisionShape3D = $LauncherHitbox/CollisionShape3D
@onready var _air_slam_shape: CollisionShape3D = $AirSlamHitbox/CollisionShape3D

func setup(player: Player) -> void:
	super.setup(player)
	var t := _t()
	(_launcher_shape.shape as BoxShape3D).size = t.ground_y_launcher_size
	var air_slam_cylinder := _air_slam_shape.shape as CylinderShape3D
	air_slam_cylinder.radius = t.air_y_aoe_radius
	air_slam_cylinder.height = t.air_y_aoe_height
	setup_launcher_hitbox(_launcher_hitbox, t.ground_y_launcher_deals_damage, tuning.stun, true)
	# El launcher Y terrestre (cargado Y) SI se parria: usa parry_poise_charged_y. El AOE aereo del Y
	# (AirSlamHitbox) queda sin parriar a proposito: es multi-target, no un golpe unico de compromiso.
	_launcher_hitbox.can_be_parried = true
	# El AOE aereo usa dos respuestas: launcher si explota en suelo, slam_arc si la caida
	# conecto con un enemigo airborne.
	_air_slam_hitbox.source = player
	_air_slam_hitbox.damage = 1.0
	_air_slam_hitbox.stun = tuning.stun
	_air_slam_hitbox.can_be_parried = false
	# La rama de suelo (launch) se cablea como los demas launchers: lanza en about_to_hit, antes
	# del daño, para que receive_hit ya vea al enemigo airborne (ver _on_air_slam_about_to_hit).
	_air_slam_hitbox.about_to_hit.connect(_on_air_slam_about_to_hit)
	_air_slam_hitbox.landed.connect(_on_air_slam_hit)

func tap(_slot: World.Slot) -> void:
	if _uninterruptible:
		return
	_tap_combo()

func hold(slot: World.Slot, level: int) -> void:
	if _uninterruptible:
		return
	if slot == World.Slot.X:
		_hold_x(level)
	else:
		_hold_y()

## Solo X usa niveles. Y cargado ignora el nivel de carga por diseno.
## Los cargados que comparten el hitbox de la hoja con los taps: el corte de momentum aereo los
## saltea (dueñan su propio desplazamiento). El AOE del Y aereo tiene hitbox propio: ver _on_air_y_hit.
func is_charged_move_active() -> bool:
	return _charged_move_active

func charge_level(held_time: float) -> int:
	var t := _t()
	var hold_threshold := _player.tuning.input_hold_threshold if _player != null else 0.0
	var extra := held_time - hold_threshold
	var level := 1 + int(floor(maxf(0.0, extra) / t.charge_level_step))
	return clampi(level, 1, t.max_charge_level)

# ---- Tap: combo de 3 (+2 en rama espera) compartido por X/Y ----

func _tap_combo() -> void:
	if _player.is_airborne():
		_aerial_tap()
		return
	if try_queue_combo(&"ground"):
		return
	reset_hit_profile()
	run_combo_chain(&"ground", STEP_COUNT, tuning.swing_time, _t().combo_window,
			2, _t().ground_wait_branch_threshold, _begin_ground_step, Callable(),
			WAIT_BRANCH_EXTRA_STEPS)

func _begin_ground_step(step: int, finisher: bool, _wait_branch: bool) -> void:
	_play_ground_step_visual(step, finisher)
	match step:
		1:
			var half := _t().combo_swing_angle
			_play_swing(Quaternion(Vector3.UP, deg_to_rad(-half)), Quaternion(Vector3.UP, deg_to_rad(half)))
		2:
			var half := _t().combo_swing_angle
			_play_swing(Quaternion(Vector3.UP, deg_to_rad(half)), Quaternion(Vector3.UP, deg_to_rad(-half)))
		_:
			_play_smash()
	_player.attack_step(tuning.swing_time)
	_player.hold_airborne_for_attack()

## Maniquí (bóveda Animacion Mazo): tramos de Sword_Heavy_Combo por paso.
func _play_ground_step_visual(step: int, finisher: bool) -> void:
	var segment := Vector2.ZERO
	match step:
		1:
			segment = HEAVY_STEP_1
		2:
			segment = HEAVY_STEP_2
		_:
			segment = HEAVY_SMASH_FINAL if finisher else HEAVY_SMASH_MID
	play_visual_clip(ANIM_HEAVY, segment.x, segment.y, tuning.swing_time)

func _play_smash() -> void:
	# Martillazo DESCENDENTE: arranca arriba-atras (-smash_angle) y remata clavando en el punto
	# bajo-al-frente (0). Antes era un pendulo simetrico (-x..+x): el punto mas bajo caia a MITAD
	# del swing y el mazo volvia a subir proyectandose arriba-adelante, por eso no parecia un
	# smash (verificado en world/mace_smash_trace: puntaY -0.14 -> -1.32 -> -0.57, puntaZ -2.28).
	var up := _t().smash_angle
	_play_swing(Quaternion(Vector3.RIGHT, deg_to_rad(-up)), Quaternion.IDENTITY)

# ---- Personalidad X: cargado (vueltas, 3 niveles) ----

func _hold_x(level: int) -> void:
	cancel_routines()
	if _player.is_airborne():
		if _player.meter.spend_charged(1, false):
			_aerial_charged_x(level >= _t().max_charge_level)
		else:
			_tap_combo()
		return
	var actual_level := mini(level, _player.meter.affordable_bars())
	if actual_level <= 0:
		_tap_combo()
	elif _player.meter.spend_charged(actual_level, false):
		_run_charged_spins(actual_level)
	else:
		_tap_combo()

func _run_charged_spins(level: int) -> void:
	var t := _t()
	var id := begin_routine()
	reset_hit_profile()
	# Las vueltas son un move de compromiso: pegar durante ellas ya no arranca otro combo
	# (que las cancelaria via begin_routine). El dodge/dash siguen siendo escape: no pasan por aca.
	_uninterruptible = true
	_charged_move_active = true
	var sweet_spot := level >= t.max_charge_level
	_player.hold_airborne_for_attack()
	for spin in range(1, level + 1):
		# Una vuelta de clip por vuelta mecánica (el tramo se repite según el nivel de carga).
		play_visual_clip(ANIM_HEAVY, HEAVY_CHARGED_X_SPIN.x, HEAVY_CHARGED_X_SPIN.y,
				t.charged_spin_time)
		_play_spin(t.charged_spin_time)
		var finisher := spin == level
		_set_hitbox_stun(t.charged_freeze_stun if (sweet_spot and not finisher) else t.charged_final_stun)
		_blade_hitbox.damage = t.charged_hit_damage if finisher else (0.0 if sweet_spot else 1.0)
		if finisher:
			arm_push(t.charged_final_push, t.charged_spin_time * tuning.push_at)
		begin_damage_window(t.charged_spin_time)
		ComboTracker.register_hit()
		await wait_seconds(t.charged_spin_time)
		if not is_routine_current(id):
			# Algo externo (stun, etc.) tomo control: soltamos el candado y salimos.
			_uninterruptible = false
			_charged_move_active = false
			return
	reset_hit_profile()
	_uninterruptible = false
	_charged_move_active = false

# ---- Personalidad Y: continuidad de combo ----

func _hold_y() -> void:
	var id := begin_routine()
	reset_hit_profile()
	if _player.is_airborne():
		_aerial_hold_y(id)
		return
	var t := _t()
	# El paso corto lleva el launcher ARMADO: el hitbox barre hacia adelante con el jugador y lanza
	# al primer enemigo que toca DURANTE el paso, en vez de esperar a que termine para activarse por
	# tiempo. El cuerpo atraviesa enemigos (pass_through), pero el LauncherHitbox es un Area3D propio
	# que detecta hurtboxes igual. La ventana cubre paso + remate, asi que un paso al vacio no cambia:
	# el final sigue lanzando lo que quede en el area.
	play_visual_clip(ANIM_HEAVY, HEAVY_CHARGED_Y_GROUND.x, HEAVY_CHARGED_Y_GROUND.y,
			tuning.swing_time)
	swing_up(t.strike_angle)
	_player.force_dash(_player.forward(), t.ground_y_dash_distance, t.ground_y_dash_duration, false)
	run_launcher_window(_launcher_hitbox, t.ground_y_launcher_height, t.ground_y_launcher_hang_time,
			t.ground_y_dash_duration + t.ground_y_launcher_duration, t.ground_y_launcher_delay, false)

# ---- Aereo ----

## Combo aereo X de 2 golpes (un tap por golpe, mismo motor que el terrestre): corre a
## swing_time porque el Mazo es pesado (el air_step_time generico es para armas rapidas).
func _aerial_tap() -> void:
	if try_queue_combo(&"air"):
		return
	reset_hit_profile()
	run_combo_chain(&"air", AIR_STEP_COUNT, tuning.swing_time, _t().combo_window,
			0, 0.0, _begin_air_step)

## Golpe 1: jab con el mango, sin push (golpe de preparacion). Golpe 2 (finisher): cabezazo
## horizontal que arma el push hacia adelante a mitad del swing.
func _begin_air_step(step: int, _finisher: bool, _wait_branch: bool) -> void:
	if step == 1:
		thrust(_t().air_handle_reach)
	else:
		swing(_t().combo_swing_angle)
		arm_push(tuning.push, tuning.swing_time * tuning.push_at)
	_player.attack_step(tuning.swing_time)
	_player.notify_aerial_attack(tuning.swing_time)

func _aerial_charged_x(sweet_spot: bool) -> void:
	var t := _t()
	var id := begin_routine()
	reset_hit_profile()
	_charged_move_active = true
	_player.notify_aerial_attack(tuning.swing_time)
	play_visual_clip(ANIM_HEAVY, HEAVY_CHARGED_X_AIR.x, HEAVY_CHARGED_X_AIR.y, tuning.swing_time)
	_player.vertical_velocity = -absf(t.air_smash_fall_speed)
	_set_hitbox_damage(t.charged_hit_damage)
	begin_damage_window(tuning.swing_time)
	ComboTracker.register_hit()
	await wait_seconds(tuning.swing_time)
	if not is_routine_current(id):
		_charged_move_active = false
		return
	if sweet_spot:
		# La vuelta congelante reusa el tramo de vueltas del X terrestre (el plan no le asigna
		# tramo propio; decidido al implementar, ver bóveda Animacion Mazo).
		play_visual_clip(ANIM_HEAVY, HEAVY_CHARGED_X_SPIN.x, HEAVY_CHARGED_X_SPIN.y,
				t.charged_spin_time)
		_play_spin(t.charged_spin_time)
		_set_hitbox_stun(t.air_freeze_stun)
		begin_damage_window(t.charged_spin_time)
		ComboTracker.register_hit()
		_player.notify_aerial_attack(t.air_freeze_extra_hang_time)
		await wait_seconds(t.charged_spin_time)
		if not is_routine_current(id):
			_charged_move_active = false
			return
	reset_hit_profile()
	_charged_move_active = false

## Y aereo: cae en diagonal para interceptar. Si impacta el suelo, estalla un cilindro que
## lanza a los enemigos del area. Si impacta un enemigo airborne, estalla el cilindro,
## aplica slam_arc y el jugador rebota arriba-y-adelante, sin gastar doble salto.
func _aerial_hold_y(id: int) -> void:
	var t := _t()
	_set_air_y_fall_velocity()
	# La caída dura hasta el impacto (variable): el tramo se estira al techo de la caída y el
	# estallido corta el override al arrancar el siguiente golpe o expirar.
	play_visual_clip(ANIM_HEAVY, HEAVY_CHARGED_Y_AIR.x, HEAVY_CHARGED_Y_AIR.y,
			t.air_y_max_fall_time)
	_player.notify_aerial_attack(t.air_y_max_fall_time)
	ComboTracker.register_hit()
	var end_at := World.now() + t.air_y_max_fall_time
	var hit_enemy_in_air := false
	while is_routine_current(id) and World.now() < end_at:
		if _player.is_on_floor():
			break
		var enemy := _contacted_enemy()
		if enemy != null:
			# Rebote SOLO si el enemigo esta genuinamente en el aire. Si esta en el piso (o es un
			# golpeable sin estado aereo) cuenta como impacto de suelo: te plantas donde caes y el
			# AOE lo lanza, sin salir volando con el. El stun no cambia esto: manda is_airborne().
			hit_enemy_in_air = enemy.has_method("is_airborne") and bool(enemy.call("is_airborne"))
			break
		await get_tree().physics_frame
	if not is_routine_current(id):
		return
	await _burst_air_slam(id, hit_enemy_in_air)

func _set_air_y_fall_velocity() -> void:
	var t := _t()
	var angle := deg_to_rad(t.air_y_fall_angle)
	var horizontal_speed := cos(angle) * t.air_y_fall_speed
	var vertical_speed := sin(angle) * t.air_y_fall_speed
	_player.set_momentum(_player.forward() * horizontal_speed)
	_player.vertical_velocity = -absf(vertical_speed)
	_player.air_state = Player.AirState.AIRBORNE

## Enemigo/golpeable tocado fisicamente durante la caida (mismas colisiones de CharacterBody3D
## que usa PlayerEnemyBounce): el primer collider en LAYER_ENEMY, o null si no toco ninguno.
## No distingue aire/piso: eso lo decide quien llama con is_airborne().
func _contacted_enemy() -> Node:
	for index in range(_player.get_slide_collision_count()):
		var collision := _player.get_slide_collision(index)
		if collision == null:
			continue
		var collider := collision.get_collider() as CollisionObject3D
		if collider != null and (collider.collision_layer & World.LAYER_ENEMY) != 0:
			return collider
	return null

## Estallido del cilindro: rebota al jugador (solo si el impacto fue en el aire) y prende el
## hitbox una vez para golpear/rebotar a todos los de adentro.
func _burst_air_slam(id: int, hit_enemy_in_air: bool) -> void:
	var t := _t()
	end_damage_window()
	end_launcher_window()
	end_visual_clip()  # la caída terminó: suelta el tramo estirado del Y aéreo
	_air_y_hit_enemy_in_air = hit_enemy_in_air
	if hit_enemy_in_air:
		# La caida fue abajo+adelante; el rebote sale arriba+adelante a un angulo FIJO (no depende
		# del angulo de caida): air_y_bounce_angle da la inclinacion y air_y_bounce_speed la fuerza.
		# No gasta el doble salto.
		var bounce_angle := deg_to_rad(t.air_y_bounce_angle)
		_player.set_momentum(_player.forward() * (cos(bounce_angle) * t.air_y_bounce_speed))
		_player.vertical_velocity = sin(bounce_angle) * t.air_y_bounce_speed
		_player.air_state = Player.AirState.AIRBORNE
	else:
		# Impacto contra el suelo: el jugador se planta donde cayo. Corta el momentum
		# horizontal de la caida diagonal para no seguir deslizandose hacia adelante.
		_player.set_momentum(Vector3.ZERO)
	_air_slam_hitbox.begin_swing()
	await wait_seconds(t.air_y_aoe_duration)
	_air_slam_hitbox.end_swing()

## Rama de SUELO del estallido, ANTES del daño (mismo patron que _on_launcher_about_to_hit): lanza
## al enemigo primero, asi receive_hit lo ve airborne y su stun fija _airborne_until al hang, que lo
## mantiene suspendido durante la subida. Si el launch corriera despues del stun (en landed), el
## enemigo comeria el stun en el piso, la gravedad le ganaria al launch y arrancaria el ragdoll sin
## llegar a subir. La rama aerea (slam_arc) NO va aca: necesita correr despues del stun.
func _on_air_slam_about_to_hit(hurtbox: Hurtbox) -> void:
	if _air_y_hit_enemy_in_air:
		return
	var target: Node = hurtbox.owner_node
	if target.has_method("launch"):
		# El stun del hitbox va como consulta de poise: si al enemigo le queda reserva, aguanta el
		# estallido en el piso y no se lo lanza (EnemyBase.launch).
		target.call("launch", _t().air_y_ground_launch_height, _t().air_y_launcher_hang_time,
				_air_slam_hitbox.stun, target is EnemyBase)

## Cada enemigo del estallido: alimenta meter/kills/air-stall. Si el impacto fue aereo, ademas lo
## clava y lo hace PICAR en arco balistico (slam_arc) DESPUES del daño: el slam fija
## _airborne_until=now para caer y debe ser lo ultimo (si el stun corriera despues volveria a
## suspenderlo). La rama de suelo (launcher vertical) ya se aplico en _on_air_slam_about_to_hit.
func _on_air_slam_hit(hurtbox: Hurtbox, died: bool) -> void:
	# Cargado: el rebote arriba-y-adelante ES el move, no se le come el momentum.
	register_weapon_hit(hurtbox, died, false)
	if not _air_y_hit_enemy_in_air:
		return
	var target: Node = hurtbox.owner_node
	if target.has_method("slam_arc"):
		var t := _t()
		# Pique GENUINO en tu direccion (mismo forward que tu rebote): el enemigo se clava y pica en
		# arco balistico. No se ata a tu altura; la altura la da el arco (up/forward/gravity). Es un
		# verbo aparte del slam_arc vertical que usa la Espada.
		target.call("slam_arc", t.air_y_down_speed, _player.forward(),
				t.air_y_bounce_enemy_up_speed, t.air_y_bounce_enemy_forward_speed,
				t.air_y_bounce_enemy_gravity)

func _set_hitbox_stun(s: StunSettings) -> void:
	_blade_hitbox.stun = s
	if _air_disc_hitbox != null:
		_air_disc_hitbox.stun = s

func _set_hitbox_damage(damage: float) -> void:
	_blade_hitbox.damage = damage
	if _air_disc_hitbox != null:
		_air_disc_hitbox.damage = damage

func _t() -> MaceTuning:
	return tuning as MaceTuning

func _default_tuning() -> WeaponTuning:
	return MaceTuning.new()
