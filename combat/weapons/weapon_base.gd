class_name WeaponBase extends Node3D
## Arma abstracta (ex WeaponBase.cs). Estado propio: cargas, kills, nivel.
## Tap/hold por slot; el tuning numérico vive en un Resource en data/.

func tap() -> void:
	pass

func hold(_level: int) -> void:
	pass
