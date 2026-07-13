class_name RiftSpawner extends Node
## Modulo componible: al recibir el PRIMER golpe arranca un timer, y al cumplirse el dueño se va
## al otro mundo dejando una GRIETA (WorldRift) atras. Cruzar esa grieta es lo unico que voltea el
## mundo de todos — irse no cambia el mundo de nadie, solo abre la puerta.
##
## El timer arranca UNA sola vez: los golpes siguientes no lo reinician ni lo adelantan. Pegarle
## mas rapido no acelera la huida; la ventana es la misma desde que lo tocaste.
##
## Eje ortogonal a WorldSwitchTrigger (que voltea el mundo directo, ON_HIT/ON_DEATH). Aca el
## cambio de mundo no lo decide el dueño: lo decide el jugador, cruzando o no la grieta.
##
## Depende de dos hermanos: Hurtbox (de donde escucha el golpe) y WorldMembership (la afiliacion
## que voltea). Sin ellos no hace nada — no los exige, como el resto de modulos del proyecto.

## Se fue al otro mundo y dejo la grieta.
signal shifted(rift: WorldRift)

## Segundos entre el primer golpe recibido y la huida. Es la ventana para matarlo antes de que
## se vaya: corto = casi no se lo puede retener, largo = la grieta es un premio dificil.
@export var delay := 3.0
## Tuning de la grieta que deja. Sin esto la grieta usa sus defaults.
@export var rift_tuning: WorldRiftTuning

var _armed := false
var _shifted := false

@onready var _membership: WorldMembership = World.find_sibling(self, WorldMembership) as WorldMembership

func _ready() -> void:
	var hurtbox := World.find_sibling(self, Hurtbox) as Hurtbox
	if hurtbox != null:
		hurtbox.hit.connect(_on_hit)

## Ya lo golpearon y el reloj corre (o ya se fue).
func is_armed() -> bool:
	return _armed

func has_shifted() -> bool:
	return _shifted

func _on_hit(_from: Node, _damage: float) -> void:
	if _armed:
		return  # el reloj ya corre: los golpes siguientes no lo reinician
	_armed = true
	_shift_routine()

func _shift_routine() -> void:
	await get_tree().create_timer(delay).timeout
	if _shifted or not is_instance_valid(self):
		return
	shift_now()

## Se va al otro mundo y deja la grieta. Publico a proposito: cualquier cosa puede forzar la huida
## sin esperar al timer (un ataque especial, un scripted event) sin tener que replicar esto.
func shift_now() -> void:
	if _shifted:
		return
	_shifted = true
	var owner_3d := get_parent() as Node3D
	# Volteando su afiliacion el dueño queda inactivo en este mundo: intangible, cascara y humo.
	# Todo eso ya lo resuelve WorldMembership — aca solo se cambia de lado.
	if _membership != null:
		_membership.affiliation = World.opposite_world(_membership.affiliation)
		_membership.refresh()
	if owner_3d == null:
		return
	# La grieta cuelga de la escena, no del dueño: tiene que quedarse donde el cuerpo cruzo aunque
	# el dueño despues se mueva o muera.
	var rift := WorldRift.spawn(owner_3d.global_position, get_tree().current_scene, rift_tuning)
	if rift != null:
		shifted.emit(rift)
