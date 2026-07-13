class_name WorldRift extends Area3D
## La GRIETA: una puerta temporal al otro mundo. Se abre donde algo cruzo, y cruzarla voltea el
## mundo de TODOS (WorldManager.switch_world, con la onda del scan naciendo en la grieta misma).
##
## Es de UN SOLO USO: apenas alguien la cruza se cierra, aunque le quedara ventana. Si nadie la
## cruza antes de `tuning.lifetime`, se cierra sola y NO cambia nada — la oportunidad se perdio.
##
## No pertenece a ningun sistema en particular: se abre llamando a `WorldRift.spawn()`, asi que
## cualquier cosa puede dejar una (el enemigo del RiftSpawner es el primer detonante, pero un
## bloque, un pickup o un trigger de nivel pueden abrirla igual). Es el eje "quien la abre",
## separado del eje "que hace" — mismo espiritu que WorldSwitchTrigger.
##
## Su color es el del mundo DESTINO (el opuesto al actual), igual que los bloques de world switch:
## la grieta anuncia adonde manda. Si el mundo cambia mientras sigue abierta, se repinta.

## Se cerro. `crossed` = true si fue porque alguien la cruzo, false si se vencio sola.
signal closed(crossed: bool)

const SCENE_PATH := "res://world/rifts/world_rift.tscn"

@export var tuning: WorldRiftTuning

var _consumed := false
var _opened_at := 0.0
var _material: StandardMaterial3D

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _light: OmniLight3D = $Light
@onready var _shape: CollisionShape3D = $CollisionShape3D

## Unico punto de entrada: abre una grieta en `position`. `parent` es quien la sostiene en la
## escena (normalmente `get_tree().current_scene`, igual criterio que RangedAttack._fire); nunca
## el que la abrio, porque la grieta tiene que quedarse donde nacio aunque su dueño se mueva o muera.
static func spawn(position: Vector3, parent: Node, tuning: WorldRiftTuning = null) -> WorldRift:
	if parent == null:
		return null
	var scene := load(SCENE_PATH) as PackedScene
	var rift := scene.instantiate() as WorldRift
	rift.tuning = tuning
	parent.add_child(rift)
	rift.global_position = position
	return rift

func _ready() -> void:
	if tuning == null:
		tuning = WorldRiftTuning.new()
	collision_layer = 0
	collision_mask = World.LAYER_PLAYER  # solo el jugador la cruza; los enemigos la ignoran
	monitoring = true
	monitorable = false
	var sphere := _shape.shape as SphereShape3D
	if sphere != null:
		sphere.radius = tuning.trigger_radius
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.emission_enabled = true
	_mesh.set_surface_override_material(0, _material)
	_light.omni_range = tuning.light_range
	_light.shadow_enabled = false
	_opened_at = World.now()
	body_entered.connect(_on_body_entered)
	WorldManager.world_changed.connect(_on_world_changed)
	_repaint()
	_expire_routine()

## Cuanto le queda abierta, en segundos. 0 = vencida.
func time_left() -> float:
	return maxf(tuning.lifetime - (World.now() - _opened_at), 0.0)

func is_consumed() -> bool:
	return _consumed

func _process(_delta: float) -> void:
	if _consumed:
		return
	# Aviso de cierre: en los ultimos segundos la grieta parpadea. Fuera de esa ventana el brillo
	# es plano (no late): el parpadeo TIENE que significar "se cierra", no ser decoracion.
	var energy := tuning.glow_energy
	if tuning.warning_time > 0.0 and time_left() <= tuning.warning_time:
		var wave := 0.5 + 0.5 * sin(World.now() * tuning.warning_pulse_speed * TAU)
		energy = lerpf(tuning.glow_energy * 0.2, tuning.glow_energy, wave)
	_material.emission_energy_multiplier = energy
	_light.light_energy = tuning.light_energy * (energy / maxf(0.01, tuning.glow_energy))

func _on_body_entered(body: Node3D) -> void:
	if _consumed or body is not Player:
		return
	_consume()

## Cruzada: voltea el mundo y se cierra. La onda del scan nace en la grieta (no en el jugador):
## el mundo destino se revela desde la puerta hacia afuera.
func _consume() -> void:
	_consumed = true
	_close()
	WorldManager.switch_world(global_position)
	closed.emit(true)

func _expire_routine() -> void:
	await get_tree().create_timer(tuning.lifetime).timeout
	if _consumed or not is_instance_valid(self):
		return
	_consumed = true  # vencida: se cierra igual, pero sin tocar el mundo
	_close()
	closed.emit(false)

## El cierre visual es el mismo se haya cruzado o vencido: se encoge y se apaga. Lo unico que
## cambia entre los dos finales es si antes se llamo a switch_world.
func _close() -> void:
	set_process(false)
	# El cruce llega desde body_entered, o sea durante el flush de queries de fisica: ahi el motor
	# bloquea apagar la colision de un Area3D. set_deferred lo aplica al terminar el flush.
	set_deferred("monitoring", false)
	_shape.set_deferred("disabled", true)
	var close := create_tween().set_parallel(true)
	close.tween_property(_mesh, "scale", Vector3.ZERO, tuning.close_time)
	close.tween_property(_light, "light_energy", 0.0, tuning.close_time)
	close.chain().tween_callback(queue_free)

func _on_world_changed(_world: World.Kind) -> void:
	if not _consumed:
		_repaint()

## El color del mundo al que manda (el opuesto al actual), igual criterio que los bloques y el
## enemigo de world switch. Nunca se hardcodea en el .tscn: sale de World.
func _repaint() -> void:
	var destination := World.opposite_world(WorldManager.current)
	var color := World.world_color(destination)
	_material.albedo_color = color
	_material.emission = World.world_emission(destination)
	_light.light_color = color
