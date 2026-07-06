class_name WeaponBase extends Node3D
## Arma abstracta (ex WeaponBase.cs). Estado propio: kills, nivel; la ventana de daño
## de cada swing y el motor genérico del combo aéreo. Tap/hold por slot (World.Slot);
## el tuning numérico vive en un Resource en data/ (WeaponTuning).
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
var _aerial_playing := false
var _aerial_window_open := false
var _aerial_queued := false
var _aerial_queued_time := 0.0

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

# ---- API que enruta PlayerCombat (cada arma define sus personalidades) ----

func tap(_slot: World.Slot) -> void:
	pass

func hold(_slot: World.Slot, _level: int) -> void:
	pass

# ---- Combo aéreo (Template Method, ex PlayAerialCombo) ----

## Cuántos golpes tiene el combo aéreo de esta arma (0 = no tiene). El último es el finisher.
func air_steps() -> int:
	return 0

## Swing visual del golpe aéreo N (1-based). wait_branch = tras el golpe 1 se esperó
## (rama de vueltas + empuje en vez de diagonal + spike). Default no-op.
func play_air_step(_step: int, _finisher: bool, _wait_branch: bool) -> void:
	pass

## Motor reutilizable: N golpes, UN tap por golpe. Si tapeás rápido tras el golpe 1 →
## rama base (finisher spikea al suelo). Si esperás → rama de vueltas (finisher empuja).
func play_aerial_combo() -> void:
	if air_steps() <= 0 or _player == null:
		return
	if _aerial_playing:
		if _aerial_window_open:
			_aerial_queued = true
			_aerial_queued_time = World.now()
		return
	_run_aerial_combo()

func _run_aerial_combo() -> void:
	_aerial_playing = true
	_routine_id += 1
	var id := _routine_id
	var steps := air_steps()
	var wait_branch := false

	for step in range(1, steps + 1):
		_aerial_queued = false
		_aerial_window_open = false
		var finisher := step == steps
		play_air_step(step, finisher, wait_branch)
		# No flota sí o sí: solo marca "atacando en el aire" → si NO conecta, caés con
		# más fuerza. El float lo dispara el hitbox al conectar (landed → air-hit-stall).
		_player.notify_aerial_attack(tuning.air_step_time)
		begin_damage_window(tuning.air_step_time)
		ComboTracker.register_hit()
		await wait_seconds(tuning.air_step_time)
		if id != _routine_id:
			return
		var step_end := World.now()

		if finisher:
			# Solo lo lanzable reacciona (has_method): una pared golpeada se ignora.
			for hurtbox in _window_hits.duplicate():
				var target := hurtbox.owner_node
				if wait_branch and target.has_method("push"):
					target.call("push", _player.forward(), tuning.air_push_speed, tuning.air_push_up_speed)
				elif not wait_branch and target.has_method("slam"):
					target.call("slam", tuning.air_spike_down_speed)
			break

		# Ventana de encadene: esperar el siguiente tap o cortar el combo.
		_aerial_window_open = true
		var expiry := World.now() + tuning.air_combo_window
		while World.now() < expiry and not _aerial_queued:
			await get_tree().process_frame
			if id != _routine_id:
				return
		_aerial_window_open = false
		if not _aerial_queued:
			break
		# Solo la espera tras el golpe 1 decide la rama (el terrestre la decide tras el 2).
		if step == 1:
			wait_branch = (_aerial_queued_time - step_end) >= tuning.air_wait_branch_threshold

	_aerial_playing = false

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

func _on_hit(hurtbox: Hurtbox, died: bool) -> void:
	_window_hits.append(hurtbox)
	# Conectar en el aire contra algo que lo dispara ralentiza la caída del jugador.
	if hurtbox.triggers_air_hit_stall:
		_player.register_air_hit_stall()
	var meter := _player.meter
	if meter != null:
		meter.gain_on_hit()
		if died:
			meter.gain_on_kill()
			on_kill()

# ---- Progresión ----

func on_kill() -> void:
	kill_count += 1
	if level < tuning.max_level and kill_count >= tuning.kills_to_upgrade * level:
		level += 1

# ---- Helpers ----

## Invalida las rutinas en curso (combos): cada una chequea su id tras cada await.
func cancel_routines() -> void:
	_routine_id += 1
	_aerial_playing = false
	_aerial_window_open = false

func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(maxf(0.01, seconds)).timeout

func _default_tuning() -> WeaponTuning:
	return WeaponTuning.new()
