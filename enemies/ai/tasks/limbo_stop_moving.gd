extends BTAction

func _tick(delta: float) -> int:
	if agent != null and agent.has_method("limbo_stop_moving") and agent.call("limbo_stop_moving", delta):
		return SUCCESS
	return FAILURE
