class_name AttackMovementProfile extends Resource
## Todo lo que UN gesto de ataque (gesto x tramo) le hace a la posicion de los cuerpos, con la
## variante RT expresada como PORCENTAJES sobre esa misma base en vez de como un perfil aparte.
## Agrupa en un solo campo del tuning lo que antes eran hasta cinco campos sueltos repartidos en
## tres subgrupos, MAS los ids de rutina que el arma guardaba para reconectarlos en runtime.
##
## Lo usan TODOS los ataques especiales de la Espada: los cuatro taps direccionales de X, los taps
## de Y y los cargados de Y. La excepcion es el X cargado, que no mueve al Player con un Mover sino
## con `force_dash` (i-frames, hitbox propio, reposicionamiento al atravesar): darle un slot seria
## un campo que miente. Los combos normales tampoco entran: su coreografia es de varias fases y el
## Mover sale en un beat concreto de la cadena, que es codigo, no tuning.
##
## Respeta las reglas de obsidian/Mover y Floater: un slot por cuerpo (un Mover o un Floater solo
## controla a su dueno) y el ataque es dueno de la intencion mientras el cuerpo es dueno de su
## fisica. El perfil NO ejecuta nada: WeaponBase lo traduce a request_mover / request_float, que
## conservan sus gates (piso y dash en Player, poise quebrado en Enemy).
##
## Un slot en null = este golpe no hace eso, y es la forma de apagarlo desde el inspector sin tocar
## codigo. Un perfil entero en null = el golpe no mueve a nadie (es el caso real de tap adelante + X
## en suelo, que son vueltas puras).
##
## POR QUE RT ES UN PORCENTAJE Y NO OTRO PERFIL: el mismo modelo que PlayerSprint. El valor base
## vive una sola vez en el .tres y el bono se aplica en el consumidor, asi que "sin RT" es
## literalmente multiplicar por 1.0 y no una rama aparte. Con dos perfiles por gesto habia que
## reescribir un recorrido entero para cambiar cuanto retrocede el RT, y los gestos que no usaban
## la variante dejaban slots vacios que no se distinguian de un olvido.

## De donde sale la direccion de `player_travel`. Los gestos direccionales ya fijaron el facing al
## objetivo lockeado antes de moverse, asi que el forward del Player ES hacia el objetivo.
enum Direction {
	## Usa la `direction` del MoverSettings tal cual. Es lo correcto para recorridos verticales
	## (launcher, spike, plunge), donde la direccion no depende de hacia donde mira nadie.
	PROFILE,
	## Forward del Player, aplanado en Y. Avances.
	PLAYER_FORWARD,
	## Opuesto al forward del Player, aplanado en Y. Retrocesos.
	PLAYER_BACK,
}

## CUANDO sale `enemy_travel`. El mismo slot alimenta tres momentos distintos y solo el perfil puede
## distinguirlos, por eso este eje SI es tuning y no codigo: el momento cambia lo que se siente,
## no solo cuando ocurre.
enum EnemyTravelAt {
	## En `about_to_hit`, ANTES del dano. El Stun del mismo golpe ya ve al objetivo en el aire, que
	## es lo que hace que un launcher abra juggle en vez de dejarlo parado. Solo lo cobra un golpe
	## con ventana vertical (WeaponBase.run_vertical_window_from_profile); en cualquier otro es un
	## momento que nunca llega.
	BEFORE_DAMAGE,
	## Al conectar, despues del dano. Es lo normal: spikes y empujones a los que les da igual lo que
	## vio el Stun. Lo cobra CUALQUIER golpe del arma, sin que la rutina tenga que pedir nada.
	ON_HIT,
	## Al cerrar la ventana de dano, sobre TODO lo golpeado en ella. Es lo que necesita un plunge:
	## arrancar el recorrido durante el swing saca al objetivo del alcance del propio golpe.
	WINDOW_END,
}

@export_group("Player")
## Recorrido del Player. null = este golpe no lo desplaza.
@export var player_travel: MoverSettings
## De donde sale la direccion de `player_travel`. PROFILE la respeta tal cual; las otras dos la
## recalculan en runtime contra el facing y clonan el perfil para no pisar el recurso compartido.
@export var player_direction := Direction.PROFILE
## El recorrido del Player espera a que cierre la ventana de dano en vez de salir con el golpe. Es
## el gemelo de `EnemyTravelAt.WINDOW_END` y va junto: en un plunge, caer durante el swing te saca
## de rango y el hitbox no llega al enemigo. Las ventanas verticales (launcher) no miran este flag:
## arrancan su recorrido ellas mismas, tras su propio delay.
@export var player_travel_at_window_end := false
## Hang del Player AL INICIAR el golpe. Solo tiene sentido en ataques SIN `player_travel`: mientras
## corre un Mover, el Mover es dueno de la vertical y este Floater no se aplica (en TOTAL el loop del
## Player hace return antes de leerlo; en PARTIAL el Mover lo sobreescribe el mismo frame). El hang
## que va DESPUES de un recorrido es `player_travel.float_duration`, que lo dispara el propio Mover
## al terminar y no sale si el recorrido se cancela. Ver combat/mover.gd y player/player.gd.
@export var player_hang: FloaterSettings

