extends BTAction

func _tick(delta: float) -> int:
	if agent != null and agent.has_method("limbo_evade_window") and agent.call("limbo_evade_window", delta):
		return RUNNING
	return FAILURE
