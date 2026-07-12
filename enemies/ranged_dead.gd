class_name RangedDead extends GroundedEnemy
## Variante Dead de rango: conserva el cuerpo/IA comun y equipa solo RangedAttack.

func _ready() -> void:
	super._ready()
	_attacks.clear()
	var ranged_attack := get_node_or_null("RangedAttack") as RangedAttack
	if ranged_attack != null:
		ranged_attack.setup(self)
		_attacks.append(ranged_attack)
