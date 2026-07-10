class_name EnemyAIBlackboard extends RefCounted
## Estado compartido de IA del enemigo: percepcion escribe, decision emite intent,
## locomocion ejecuta.

enum IntentKind { NONE, MOVE_TO, FLEE_FROM, SEARCH_AT, HOLD, FACE }
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

func move_to(point: Vector3, profile := SpeedProfile.CHASE) -> void:
	set_intent(IntentKind.MOVE_TO, point, profile)

func roam() -> void:
	set_intent(IntentKind.MOVE_TO, navigation_home_position, SpeedProfile.ROAM)

func search_at(point: Vector3) -> void:
	set_intent(IntentKind.SEARCH_AT, point, SpeedProfile.SEARCH)

func flee_from(point: Vector3) -> void:
	set_intent(IntentKind.FLEE_FROM, point, SpeedProfile.FLEE)

func set_intent(kind: int, point: Vector3, profile: int) -> void:
	navigation_intent_kind = kind
	navigation_intent_point = point
	navigation_speed_profile = profile
