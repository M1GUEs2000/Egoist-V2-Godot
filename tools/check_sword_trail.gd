extends SceneTree
## Verificacion enfocada de la estela de la Espada (visual/sword_trail.gd).
##
## Lo que se rompe en silencio aca no es un numero de tuning sino el CABLEADO: los dos markers salen
## por NodePath, y un rename o un reparent en sword.tscn los deja sin resolver sin que nada falle —
## la estela simplemente no aparece, y eso se confunde con "hay que tunear el gradiente". Este check
## instancia la espada REAL y comprueba que la tira se genera de verdad.
##
##   & $GODOT --headless --path . --script res://tools/check_sword_trail.gd

const SWORD_SCENE := "res://combat/weapons/sword/sword.tscn"

var _failures: PackedStringArray = []

func _initialize() -> void:
	_run()

## Corrutina y no _initialize directo: add_child dentro de _initialize todavia no dispara el _ready
## del nodo, asi que sin esperar un frame el trail llegaria a las comprobaciones sin su ImmediateMesh
## ni sus markers resueltos, y el check estaria midiendo su propio arranque a medias.
func _run() -> void:
	var trail := _instantiate_trail()
	await process_frame
	if trail != null:
		_check_markers(trail)
		_check_geometry(trail)
		# La espada se instancio a mano, asi que se libera a mano. Los 2 ObjectDB leaks que igual
		# reporta el motor al salir NO son de aca: el check_attack_data que ya existia los reporta
		# iguales sin instanciar ninguna escena (vienen del helper del plugin MCP).
		trail.get_parent().free()

	if _failures.is_empty():
		print("CHECK sword_trail=OK")
	else:
		for failure in _failures:
			printerr("CHECK sword_trail=FAIL %s" % failure)
	quit(0 if _failures.is_empty() else 1)

func _instantiate_trail() -> SwordTrail:
	var packed := load(SWORD_SCENE) as PackedScene
	if packed == null:
		_fail("no se pudo cargar %s" % SWORD_SCENE)
		return null
	var sword := packed.instantiate()
	# El _ready del trail resuelve los markers, asi que la instancia tiene que entrar al arbol.
	root.add_child(sword)
	var trail := sword.get_node_or_null("Trail") as SwordTrail
	if trail == null:
		_fail("sword.tscn no tiene un nodo `Trail` con el script SwordTrail. " \
				+ "WeaponBase lo busca por ese nombre exacto y sin el no hay estela.")
		return null
	if trail.tuning == null:
		_fail("el nodo Trail no tiene SwordTrailTuning asignado.")
		return null
	return trail

## Los NodePath son el punto fragil: resuelven o no resuelven, y no resolver es silencioso.
func _check_markers(trail: SwordTrail) -> void:
	for path: NodePath in [trail.base_marker, trail.tip_marker]:
		if path.is_empty():
			_fail("el Trail tiene un marker sin asignar.")
		elif trail.get_node_or_null(path) as Node3D == null:
			_fail("el marker `%s` no resuelve a un Node3D desde el Trail." % path)

## La prueba real: mover la hoja y ver que salen vertices. Se mueve el Pivot a mano porque en
## headless no hay animacion — lo que se valida es el muestreo, no el clip.
func _check_geometry(trail: SwordTrail) -> void:
	var pivot := trail.get_node_or_null("../Hand/Pivot") as Node3D
	if pivot == null:
		_fail("no se encontro Hand/Pivot para simular el swing.")
		return

	trail.emit()
	# Tres muestras separadas de sobra: por encima de min_sample_distance y por debajo de
	# max_segment_length, o sea el caso normal de un swing.
	for i in 3:
		pivot.position.x += 0.2
		trail._process(0.016)
	var mesh := trail.mesh as ImmediateMesh
	if mesh == null or mesh.get_surface_count() == 0:
		_fail("tras tres muestras el ImmediateMesh sigue vacio: la estela no genera geometria.")

	# Un salto mayor a max_segment_length (el X cargado que atraviesa al enemigo) tiene que CORTAR la
	# estela, no tender una banda recta de varios metros.
	pivot.position.x += trail.tuning.max_segment_length + 1.0
	trail._process(0.016)
	if (trail.mesh as ImmediateMesh).get_surface_count() != 0:
		_fail("un salto mayor a max_segment_length no corto la estela.")

	# Apagada, la cola tiene que morir sola al pasar el lifetime en vez de quedar colgada para siempre.
	trail.stop()
	trail._process(trail.tuning.lifetime + 0.1)
	trail._process(0.016)
	if (trail.mesh as ImmediateMesh).get_surface_count() != 0:
		_fail("la cola no se desvanecio al pasar el lifetime con la estela apagada.")

func _fail(message: String) -> void:
	_failures.append(message)
