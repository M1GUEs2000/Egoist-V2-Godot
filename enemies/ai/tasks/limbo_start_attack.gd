extends BTAction

func _tick(_delta: float) -> int:
	if agent != null and agent.has_method("limbo_start_attack") and agent.call("limbo_start_attack"):
		return SUCCESS
	return FAILURE
