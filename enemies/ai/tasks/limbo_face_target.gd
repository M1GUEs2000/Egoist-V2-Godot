extends BTAction

func _tick(_delta: float) -> int:
	if agent != null and agent.has_method("limbo_face_target") and agent.call("limbo_face_target"):
		return SUCCESS
	return FAILURE
