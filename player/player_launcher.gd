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
var _air_stall_until := 0.0
var _aerial_attack_until := 0.0
var _last_stall_time := -999.0
var _stall_count := 0

# Freeze de caida del Brazo (aire): a diferencia del air stall del arma, NO flota ni resetea. La
# VERTICAL se congela un instante (pausa) y al soltar retoma la caida con el momentum COMPLETO
# previo. El HORIZONTAL en cambio DECELERA: cada golpe le baja la velocidad de momentum (bump) por
# un factor, no lo conserva. Ver register_arm_air_freeze / consume_air_freeze.
var _air_freeze_until := 0.0
var _frozen_vertical := 0.0
var _air_freeze_pending_restore := false

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
	# Conectando golpes en el aire: cae lento. Atacando en el aire sin conectar: cae MÁS fuerte.
	if World.now() < _air_stall_until:
		return t.air_stall_float_gravity
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

## Hang PROPIO de un move (no el air-hit-stall genérico): frena la caída en seco y sostiene al
## jugador `duration` segundos exactos, sin depender del contador de combo ni de air_stall_scale.
## No consume el doble salto: la ventana existe justamente para que el jugador lo gaste.
## Lo usa el Y cargado aéreo del Mazo, que al conectar lanza al enemigo y se queda flotando.
func hover(duration: float) -> void:
	if _body.is_on_floor():
		return
	# Frena la CAÍDA, nunca una subida. El hang de un move puede llegar con delay (la explosión
	# del sweet spot sale ~0.33s después del golpe): si para entonces el jugador ya gastó el
	# doble salto, poner la vertical en 0 se lo mataba a mitad de ascenso, y abrir la ventana de
	# gravedad baja sobre esa subida lo mandaba disparado. Subiendo por lo suyo, el hover no va.
	if _body.vertical_velocity > 0.0:
		return
	_air_stall_until = maxf(_air_stall_until, World.now() + duration)
	_body.vertical_velocity = 0.0
	_body.air_state = Player.AirState.AIRBORNE

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
	_air_stall_until = maxf(_air_stall_until, World.now() + duration)
	# Congela la caída (velocity negativa → 0) pero preserva una subida CHICA (ej. el hop del
	# primer spin de la rama espera): así el air-hit no mata el impulso vertical. El cap evita
	# amplificar un salto: sin él, un golpe justo tras un doble salto conservaba toda la velocidad
	# del salto y con la gravedad baja del stall el jugador salía disparado.
	_body.vertical_velocity = clampf(_body.vertical_velocity, 0.0, t.air_stall_max_rise)
	_body.air_state = Player.AirState.AIRBORNE

## Freeze de caida del Brazo al conectar en el aire (ver Gameplay/Brazo). Dos efectos distintos:
## - VERTICAL: guarda la velocidad de caida actual y la congela `duration` segundos (pausa);
##   consume_air_freeze la restaura COMPLETA al soltar. Si ya hay un freeze activo solo extiende la
##   ventana sin re-capturar (el vertical ya vale 0 durante el freeze).
## - HORIZONTAL: DECELERA el momentum (bump) por `horizontal_keep` (0-1) en el acto — cada golpe lo
##   baja mas (no es una pausa: es un freno que decrece). 1.0 = no frena, 0.0 = lo mata.
func register_arm_air_freeze(duration: float, horizontal_keep: float) -> void:
	if _body.is_on_floor():
		return
	_body.bump_velocity *= clampf(horizontal_keep, 0.0, 1.0)
	if duration <= 0.0:
		return
	if not is_air_frozen():
		_frozen_vertical = _body.vertical_velocity
	_air_freeze_until = maxf(_air_freeze_until, World.now() + duration)
	_air_freeze_pending_restore = true

func is_air_frozen() -> bool:
	return World.now() < _air_freeze_until

## Lo llama el glue cada frame: mientras dure el freeze devuelve true (el glue mantiene la caida
## en 0); al terminar, restaura una sola vez el momentum de caida previo y devuelve false.
func consume_air_freeze() -> bool:
	if is_air_frozen():
		return true
	if _air_freeze_pending_restore:
		_air_freeze_pending_restore = false
		_body.vertical_velocity = _frozen_vertical
	return false

func reset_air_stall() -> void:
	_air_stall_until = 0.0
	_aerial_attack_until = 0.0
	_stall_count = 0
	_air_freeze_until = 0.0
	_air_freeze_pending_restore = false

## Cancela el launcher (al dashear/bumpear/swing): apaga flotación y stall.
func cancel() -> void:
	is_launched = false
	_float_until = 0.0
	_fall_until = 0.0
	reset_air_stall()
