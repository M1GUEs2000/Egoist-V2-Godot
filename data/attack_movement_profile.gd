class_name AttackMovementProfile extends Resource
## Todo lo que UNA variante de ataque (gesto x tramo x RT) le hace a la posicion de los cuerpos.
## Agrupa en un solo campo del tuning lo que antes eran hasta cinco campos sueltos repartidos en
## tres subgrupos, MAS los ids de rutina que el arma guardaba para reconectarlos en runtime.
##
## Respeta las reglas de obsidian/Mover y Floater: un slot por cuerpo (un Mover o un Floater solo
## controla a su dueno) y el ataque es dueno de la intencion mientras el cuerpo es dueno de su
## fisica. El perfil NO ejecuta nada: WeaponBase.run_attack_movement lo traduce a request_mover /
## request_float, que conservan sus gates (piso y dash en Player, poise quebrado en Enemy).
##
## Un slot en null = este golpe no hace eso. Un perfil entero en null = el golpe no mueve a nadie
## (es el caso real de tap adelante + X en suelo, que son vueltas puras).
##
## Pendiente: cuando migren los taps de Y hace falta un slot `enemy_travel` (Mover directo sobre el
## enemigo, hoy `tap_back_y_enemy_mover` y `tap_back_y_air_enemy_mover`). No se agrega antes de
## tener el consumidor: seria un campo muerto en el inspector.

## Cuando arranca el hang del Player.
enum HangAt {
	## Al iniciar el golpe. Es el caso de tap adelante + X aereo: cuelga y gira en el sitio.
	START,
	## Al cerrar `player_travel`. Es el caso de tap atras + X aereo RT: primero retrocede y recien
	## al terminar el retroceso cuelga. Sin recorrido que esperar, no cuelga nunca.
	TRAVEL_END,
}

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

@export_group("Player")
## Recorrido del Player. null = este golpe no lo desplaza.
@export var player_travel: MoverSettings
## De donde sale la direccion de `player_travel`. PROFILE la respeta tal cual; las otras dos la
## recalculan en runtime contra el facing y clonan el perfil para no pisar el recurso compartido.
@export var player_direction := Direction.PROFILE
## Hang del Player. null o duration 0 = no cuelga. Si `player_travel` ya trae su propio
## `float_duration`, tunear ahi y dejar este vacio: son la misma cosa pedida desde dos lados.
@export var player_hang: FloaterSettings
## Momento en que arranca `player_hang`.
@export var player_hang_at := HangAt.START

@export_group("Enemy")
## Hang de CADA enemigo que conecta este golpe, renovado por golpe (el Floater usa max), asi queda
## pegado durante el combo y cae al dejar de golpearlo. null = el golpe cae al hold generico del
## arma (SwordTuning.air_hit_enemy_floater). Ver combat/floater.gd.
@export var enemy_on_hit: FloaterSettings

@export_group("Proyectil")
## Si este golpe dispara su proyectil al cerrar `player_travel`. Sin recorrido no dispara nunca, y
## un recorrido cancelado (stun, pared, Mover nuevo) tampoco: no quedan disparos tardios.
@export var fires_projectile := false
## Launcher que el proyectil le aplica al enemigo que impacta. null conserva el proyectil y
## desactiva solo su elevacion.
@export var projectile_enemy_mover: MoverSettings

@export_group("Reglas")
## Este golpe se hace cargo de la vertical del Player: el arma NO le aplica encima su air-hit-stall
## generico ni le corta el momentum aereo al conectar. Prenderlo en los gestos que ya piden su
## propio Mover/Floater, o el hang generico les pisa el suyo. Ver WeaponBase.register_weapon_hit.
@export var overrides_air_hit := false
