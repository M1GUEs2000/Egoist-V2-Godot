extends Node
## Estado global del combo (ex ComboTracker.cs). Autoload: ComboTracker.
## Global por diseño: cualquier arma lee "vas N hits" para decidir su potencia
## (Hachas-Y se inyecta en el combo de cualquier otra arma).
# ponytail: combo window simple por tiempo; añadir cancel windows por animación en H1.

signal hit_registered(count: int)

const COMBO_WINDOW := 1.5  # segundos entre hits para mantener combo

var hit_count := 0

var _last_hit_time := -999.0

func _process(_delta: float) -> void:
	if hit_count > 0 and _now() - _last_hit_time > COMBO_WINDOW:
		reset_combo()

func register_hit() -> void:
	hit_count += 1
	_last_hit_time = _now()
	hit_registered.emit(hit_count)

func reset_combo() -> void:
	hit_count = 0

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
