class_name Floater extends Node
## Primitiva vertical universal #1 (ver obsidian/Plan Autoridad Vertical). Suspende a su dueno un
## tiempo exacto escalando la caida por `fall_scale`, y al vencer deja que la gravedad normal
## retome. No guarda ni restaura velocidades y no tiene prioridades. Es hijo de Player y de
## EnemyBase (se instancia por codigo en su _ready); cada instancia solo toca a SU dueno.
##
## La logica de tiempo (start/cancel/is_floating/fall_scale) es independiente del cuerpo. La
## aplicacion por frame (apply_fall) la llama el cuerpo desde su integracion vertical, pasando su
## propia gravedad (Player: tuning.gravity; Enemy: _air_gravity), asi el componente sirve para los
## dos sin conocer sus internals.
##
## Los valores (duration, fall_scale) los define QUIEN ataca, por arma y por ataque (viven en el
## tuning del ataque, no aca). Ver combat/mover.gd para la primitiva #2.

var _body: Node  # Player o EnemyBase; reservado para usos futuros del componente.
var _float_until := 0.0
var _fall_scale := 1.0

func setup(body: Node) -> void:
	_body = body

## Suspende la caida del dueno `duration` segundos escalando su gravedad por `fall_scale`
## (0.0 = hold total con velocity.y en 0; 1.0 = gravedad normal; intermedio = deriva lenta, ej.
## 0.15 = cae al 15%). Renueva el vencimiento con max(actual, now + duration) y adopta el
## `fall_scale` de la ultima solicitud (gana el ultimo que escribe). `duration` <= 0 no hace nada.
func start_float(duration: float, fall_scale: float) -> void:
	if duration <= 0.0:
		return
	_float_until = maxf(_float_until, World.now() + duration)
	_fall_scale = clampf(fall_scale, 0.0, 1.0)

## Corta el float en el acto y devuelve el control a la gravedad normal.
func cancel_float() -> void:
	_float_until = 0.0

func is_floating() -> bool:
	return World.now() < _float_until

func fall_scale() -> float:
	return _fall_scale

## Vertical de ESTE frame mientras el float esta activo. El cuerpo pasa su vertical actual, su
## gravedad (negativa) y delta; devuelve la nueva vertical. 0.0 = hold total (0); intermedio =
## suma la gravedad escalada; 1.0 = gravedad normal. No distingue subida de caida: escalar la
## gravedad frena una subida igual que ralentiza una caida — el ataque decide CUANDO flotar.
func apply_fall(vertical: float, gravity: float, delta: float) -> float:
	if _fall_scale <= 0.0:
		return 0.0
	return vertical + gravity * _fall_scale * delta
