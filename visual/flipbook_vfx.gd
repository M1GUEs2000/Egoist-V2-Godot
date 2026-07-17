@tool
class_name FlipbookVFX extends Node3D
## Reproductor de flipbook (spritesheet en grilla) sobre un quad billboard. Expone el MISMO
## contrato que los VFX Binbun (play()/stop()/one_shot/finished), asi que se enchufa en cualquier
## lugar que ya los use — ej. PlayerArm.vfx_scene (aura del brazo + impacto). Todo tuneable:
## textura, grilla, fps, tinte (color), brillo y escala (por el Node3D).
##
## Uso: seteá `texture` con un PNG de Brackeys y `columns`/`rows` según su nombre
## (ej. explosion_6x5 -> columns 6, rows 5). Para probar en el editor: botón Play del inspector.

signal finished
signal stopped

## Spritesheet a reproducir.
@export var texture: Texture2D:
	set(v):
		texture = v
		_apply_material()
## Columnas de la grilla del sheet (ej. explosion_6x5 -> 6).
@export_range(1, 32) var columns := 6:
	set(v):
		columns = maxi(1, v)
		_apply_material()
## Filas de la grilla (ej. explosion_6x5 -> 5).
@export_range(1, 32) var rows := 5:
	set(v):
		rows = maxi(1, v)
		_apply_material()
## Cuadros por segundo de la animación. Más alto = más rápido.
@export var fps := 30.0
## true = corre una vez y emite `finished` (impacto); false = loopea para siempre (aura).
@export var one_shot := true
## Reproduce solo al entrar al árbol. Útil para previsualizar en el editor.
@export var autoplay := false

@export_group("Look")
## Tinte multiplicado sobre el efecto. Blanco = color original del PNG.
@export var tint_color := Color.WHITE:
	set(v):
		tint_color = v
		_apply_look()
## Brillo/glow. 1 = original; >1 empuja el bloom.
@export var brightness := 1.0:
	set(v):
		brightness = v
		_apply_look()

@export_tool_button("Play") var _play_button := func(): play()
@export_tool_button("Stop") var _stop_button := func(): stop()

@onready var _quad: MeshInstance3D = $Quad

var _mat: ShaderMaterial
var _time := 0.0
var _playing := false

func _ready() -> void:
	_apply_material()
	_apply_look()
	if autoplay:
		play()

func _grab_material() -> void:
	if _mat != null:
		return
	if _quad == null:
		_quad = get_node_or_null("Quad") as MeshInstance3D
	if _quad != null and _quad.material_override is ShaderMaterial:
		_mat = _quad.material_override as ShaderMaterial

func _apply_material() -> void:
	_grab_material()
	if _mat == null:
		return
	_mat.set_shader_parameter("flipbook", texture)
	_mat.set_shader_parameter("columns", columns)
	_mat.set_shader_parameter("rows", rows)

func _apply_look() -> void:
	_grab_material()
	if _mat == null:
		return
	_mat.set_shader_parameter("tint_color", tint_color)
	_mat.set_shader_parameter("brightness", brightness)

func play() -> void:
	_grab_material()
	_time = 0.0
	_playing = true
	_set_frame(0)

func stop() -> void:
	_playing = false
	stopped.emit()

func _process(delta: float) -> void:
	if not _playing or fps <= 0.0:
		return
	_time += delta
	var total := columns * rows
	var f := int(_time * fps)
	if f >= total:
		if one_shot:
			_playing = false
			_set_frame(total - 1)
			finished.emit()
			return
		_time = fmod(_time, float(total) / fps)
		f = int(_time * fps)
	_set_frame(f)

func _set_frame(f: int) -> void:
	_grab_material()
	if _mat != null:
		_mat.set_shader_parameter("frame", f)