@export_group("Enemy")
## Recorrido que este golpe le aplica al Enemy: el ascenso de un launcher, el spike de la Y cargada
## aerea, la caida de un plunge. null = este golpe no lo desplaza. Nunca es el mismo recurso que
## `player_travel` aunque los numeros coincidan: son dos cuerpos y se tunean por separado.
@export var enemy_travel: MoverSettings
## En que momento del golpe sale `enemy_travel`. Ver EnemyTravelAt.
@export var enemy_travel_at := EnemyTravelAt.ON_HIT
## Antes de arrancar `enemy_travel`, sube o baja al objetivo a la altura del Player. Es lo que hace
## que un plunge se sienta como "bajamos juntos" y no como dos caidas paralelas: si el golpe entro
## por encima tuyo, el enemigo se alinea primero. Solo alinea si el Mover realmente va a entrar
## (aereo y quebrado): teletransportar a un enemigo entero y dejarlo ahi seria peor que no hacer nada.
@export var enemy_travel_aligns_y := false
## Hang de CADA enemigo que conecta este golpe, renovado por golpe (el Floater usa max), asi queda
## pegado durante el combo y cae al dejar de golpearlo. null = el golpe cae al hold generico del
## arma (SwordTuning.air_hit_enemy_floater). Ver combat/floater.gd.
@export var enemy_on_hit: FloaterSettings

@export_group("Con RT")
# Bonos en PORCENTAJE sobre el valor base de arriba, aplicados solo cuando el gesto pago meter.
# 0 = el RT no toca ese canal; 80 = vale 1.8x; -100 = lo apaga. Se aplican en el consumidor
# (WeaponBase clona el recurso), nunca sobre el .tres: el valor base tiene que seguir leyendose tal
# cual en el inspector. Mismo modelo que los bonos de PlayerSprint.
#
# `enemy_travel` no tiene bonos: hoy ningun gesto que mueva al Enemy tiene variante RT (los taps de
# Y son gratis y los cargados cobran barra entera, sin rama). Serian sliders muertos en el inspector.
# Cuando exista el primer caso real se agregan igual que estos.
## Bono % a los metros de `player_travel`: cuanto MAS LEJOS llega el recorrido con RT.
@export_range(-100.0, 300.0, 1.0) var rt_player_travel_distance_bonus := 0.0
## Bono % a la velocidad inicial de `player_travel`: cuanto MAS RAPIDO arranca con RT.
@export_range(-100.0, 300.0, 1.0) var rt_player_travel_speed_bonus := 0.0
## Bono % a la aceleracion de `player_travel`. Va aparte de la velocidad a proposito: subir solo la
## velocidad inicial deja un recorrido que arranca fuerte y se siente lavado al final.
@export_range(-100.0, 300.0, 1.0) var rt_player_travel_acceleration_bonus := 0.0
## Bono % a los segundos de hang del Player. Escala el que ese golpe use — `player_hang.duration` si
## no viaja, o `player_travel.float_duration` si viaja — asi el slider vale igual en los dos casos.
## El `fall_scale` NO se escala: 0 es hold total (y 0 por cualquier bono sigue siendo 0) y el rango
## esta clampeado a 0-1, asi que un bono no tendria a donde ir. Si el RT tiene que cambiar COMO caes
## y no solo cuanto, eso es un campo propio, no un porcentaje.
@export_range(-100.0, 300.0, 1.0) var rt_player_hang_bonus := 0.0
## Bono % a los segundos de `enemy_on_hit`. -100 lo apaga del todo (el enemigo NO cae al hold
## generico del arma: el perfil sigue siendo el dueno del hang, solo que pidiendo cero).
@export_range(-100.0, 300.0, 1.0) var rt_enemy_hang_bonus := 0.0
## El movimiento de este golpe existe SOLO con RT: sin barra el perfil entero no se cobra. Es el caso
## de tap atras + X aereo, que sin barra son vueltas en el sitio y con barra ademas retrocede. Sin
## esto habria que elegir entre darle recorrido a la variante gratis o volver a dos perfiles por gesto.
@export var rt_only := false

@export_group("Proyectil (solo con RT)")
## Si este golpe dispara su proyectil al cerrar `player_travel`. Es siempre premio de RT: sin barra
## no dispara nunca. Sin recorrido no dispara (no hay momento que esperar), y un recorrido cancelado
## (stun, pared, Mover nuevo) tampoco: no quedan disparos tardios.
@export var rt_fires_projectile := false
## Launcher que el proyectil le aplica al enemigo que impacta. Va a mano, sin porcentajes: es el
## unico Mover del perfil que no le pertenece ni al Player ni al enemigo que golpea este swing.
## null conserva el proyectil y desactiva solo su elevacion.
@export var rt_projectile_enemy_mover: MoverSettings

@export_group("Reglas")
## Este golpe se hace cargo de la vertical del Player: el arma NO le aplica encima su air-hit-stall
## generico ni le corta el momentum aereo al conectar. Prenderlo en los gestos que ya piden su
## propio Mover/Floater, o el hang generico les pisa el suyo. Aplica con RT y sin RT por igual: es
## una regla del gesto, no una recompensa. Ver WeaponBase.register_weapon_hit.
@export var overrides_air_hit := false
