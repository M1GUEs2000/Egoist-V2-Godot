class_name PlayerAirKillReset extends Node
## Reset de recursos (doble salto + airdash) al matar estando en el aire.
##
## El control de caida al cargar en el aire ya NO vive aca: es un Floater
## (ver Player.apply_air_charge_float). Este bloque solo devuelve recursos.

var _body: Player

func setup(body: Player) -> void:
	_body = body

func apply_air_kill_reset() -> void:
	if _body == null or not _body.is_airborne():
		return
	_body.restore_double_jump()
	_body.restore_airdash()
