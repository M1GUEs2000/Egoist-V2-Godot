class_name VfxInjector
## Contrato compartido para inyectar un vfx_scene (FlipbookVFX, ParticleBurstVFX o Binbun) en
## cualquier sistema. Antes vivia duplicado en PlayerArm (aura + impacto); las armas lo
## reusan igual para el impacto del golpe (WeaponBase). Duck typing: cualquier efecto que
## exponga one_shot/play()/finished (nativos de FlipbookVFX y ParticleBurstVFX) enchufa.

## Instancia `scene` en `parent`, la ubica en `at` (si es Node3D), aplica tinte/escala y la
## arranca one-shot. Se auto-libera al terminar (`finished`) o a los 2s si el efecto no lo emite.
static func spawn_impact(scene: PackedScene, parent: Node, at: Vector3, scale := 1.0,
		tint := false, primary := Color.WHITE, secondary := Color.WHITE, emission := 1.0) -> void:
	if scene == null or parent == null:
		return
	var vfx := scene.instantiate()
	parent.add_child(vfx)
	if vfx is Node3D:
		var n := vfx as Node3D
		n.global_position = at
		n.scale = Vector3.ONE * scale
	apply_look(vfx, tint, primary, secondary, emission)
	play(vfx, false)
	if vfx.has_signal("finished"):
		vfx.connect("finished", vfx.queue_free, CONNECT_ONE_SHOT)
	else:
		parent.get_tree().create_timer(2.0).timeout.connect(vfx.queue_free)

## loop=true = permanente (aura); false = one-shot (impacto).
static func play(vfx: Node, loop: bool) -> void:
	if "one_shot" in vfx:
		vfx.set("one_shot", not loop)
	if vfx.has_method("play"):
		vfx.call("play")

## Pinta el VFX con colores propios (solo si tint esta activo y el efecto expone esas props).
static func apply_look(vfx: Node, tint: bool, primary: Color, secondary: Color,
		emission: float) -> void:
	if not tint:
		return
	# Efectos Binbun (fuego/portal): reemplazan color.
	if "primary_color" in vfx:
		vfx.set("primary_color", primary)
	if "secondary_color" in vfx:
		vfx.set("secondary_color", secondary)
	if "emission" in vfx:
		vfx.set("emission", emission)
	# Flipbooks/particulas Brackeys (FlipbookVFX, ParticleBurstVFX): tinte + brillo.
	if "tint_color" in vfx:
		vfx.set("tint_color", primary)
	if "brightness" in vfx:
		vfx.set("brightness", emission)
