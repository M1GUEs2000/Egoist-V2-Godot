extends BTCondition

func _tick(_delta: float) -> int:
	if agent != null and agent.has_method("limbo_has_target") and not agent.call("limbo_has_target"):
		return SUCCESS
	return FAILURE
