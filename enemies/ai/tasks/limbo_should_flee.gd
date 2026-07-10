extends BTCondition

func _tick(_delta: float) -> int:
	if agent != null and agent.has_method("limbo_should_flee") and agent.call("limbo_should_flee"):
		return SUCCESS
	return FAILURE
