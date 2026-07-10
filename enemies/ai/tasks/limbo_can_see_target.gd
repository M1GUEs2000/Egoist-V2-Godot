extends BTCondition

func _tick(_delta: float) -> int:
	if agent != null and agent.has_method("limbo_can_see_target") and agent.call("limbo_can_see_target"):
		return SUCCESS
	return FAILURE
