extends BTCondition

func _tick(_delta: float) -> int:
	if agent != null and agent.has_method("limbo_is_attacking") and agent.call("limbo_is_attacking"):
		return SUCCESS
	return FAILURE
