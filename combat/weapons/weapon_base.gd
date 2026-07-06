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
## Convención de escena de un arma (ver sword.tscn):
##   Arma (WeaponBase)
##   ├── Pivot (Node3D)            ← rota durante los swings
##   │   └── BladeHitbox (Hitbox)  ← acompaña la hoja
##   └── AirDiscHitbox (Hitbox)    ← opcional: disco alrededor del player en golpes aéreos

@export var tuning: WeaponTuning

var level := 1
var kill_count := 0

var _player: Player
## Golpeados de la ventana de daño en curso (el finisher aéreo los spikea/empuja).
var _window_hits: Array[Hurtbox] = []
var _shared_dedup: Array[Hurtbox] = []
var _window_id := 0
var _routine_id := 0
var _combo_playing := false
var _combo_window_open := false
var _combo_queued := false
var _combo_queued_time := 0.0
var _combo_kind := &""

@onready var _pivot: Node3D = $Pivot
@onready var _blade_hitbox: Hitbox = $Pivot/BladeHitbox
@onready var _air_disc_hitbox: Hitbox = get_node_or_null("AirDiscHitbox")

func _ready() -> void:
	if tuning == null:
		tuning = _default_tuning()

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
func run_combo_chain(kind: StringName, steps: int, step_time: float, chain_window: float,
		branch_step: int, branch_threshold: float,
		begin_step: Callable, finish := Callable()) -> void:
	_combo_playing = true
	_combo_kind = kind
	_routine_id += 1
	var id := _routine_id
	var wait_branch := false

	for step in range(1, steps + 1):
		_combo_queued = false
		_combo_window_open = false
		var finisher := step == steps
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
	# No flota sí o sí: solo marca "atacando en el aire" → si NO conecta, caés con
	# más fuerza. El float lo dispara el hitbox al conectar (landed → air-hit-stall).
	_player.notify_aerial_attack(tuning.air_step_time)

## Solo lo lanzable reacciona (has_method): una pared golpeada se ignora.
func _finish_air_combo(wait_branch: bool) -> void:
	for hurtbox in _window_hits.duplicate():
		var target: Node = hurtbox.owner_node
		if wait_branch and target.has_method("push"):
			target.call("push", _player.forward(), tuning.air_push_speed, tuning.air_push_up_speed)
		elif not wait_branch and target.has_method("slam"):
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

## Reacción común a cualquier golpe conectado del arma (hoja, disco, launcher, dash
## cargado): air-hit-stall + meter + progresión de kills.
func register_weapon_hit(hurtbox: Hurtbox, died: bool) -> void:
	# Conectar en el aire contra algo que lo dispara ralentiza la caída del jugador.
	if hurtbox.triggers_air_hit_stall:
		_player.register_air_hit_stall()
	var meter := _player.meter
	if meter != null:
		meter.gain_on_hit()
		if died:
			meter.gain_on_kill()
			on_kill()

func _on_hit(hurtbox: Hurtbox, died: bool) -> void:
	_window_hits.append(hurtbox)
	register_weapon_hit(hurtbox, died)

# ---- Progresión ----

func on_kill() -> void:
	kill_count += 1
	if level < tuning.max_level and kill_count >= tuning.kills_to_upgrade * level:
		level += 1

# ---- Helpers ----

## Invalida las rutinas en curso (combos): cada una chequea su id tras cada await.
func cancel_routines() -> void:
	_routine_id += 1
	_combo_playing = false
	_combo_window_open = false
	_combo_kind = &""

func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(maxf(0.01, seconds)).timeout

func _default_tuning() -> WeaponTuning:
	return WeaponTuning.new()
