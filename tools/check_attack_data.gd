extends SceneTree
## Verificacion enfocada de los dos contratos de datos que se tocaron el 2026-07-30:
## AttackClip.speed_bonus (reemplaza a `duration` en segundos) y AttackMovementProfile.enemy_push
## (reemplaza al bool AttackStep.pushes).
##
## Carga los .tres REALES y valida lo que un typo o un guardado a destiempo rompen en silencio: un
## `speed_bonus = null` serializado, un clip que apunta a una animacion inexistente, o un paso que
## quedo sin empujon tras la migracion. No corre gameplay.
##
##   & $GODOT --headless --path . --script res://tools/check_attack_data.gd

## Tuning de los que se sacan las secuencias a revisar. Se leen del TUNING y no de una lista de
## rutas: una secuencia puede vivir en su propio .tres o guardada adentro del tuning (el inspector
## crea sub-recursos inline al armar una nueva), y una lista de archivos no ve las segundas. Lo que
## importa es lo que el arma va a correr, no donde quedo guardado.
const TUNINGS := [
	"res://data/sword_tuning.tres",
]
## Secuencias que todavia no cuelgan de ningun campo del tuning (ramas compartidas, WIP).
const EXTRA_SEQUENCES := [
	"res://data/sword_air_charged_y_knock.tres",
]
const CLIP_NAMES_PATH := "res://data/clip_names.txt"

var _failures: Array[String] = []
var _clips_seen := 0
var _steps_seen := 0
var _pushes_seen := 0
var _stuns_seen := 0

func _initialize() -> void:
	var known := _known_clip_names()
	for path in EXTRA_SEQUENCES:
		var sequence: Resource = load(path)
		if sequence == null:
			_fail("%s no carga" % path)
			continue
		_check_steps(path, sequence.get("steps"), known)
	for path in TUNINGS:
		_check_tuning(path, known)

	print("check_attack_data: %d pasos, %d clips, %d empujones, %d stuns propios" % [
		_steps_seen, _clips_seen, _pushes_seen, _stuns_seen])
	if _failures.is_empty():
		print("ATTACK DATA OK")
		quit()
		return
	for failure in _failures:
		printerr("  FAIL: %s" % failure)
	printerr("ATTACK DATA FAIL (%d)" % _failures.size())
	quit(1)

## Todo campo del tuning que sea un AttackSequence, sin nombrarlos uno por uno: un gesto migrado
## agrega su campo y entra solo al chequeo. Nombrarlos a mano garantizaba que el ultimo migrado se
## olvidara, que es justo cuando mas hace falta revisarlo.
func _check_tuning(path: String, known: PackedStringArray) -> void:
	var tuning: Resource = load(path)
	if tuning == null:
		_fail("%s no carga" % path)
		return
	var found := 0
	for property in tuning.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		var value: Variant = tuning.get(property.name)
		if value is AttackSequence:
			found += 1
			_check_steps("%s > %s" % [path, property.name], value.steps, known)
	if found == 0:
		_fail("%s no expone ninguna AttackSequence (campo renombrado?)" % path)

## Recorre el arbol completo: los pasos del tronco y, recursivamente, los de cada rama por espera.
## Sin la recursion la mitad de los combos de la Espada quedaria sin revisar — las ramas son las que
## llevan los empujones.
func _check_steps(path: String, steps: Variant, known: PackedStringArray) -> void:
	if steps == null:
		return
	for step in steps:
		if step == null:
			_fail("%s: un paso es null" % path)
			continue
		_steps_seen += 1
		_check_step(path, step, known)
		_check_steps(path, step.get("wait_steps"), known)

