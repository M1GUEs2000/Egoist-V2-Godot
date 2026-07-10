extends BTAction

func _tick(delta: float) -> int:
	if agent != null and agent.has_method("limbo_search_last_known") and agent.call("limbo_search_last_known", delta):
		return RUNNING
	return FAILURE
