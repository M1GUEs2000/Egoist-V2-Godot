class_name SpikeWall extends StaticBody3D
## Pared de pinchos: al tocarla stunea, rebota perpendicularmente y restaura recursos aereos.
## La misma escena sirve para los dos mundos: `world` decide en cuál aparece y de qué color
## se pinta (tomate = vivo, morado = muerto — la convención vive en World.world_color).
## Se instancia una vez por mundo en test_scene; no hay dos .tscn.

## En qué mundo existe esta pared. Manda sobre el `affiliation` del WorldMembership hijo:
## se setea acá para que una instancia pueda cambiar de mundo con UNA línea en el .tscn
## (override de propiedad raíz), sin tener que hacer editable el nodo hijo.
@export var world := World.Kind.LIVING

@export var stun_duration := 0.45
@export var stun_power := 2.0
@export var push_horizontal_speed := 9.0
@export var push_vertical_speed := 5.5
@export var hit_cooldown := 0.35

## Cuánto más oscuros son los pinchos traseros respecto de los delanteros.
const BACK_SPIKE_DIM := 0.4
const STRIPE_EMISSION_ENERGY := 0.35

var _last_hit_time := -999.0

@onready var _trigger: Area3D = $Trigger
@onready var _membership: WorldMembership = $WorldMembership

func _ready() -> void:
	collision_layer = World.LAYER_WORLD
	collision_mask = 0
	_trigger.collision_layer = 0
	_trigger.collision_mask = World.LAYER_PLAYER
	_trigger.body_entered.connect(_on_body_entered)
	_paint_world_colors()
	if _membership != null:
		_membership.affiliation = world
		_membership.changed.connect(_on_membership_changed)
		_membership.refresh()  # el _ready del módulo ya corrió con la afiliación vieja

## Rayas y pinchos toman el color del mundo: la pared se lee de un vistazo como "esta es
## del mundo vivo/muerto". Los materiales se generan por código (los del .tscn son solo
## preview de editor) para que el color no quede duplicado en la escena.
func _paint_world_colors() -> void:
	var base := World.world_color(world)
	_apply_material(_stripe_material(base), "Stripe*")
	_apply_material(_flat_material(base), "SpikeFront*")
	_apply_material(_flat_material(base * BACK_SPIKE_DIM), "SpikeBack*")

func _apply_material(material: StandardMaterial3D, pattern: String) -> void:
	for mesh in find_children(pattern, "MeshInstance3D"):
		(mesh as MeshInstance3D).set_surface_override_material(0, material)

func _stripe_material(base: Color) -> StandardMaterial3D:
	var material := _flat_material(base)
	material.emission_enabled = true
	material.emission = World.world_emission(world)
	material.emission_energy_multiplier = STRIPE_EMISSION_ENERGY
	return material

func _flat_material(base: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(base.r, base.g, base.b, 1.0)
	return material

func _on_body_entered(body: Node3D) -> void:
	if _membership != null and not _membership.is_active:
		return
	var player := body as Player
	if player == null:
		return
	if World.now() - _last_hit_time < hit_cooldown:
		return
	_last_hit_time = World.now()

	var push_dir := _normal_away_from(player.global_position)
	if player.has_method("try_apply_stun"):
		player.try_apply_stun(
				stun_duration,
				stun_power,
				PlayerStun.Mode.PUSH,
				push_dir,
				push_horizontal_speed,
				push_vertical_speed)
	else:
		player.apply_stun(stun_duration, PlayerStun.Mode.PUSH, push_dir, push_horizontal_speed, push_vertical_speed)
	player.restore_double_jump()
	player.restore_airdash()

func _normal_away_from(world_position: Vector3) -> Vector3:
	var normal := global_basis.z.normalized()
	var to_player := world_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.0001:
		return normal
	return normal if normal.dot(to_player) >= 0.0 else -normal

func _on_membership_changed(active: bool) -> void:
	# WorldMembership puede refrescarse en medio de señales/flush de física (por ejemplo,
	# un hit que cambia de mundo). Godot bloquea cambiar Area3D.monitorable en ese punto.
	_trigger.set_deferred("monitoring", active)
	_trigger.set_deferred("monitorable", active)
	for shape in _trigger.find_children("*", "CollisionShape3D"):
		(shape as CollisionShape3D).set_deferred("disabled", not active)
