class_name Hurtbox extends Area3D
## Lo que las armas golpean (reemplaza IHittable + GetComponentInParent de v1).
## Nodo hijo del dueño, en grupo "hurtbox". Rutea el daño al Health hermano y avisa
## de CADA golpe con la señal hit (ahí se enganchan reacciones tipo WorldSwitchTrigger,
## independientes de si el dueño muere — el eje "reacción" separado del eje "vida" de v1).
##
## Capacidades opcionales del dueño por has_method(): launch/slam/push/slam_bounce
## (ex ILaunchable) · try_parry (ex IParryable). Una pared nunca sale volando.

signal hit(from: Node, damage: float)

## Si null, se busca un Health hermano en _ready (puede no haber: indestructible puro).
@export var health: Health

@onready var owner_node := get_parent()

func _ready() -> void:
	add_to_group("hurtbox")
	if health == null:
		for sibling in owner_node.get_children():
			if sibling is Health:
				health = sibling
				break

func can_receive_hit() -> bool:
	return health == null or not health.is_dead()

## Punto de entrada único del daño. Devuelve true si el golpe mató al dueño.
func receive_hit(from: Node, damage: float, _hit_direction: Vector3, _stun: StunSettings) -> bool:
	if not can_receive_hit():
		return false
	hit.emit(from, damage)
	if health != null:
		return health.take_damage(damage)
	return false
