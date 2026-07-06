class_name Hitbox extends Area3D
## Lo que golpea (unifica WeaponTraceHitbox / ConeLauncherHitbox / AirDiscHitbox de v1).
## Tonto a propósito: detecta Hurtboxes, deduplica por swing y entrega el golpe.
## Quién lo prende/apaga y qué pasa al conectar lo decide el dueño (arma/ataque) vía landed.

signal landed(hurtbox: Hurtbox, died: bool)

@export var damage := 1.0
@export var stun: StunSettings

## Quien ataca: su propia hurtbox se ignora (se setea al crear el arma/ataque).
var source: Node

var _already_hit: Array[Hurtbox] = []

func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)

## El dueño llama esto al iniciar un swing: limpia dedup y prende detección.
func begin_swing() -> void:
	_already_hit.clear()
	monitoring = true

func end_swing() -> void:
	monitoring = false

func _on_area_entered(area: Area3D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or hurtbox in _already_hit:
		return
	if source != null and hurtbox.owner_node == source:
		return
	_already_hit.append(hurtbox)
	var direction := (hurtbox.global_position - global_position).normalized()
	var died := hurtbox.receive_hit(source, damage, direction, stun)
	landed.emit(hurtbox, died)
