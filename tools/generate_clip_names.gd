extends SceneTree
## Genera `data/clip_names.txt`: la lista de animaciones que AttackClip ofrece como sugerencia en el
## inspector (ver AttackClip.CLIP_NAMES_PATH).
##
## Corre HEADLESS y a mano, nunca desde el editor:
##
##   & $GODOT --headless --path . --script res://tools/generate_clip_names.gd
##
## Por que no lo hace el propio AttackClip al vuelo: instanciar los .glb dentro de
## `_validate_property` reentra al escaneo del EditorFileSystem y cuelga el editor. El detalle esta
## en AttackClip.
##
## Regenerar al agregar un clip nuevo a la libreria del maniqui, o sea cuando cambien UAL2, o
## `UAL1_ANIMATIONS` / `CUSTOM_ANIMATIONS` en PlayerAnimationController.

## El maniqui de la escena del Player (player.tscn > Visual/UAL2_Standard) aporta la libreria base.
const UAL2_SCENE_PATH := "res://assets/animations/Universal Animation Library 2[Standard]/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb"
const OUTPUT_PATH := "res://data/clip_names.txt"

# COPIA DELIBERADA de PlayerAnimationController.UAL1_ANIMATIONS / CUSTOM_ANIMATIONS. Referenciar esa
# clase hacia compilar al Player entero, y `--script` corre SIN autoloads: reventaba con "Identifier
# not found: WorldManager". Si cambian alla, cambiar aca — desincronizarse solo cuesta una sugerencia
# de mas o de menos en el inspector, nunca comportamiento.
const UAL1_ANIMATIONS := [&"Idle", &"Walk", &"Sprint"]
const CUSTOM_ANIMATIONS := [&"Sword_Launcher"]

func _initialize() -> void:
	var names := PackedStringArray()
	# UAL2 entero: es la libreria que el AnimationPlayer del maniqui ya trae puesta.
	names.append_array(_animations_of(load(UAL2_SCENE_PATH) as PackedScene))
	# De UAL1 y de los .glb sueltos, SOLO lo que PlayerAnimationController copia de verdad en
	# runtime. Listar el glb entero ofreceria clips que no van a existir cuando el golpe salga: el
	# bug silencioso que este archivo viene a evitar.
	for animation_name in UAL1_ANIMATIONS:
		names.append(String(animation_name))
	for animation_name in CUSTOM_ANIMATIONS:
		names.append(String(animation_name))
	names.sort()

	var out := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if out == null:
		push_error("No se pudo escribir %s" % OUTPUT_PATH)
		quit(1)
		return
	out.store_line("# Generado por tools/generate_clip_names.gd. No editar a mano.")
	for clip_name in names:
		out.store_line(clip_name)
	out.close()
	print("clip_names.txt: %d clips" % names.size())
	quit()

## Instancia, lee y libera. `free` y no `queue_free`: el nodo esta fuera del arbol, nadie lo
## procesaria.
func _animations_of(scene: PackedScene) -> PackedStringArray:
	if scene == null:
		return PackedStringArray()
	var root := scene.instantiate()
	var player := _find_animation_player(root)
	var names := PackedStringArray() if player == null else player.get_animation_list()
	root.free()
	return names

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
