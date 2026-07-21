class_name HitDummy extends CharacterBody3D
## Receptor minimo para probar armas. Ejecuta los perfiles verticales que recibe, igual que un
## cuerpo de combate, sin decidir trayectoria ni conservar verbos verticales propios.

@export var gravity := -24.0

var mover: Mover
var floater: Floater

func _ready() -> void:
	mover = Mover.new()
	add_child(mover)
	floater = Floater.new()
	add_child(floater)
	floater.setup(self)
	mover.setup(self, floater)

## El dummy no tiene poise: acepta cualquier perfil para que el arma pueda probar su coreografia.
func request_mover(settings: MoverSettings, _stun: StunSettings = null,
		_starts_lying := false, _preserve_next_hit := false) -> bool:
	if settings == null:
		return false
	floater.cancel_float()
	mover.start_mover(settings)
	return true

func request_float(duration: float, fall_scale: float) -> bool:
	if duration <= 0.0 or not is_airborne():
		return false
	floater.start_float(duration, fall_scale)
	return true

func cancel_vertical_control(reason := Mover.CancelReason.ATTACK_RULE) -> void:
	mover.cancel_mover(reason)
	floater.cancel_float()

func is_airborne() -> bool:
	return mover.is_moving() or floater.is_floating() or not is_on_floor()

func is_stunned() -> bool:
	return true

func _physics_process(delta: float) -> void:
	if mover.is_moving():
		mover.tick(delta)
		return
	if is_on_floor() and velocity.y <= 0.0:
		velocity = Vector3.ZERO
		return
	var fall_scale := floater.fall_scale() if floater.is_floating() else 1.0
	velocity.y += gravity * fall_scale * delta
	move_and_slide()
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
