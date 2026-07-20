class_name Mover extends Node
## Primitiva vertical universal #2 (ver obsidian/Plan Autoridad Vertical). Desplaza a su dueno por
## la trayectoria de un MoverSettings y, al terminar, puede pedirle un Floater al mismo cuerpo. Es
## hijo de Player y de EnemyBase (se instancia por codigo en su _ready); cada instancia solo mueve a
## SU dueno. La coordinacion de ambos cuerpos vive en el ataque, que emite una solicitud por cuerpo
## (no existe target=BOTH aca).
##
## El cuerpo lo maneja llamando tick(delta) en su bucle de fisica mientras is_moving() (mismo patron
## que el viejo launcher.tick_launch): el Mover fija velocity y hace move_and_slide, asi corta la
## gravedad normal durante el recorrido. Al terminar emite mover_finished(reason) y, si el settings
## pide Floater, lo detona en su propio cuerpo.

## Termino con exito: recorrio la distancia o encontro una condicion habilitada en `stop_on`.
signal mover_finished(reason: int)   # Mover.FinishReason
## Se aborto antes de terminar (stun, muerte, reemplazo, regla del ataque).
signal mover_cancelled(reason: int)  # Mover.CancelReason

## Por que termino el recorrido con exito. Se corresponde con los flags stop_on de MoverSettings.
enum FinishReason {
	DISTANCE,  # recorrio toda la `distance` (tope de seguridad)
	FLOOR,     # toco piso (stop_on FLOOR)
	WALL,      # choco pared (stop_on WALL)
	ENEMY,     # golpeo enemigo (stop_on ENEMY)
}

## Por que se aborto el recorrido antes de completarse.
enum CancelReason {
	STUN,        # el dueno entro en stun
	DEATH,       # el dueno murio
	SUPERSEDED,  # otro Mover del mismo cuerpo lo reemplazo
	ATTACK_RULE, # una regla del ataque lo corto
}

var _body: CharacterBody3D  # Player o EnemyBase.
var _floater: Floater       # Floater del mismo cuerpo, para el hang al terminar.
var _settings: MoverSettings
var _active := false
var _dir := Vector3.UP
var _speed := 0.0
var _traveled := 0.0

func setup(body: CharacterBody3D, floater: Floater) -> void:
	_body = body
	_floater = floater

## Arranca el recorrido descrito por `settings`. Un Mover nuevo reemplaza al anterior del mismo
## cuerpo (el que se va emite mover_cancelled(SUPERSEDED)).
func start_mover(settings: MoverSettings) -> void:
	if settings == null:
		return
	if _active:
		_active = false
		mover_cancelled.emit(CancelReason.SUPERSEDED)
	_settings = settings
	_dir = settings.direction.normalized() if settings.direction.length_squared() > 0.0001 else Vector3.UP
	_speed = settings.speed
	_traveled = 0.0
	_active = true

## Aborta el recorrido en curso con una CancelReason. No detona el Floater de `settings`.
func cancel_mover(reason: int) -> void:
	if not _active:
		return
	_active = false
	mover_cancelled.emit(reason)

func is_moving() -> bool:
	return _active

## Un frame de recorrido. Lo llama el cuerpo mientras is_moving(). Acelera (accel puede ser 0),
## avanza por `_dir` a la velocidad del frame (recortada para clavar la distancia exacta), y corta
## si cumplio la distancia o toco una condicion de `stop_on`. ENEMY todavia no se detecta (F4).
func tick(delta: float) -> void:
	if not _active or _body == null or delta <= 0.0:
		return
	_speed += _settings.acceleration * delta
	if _speed < 0.0:
		_speed = 0.0  # una desaceleracion frena, no invierte la marcha
	var remaining := _settings.distance - _traveled
	var frame_speed := _speed
	var will_reach := false
	if frame_speed * delta >= remaining:
		frame_speed = remaining / delta  # ultimo tramo: clava la distancia exacta este frame
		will_reach = true
	var before := _body.global_position
	_body.velocity = _dir * frame_speed
	_body.move_and_slide()
	_traveled += maxf(0.0, (_body.global_position - before).dot(_dir))
	if will_reach or _traveled >= _settings.distance:
		_finish(FinishReason.DISTANCE)
		return
	if (_settings.stop_on & MoverSettings.STOP_ON_FLOOR) and _body.is_on_floor():
		_finish(FinishReason.FLOOR)
		return
	if (_settings.stop_on & MoverSettings.STOP_ON_WALL) and _body.is_on_wall():
		_finish(FinishReason.WALL)

func _finish(reason: int) -> void:
	_active = false
	mover_finished.emit(reason)
	if _settings.float_duration > 0.0 and _floater != null:
		_floater.start_float(_settings.float_duration, _settings.float_fall_scale)
