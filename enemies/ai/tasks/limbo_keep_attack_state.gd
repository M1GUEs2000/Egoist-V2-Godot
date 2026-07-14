extends BTAction

func _tick(delta: float) -> int:
	if agent != null and agent.has_method("limbo_keep_attack_state") and agent.call("limbo_keep_attack_state", delta):
		return SUCCESS
	return FAILURE
