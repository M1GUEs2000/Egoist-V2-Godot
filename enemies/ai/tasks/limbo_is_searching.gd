extends BTCondition

func _tick(_delta: float) -> int:
	if agent != null and agent.has_method("limbo_is_searching") and agent.call("limbo_is_searching"):
		return SUCCESS
	return FAILURE
