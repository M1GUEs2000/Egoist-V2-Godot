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
## Recorrido del Player, y tambien su hang: el Floater de este golpe sale de
## `player_travel.float_duration`, no de un slot aparte. null = este golpe no le hace nada a su
## posicion.
##
## COLGAR SIN VIAJAR es `distance = 0`: el Mover corre un frame, termina y detona su Floater. Antes
## habia un `player_hang` separado y los dos podian convivir en el mismo perfil, que es la fuente de
## los conflictos de vertical — un Floater arrancado mientras corre un Mover no se aplica mientras
## dura el recorrido, pero SI despues, asi que "no se aplica nunca" era falso y el hang se colaba.
## Con un solo slot el conflicto no se puede declarar. *(2026-07-30)*
@export var player_travel: MoverSettings
## El recorrido del Player espera a que cierre la ventana de dano en vez de salir con el golpe. Es
## el gemelo de `EnemyTravelAt.WINDOW_END` y va junto: en un plunge, caer durante el swing te saca
## de rango y el hitbox no llega al enemigo. Las ventanas verticales (launcher) no miran este flag:
## arrancan su recorrido ellas mismas, tras su propio delay.
@export var player_travel_at_window_end := false

@export_group("Enemy")
## Recorrido que este golpe le aplica al Enemy, y tambien su hang: sale de
## `enemy_travel.float_duration`, igual que el del Player. null = este golpe no lo desplaza.
##
## COLGARLO SIN MOVERLO es `distance = 0`. Reemplaza al viejo `enemy_on_hit`, que era un slot aparte
## y podia convivir con el recorrido: como `EnemyBase.request_mover` llama `_cancel_air_hold()`, el
## Mover le mataba el Floater al hang declarado justo al lado. Ahora es imposible pedir las dos
## cosas. *(2026-07-30)*
##
## Nunca es el mismo recurso que `player_travel` aunque los numeros coincidan: son dos cuerpos y se
## tunean por separado.
@export var enemy_travel: MoverSettings
## En que momento del golpe sale `enemy_travel`. Ver EnemyTravelAt.
@export var enemy_travel_at := EnemyTravelAt.ON_HIT
## Antes de arrancar `enemy_travel`, sube o baja al objetivo a la altura del Player. Es lo que hace
## que un plunge se sienta como "bajamos juntos" y no como dos caidas paralelas: si el golpe entro
## por encima tuyo, el enemigo se alinea primero. Solo alinea si el Mover realmente va a entrar
## (aereo y quebrado): teletransportar a un enemigo entero y dejarlo ahi seria peor que no hacer nada.
@export var enemy_travel_aligns_y := false
## Empujon en arco que este golpe le manda al enemigo. null = este golpe no empuja.
##
## NO es un Mover y no puede serlo todavia: el push tiene solver balistico propio (ver
## PushSettings, que se tunea por DONDE CAE y no por velocidad) y espera al "bouncer" del plan de
## autoridad vertical. Vive igual en este perfil porque el tema del Resource es que le hace el golpe
## a la POSICION de los cuerpos, y un empujon es exactamente eso: tenerlo afuera obligaba a mirar en
## dos lados para saber si un golpe mueve a alguien.
##
## Reemplaza al bool `AttackStep.pushes`, que apuntaba al PushSettings unico del arma
## (`WeaponTuning.push`): con un solo arco por arma, los dos golpes que empujan empujaban idéntico y
## no habia forma de separarlos. El Mazo ya habia chocado con eso y se habia hecho un campo suelto
## propio (`MaceTuning.charged_final_push`). *(2026-07-30)*
@export var enemy_push: PushSettings
## En que fraccion del golpe se arma el empujon, 0-1 sobre su duracion. Normalizado igual que
## `AttackClip.hitbox_open`, y por el mismo motivo: cambiar cuanto dura el golpe no tiene que
## reubicar el empujon. Lo ya golpeado sale volando en ese instante y lo que conecte despues se
## empuja al momento. 1 = al cerrar el golpe.
##
## Es un momento propio y no uno de `EnemyTravelAt` a proposito: el push no ocurre en el impacto ni
## al cerrar la ventana, sino en un punto del swing que el arma elige (la Espada lo tenia en 0.65).
@export_range(0.0, 1.0, 0.05) var enemy_push_at := 1.0

@export_group("Con RT")
# Bonos en PORCENTAJE sobre el valor base de arriba, aplicados solo cuando el gesto pago meter.
# 0 = el RT no toca ese canal; 80 = vale 1.8x; -100 = lo apaga. Se aplican en el consumidor
# (WeaponBase clona el recurso), nunca sobre el .tres: el valor base tiene que seguir leyendose tal
# cual en el inspector. Mismo modelo que los bonos de PlayerSprint.
#
## Bonos % compartidos por `player_travel` y `enemy_travel`: cuanto MAS LEJOS, RAPIDO y con cuanta
## aceleracion sale cualquier Mover del gesto con RT. Los dos cuerpos conservan sus Resources
## separados; solo comparten la variante RT, para que un mismo gesto no tenga seis sliders gemelos.
@export_range(-100.0, 300.0, 1.0) var rt_travel_distance_bonus := 0.0
@export_range(-100.0, 300.0, 1.0) var rt_travel_speed_bonus := 0.0
@export_range(-100.0, 300.0, 1.0) var rt_travel_acceleration_bonus := 0.0
## Bono adicional % a la velocidad de la animacion con RT. Pertenece al perfil porque es una
## variante del mismo gesto: WeaponBase lo suma al `speed_bonus` del clip y resuelve una sola
## duracion para runner, animador y ventana de dano.
@export_range(-90.0, 300.0, 1.0, "or_greater", "suffix:%") var rt_animation_speed_bonus := 0.0
## Bono % a los segundos de hang del Player: `player_travel.float_duration`.
## El `fall_scale` NO se escala: 0 es hold total (y 0 por cualquier bono sigue siendo 0) y el rango
## esta clampeado a 0-1, asi que un bono no tendria a donde ir. Si el RT tiene que cambiar COMO caes
## y no solo cuanto, eso es un campo propio, no un porcentaje.
@export_range(-100.0, 300.0, 1.0) var rt_player_hang_bonus := 0.0
## Bono % a los segundos de hang del Enemy: `enemy_travel.float_duration`. -100 lo apaga del todo.
@export_range(-100.0, 300.0, 1.0) var rt_enemy_hang_bonus := 0.0
## Este perfil existe SOLO con RT. Dentro de una AttackSequence se omite el paso entero sin barra
## (clip, dano, movimiento y proyectil), lo que permite declarar [ataque normal, remate RT] en el
## mismo auto-chain. Si un ataque legacy consume el perfil directamente, se bloquea su movimiento.
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
