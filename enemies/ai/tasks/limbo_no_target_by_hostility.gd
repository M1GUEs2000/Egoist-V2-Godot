extends BTAction

func _tick(delta: float) -> int:
	if agent != null and agent.has_method("limbo_no_target_by_hostility") and agent.call("limbo_no_target_by_hostility", delta):
		return RUNNING
	return FAILURE