func _check_step(path: String, step: Variant, known: PackedStringArray) -> void:
	# El bool viejo: si sobrevive en algun .tres, ese golpe dejo de empujar sin avisar.
	if step.get("pushes") != null:
		_fail("%s: un paso todavia declara `pushes` (migrar a movement.enemy_push)" % path)

	var clip: Variant = step.get("clip")
	if clip != null:
		_clips_seen += 1
		_check_clip(path, clip, known)

	_check_step_stun(path, step)

	var movement: Variant = step.get("movement")
	if step.get("uses_vertical_hitbox"):
		if clip == null:
			_fail("%s: paso vertical sin AttackClip" % path)
		if movement == null:
			_fail("%s: paso vertical sin AttackMovementProfile" % path)
	if movement == null:
		return
	var push: Variant = movement.get("enemy_push")
	if push == null:
		return
	_pushes_seen += 1
	# Un `enemy_push_at` en 0 arma el empujon en el frame 0 del golpe, o sea antes de que el hitbox
	# haya tocado a nadie: el golpe se ve pero no empuja.
	if movement.enemy_push_at <= 0.0:
		_fail("%s: enemy_push con enemy_push_at en 0" % path)
	if push.distance <= 0.0:
		_fail("%s: enemy_push con distance en 0 (no empuja a ningun lado)" % path)

## La trampa del stun por paso: el Floater del Enemy solo sostiene a alguien con el poise QUEBRADO
## (EnemyBase.request_float). Un golpe con `poise_damage` en 0 no quiebra, asi que el enemigo no se
## puede colgar y el juggle aereo se cae en silencio — se ve el impacto y el cuerpo sigue de largo.
## Apagar el stun de un golpe aereo se hace con `airborne` en 0, nunca con `poise_damage`.
func _check_step_stun(path: String, step: Variant) -> void:
	var stun: Variant = step.get("stun")
	if stun == null:
		return
	_stuns_seen += 1
	if stun.poise_damage <= 0.0:
		var moves_enemy := false
		var movement: Variant = step.get("movement")
		if movement != null:
			moves_enemy = movement.enemy_travel != null
		if moves_enemy:
			_fail("%s: stun con poise_damage 0 en un paso que cuelga o mueve al enemigo (sin quiebre, el Floater no lo sostiene)" % path)
	if stun.grounded < 0.0 or stun.airborne < 0.0:
		_fail("%s: stun con duracion negativa" % path)

func _check_clip(path: String, clip: Variant, known: PackedStringArray) -> void:
	# `speed_bonus = null` es lo que Godot serializo al guardar un .tres mientras el script cambiaba
	# de campo. Al cargarlo, scaled_duration opera sobre null y el golpe entero se cae.
	var bonus: Variant = clip.get("speed_bonus")
	if typeof(bonus) != TYPE_FLOAT:
		_fail("%s: speed_bonus no es float (%s) en el clip '%s'" % [
			path, type_string(typeof(bonus)), clip.clip])
	elif bonus <= -100.0:
		_fail("%s: speed_bonus %f en '%s' congela el golpe" % [path, bonus, clip.clip])
	else:
		# El contrato: 0 = la base tal cual, 100 = la mitad de tiempo.
		var scaled: float = clip.scaled_duration(1.0)
		var expected: float = 1.0 / (1.0 + bonus / 100.0)
		if not is_equal_approx(scaled, expected):
			_fail("%s: scaled_duration(1.0) dio %f y se esperaba %f" % [path, scaled, expected])

	if clip.clip == &"":
		_fail("%s: un AttackClip no declara animacion" % path)
	elif not known.is_empty() and not known.has(String(clip.clip)):
		_fail("%s: el clip '%s' no existe en la libreria del maniqui" % [path, clip.clip])

## La misma lista que el desplegable del inspector. Vacia = no se valida contra ella (el archivo se
## genera con tools/generate_clip_names.gd y su ausencia no es un error de datos).
func _known_clip_names() -> PackedStringArray:
	var names := PackedStringArray()
	if not FileAccess.file_exists(CLIP_NAMES_PATH):
		return names
	for line in FileAccess.get_file_as_string(CLIP_NAMES_PATH).split("\n", false):
		var clip_name := line.strip_edges()
		if clip_name != "" and not clip_name.begins_with("#"):
			names.append(clip_name)
	return names

func _fail(message: String) -> void:
	_failures.append(message)
