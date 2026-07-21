class_name Hurtbox extends Area3D
## Los receptores verticales actuales exponen `request_mover` y `request_float`: el ataque entrega
## el perfil y el duenio lo ejecuta. Los verbos legacy de las notas siguientes son inventario F0.
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

## Enemigos true: conectarle un golpe en el aire ralentiza la caída del jugador (air-hit-stall).
@export var triggers_air_hit_stall := false

@onready var owner_node: Node = get_parent()

func _ready() -> void:
	add_to_group("hurtbox")
	collision_layer = World.LAYER_HURTBOX  # me detectan los Hitbox
	collision_mask = 0                     # yo no detecto a nadie
	monitoring = false
	if health == null:
		health = World.find_sibling(self, Health) as Health

func can_receive_hit() -> bool:
	if owner_node.has_method("can_receive_hit") and not owner_node.call("can_receive_hit"):
		return false
	return health == null or not health.is_dead()

## Punto de entrada único del daño. Devuelve true si el golpe mató al dueño.
func receive_hit(from: Node, damage: float, _hit_direction: Vector3, _stun: StunSettings) -> bool:
	if not can_receive_hit():
		return false
	var attacker := from as EnemyBase
	var target := owner_node as EnemyBase
	if attacker != null and target != null and not EnemyBase.can_damage_enemy(attacker, target):
		return false
	if owner_node.has_method("on_hurtbox_hit"):
		owner_node.call("on_hurtbox_hit", from, damage, _hit_direction, _stun)
	hit.emit(from, damage)
	if health != null:
		# El dueño puede multiplicar el daño entrante (ej: enemigo VULNERABLE tras un parry, ver
		# EnemyBase.incoming_damage_multiplier). Sin el método, x1 (sin cambio para el resto).
		var multiplier := 1.0
		if owner_node.has_method("incoming_damage_multiplier"):
			multiplier = owner_node.call("incoming_damage_multiplier")
		return health.take_damage(damage * multiplier)
	return false
