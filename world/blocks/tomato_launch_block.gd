class_name TomatoLaunchBlock extends Node
## Bloque rojo de traversal: al golpearlo bumpea al player y restaura double jump/airdash.

@export var horizontal_speed := 10.0
@export var vertical_speed := 12.0

func _ready() -> void:
	var hurtbox := World.find_sibling(self, Hurtbox) as Hurtbox
	if hurtbox != null:
		hurtbox.hit.connect(_on_hit)

func _on_hit(from: Node, _damage: float) -> void:
	var player := from as Player
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	var dir := player.locomotion.last_move_dir
	if dir.length_squared() < 0.0001:
		dir = player.forward()
	player.bump(dir, horizontal_speed, vertical_speed)
	player.restore_double_jump()
	player.restore_airdash()
