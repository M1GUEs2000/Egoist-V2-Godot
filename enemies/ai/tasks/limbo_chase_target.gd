extends BTAction

func _tick(delta: float) -> int:
	if agent != null and agent.has_method("limbo_chase_target") and agent.call("limbo_chase_target", delta):
		return RUNNING
	return FAILURE
