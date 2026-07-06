class_name EnemyBase extends CharacterBody3D
## Identidad común de enemigo (ex EnemyBase.cs, sin contratos C#):
## compone como hijos Health + WorldMembership + Hurtbox. Armored con vida propia.

enum Hostility { PASSIVE, REACTIVE, AGGRESSIVE, ULTRA_AGGRESSIVE }

@export var hostility := Hostility.PASSIVE
@export var alert_radius := 8.0
@export var armored := false
