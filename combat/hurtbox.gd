class_name Hurtbox extends Area3D
## Lo que las armas golpean (reemplaza IHittable + GetComponentInParent).
## Va en grupo "hurtbox". Capacidades opcionales del dueño por has_method():
## launch/slam/push/slam_bounce (ex ILaunchable) · try_parry (ex IParryable).

signal hit(from: Node, damage: float)
