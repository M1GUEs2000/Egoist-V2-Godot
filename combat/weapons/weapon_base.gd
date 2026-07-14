class_name WeaponBase extends Node3D
## Arma abstracta (ex WeaponBase.cs). Estado propio: kills, nivel; la ventana de daño
## de cada swing y el motor genérico de cadenas de golpes (combos terrestre y aéreo
## comparten el mismo runner; cada arma pone solo su coreografía). Tap/hold por slot
## (World.Slot); el tuning numérico vive en un Resource en data/ (WeaponTuning).
##
## La ventana de daño reemplaza los trace-hitboxes muestreados de v1: el Hitbox de la
## hoja es un Area3D hijo del Pivot que barre físicamente con el swing (Jolt lo samplea
## cada physics frame, mismo grano que el trace de v1). En el aire se suma el disco.
##
## Convención de escena de un arma (ver sword.tscn). El root del arma está en el origen
## del player: es el EJE alrededor del cual orbita la mano.
##   Arma (WeaponBase)
##   ├── Hand (Node3D)                 ← la mano: rota durante los swings y así orbita al player
##   │   └── Pivot (Node3D)            ← muñeca RÍGIDA: solo aleja la hoja hand_radius de la mano
##   │       └── BladeHitbox (Hitbox)  ← acompaña la hoja
##   └── AirDiscHitbox (Hitbox)        ← opcional: disco alrededor del player en golpes aéreos
##
## El golpe no nace de girar la hoja sobre un punto fijo al costado del jugador: nace de
## MOVER la mano alrededor del jugador. La hoja cuelga rígida, apuntando siempre hacia
## afuera, y describe el arco porque la mano la lleva. Rotar la mano en Y la pasea por un
## semicírculo al frente; rotarla en X la sube/baja; alejar el radio la extiende (estocada).

@export var tuning: WeaponTuning

## Juice de carga: la hoja emite este color al mantener un ataque (glow proporcional a
## buffer.charge_progress()). Greybox, sin assets: emission sobre el material de la hoja.
@export var charge_glow_color := Color(1.0, 0.82, 0.28)
@export var charge_glow_max_energy := 2.5

var level := 1
var kill_count := 0

var _player: Player
## Golpeados de la ventana de daño en curso (el finisher aéreo los spikea/empuja).
var _window_hits: Array[Hurtbox] = []
## PushSettings de la ventana en curso una vez cumplido su delay (null = sin armar).
var _armed_push: PushSettings
var _shared_dedup: Array[Hurtbox] = []
var _window_id := 0
var _routine_id := 0
var _combo_playing := false
var _combo_window_open := false
var _combo_queued := false
var _combo_queued_time := 0.0
var _combo_kind := &""
var _swing_tween: Tween
var _launcher_id := 0
var _launcher_height := 0.0
var _launcher_hang_time := 0.0
var _launcher_starts_lying := false
# El stun del launcher: el enemigo lo necesita para consultar su poise y decidir si el launch
# entra (no se lo puede mover si le queda reserva). Ver EnemyBase.launch.
var _launcher_stun: StunSettings
var _active_launcher_hitbox: Hitbox
## Pose de mano desde la que arranca la estocada en curso (ver thrust).
var _thrust_from := Quaternion.IDENTITY
var _thrust_reach := 0.0

@onready var _hand: Node3D = $Hand
@onready var _pivot: Node3D = $Hand/Pivot
@onready var _blade_hitbox: Hitbox = $Hand/Pivot/BladeHitbox
@onready var _air_disc_hitbox: Hitbox = get_node_or_null("AirDiscHitbox")
@onready var _blade_mesh: MeshInstance3D = _find_charge_glow_mesh()

var _blade_material: StandardMaterial3D

func _ready() -> void:
	if tuning == null:
		tuning = _default_tuning()
	_hand.position = Vector3(0.0, tuning.hand_height, 0.0)
	_reset_hand()
	_setup_blade_glow()

func setup(player: Player) -> void:
	_player = player
	for hitbox: Hitbox in [_blade_hitbox, _air_disc_hitbox]:
		if hitbox == null:
			continue
		hitbox.source = player
		hitbox.damage = 1.0
		hitbox.stun = tuning.stun
		hitbox.share_already_hit(_shared_dedup)
		hitbox.landed.connect(_on_hit)
	# Hoja y disco aéreo se parrian (decisión de diseño: v1 solo parriaba la hoja; acá
	# también el disco). El launcher no (ver Sword.setup).
	# ponytail: v1 además solo dejaba parriar en la mitad del propio swing (CanParryAt →
	# "clash" mutuo). Acá es parriable todo el swing y la ventana estrecha del enemigo ya
	# acota; afinar el clash mid-swing cuando haya Godot para tunear.

