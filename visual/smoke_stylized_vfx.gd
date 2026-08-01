@tool
class_name SmokeStylizedVFX extends GPUParticles3D
## Humo estilizado hecho de nubes 3D (res://visual/sm_cloud.res) en vez de sprites billboard: cada
## particula es una malla con volumen propio, asi que el humo se lee igual desde cualquier angulo de
## la camara isometrica y no gira para mirarla.
##
## Mismo contrato que FlipbookVFX y ParticleBurstVFX (play()/stop(), one_shot y finished nativos,
## tint_color/brightness), asi que VfxInjector lo enchufa en cualquier vfx_scene existente sin
## codigo nuevo. El movimiento (amount, lifetime, velocidad, curvas de escala y alpha) se tunea
## directo en el inspector nativo del emisor: este script solo maneja el look del shader.
##
## Uso: instanciar donde haga falta, llamar play(). Con `autofree` se libera sola al terminar.

## true = se queue_free() sola al terminar (instancias creadas en runtime, no puestas en escena).
@export var autofree := false

@export_group("Look")
## true = bandas de luz duras contra el sol propio del shader, la nube se lee con volumen.
## false = color plano, solo silueta.
## Ver [[Direccion de Arte]]: el estilo final es 3D pixel art con su propio toon global, asi que el
## cell shading de aca es exploracion, no la respuesta definitiva.
@export var cell_shaded := true:
	set(v):
		cell_shaded = v
		_apply_look()
## Tinte multiplicado sobre el gradiente del emisor. Blanco = el gradiente tal cual.
@export var tint_color := Color.WHITE:
	set(v):
		tint_color = v
		_apply_look()
## Brillo/glow. 1 = original; >1 empuja el bloom del WorldEnvironment.
@export var brightness := 1.0:
	set(v):
		brightness = v
		_apply_look()

## Los botones del inspector invocan el Callable via el editor, no desde este script:
## el analizador estatico no lo ve como "uso" y marca falso positivo de var sin usar.
@warning_ignore("unused_private_class_variable")
@export_tool_button("Play") var _play_button := func(): play()
@warning_ignore("unused_private_class_variable")
@export_tool_button("Stop") var _stop_button := func(): stop()

var _shader_mat: ShaderMaterial

func _ready() -> void:
	if not Engine.is_editor_hint():
		# El material es un .tres compartido: sin esta copia, dos emisores con distinto tinte se
		# pisan el color entre ellos (y el ultimo en escribir gana). Se duplica solo en runtime
		# para no ensuciar la escena guardada, y el Shader en si se sigue compartiendo, asi que
		# esto no recompila nada: la copia es del material, no del programa.
		if material_override is ShaderMaterial:
			material_override = (material_override as ShaderMaterial).duplicate()
			# Los setters de los @export corren al instanciar, antes de _ready, asi que el cache
			# puede estar apuntando al material compartido. Se invalida o la copia no se usa.
			_shader_mat = null
	_apply_look()
	if autofree and not Engine.is_editor_hint():
		finished.connect(queue_free)

func play() -> void:
	restart()
	emitting = true

func stop() -> void:
	emitting = false

func _grab_material() -> void:
	if _shader_mat != null:
		return
	# El material del humo vive en el override del draw pass y no en el mesh: el mesh-nube es un
	# .res compartido, y pintarlo ahi le cambiaria el look a cualquier otro efecto que lo reuse.
	if material_override is ShaderMaterial:
		_shader_mat = material_override as ShaderMaterial

func _apply_look() -> void:
	_grab_material()
	if _shader_mat == null:
		return
	_shader_mat.set_shader_parameter("flat_shaded", not cell_shaded)
	_shader_mat.set_shader_parameter("tint", tint_color)
	_shader_mat.set_shader_parameter("brightness", brightness)
