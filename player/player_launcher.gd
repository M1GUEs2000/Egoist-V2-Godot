class_name PlayerLauncher extends Node
## Bloque (ex PlayerLauncher.cs): combate aéreo del jugador — el launcher (sube y flota)
## y el air-hit-stall (conectando golpes en el aire la caída se RALENTIZA; atacando en el
## aire SIN conectar cae con MÁS fuerza). No aplica gravedad él mismo: provee al glue la
## ESCALA de gravedad de este frame. (El freeze vertical de v1 nunca se usaba: eliminado.)

var is_launched := false

var _body: Player
var _height := 0.0
var _rise_time := World.LAUNCH_RISE_TIME
var _rise_left := 0.0
var _float_until := 0.0
var _fall_until := 0.0
var _aerial_attack_until := 0.0
var _last_stall_time := -999.0
var _stall_count := 0

func setup(body: Player) -> void:
	_body = body

## El dueño ya canceló dash/swing antes de esto. (hang_time reservado: v1 lo recibía sin usarlo.)
func start_launch(height: float, _hang_time: float, rise_time: float = World.LAUNCH_RISE_TIME) -> void:
	is_launched = true
	_height = height
	_rise_time = maxf(0.01, rise_time)
	_rise_left = _rise_time
	_body.air_state = Player.AirState.AIRBORNE
	_body.vertical_velocity = 0.0

func tick_launch(delta: float) -> void:
	_body.velocity = Vector3.UP * (_height / _rise_time)
	_body.move_and_slide()
	_rise_left -= delta
	if _rise_left <= 0.0:
		is_launched = false
		_body.vertical_velocity = 0.0
		var t := _body.tuning
		_float_until = World.now() + t.launcher_float_duration
		_fall_until = World.now() + t.launcher_fall_duration

## Escala de gravedad para este frame. El momentum horizontal NO se toca acá.
func gravity_scale() -> float:
	var t := _body.tuning
	# Atacando en el aire sin conectar: cae MÁS fuerte. (Conectando cae lento, pero eso ya no pasa
	# por acá: desde F3 el hang del air-hit lo sostiene el Floater, que tiene prioridad en el glue.)
	if World.now() < _aerial_attack_until:
		return t.aerial_whiff_fall_gravity
	if World.now() < _float_until:
		return t.launcher_float_gravity
	if World.now() < _fall_until:
		return t.launcher_fall_gravity
	return 1.0

## El arma avisa que hay un golpe aéreo en curso: si NO conecta, la caída se agrava.
## Si conecta, el hitbox llama register_air_hit_stall y el float gana prioridad.
func notify_aerial_attack(duration: float) -> void:
	if _body.is_on_floor():
		return
	_aerial_attack_until = maxf(_aerial_attack_until, World.now() + duration)

## `cuts_momentum` false = golpe CARGADO: frena la caída como cualquier otro, pero no le toca el
## momentum horizontal (los cargados dueñan su propio desplazamiento: dash, auto-launch, spike).
func register_air_hit_stall(scale := 1.0, cuts_momentum := true) -> void:
	if _body.is_on_floor():
		return
	var t := _body.tuning
	# Contraparte horizontal del freno vertical de abajo: el golpe come momentum en las dos fuentes
	# (inercia del input y bump), así conectar en el aire ancla al jugador en vez de dejarlo viajando.
	if cuts_momentum:
		_body.bump_velocity *= clampf(t.air_stall_momentum_keep, 0.0, 1.0)
		_body.locomotion.scale_air_velocity(t.air_stall_momentum_keep)
	if World.now() - _last_stall_time > t.air_stall_combo_window:
		_stall_count = 0
	_stall_count += 1
	_last_stall_time = World.now()
	var duration := minf(t.air_stall_base + t.air_stall_per_hit * (_stall_count - 1), t.air_stall_max) * scale
	# (F3) El hang ya no es un temporizador de este modulo: lo sostiene el Floater del cuerpo con la
	# misma duracion escalada por combo y la misma escala de caida. Lo que queda aca es la
	# contabilidad del combo (_stall_count/_last_stall_time) y el corte de momentum horizontal.
	_body.floater.start_float(duration, t.air_stall_float_gravity)
	# Congela la caída (velocity negativa → 0) pero preserva una subida CHICA (ej. el hop del
	# primer spin de la rama espera): así el air-hit no mata el impulso vertical. El cap evita
	# amplificar un salto: sin él, un golpe justo tras un doble salto conservaba toda la velocidad
	# del salto y con la gravedad baja del stall el jugador salía disparado.
	_body.vertical_velocity = clampf(_body.vertical_velocity, 0.0, t.air_stall_max_rise)
	_body.air_state = Player.AirState.AIRBORNE

## El hang en si lo apaga el Floater (Player lo cancela en el mismo punto); aca queda el reset de
## la ventana de whiff y del contador de combo.
func reset_air_stall() -> void:
	_aerial_attack_until = 0.0
	_stall_count = 0

## Cancela el launcher (al dashear/bumpear/swing): apaga flotación y stall.
func cancel() -> void:
	is_launched = false
	_float_until = 0.0
	_fall_until = 0.0
	reset_air_stall()
