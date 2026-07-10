extends BTAction

func _tick(delta: float) -> int:
	if agent != null and agent.has_method("limbo_flee_from_target") and agent.call("limbo_flee_from_target", delta):
		return RUNNING
	return FAILURE
