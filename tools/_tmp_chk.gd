extends SceneTree
func _initialize() -> void:
	var t: Resource = load("res://data/sword_tuning.tres")
	for f in ["tap_forward_y_ground_sequence", "tap_forward_y_air_sequence", "tap_back_y_air_sequence"]:
		var s: Variant = t.get(f)
		print("CHK ", f, " = ", "NULL" if s == null else str(s.steps.size()) + " pasos")
	var air: Variant = t.tap_forward_y_air_sequence
	print("CHK push=", air.steps[0].movement.enemy_push, " at=", air.steps[0].movement.enemy_push_at)
	var back: Variant = t.tap_back_x_air_sequence
	print("CHK perfil tiene rt_animation_speed_bonus? ", back.steps[0].movement.get("rt_animation_speed_bonus"))
	print("CHK paso tiene rt_animation_speed_bonus? ", back.steps[0].rt_animation_speed_bonus)
	quit()