# ---- API que enruta PlayerCombat (cada arma define sus personalidades) ----

func tap(_slot: World.Slot) -> void:
	pass

func hold(_slot: World.Slot, _level: int) -> void:
	pass

## PlayerCombat llama esto antes de resetear la pose del arma en un press.
## Si hay una cadena activa, ese press puede ser solo un input encolado para el próximo
## golpe: resetear la rotación acá hace que armas pesadas como el Mazo parezcan reiniciar
## el swing con cada click. La Espada ya se sentía bien por timing, pero el contrato correcto
## es no tocar la pose mientras el runner de combo sigue vivo.
func should_reset_pose_on_press() -> bool:
	return not _combo_playing

## Nivel de carga (1-based) para una duración de hold sostenida. Default: un solo
## nivel (comportamiento actual de la Espada, que ignora _level). El Mazo lo
## sobreescribe para sus 3 niveles de vueltas cargadas.
func charge_level(_held_time: float) -> int:
	return 1

# ---- Motor genérico de cadenas de golpes (ex PlayAerialCombo, hoy también terrestre) ----

## Un tap mientras corre una cadena del mismo tipo: encola el siguiente golpe si la
## ventana está abierta (si no, mid-swing, se ignora). Devuelve true si el tap fue
## consumido; false si no hay cadena de este tipo corriendo y hay que arrancar una.
func try_queue_combo(kind: StringName) -> bool:
	if not _combo_playing or _combo_kind != kind:
		return false
	if _combo_window_open:
		_combo_queued = true
		_combo_queued_time = World.now()
	return true

## Cadena de N golpes, UN tap por golpe, con ventana de encadene entre golpes.
## begin_step(step, finisher, wait_branch) pone la coreografía del golpe; la ventana de
## daño y el ComboTracker los pone el motor. Tras branch_step, tardar al menos
## branch_threshold (dentro de la ventana) en encadenar activa la rama "espera".
## finish(wait_branch) corre al completar el finisher (si es válida). Arrancar una
## cadena invalida cualquier otra en curso (routine_id compartido).
## wait_branch_extra_steps: si la rama "espera" se activa en branch_step, el total
## de golpes de esta corrida pasa de steps a steps + wait_branch_extra_steps (0 =
## la rama solo cambia coreografía, no cantidad — comportamiento de la Espada).
func run_combo_chain(kind: StringName, steps: int, step_time: float, chain_window: float,
		branch_step: int, branch_threshold: float,
		begin_step: Callable, finish := Callable(), wait_branch_extra_steps := 0) -> void:
	var id := begin_routine()
	_combo_playing = true
	_combo_kind = kind
	var wait_branch := false
	var total_steps := steps

	var step := 1
	while step <= total_steps:
		_combo_queued = false
		_combo_window_open = false
		var finisher := step == total_steps
		begin_step.call(step, finisher, wait_branch)
		begin_damage_window(step_time)
		ComboTracker.register_hit()
		await wait_seconds(step_time)
		if id != _routine_id:
			return
		var step_end := World.now()

		if finisher:
			if finish.is_valid():
				finish.call(wait_branch)
			break

		# Ventana de encadene: esperar el siguiente tap o cortar la cadena.
		_combo_window_open = true
		var expiry := World.now() + chain_window
		while World.now() < expiry and not _combo_queued:
			await get_tree().process_frame
			if id != _routine_id:
				return
		_combo_window_open = false
		if not _combo_queued:
			break
		if step == branch_step:
			wait_branch = (_combo_queued_time - step_end) >= branch_threshold
			if wait_branch:
				total_steps += wait_branch_extra_steps
		step += 1

	_combo_playing = false
	_combo_window_open = false

# ---- Combo aéreo (la coreografía la define cada arma) ----

## Cuántos golpes tiene el combo aéreo de esta arma (0 = no tiene). El último es el finisher.
func air_steps() -> int:
	return 0

## Swing visual del golpe aéreo N (1-based). wait_branch = tras el golpe 1 se esperó
## (rama de vueltas + empuje en vez de diagonal + spike). Default no-op.
func play_air_step(_step: int, _finisher: bool, _wait_branch: bool) -> void:
	pass

## N golpes aéreos sobre el motor genérico. Si tapeás rápido tras el golpe 1 → rama
## base (finisher spikea al suelo). Si esperás → rama de vueltas (finisher empuja).
func play_aerial_combo() -> void:
	if air_steps() <= 0 or _player == null:
		return
	if try_queue_combo(&"air"):
		return
	run_combo_chain(&"air", air_steps(), tuning.air_step_time, tuning.air_combo_window,
			1, tuning.air_wait_branch_threshold, _begin_air_step, _finish_air_combo)

