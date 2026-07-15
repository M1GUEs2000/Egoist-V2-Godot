class_name PlayerArm extends Node
## Brazo: puño remoto, habilidad permanente del jugador (ver obsidian/Gameplay/Brazo). No es
## WeaponBase: no ocupa slot X/Y, no usa el motor de combos/swing orbital de las armas.
## Primera pasada: solo combate, solo tap. Golpea al target del lock-on pasivo (lockeado si hay
## uno, si no el más cercano en el cono de mira — mismo target que usa PlayerLocomotion para el
## snap del golpe normal). Daño y poise bajos; genera meter propio y bajo al conectar.

@export var tuning: ArmTuning

var _taps_used := 0
var _cooldown_until := -999.0
var _swing_id := 0
var _player: Player

@onready var _hitbox: Hitbox = $ArmHitbox
@onready var _marker: MeshInstance3D = $ArmMarker

func _ready() -> void:
	if tuning == null:
		tuning = ArmTuning.new()
	_marker.visible = false

## Punto morado sobre quien recibiria el golpe AHORA (lock-on pasivo del Brazo): no depende de
## armas afuera ni de estar atacando, a diferencia del reticle de combate (ver LockOn._process).
func _process(_delta: float) -> void:
	if _player == null:
		return
	var target := _resolve_target()
	_marker.visible = target != null
	if target != null:
		_marker.global_position = _player.lock_on.head_position(target)

func _input(event: InputEvent) -> void:
	if _player != null and _player.is_stunned():
		return
	if event.is_action_pressed("arm_attack"):
		_try_tap()

func setup(player: Player) -> void:
	_player = player
	_hitbox.source = player
	_hitbox.damage = tuning.damage
	_hitbox.stun = tuning.stun
	_hitbox.landed.connect(_on_hit)

func _try_tap() -> void:
	if _taps_used >= tuning.max_taps:
		if World.now() < _cooldown_until:
			return  # en cooldown: el apreton no hace nada
		_taps_used = 0  # cooldown cumplido: vuelve a habilitarse

	var target := _resolve_target()
	if target == null:
		return  # sin nadie marcado: apreton gratis, no gasta tap

	# Se gasta el tap ACA (antes del await): si no, taps mas rapidos que travel_time se
	# colarian todos antes de que el primero llegue a incrementar el contador.
	_taps_used += 1
	if _taps_used >= tuning.max_taps:
		_cooldown_until = World.now() + tuning.cooldown_duration

	_swing_id += 1
	var id := _swing_id
	_hitbox.global_position = target.global_position
	_hitbox.begin_swing()
	await get_tree().create_timer(maxf(0.01, tuning.travel_time)).timeout
	if id == _swing_id:
		_hitbox.end_swing()

## Mismo target que el snap del golpe normal sin lock (ver PlayerLocomotion): lockeado si hay
## uno, si no el enemigo mas centrado en el cono de mira.
func _resolve_target() -> EnemyBase:
	if _player.lock_on.is_locked:
		return _player.lock_on.current_target
	return _player.lock_on.nearest_in_cone(_player.forward())

func _on_hit(_hurtbox: Hurtbox, _died: bool) -> void:
	if _player.meter != null:
		_player.meter.gain_bars(tuning.meter_gain_on_hit)
