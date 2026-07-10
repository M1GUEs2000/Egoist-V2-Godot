extends BTAction

func _tick(_delta: float) -> int:
	if agent != null and agent.has_method("limbo_keep_attack_state") and agent.call("limbo_keep_attack_state"):
		return SUCCESS
	return FAILURE
