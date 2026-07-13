class_name EnemyLimboTreeBuilder extends RefCounted
## Construye por codigo el BehaviorTree equivalente al selector FSM actual.
##
## El recurso se arma en runtime para no depender de serializacion manual de .tres
## sin abrir Godot. Cuando se valide en editor, puede guardarse como .tres.

const TASK_PATH := "res://enemies/ai/tasks/%s"

static func build_combat_tree() -> Resource:
	if not ClassDB.class_exists("BehaviorTree"):
		return null
	var tree := ClassDB.instantiate("BehaviorTree") as Resource
	var root := _task("BTDynamicSelector")
	if tree == null or root == null:
		return null
	_add(root, _sequence([
		_script_task("limbo_is_attacking.gd"),
		_script_task("limbo_face_target.gd"),
		_script_task("limbo_keep_attack_state.gd"),
	]))
	_add(root, _sequence([
		_script_task("limbo_should_flee.gd"),
		_selector([
			_sequence([
				_script_task("limbo_can_hide.gd"),
				_script_task("limbo_stop_moving.gd"),
			]),
			_script_task("limbo_flee_from_target.gd"),
		]),
	]))
	_add(root, _script_task("limbo_evade_window.gd"))
	_add(root, _sequence([
		_script_task("limbo_has_no_target.gd"),
		_script_task("limbo_no_target_by_hostility.gd"),
	]))
	_add(root, _sequence([
		_script_task("limbo_is_alerted.gd"),
		_script_task("limbo_face_target.gd"),
	]))
	_add(root, _sequence([
		_script_task("limbo_can_see_target.gd"),
		_selector([
			_sequence([
				_script_task("limbo_in_attack_range.gd"),
				_script_task("limbo_engage_target.gd"),
			]),
			_script_task("limbo_chase_target.gd"),
		]),
	]))
	_add(root, _sequence([
		_script_task("limbo_is_searching.gd"),
		_script_task("limbo_search_last_known.gd"),
	]))
	_add(root, _script_task("limbo_no_target_by_hostility.gd"))
	tree.call("set_root_task", root)
	return tree

static func _selector(children: Array) -> Object:
	var node := _task("BTDynamicSelector")
	for child in children:
		_add(node, child)
	return node

static func _sequence(children: Array) -> Object:
	var node := _task("BTDynamicSequence")
	for child in children:
		_add(node, child)
	return node

static func _task(class_name_value: String) -> Object:
	if not ClassDB.class_exists(class_name_value):
		return null
	return ClassDB.instantiate(class_name_value)

static func _script_task(file_name: String) -> Object:
	var script := load(TASK_PATH % file_name) as Script
	if script == null:
		return null
	return script.new()

static func _add(parent: Object, child: Object) -> void:
	if parent != null and child != null:
		parent.call("add_child", child)
