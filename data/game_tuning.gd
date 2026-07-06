class_name GameTuning extends Resource
## Tuning global que no pertenece a un arma ni al jugador (regla v2: todo valor
## tuneable vive en un .tres). Instancia editable: data/game_tuning.tres.

@export_group("Combo global")
## Segundos entre hits para mantener el combo (ComboTracker).
@export var combo_window := 1.5
