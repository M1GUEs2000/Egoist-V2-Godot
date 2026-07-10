class_name PlayerAirKillReset extends Node
## Reset de recursos al matar en el aire y control de caida al empezar una carga aerea.
##
## No sostiene al player en hover: solo reduce la velocidad vertical negativa. La secuencia
## se resetea al tocar suelo o al matar estando en el aire.

var _body: Player
var _air_charge_fall_uses := 0

func setup(body: Player) -> void:
	_body = body

func apply_air_charge_fall_control() -> void:
	if _body == null or _body.is_on_floor() or _body.vertical_velocity >= 0.0:
		return
	var reduction := _fall_reduction_for_use(_air_charge_fall_uses)
	_body.vertical_velocity *= 1.0 - reduction
	_body.air_state = Player.AirState.AIRBORNE
	_air_charge_fall_uses += 1

func reset_air_charge_fall_control() -> void:
	_air_charge_fall_uses = 0

func apply_air_kill_reset() -> void:
	if _body == null or not _body.is_airborne():
		return
	_body.restore_double_jump()
	_body.restore_airdash()
	reset_air_charge_fall_control()

func _fall_reduction_for_use(use_index: int) -> float:
	var steps := _body.tuning.air_charge_fall_reduction_steps
	if steps.is_empty():
		return 0.0
	var index := mini(use_index, steps.size() - 1)
	return clampf(steps[index], 0.0, 1.0)
