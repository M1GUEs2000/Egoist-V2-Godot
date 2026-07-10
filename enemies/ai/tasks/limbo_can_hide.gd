extends BTCondition

func _tick(_delta: float) -> int:
	if agent != null and agent.has_method("limbo_can_hide") and agent.call("limbo_can_hide"):
		return SUCCESS
	return FAILURE
