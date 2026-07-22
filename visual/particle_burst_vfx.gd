@tool
class_name ParticleBurstVFX extends GPUParticles3D
## Burst de particulas con un sprite suelto (carpeta assets_por_aprobar/VFX/.../particles/:
## slash, effect, magic, smoke...). Mismo contrato que FlipbookVFX (play()/stop(); one_shot y
## finished ya son nativos de GPUParticles3D), asi que se enchufa en cualquier vfx_scene
## existente (PlayerArm.tuning.vfx_scene, WeaponTuning.hit_vfx_scene). Amount, lifetime, spread,
## velocidad, gravedad y escala se tunean directo en el inspector nativo de GPUParticles3D y su
## ParticleProcessMaterial: este script solo pone el sprite y el tinte.
##
## Uso: instanciar donde haga falta (arma, hitbox, punto de impacto), setear `texture`, llamar
## play(). Con `autofree` en true se libera sola al terminar (instancias spawneadas al vuelo).

## true = se queue_free() sola al terminar el burst (instancias creadas en runtime, no en escena).
@export var autofree := false
## Sprite del bundle (ej. slash_01_a.png). Se pinta sobre el quad billboard del draw pass.
@export var texture: Texture2D:
	set(v):
		texture = v
		_apply_texture()

@export_group("Look")
## Tinte multiplicado sobre el sprite. Blanco = color original del PNG.
@export var tint_color := Color.WHITE:
	set(v):
		tint_color = v
		_apply_look()
## Brillo/glow. 1 = original; >1 activa emission y empuja el bloom.
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

var _draw_mat: StandardMaterial3D

func _ready() -> void:
	_grab_material()
	_apply_texture()
	_apply_look()
	if autofree:
		finished.connect(queue_free)

func play() -> void:
	restart()
	emitting = true

func stop() -> void:
	emitting = false

func _grab_material() -> void:
	if _draw_mat != null:
		return
	if draw_pass_1 is QuadMesh and (draw_pass_1 as QuadMesh).material is StandardMaterial3D:
		_draw_mat = (draw_pass_1 as QuadMesh).material as StandardMaterial3D

func _apply_texture() -> void:
	_grab_material()
	if _draw_mat != null:
		_draw_mat.albedo_texture = texture

func _apply_look() -> void:
	_grab_material()
	if _draw_mat == null:
		return
	_draw_mat.albedo_color = tint_color
	_draw_mat.emission_enabled = brightness > 1.0
	if _draw_mat.emission_enabled:
		_draw_mat.emission = tint_color
		_draw_mat.emission_energy_multiplier = brightness
