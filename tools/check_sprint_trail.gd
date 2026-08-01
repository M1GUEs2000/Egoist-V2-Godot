extends SceneTree
## Check aislado de SprintTrail: verifica la misma geometria procedural usada por Player sin cargar
## los autoloads de gameplay. El cableado de player.tscn se mantiene simple: Bottom/Top + Trail.

const TUNING := preload("res://data/sprint_trail_tuning.tres")

var _failures: PackedStringArray = []

func _initialize() -> void:
	_run()

func _run() -> void:
	var owner := Node3D.new()
	var bottom := Marker3D.new()
	bottom.name = "Bottom"
	bottom.position = Vector3(0.0, 0.12, 0.0)
	owner.add_child(bottom)
	var top := Marker3D.new()
	top.name = "Top"
	top.position = Vector3(0.0, 1.7, 0.0)
	owner.add_child(top)
	var trail := SprintTrail.new()
	trail.name = "SprintTrail"
	trail.tuning = TUNING
	trail.base_marker = NodePath("../Bottom")
	trail.tip_marker = NodePath("../Top")
	owner.add_child(trail)
	root.add_child(owner)
	await process_frame
	_check_geometry(owner, trail)
	owner.free()
	for failure in _failures:
		printerr("CHECK sprint_trail=FAIL %s" % failure)
	if _failures.is_empty():
		print("CHECK sprint_trail=OK")
	quit(0 if _failures.is_empty() else 1)

func _check_geometry(owner: Node3D, trail: SprintTrail) -> void:
	trail.emit()
	for i in 3:
		owner.global_position.x += 0.2
		trail._process(0.016)
	var ribbon := trail.mesh as ImmediateMesh
	if ribbon == null or ribbon.get_surface_count() == 0:
		_fail("mover los markers verticales no genero una cinta.")
	trail.stop()
	trail._process(trail.tuning.lifetime + 0.1)
	if (trail.mesh as ImmediateMesh).get_surface_count() != 0:
		_fail("la cola no se limpio tras su lifetime.")

func _fail(message: String) -> void:
	_failures.append(message)