func _begin_air_step(step: int, finisher: bool, wait_branch: bool) -> void:
	play_air_step(step, finisher, wait_branch)
	if finisher and wait_branch:
		arm_push(tuning.push, tuning.air_step_time * tuning.push_at)
	_player.attack_step(tuning.air_step_time)  # avanza hacia el lockeado / al frente, igual que en tierra
	# No flota sí o sí: solo marca "atacando en el aire" → si NO conecta, caés con
	# más fuerza. El float lo dispara el hitbox al conectar (landed → air-hit-stall).
	_player.notify_aerial_attack(tuning.air_step_time)

## Solo lo lanzable reacciona (has_method): una pared golpeada se ignora.
func _finish_air_combo(wait_branch: bool) -> void:
	if wait_branch:
		return  # el push ya lo armó _begin_air_step
	for hurtbox in _window_hits.duplicate():
		var target: Node = hurtbox.owner_node
		if target.has_method("slam"):
			target.call("slam", tuning.air_spike_down_speed)

# ---- Ventana de daño ----

## Prende el Hitbox de la hoja durante el swing (+ disco aéreo si el player está en el
## aire, como v1). Los golpeados quedan en _window_hits. Fire-and-forget: se llama sin await.
func begin_damage_window(duration: float) -> void:
	_window_id += 1
	var id := _window_id
	_window_hits.clear()
	_blade_hitbox.begin_swing()
	if _air_disc_hitbox != null and _player != null and _player.is_airborne():
		_air_disc_hitbox.begin_swing()
	await wait_seconds(duration)
	if id != _window_id:
		return  # otro swing ya arrancó: él es dueño de los hitboxes ahora
	_blade_hitbox.end_swing()
	if _air_disc_hitbox != null:
		_air_disc_hitbox.end_swing()

func end_damage_window() -> void:
	_window_id += 1
	_window_hits.clear()
	if _blade_hitbox != null:
		_blade_hitbox.end_swing()
	if _air_disc_hitbox != null:
		_air_disc_hitbox.end_swing()

func end_launcher_window() -> void:
	_launcher_id += 1
	if _active_launcher_hitbox != null:
		_active_launcher_hitbox.end_swing()
	_active_launcher_hitbox = null

## Arma el push de esta ventana. Tras `delay` segundos empuja a todo lo golpeado hasta
## ese momento y queda armado: lo que conecte después se empuja en el instante del hit.
func arm_push(settings: PushSettings, delay: float) -> void:
	if settings == null:
		return
	var id := _routine_id
	await wait_seconds(delay)
	if not is_routine_current(id):
		return
	_armed_push = settings
	_push_window_hits(settings)

## Empuja a los golpeados de la ventana en curso.
func _push_window_hits(settings: PushSettings) -> void:
	for hurtbox in _window_hits.duplicate():
		if is_instance_valid(hurtbox):
			_push_target(hurtbox, settings)

## Solo lo empujable reacciona (has_method): una pared golpeada se ignora.
func _push_target(hurtbox: Hurtbox, settings: PushSettings) -> void:
	var target: Node = hurtbox.owner_node
	if is_instance_valid(target) and target.has_method("push"):
		target.call("push", _player.forward(), settings)

## Reacción común a cualquier golpe conectado del arma (hoja, disco, launcher, dash
## cargado): air-hit-stall + meter + progresión de kills.
func register_weapon_hit(hurtbox: Hurtbox, died: bool) -> void:
	# Conectar en el aire contra algo que lo dispara ralentiza la caída del jugador.
	if hurtbox.triggers_air_hit_stall:
		_player.register_air_hit_stall(tuning.air_stall_scale)
	var meter := _player.meter
	if meter != null:
		meter.gain_on_hit()
		if died:
			meter.gain_on_kill()
	if died:
		if _player.is_airborne():
			_player.apply_air_kill_reset()
		on_kill()

func _on_hit(hurtbox: Hurtbox, died: bool) -> void:
	_window_hits.append(hurtbox)
	if _armed_push != null:
		_push_target(hurtbox, _armed_push)
	register_weapon_hit(hurtbox, died)

# ---- Progresión ----

func on_kill() -> void:
	kill_count += 1
	if level < tuning.max_level and kill_count >= tuning.kills_to_upgrade * level:
		level += 1

# ---- Juice: glow de carga en la hoja ----

