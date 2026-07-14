class_name EnemyAIBlackboard extends RefCounted
## Estado compartido de IA del enemigo: percepcion escribe, decision emite intent,
## locomocion ejecuta.

enum IntentKind { NONE, MOVE_TO, FLEE_FROM, SEARCH_AT, HOLD, FACE, STRAFE, BACKPEDAL, EVADE }
enum SpeedProfile { CHASE, ROAM, SEARCH, FLEE }

var perception_target: Node3D
var perception_can_see_target := false
var perception_last_known_position := Vector3.ZERO
var perception_is_alerted := false
var perception_is_searching := false

var navigation_intent_kind := IntentKind.NONE
var navigation_intent_point := Vector3.ZERO
var navigation_speed_profile := SpeedProfile.CHASE
var navigation_home_position := Vector3.ZERO
var navigation_stuck_timer := 0.0
var navigation_strafe_distance := 0.0
## Distancia a la que un MOVE_TO se da por llegado: el agente frena ahi en vez de caminar
## hasta el cuerpo del target. En 0 avanza hasta el punto exacto (roam, search).
var navigation_stop_distance := 0.0
## Velocidad del salto de esquive, en m/s. La decide la decision a partir de la distancia que
## quiere recorrer; la locomocion solo la ejecuta.
var navigation_evade_speed := 0.0

var combat_attacking := false
var combat_incoming_attack_until := -999.0

func sync_perception(perception: Perception) -> void:
	if perception == null:
		perception_target = null
		perception_can_see_target = false
		perception_is_alerted = false
		perception_is_searching = false
		return
	perception_target = perception.target
	perception_can_see_target = perception.can_see_target
	perception_last_known_position = perception.last_known_position
	perception_is_alerted = perception.is_alerted()
	perception_is_searching = perception.is_searching()

func clear_intent() -> void:
	set_intent(IntentKind.NONE, Vector3.ZERO, SpeedProfile.CHASE)

func hold() -> void:
	set_intent(IntentKind.HOLD, Vector3.ZERO, SpeedProfile.CHASE)

func face(point: Vector3) -> void:
	set_intent(IntentKind.FACE, point, SpeedProfile.CHASE)

func move_to(point: Vector3, profile := SpeedProfile.CHASE, stop_distance := 0.0) -> void:
	navigation_stop_distance = stop_distance
	set_intent(IntentKind.MOVE_TO, point, profile)

func roam() -> void:
	set_intent(IntentKind.MOVE_TO, navigation_home_position, SpeedProfile.ROAM)

func search_at(point: Vector3) -> void:
	set_intent(IntentKind.SEARCH_AT, point, SpeedProfile.SEARCH)

func flee_from(point: Vector3) -> void:
	set_intent(IntentKind.FLEE_FROM, point, SpeedProfile.FLEE)

## Rodea un punto (target en combate, atacante en EVADE) moviendose perpendicular a el.
## `keep_distance` > 0 corrige el radio hacia ese ring mientras orbita; en 0 mantiene
## la distancia que tenga (util para el esquive puro, que solo sale de la trayectoria).
func strafe_around(point: Vector3, keep_distance := 0.0) -> void:
	navigation_strafe_distance = keep_distance
	set_intent(IntentKind.STRAFE, point, SpeedProfile.CHASE)

## Esquive reactivo: salta alejandose de `point` (el origen del golpe entrante), sin dejar de
## mirarlo, a `speed` m/s. La velocidad viaja en el intent porque la decide la decision (sale de
## evade_distance / evade_duration del enemigo), no la locomocion. La forma del salto (recto o
## diagonal) es de GroundLocomotion: `evade_diagonal_bias`.
func evade_from(point: Vector3, speed: float) -> void:
	navigation_evade_speed = speed
	set_intent(IntentKind.EVADE, point, SpeedProfile.CHASE)

## Retrocede en linea recta alejandose de `point`, sin dejar de mirarlo, hasta `keep_distance`.
## Es como sale del combo: primero gana distancia de frente, y recien afuera orbita.
func backpedal_from(point: Vector3, keep_distance: float) -> void:
	navigation_strafe_distance = keep_distance
	set_intent(IntentKind.BACKPEDAL, point, SpeedProfile.CHASE)

func set_intent(kind: int, point: Vector3, profile: int) -> void:
	navigation_intent_kind = kind
	navigation_intent_point = point
	navigation_speed_profile = profile
