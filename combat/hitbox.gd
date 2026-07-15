class_name Hitbox extends Area3D
## Lo que golpea (unifica WeaponTraceHitbox / ConeLauncherHitbox / AirDiscHitbox de v1).
## Tonto a propósito: detecta Hurtboxes, deduplica por swing y entrega el golpe.
## Quién lo prende/apaga y qué pasa al conectar lo decide el dueño (arma/ataque) vía landed.

signal landed(hurtbox: Hurtbox, died: bool)
## Se emite ANTES de aplicar el daño de un golpe que sí va a conectar (no parriado). El dueño
## engancha reacciones que deben ocurrir primero: p.ej. el launcher lanza al enemigo aquí, así
## receive_hit ya lo ve en el aire y usa el stun aéreo (ex ConeLauncherHitbox: lanza y luego TakeHit).
signal about_to_hit(hurtbox: Hurtbox)
## El dueño del hurtbox parrió este golpe (melee mid-swing): no hubo daño (ex gizmo cyan de v1).
signal parried(hurtbox: Hurtbox)

@export var damage := 1.0
@export var stun: StunSettings
## Si el objetivo puede parriar (has_method try_parry) se le da la chance antes del daño.
## El launcher lo apaga: en v1 el cono nunca preguntaba parry (ver ConeLauncherHitbox).
@export var can_be_parried := true

## Quien ataca: su propia hurtbox se ignora (se setea al crear el arma/ataque).
var source: Node

var _already_hit: Array[Hurtbox] = []

func _ready() -> void:
	monitoring = false
	monitorable = false
	collision_layer = 0
	collision_mask = World.LAYER_HURTBOX  # solo detecto hurtboxes
	area_entered.connect(_on_area_entered)

## Varios hitboxes de la misma arma (hoja + disco aéreo) comparten el dedup:
## un enemigo cuenta una sola vez por swing aunque lo toquen los dos.
func share_already_hit(shared: Array[Hurtbox]) -> void:
	_already_hit = shared

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
	var direction := (hurtbox.global_position - global_position).normalized()
	var target := hurtbox.owner_node
	var attacker_enemy := source as EnemyBase
	var target_enemy := target as EnemyBase
	if attacker_enemy != null and target_enemy != null \
			and not EnemyBase.can_damage_enemy(attacker_enemy, target_enemy):
		return
	_already_hit.append(hurtbox)
	# Parry: si el dueño puede parriar ESTE golpe ahora mismo (melee mid-swing en su ventana),
	# se auto-stunea y el golpe NO hace daño (ex WeaponTraceHitbox: TryParry antes de TakeHit).
	if can_be_parried and target != null and target.has_method("try_parry") \
			and target.call("try_parry", source, direction):
		parried.emit(hurtbox)
		return
	about_to_hit.emit(hurtbox)  # reacciones pre-daño (ej: el launcher lanza primero)
	var died := hurtbox.receive_hit(source, damage, direction, stun)
	landed.emit(hurtbox, died)
