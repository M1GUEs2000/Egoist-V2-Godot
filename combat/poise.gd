class_name Poise extends RefCounted
## Medidor de stagger: la reserva que hay que romper para stunear a alguien. Reemplaza al viejo
## umbral instantaneo (power >= threshold), que decidia el stun golpe a golpe y sin memoria.
##
## Cada golpe suma su poise_damage (StunSettings) a un acumulado que DECAE solo: presion
## sostenida quiebra, golpes espaciados no. Cuando el acumulado alcanza la reserva efectiva,
## el dueño se quiebra (entra en stun) y su reserva baja un escalon de break_levels — castigar
## sin pausa es cada vez mas facil, y en el ultimo escalon (0.0) queda siempre stuneable.
## Sin recibir golpes por recovery_time, vuelve al 100% en silencio (el jugador no lo ve).
##
## La armadura NO es un umbral aparte: suma armor_bonus a la reserva. Al romperse, el bonus
## deja de sumar solo — no hay que avisarle nada a este objeto.
##
## No es un Node: no necesita el arbol ni _process. El decaimiento y la recuperacion se
## calculan al vuelo contra World.now(), asi que solo hay trabajo cuando alguien pega o consulta.

## Reserva base a romper, en puntos de poise.
var poise_max := 6.0
## Puntos extra de reserva mientras el dueño este armado. Se pierden al romperse la armadura.
var armor_bonus := 6.0
## Drenaje lineal del acumulado, en puntos por segundo.
var decay_per_second := 1.5
## Escalera de degradacion: multiplicadores de la reserva tras cada quiebre. El primero es el
## estado intacto. 0.0 = reserva nula, cualquier golpe stunea. Un solo elemento [1.0] = nunca
## degrada (el player).
var break_levels: Array[float] = [1.0, 0.8, 0.6, 0.4, 0.2, 0.0]
## Segundos sin recibir poise tras los que la reserva vuelve al 100% (primer escalon).
var recovery_time := 20.0

var _accumulated := 0.0
var _break_index := 0
# Dos relojes distintos a proposito: el decaimiento drena desde la ULTIMA puesta al dia (si no,
# consultar el estado entre golpes drenaria dos veces el mismo tramo), y la recuperacion mide
# desde el ultimo GOLPE (es el "hace 20s que nadie lo toca").
var _last_hit_time := -999.0
var _last_settle_time := 0.0

## Reserva que hay que superar AHORA: base (+ armadura) escalada por los quiebres ya sufridos.
func effective_max(armored: bool) -> float:
	var base := poise_max + (armor_bonus if armored else 0.0)
	return maxf(0.0, base * _current_level())

## Suma el poise de un golpe. Devuelve true si lo quebro: ahi el dueño entra en stun.
func take_poise_damage(amount: float, armored := false) -> bool:
	if amount <= 0.0:
		return false  # un golpe sin poise nunca stunea, ni con la reserva en cero
	var now := World.now()
	_settle(now)
	_last_hit_time = now
	_accumulated += amount
	if _accumulated < effective_max(armored):
		return false
	_break()
	return true

## Consulta si un golpe de este poise QUEBRARIA la reserva, sin consumirlo. La necesitan los
## desplazamientos que se deciden ANTES de que el golpe cobre el poise (el launcher corre en
## about_to_hit, ver EnemyBase.launch): si consumieran aca, el golpe lo cobraria dos veces.
func would_break(amount: float, armored := false) -> bool:
	if amount <= 0.0:
		return false  # un golpe sin poise nunca stunea, ni con la reserva en cero
	_settle(World.now())
	return _accumulated + amount >= effective_max(armored)

## Cuanto lleva acumulado ahora mismo (ya decaido). Para el smoke y un futuro HUD de stagger.
func accumulated() -> float:
	_settle(World.now())
	return _accumulated

## En que escalon de degradacion esta: 0 = intacto.
func break_index() -> int:
	_settle(World.now())
	return _break_index

## Vuelve a cero absoluto (reserva intacta y acumulado limpio).
func reset() -> void:
	_accumulated = 0.0
	_break_index = 0
	_last_hit_time = -999.0
	_last_settle_time = World.now()

# Pone el estado al dia contra el reloj: recupera del todo si lleva recovery_time sin golpes, o
# drena lo que corresponda al tiempo transcurrido. Se llama al recibir y al consultar, nunca por frame.
func _settle(now: float) -> void:
	if now - _last_hit_time >= recovery_time:
		_accumulated = 0.0
		_break_index = 0
		_last_settle_time = now
		return
	var elapsed := now - _last_settle_time
	if elapsed > 0.0:
		_accumulated = maxf(0.0, _accumulated - decay_per_second * elapsed)
	_last_settle_time = now

func _break() -> void:
	_accumulated = 0.0
	_break_index = mini(_break_index + 1, maxi(0, break_levels.size() - 1))

func _current_level() -> float:
	if break_levels.is_empty():
		return 1.0
	return break_levels[clampi(_break_index, 0, break_levels.size() - 1)]
