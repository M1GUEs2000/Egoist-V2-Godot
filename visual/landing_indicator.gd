class_name LandingIndicator extends Node3D
## Circulo azul de aterrizaje bajo una fuente (jugador o, via `source`, el target del
## lock-on) cuando esta en el aire (ex LandingIndicator.cs). Raycast hacia abajo contra
## LAYER_WORLD: aparece en el punto del suelo, sigue su normal, y solo se muestra si la
## fuente esta por encima de `min_air_height`. Malla y material se generan por codigo
## (no hay .tres que tunear; los numeros son @export en este nodo).

@export var min_air_height := 0.5      ## altura minima sobre el suelo para mostrarlo (m)
@export var max_ray_distance := 60.0   ## alcance del raycast hacia abajo (m)
@export var radius := 0.6              ## radio exterior del anillo
@export var thickness := 0.12          ## grosor del anillo (exterior - interior)
@export var surface_offset := 0.03     ## separacion del suelo para evitar z-fighting
@export var color := Color(0.25, 0.6, 1.0, 0.85)  ## azul del circulo

## Si false, nunca se muestra aunque `source` este en el aire (lo controla, por ejemplo,
## LockOn: el ring del target solo debe verse mientras hay lock-on activo).
var enabled := true
## Nodo a seguir. Por defecto el padre (uso original: colgado del Player); LockOn lo
## reasigna cada frame al target actual para reusar este mismo componente.
var source: Node3D

var _ring: MeshInstance3D

func _ready() -> void:
	# Se posiciona en coordenadas globales propias: top_level corta la herencia del
	# transform del padre (necesario para seguir un target que no es el padre).
	top_level = true
	if source == null:
		# Cuelga del Player en la escena original. No usar el grupo "player" aca: el
		# _ready del hijo corre antes que el del padre, y el grupo todavia no existe.
		source = get_parent() as Node3D
	_build_ring()
	visible = false

func _build_ring() -> void:
	var mesh := TorusMesh.new()
	mesh.outer_radius = radius
	mesh.inner_radius = maxf(radius - thickness, 0.01)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = Color(color.r, color.g, color.b)
	mat.emission_energy_multiplier = 1.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring = MeshInstance3D.new()
	_ring.mesh = mesh
	_ring.material_override = mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)  # TorusMesh ya nace plano en XZ: no necesita rotacion

func _physics_process(_delta: float) -> void:
	if not enabled or source == null:
		visible = false
		return
	var space := get_world_3d().direct_space_state
	var from := source.global_position + Vector3.UP * 0.2
	var to := from + Vector3.DOWN * max_ray_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, World.LAYER_WORLD)
	query.exclude = [source.get_rid()] if source is CollisionObject3D else []
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		visible = false
		return
	var ground: Vector3 = hit.position
	if source.global_position.y - ground.y < min_air_height:
		visible = false
		return
	visible = true
	global_position = ground + (hit.normal as Vector3) * surface_offset
	_align_to_normal(hit.normal)

## Orienta el anillo para que quede tumbado sobre el suelo, siguiendo su inclinacion.
func _align_to_normal(normal: Vector3) -> void:
	var up := (normal as Vector3).normalized()
	if up.is_equal_approx(Vector3.UP):
		global_basis = Basis()
		return
	var axis := Vector3.UP.cross(up)
	if axis.length_squared() < 0.000001:
		global_basis = Basis()  # normal apuntando hacia abajo: raro, dejar plano
		return
	global_basis = Basis(axis.normalized(), Vector3.UP.angle_to(up))
