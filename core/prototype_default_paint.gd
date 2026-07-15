class_name PrototypeDefaultPaint extends Node
## Componente hijo para piezas de Structures SIN WorldMembership (no tienen afiliacion de
## mundo). Pinta sus meshes con la textura verde del pack prototipo (ver [[Colores de mundo]]).
## Piezas CON WorldMembership no llevan esto: ese modulo ya pinta su propio color via
## `paint_prototype_material`.

func _ready() -> void:
	var target := get_parent() as Node3D
	if target == null:
		return
	var material := World.prototype_material(World.PROTOTYPE_TEXTURE_NONE)
	World.paint_all_surfaces(target, material)