## Prepara un material propio en la hoja con emission apagada (energy 0), listo para el
## glow de carga. Duplica el material base para no pisar otras instancias del arma.
func _find_charge_glow_mesh() -> MeshInstance3D:
	var preferred := get_node_or_null("Hand/Pivot/BladeMesh") as MeshInstance3D
	if preferred != null:
		return preferred
	# El Mazo no tiene BladeMesh: su parte visible/cargable es la cabeza.
	preferred = get_node_or_null("Hand/Pivot/HeadMesh") as MeshInstance3D
	if preferred != null:
		return preferred
	return get_node_or_null("Hand/Pivot/HandleMesh") as MeshInstance3D

func _setup_blade_glow() -> void:
	if _blade_mesh == null:
		return
	var base := _blade_mesh.get_active_material(0)
	if base is StandardMaterial3D:
		_blade_material = (base as StandardMaterial3D).duplicate()
	else:
		_blade_material = StandardMaterial3D.new()
	_blade_material.emission_enabled = true
	_blade_material.emission = charge_glow_color
	_blade_material.emission_energy_multiplier = 0.0
	_blade_mesh.set_surface_override_material(0, _blade_material)

## Intensidad del glow de carga, 0→1 (lo llama PlayerCombat con buffer.charge_progress()).
func set_charge_glow(t: float) -> void:
	if _blade_material != null:
		_blade_material.emission_energy_multiplier = clampf(t, 0.0, 1.0) * charge_glow_max_energy

# ---- Launcher genérico (cono/área que lanza antes de golpear, ex ConeLauncherHitbox) ----
## Cablea un Hitbox como launcher: nunca se parria, lanza al objetivo ANTES del daño
## (about_to_hit) así el golpe ya ve is_airborne = true, y alimenta meter/air-hit-stall
## al conectar (landed → _on_hit). Cada arma llama esto en su setup() para su propio
## hitbox de launcher.
func setup_launcher_hitbox(hitbox: Hitbox, deals_damage: bool, stun_settings: StunSettings,
		starts_lying := false) -> void:
	hitbox.source = _player
	hitbox.damage = 1.0 if deals_damage else 0.0
	hitbox.stun = stun_settings
	hitbox.can_be_parried = false
	_launcher_stun = stun_settings
	_launcher_starts_lying = starts_lying
	hitbox.about_to_hit.connect(_on_launcher_about_to_hit)
	hitbox.landed.connect(_on_hit)

## Solo lanza lo lanzable (has_method): una pared o un pickup no salen volando. El enemigo decide
## si el launch entra: con poise de sobra lo aguanta y no se mueve (EnemyBase.launch).
func _on_launcher_about_to_hit(hurtbox: Hurtbox) -> void:
	var target: Node = hurtbox.owner_node
	if target.has_method("launch"):
		target.call("launch", _launcher_height, _launcher_hang_time, _launcher_stun,
				_launcher_starts_lying and target is EnemyBase)

## Ventana de daño del launcher con id-guard: espera `delay` (deja arrancar el swing
## visual), opcionalmente lanza al player y prende el hitbox `duration` segundos. Arrancar un nuevo
## launcher invalida cualquier ventana anterior (mismo patrón que begin_damage_window).
func run_launcher_window(hitbox: Hitbox, height: float, hang_time: float,
		duration: float, delay := 0.05, launches_player := true) -> void:
	_launcher_id += 1
	var id := _launcher_id
	_launcher_height = height
	_launcher_hang_time = hang_time
	await wait_seconds(delay)
	if id != _launcher_id:
		return
	if launches_player:
		_player.launch(height, hang_time)
	_active_launcher_hitbox = hitbox
	hitbox.begin_swing()
	ComboTracker.register_hit()
	await wait_seconds(duration)
	if id != _launcher_id:
		return
	hitbox.end_swing()
	if _active_launcher_hitbox == hitbox:
		_active_launcher_hitbox = null

# ---- Swings procedurales (tweens de quaternion sobre la Hand, sin AnimationPlayer) ----
## Genérico para cualquier arma con Hand/Pivot; la coreografía (qué ángulo, qué step) la
## define cada arma (ver Sword/Mace), esto solo mueve la mano alrededor del jugador.

## Swing horizontal (eje Y): la mano recorre un semicírculo al frente, de un lado al otro.
## Corte por defecto.
func swing(angle: float) -> void:
	_swing_axis(angle, Vector3.UP)

## Swing vertical ascendente (eje X): la mano sube en arco frente al jugador (uppercut
## del launcher).
func swing_up(angle: float) -> void:
	_swing_axis(angle, Vector3.RIGHT)

