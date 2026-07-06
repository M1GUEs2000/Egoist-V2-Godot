class_name WorldMembership extends Node
## "¿En qué mundo vivo YO?" (ex WorldMembership.cs). Componer como nodo hijo.
## Absorbe las 4 subclases de enemigo por mundo de la v1.

signal changed(active: bool)

enum Mode { FIXED, BOTH, TIMED, FOLLOWS }

@export var mode := Mode.FIXED
@export var affiliation := World.Kind.LIVING
@export var hide_when_inactive := true
@export var shift_interval := 0.0  # solo Mode.TIMED

var is_active := true
