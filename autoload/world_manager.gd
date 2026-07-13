extends Node
## Dueño del mundo actual (ex WorldManager.cs). Autoload: WorldManager.
##
## El switch NO es instantáneo en el espacio: sale una onda (scan) desde el origen del trigger que
## lo disparó y se expande. Cada WorldMembership se voltea recién cuando la onda lo alcanza, así que
## las cosas del mundo destino van apareciendo al paso del frente. El visual de la onda lo dibuja
## WorldScan; los números los pone data/world_scan_tuning.tres.
##
## Sin origen (y sin player en escena) no hay onda: el switch es instantáneo, como antes. Eso es lo
## que deja al smoke test corriendo sin escena ni jugador.

signal world_changed(world: World.Kind)
## La onda arrancó. `world` es el mundo DESTINO (de él sale el color de la onda) y `origin` el punto
## global donde nace. Solo se emite si hay onda.
signal scan_started(world: World.Kind, origin: Vector3)

## Origen nulo: no hay onda, el switch cae de golpe en todo el mapa.
const NO_ORIGIN := Vector3.INF

var tuning: WorldScanTuning = preload("res://data/world_scan_tuning.tres")
var current := World.Kind.LIVING
## Cuántos switches van. Sirve de token: una membresía que está esperando a la onda lo compara al
## despertar y descarta su turno si mientras tanto el mundo volvió a cambiar.
var switch_count := 0

var _scan_origin := NO_ORIGIN
var _scan_start := 0.0

## `origin` = de dónde sale la onda, en espacio global. Lo pasa el trigger que causó el switch
## (bloque golpeado, enemigo al morir). Sin él, la onda nace en el jugador.
func switch_world(origin: Vector3 = NO_ORIGIN) -> void:
	current = World.opposite_world(current)
	switch_count += 1
	_scan_origin = _resolve_origin(origin)
	_scan_start = World.now()
	world_changed.emit(current)
	if _scan_origin != NO_ORIGIN:
		scan_started.emit(current, _scan_origin)

## Segundos que le faltan a la onda del switch en curso para llegar a `point`. 0 = ya pasó por ahí
## (o no hay onda): quien pregunte se voltea ya. Es lo que escalona la aparición de las cosas.
func scan_delay_for(point: Vector3) -> float:
	if _scan_origin == NO_ORIGIN or tuning.speed <= 0.0:
		return 0.0
	# El clamp a max_radius evita que una esquina lejanísima del mapa tarde una eternidad en
	# existir: pasado ese radio, todo lo que queda se voltea junto con el frente.
	var distance := minf(_scan_origin.distance_to(point), tuning.max_radius)
	var eta := distance / tuning.speed
	return maxf(eta - (World.now() - _scan_start), 0.0)

func _resolve_origin(origin: Vector3) -> Vector3:
	if origin != NO_ORIGIN:
		return origin
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return player.global_position if player != null else NO_ORIGIN
