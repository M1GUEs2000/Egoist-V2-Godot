class_name PurpleDashBlock extends Node
## Bloque morado de traversal: al golpearlo fuerza un dash inmediato hacia donde mira el player.

@export var dash_distance := 4.0
@export var dash_duration := 0.12
@export var boost_existing_bump_momentum := false
@export var hit_cooldown := 0.1

var _last_hit_time := -999.0

func _ready() -> void:
	var hurtbox := World.find_sibling(self, Hurtbox) as Hurtbox
	if hurtbox != null:
		hurtbox.hit.connect(_on_hit)

func _on_hit(from: Node, _damage: float) -> void:
	if World.now() - _last_hit_time < hit_cooldown:
		return
	_last_hit_time = World.now()
	var player := from as Player
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if player != null:
		player.force_dash(player.forward(), dash_distance, dash_duration, boost_existing_bump_momentum)