func _swing_axis(angle: float, axis: Vector3) -> void:
	var half := deg_to_rad(angle * 0.5)
	_play_swing(Quaternion(axis, -half), Quaternion(axis, half))

## Estocada: la mano viaja desde su reposo hasta el frente del jugador extendiendo el brazo
## `reach` metros, y vuelve. La hoja no rota (muñeca rígida): la punta avanza porque la mano
## se aleja del eje. El avance del cuerpo lo pone attack_step del jugador, no esto.
func thrust(reach: float) -> void:
	_kill_swing_tween()
	_thrust_from = _hand_rest()
	_thrust_reach = reach
	_swing_tween = create_tween()
	_swing_tween.tween_method(_set_thrust_progress, 0.0, 1.0, tuning.swing_time)
	_swing_tween.tween_callback(_reset_hand)

## progress 0 = mano en reposo · 0.5 = brazo extendido al frente · 1 = de vuelta.
## La mano llega al frente en la primera mitad; el radio sale y vuelve en todo el golpe.
func _set_thrust_progress(progress: float) -> void:
	_hand.quaternion = _thrust_from.slerp(Quaternion.IDENTITY, minf(1.0, progress * 2.0))
	_set_hand_radius(tuning.hand_radius + _thrust_reach * sin(progress * PI))

func _play_swing(from: Quaternion, to: Quaternion) -> void:
	_kill_swing_tween()
	_hand.quaternion = from
	_swing_tween = create_tween()
	_swing_tween.tween_property(_hand, "quaternion", to, tuning.swing_time)
	_swing_tween.tween_callback(_reset_hand)

## Vuelta completa: la mano da la vuelta entera alrededor del jugador. `duration` < 0 → dura
## lo que un swing normal; las vueltas del X cargado del Mazo pasan su propio
## charged_spin_time (si no, el tween queda a medio girar cuando arranca la vuelta siguiente).
func _play_spin(duration := -1.0) -> void:
	_kill_swing_tween()
	var spin_time := duration if duration > 0.0 else tuning.swing_time
	_swing_tween = create_tween()
	_swing_tween.tween_method(_set_spin_angle, 0.0, TAU, spin_time)
	_swing_tween.tween_callback(_reset_hand)

func _set_spin_angle(angle: float) -> void:
	_hand.quaternion = Quaternion(Vector3.UP, angle)

## Pose de reposo de la mano: a un lado del jugador (hand_rest_yaw), brazo sin extender.
func _hand_rest() -> Quaternion:
	return Quaternion(Vector3.UP, deg_to_rad(tuning.hand_rest_yaw))

## Aleja/acerca la hoja moviendo la mano sobre su radio. La muñeca no rota: la hoja apunta
## siempre radialmente hacia afuera, así que cambiar el radio la extiende hacia adelante.
func _set_hand_radius(radius: float) -> void:
	_pivot.position = Vector3(0.0, 0.0, -radius)

func _reset_hand() -> void:
	_hand.quaternion = _hand_rest()
	_set_hand_radius(tuning.hand_radius)

func _kill_swing_tween() -> void:
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()

# ---- Helpers ----

## Arranca una rutina cancelable: invalida cualquier otra en curso (combo, vueltas
## cargadas, ventanas de sweet spot) y devuelve el id con el que hay que chequear tras
## cada await (`is_routine_current`). TODA entrada de ataque debe pasar por acá: si una
## rutina vieja sobrevive, sigue pisando el hitbox y el Pivot de la que arrancó recién.
func begin_routine() -> int:
	_routine_id += 1
	end_damage_window()
	end_launcher_window()
	_armed_push = null
	_combo_playing = false
	_combo_window_open = false
	_combo_kind = &""
	return _routine_id

## False si otra rutina arrancó mientras esta esperaba: hay que retornar sin tocar nada
## (el hitbox y el Pivot ya son de la rutina nueva).
func is_routine_current(id: int) -> bool:
	return id == _routine_id

## Invalida las rutinas en curso (combos): cada una chequea su id tras cada await.
func cancel_routines() -> void:
	begin_routine()

## Devuelve hoja y disco aéreo a su perfil de daño/stun base. Toda entrada de ataque la
## llama antes de customizarlo: así una rutina cancelada a mitad (que dejó damage 0.0 o
## el stun congelante puesto, ver Mazo) no contamina el golpe siguiente.
func reset_hit_profile() -> void:
	for hitbox: Hitbox in [_blade_hitbox, _air_disc_hitbox]:
		if hitbox != null:
			hitbox.damage = 1.0
			hitbox.stun = tuning.stun

func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(maxf(0.01, seconds)).timeout

func _default_tuning() -> WeaponTuning:
	return WeaponTuning.new()
