extends BTCondition

func _tick(_delta: float) -> int:
	if agent != null and agent.has_method("limbo_in_attack_range") and agent.call("limbo_in_attack_range"):
		return SUCCESS
	return FAILURE
