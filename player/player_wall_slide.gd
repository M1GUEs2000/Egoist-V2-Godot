class_name PlayerWallSlide extends Node
## Deslizamiento de pared por momentum: requiere input hacia la pared y contacto real.

# Feedback visual: el personaje brilla verde mientras está pegado a la pared, y la INTENSIDAD sigue
# en vivo qué fracción del MÁXIMO ACTUAL llevás a lo largo del muro (ver _max_along_wall_speed). No
# hay una velocidad de referencia propia a tunear: la escala sale del mismo techo que el slide aplica,
# así que se mueve sola con el tuning, con el sprint y con el Wall Impulse. Brillo pleno siempre
# significa lo mismo — "estás en el tope de lo que el sistema te permite ahora".
## Color del brillo mientras deslizás.
@export var glow_color := Color(0.25, 1.0, 0.4)
## Brillo al 0% del máximo actual (sin velocidad a lo largo del muro).
@export var glow_energy_min := 0.15
## Brillo al 100% del máximo actual.
@export var glow_energy_max := 6.0

var is_sliding := false
var wall_normal := Vector3.ZERO
## True mientras el slide esta usando una WallImpulseSurface y ya capturo direccion.
var is_impulsing := false
## Direccion horizontal fija tomada del primer input tangencial valido en la pared actual.
var impulse_direction := Vector3.ZERO

var _body: Player
var _ignore_until := -999.0
var _move_lock_until := -999.0
var _grace_until := -999.0
## Rumbo unitario SOBRE EL PLANO DE LA PARED (puede tener componente vertical: deslizar de lado,
## trepar y todo lo intermedio son el mismo rumbo apuntando distinto). La RAPIDEZ va aparte
## (_slide_speed) a propósito: el sistema manda la rapidez y el input solo puede redirigir.
var _slide_direction := Vector3.ZERO
var _slide_speed := 0.0
## Caída acumulada por gravedad durante la fase 2, SEPARADA de la velocidad del slide. Van aparte
## para que la gravedad no contamine la lectura del slide: `_slide_speed` sigue siendo puro "cuánto
## te queda de rampa" y es lo que mide la potencia del rebote y el brillo.
var _fall_velocity := 0.0
## Techo al que apunta la rampa en ESTE enganche (sale del rango final según qué tan rasante llegaste).
var _slide_final_speed := 0.0
## False mientras la rampa acelera (la pared te sostiene, no caés); true una vez que tocó el techo.
var _falling := false
var _fall_hold_until := -999.0
var _impulse_velocity := Vector3.ZERO
var _impulse_surface: WallImpulseSurface
var _impulse_tuning: WallImpulseTuning
var _glow_meshes: Array[MeshInstance3D] = []
var _glow_material: StandardMaterial3D
var _glow_active := false
var _smoke: SmokeStylizedVFX

const ARROW_LENGTH := 2.0
var _arrow: MeshInstance3D
var _arrow_mesh: ImmediateMesh
var _arrow_material: StandardMaterial3D

func setup(body: Player) -> void:
	_body = body
	_collect_glow_meshes(body.get_node_or_null("Visual"))
	if _glow_meshes.is_empty():
		# Fallback a la capsula placeholder por si se corre una escena sin el modelo.
		var capsule := body.get_node_or_null("Mesh") as MeshInstance3D
		if capsule != null:
			_glow_meshes.append(capsule)
	_smoke = body.get_node_or_null("WallSlideSmoke") as SmokeStylizedVFX
	_build_arrow()

## El brillo va sobre las mallas del MODELO (Visual/...), no sobre el nodo "Mesh": ese es la capsula
## placeholder y quedo con visible = false cuando entro el personaje, asi que pintarlo no se veia.
## El modelo es un arbol con Skeleton3D, de ahi la recoleccion recursiva.
func _collect_glow_meshes(root: Node) -> void:
	if root == null:
		return
	var mesh := root as MeshInstance3D
	if mesh != null:
		_glow_meshes.append(mesh)
	for child in root.get_children():
		_collect_glow_meshes(child)

func apply_slide_velocity(horizontal_velocity: Vector3, input_dir: Vector3, delta: float) -> Vector3:
	if _body == null or not is_sliding:
		return horizontal_velocity
	if World.now() < _ignore_until or _body.is_on_floor():
		cancel()
		return horizontal_velocity
	# Assist: el slide ya no exige apretar HACIA la pared; solo se corta si el jugador
	# dirige el stick EN CONTRA (se despega a propósito). Input neutro mantiene el deslice.
	if not is_impulsing and _presses_away_from_wall(input_dir, wall_normal):
		_release_by_input()
		return horizontal_velocity

	var t := _body.tuning
	_update_wall_impulse(input_dir, wall_normal, delta)
	# Wall Impulse es un carril aparte con su propio acelerador, techo y altura sostenida: cuando
	# está activo manda entero y la rampa del slide no interviene. Antes se mezclaban por suma, y
	# eso hacía que el carril compitiera contra el drenaje del slide en vez de reemplazarlo.
	if is_impulsing:
		var impulse_horizontal := _impulse_velocity
		impulse_horizontal.y = 0.0
		return impulse_horizontal - wall_normal * t.wall_slide_press_speed

	_tick_ramp(delta)
	_tick_fall(delta)
	_steer_direction(input_dir, delta)
	# El slide corre sobre el plano de la pared, así que su rumbo puede tener componente vertical
	# (trepar). La vertical se entrega al motor por separado, más la caída acumulada; acá vuelve solo
	# la parte horizontal, más la presión contra la pared — sin ella el movimiento queda paralelo al
	# muro, se pierde el contacto (is_on_wall) y el estado titila frame a frame.
	_body.vertical_velocity = _slide_direction.y * _slide_speed + _fall_velocity
	var horizontal := _slide_direction * _slide_speed
	horizontal.y = 0.0
	return horizontal - wall_normal * t.wall_slide_press_speed

## FASE 1 — la rampa. Acelerás desde la velocidad inicial hacia la final a `wall_slide_acceleration`,
## y mientras tanto la pared te SOSTIENE: la gravedad no corre (_fall_velocity queda en cero), así
## que si el rumbo apunta hacia arriba subís limpio. Al tocar el techo se abre la fase 2.
func _tick_ramp(delta: float) -> void:
	if _falling:
		return
	var t := _body.tuning
	var accel := t.wall_slide_acceleration * _body.sprint_scale(PlayerSprint.WALL_SLIDE_ACCEL)
	_slide_speed = move_toward(_slide_speed, _slide_final_speed, accel * delta)
	if _slide_speed >= _slide_final_speed - 0.001:
		_slide_speed = _slide_final_speed
		_falling = true
		_fall_hold_until = World.now() + t.wall_slide_fall_hold_time

## FASE 2 — la caída. Arranca la gravedad y el slide NO se corta de golpe: aguanta
## `wall_slide_fall_hold_time` al 100% (ahí el wall jump sale pleno) y recién después se drena
## EXPONENCIALMENTE por vida media, así la potencia del rebote se degrada suave en vez de
## desplomarse al mínimo en dos frames. Si venías trepando, el mismo drenaje te apaga la subida:
## la trepada se agota sola y el arco se da vuelta sin ningún caso especial.
func _tick_fall(delta: float) -> void:
	if not _falling:
		return
	var t := _body.tuning
	# `gravity` ya viene negativa; gravity_scale 1 = caída normal, 0 = no caés.
	_fall_velocity += t.gravity * t.wall_slide_gravity_scale * delta
	_fall_velocity = maxf(_fall_velocity, -t.wall_slide_max_fall_speed)
	if World.now() < _fall_hold_until:
		return
	# Vida media: cada `halflife` segundos queda la mitad. Independiente del framerate y, al ser
	# exponencial, nunca corta seco — sigue habiendo algo de slide aunque cuelgues mucho.
	_slide_speed *= pow(0.5, delta / maxf(0.01, t.wall_slide_fall_lateral_halflife))

## El input solo REDIRIGE el rumbo sobre el plano de la pared, con la autoridad de
## `wall_slide_steer_control`; la rapidez es intocable (la manda la rampa). Ese es el punto del
## rediseño: la salida del slide queda anclada a un techo conocido y encadenar converge.
##
## Como el input pasa por _wall_plane_vector, empujar CONTRA el muro dirige hacia arriba: podés
## arrancar deslizando de lado y curvar a trepada, o al revés, sin botón aparte.
func _steer_direction(input_dir: Vector3, delta: float) -> void:
	if _slide_direction.length_squared() < 0.0001:
		return
	_reproject_direction()
	var steer := _wall_plane_vector(input_dir, wall_normal)
	if steer.length_squared() < 0.0001:
		return
	_slide_direction = _slide_direction.move_toward(
			steer.normalized(), _body.tuning.wall_slide_steer_control * delta)
	if _slide_direction.length_squared() > 0.0001:
		_slide_direction = _slide_direction.normalized()

## Reproyecta el rumbo sobre el plano de la pared ACTUAL conservando su forma (cuánto va de lado y
## cuánto hacia arriba). Hace falta en paredes curvas: conservar el vector mundial original iría
## metiendo velocidad CONTRA el muro y el deslice se frenaría solo, sin que ningún input lo pida.
func _reproject_direction() -> void:
	var climb := _slide_direction.y
	var lateral := _slide_direction
	lateral.y = 0.0
	var lateral_speed := lateral.length()
	if lateral_speed < 0.0001:
		return
	var tangent := Vector3.UP.cross(wall_normal)
	tangent.y = 0.0
	if tangent.length_squared() < 0.0001:
		return
	tangent = tangent.normalized()
	if tangent.dot(lateral) < 0.0:
		tangent = -tangent
	_slide_direction = (tangent * lateral_speed + Vector3.UP * climb).normalized()

## LA REGLA DEL TREPADO. Convierte un vector del mundo (la velocidad con la que llegás, o el input)
## en un rumbo sobre el PLANO DE LA PARED: la parte tangencial se conserva tal cual, y la parte que
## empuja CONTRA el muro —que antes no hacía más que sostener el contacto— se dobla hacia ARRIBA,
## recortada por `wall_slide_climb_ratio`.
##
## De ahí sale todo el comportamiento sin casos especiales: llegar rasante desliza de lado, llegar
## de frente trepa, llegar en diagonal sube en diagonal. Y lo mismo con el stick mientras deslizás.
##
## El rumbo resultante se INCLINA hacia abajo hasta respetar `wall_slide_max_climb_angle`. Es un tope
## duro: por más de frente que entres, la trepada nunca pasa de ese ángulo. Sin él, entrar
## perpendicular daba un rumbo casi vertical y se trepaba la pared como una escalera.
func _wall_plane_vector(v: Vector3, normal: Vector3) -> Vector3:
	var t := _body.tuning
	var flat := v
	flat.y = 0.0
	# Solo cuenta el empuje HACIA la pared: tirar para afuera no debería hundirte, y ese caso ya lo
	# maneja _presses_away_from_wall soltándote del muro.
	var into := maxf(0.0, flat.dot(-normal))
	var lateral := flat.slide(normal)
	lateral.y = 0.0
	var climb := into * t.wall_slide_climb_ratio
	if climb <= 0.0:
		return lateral
	# tan(ángulo) = cuánta subida se banca por unidad de avance lateral. Con 45° la subida no puede
	# superar al lateral; con 0° no hay trepada.
	var max_ratio := tan(deg_to_rad(clampf(t.wall_slide_max_climb_angle, 0.0, 89.0)))
	if max_ratio <= 0.0:
		return lateral
	var lateral_speed := lateral.length()
	if lateral_speed < 0.001:
		# Entrada perpendicular pura: no hay lateral contra el cual medir el ángulo, así que en vez
		# de dejarlo vertical (que es justo lo que el tope existe para evitar) se le presta el lateral
		# justo para quedar EXACTO en el ángulo máximo. Sale una diagonal, no una escalera.
		var tangent := _climb_fallback_tangent(normal)
		if tangent.length_squared() < 0.0001:
			return lateral + Vector3.UP * climb
		return tangent * (climb / max_ratio) + Vector3.UP * climb
	return lateral + Vector3.UP * minf(climb, lateral_speed * max_ratio)

## Lado hacia el que derrapa una entrada perpendicular pura. Sigue el rumbo que ya se venía llevando
## si hay uno; si no (enganche recién hecho), toma la tangente cruda del muro. Es determinista: la
## misma pared y el mismo rumbo dan siempre el mismo lado.
func _climb_fallback_tangent(normal: Vector3) -> Vector3:
	var tangent := Vector3.UP.cross(normal)
	tangent.y = 0.0
	if tangent.length_squared() < 0.0001:
		return Vector3.ZERO
	tangent = tangent.normalized()
	var current := _slide_direction
	current.y = 0.0
	if current.length_squared() > 0.0001 and tangent.dot(current) < 0.0:
		tangent = -tangent
	return tangent

func update_after_move(horizontal_velocity: Vector3, input_dir: Vector3) -> void:
	if _body == null:
		return
	if World.now() < _ignore_until or _body.is_on_floor():
		cancel()
		return

	var normal: Vector3 = _find_wall_normal()
	var has_wall := normal.length_squared() >= 0.0001 and _body.is_on_wall()
	if not has_wall:
		# Contacto perdido: ventana de gracia (coyote) antes de cortar, así el estado no
		# titila en esquinas o micro-separaciones; se mantiene con la última normal conocida.
		if is_sliding and World.now() < _grace_until:
			return
		_carry_impulse_into_air()
		cancel()
		return

	# Solo corta si el jugador se dirige EN CONTRA de la pared (ver apply_slide_velocity).
	if not is_impulsing and _presses_away_from_wall(input_dir, normal):
		_release_by_input()
		return

	var push_speed := horizontal_velocity.dot(-normal)
	# Para ENGANCHAR hace falta empuje real contra la pared; ya deslizando se mantiene solo.
	if not is_sliding and push_speed < _body.tuning.wall_slide_min_push_speed:
		return

	var was_sliding := is_sliding
	is_sliding = true
	wall_normal = normal
	_grace_until = World.now() + _body.tuning.wall_slide_release_grace
	if not was_sliding:
		_begin_slide(horizontal_velocity)
		_set_glow(true)
		_set_smoke(true)
	_set_impulse_surface(_find_wall_impulse_surface())
	_update_glow()
	_update_arrow()

## Arma la rampa al enganchar. Un solo numero (`frac`, que tan rasante llegaste medido contra
## `move_speed`) elige a la vez el arranque Y el techo: llegar lanzado te da un tramo mas rapido y
## ademas apuntando mas alto. La RAPIDEZ es absoluta, no se le suma a la que traias — por eso
## encadenar paredes ya no acumula: entres con 5 o con 40, la rampa termina en el mismo techo.
## Lo que traias no se tira: define el rumbo y donde caes dentro de los dos rangos.
func _begin_slide(horizontal_velocity: Vector3) -> void:
	var t := _body.tuning
	# La velocidad de llegada pasa por la regla del trepado: lo que va de costado desliza de costado
	# y lo que va CONTRA la pared se dobla hacia arriba. Por eso llegar de frente lanzado ya no es un
	# caso muerto (antes no habia tangente y te quedabas cayendo pegado): ahora te sube.
	var entry := _wall_plane_vector(horizontal_velocity, wall_normal)
	var entry_speed := entry.length()
	_falling = false
	_fall_hold_until = -999.0
	_fall_velocity = 0.0
	if entry_speed <= 0.1:
		# Llegada sin velocidad util en ninguna direccion del plano: no hay rumbo que sembrar, asi
		# que se pasa directo a la fase de caida en vez de inventar uno.
		_slide_direction = Vector3.ZERO
		_slide_speed = 0.0
		_slide_final_speed = 0.0
		_falling = true
		_fall_hold_until = World.now() + t.wall_slide_fall_hold_time
		return
	var frac := clampf(entry_speed / maxf(0.001, t.move_speed), 0.0, 1.0)
	_slide_direction = entry / entry_speed
	_slide_speed = lerpf(t.wall_slide_initial_speed_min, t.wall_slide_initial_speed_max, frac) \
			* _body.sprint_scale(PlayerSprint.WALL_SLIDE_INITIAL)
	_slide_final_speed = lerpf(t.wall_slide_final_speed_min, t.wall_slide_final_speed_max, frac) \
			* _body.sprint_scale(PlayerSprint.WALL_SLIDE_FINAL)
	# Red de seguridad de tuning: con un final por debajo del inicial la rampa FRENARIA en vez de
	# acelerar, que no es lo que nadie espera al mover esos knobs. Se aplana a "no acelera".
	_slide_final_speed = maxf(_slide_final_speed, _slide_speed)

func try_wall_jump(_input_dir: Vector3) -> bool:
	if _body == null:
		return false
	var normal := wall_normal
	if not is_sliding:
		# El slide puede haberse cortado justo este frame: si sigue habiendo pared
		# real, el salto igual es rebote hacia afuera, nunca un impulso vertical puro.
		if World.now() < _ignore_until or _body.is_on_floor() or not _body.is_on_wall():
			return false
		normal = _find_wall_normal()
		if normal.length_squared() < 0.0001:
			return false

	var launch := _wall_jump_velocity(normal)
	# El rebote lo genera el propio momentum del jugador, así que su techo sí sube con el sprint
	# (a diferencia de un bloque de launch, que debe entregar siempre la misma distancia).
	_body.set_momentum(Vector3(launch.x, 0.0, launch.z), true)
	_body.vertical_velocity = launch.y
	_ignore_until = World.now() + _body.tuning.wall_slide_wall_jump_lock_time
	_move_lock_until = World.now() + _body.tuning.wall_slide_wall_jump_lock_time
	cancel()
	return true

## Velocidad de lanzamiento del wall jump para una normal de pared dada: xz = empuje horizontal
## (dirección + rapidez), y = subida. La usan tanto el salto real como la flecha de debug, así nunca
## difieren.
##
## Todo sale de UNA fracción 0-1 (ver _wall_jump_power_frac): rapidez horizontal, subida y ángulo se
## interpolan con ella entre su mínimo y su máximo. Sin multiplicadores ni pisos por separado — por
## eso el rebote no puede escalar solo entre paredes: su techo es un número fijo, no algo que dependa
## de con cuánta velocidad llegaste.
func _wall_jump_velocity(normal: Vector3) -> Vector3:
	var t := _body.tuning
	var frac := _wall_jump_power_frac(normal)
	var along := _along_wall_velocity(normal)

	# Ángulo de salida medido DESDE LA CARA de la pared: a rebote pleno salís al `min_angle` (rasante,
	# nunca menos, para no rozar el muro); sin velocidad lateral salís perpendicular (90°, para atrás).
	var angle := lerpf(PI * 0.5, deg_to_rad(t.wall_slide_wall_jump_min_angle), frac)
	var exit_dir := normal
	if along.length() > 0.001:
		# sin(angle) = componente hacia afuera del muro; cos(angle) = componente hacia tu rumbo.
		exit_dir = (normal * sin(angle) + along.normalized() * cos(angle)).normalized()

	# Los rangos salen de la PARED si estás en un carril Wall Impulse, y del player si no. Un carril
	# rápido tiene que poder tirarte más lejos que un muro común sin tocar el PlayerTuning; el ÁNGULO
	# en cambio siempre lo manda el player, porque es forma de movimiento del personaje y no una
	# propiedad de la superficie.
	var h_min := t.wall_slide_wall_jump_h_min
	var h_max := t.wall_slide_wall_jump_h_max
	var v_min := t.wall_slide_wall_jump_v_min
	var v_max := t.wall_slide_wall_jump_v_max
	if _impulse_tuning != null:
		h_min = _impulse_tuning.wall_jump_h_min
		h_max = _impulse_tuning.wall_jump_h_max
		v_min = _impulse_tuning.wall_jump_v_min
		v_max = _impulse_tuning.wall_jump_v_max
	# El sprint escala min y max a la vez, así el rango entero se corre sin deformarse (escalar solo
	# el max haría que correr cambie la FORMA de la progresión y no solo su magnitud).
	var h_speed := lerpf(h_min, h_max, frac) * _body.sprint_scale(PlayerSprint.WALL_JUMP_H)
	var v_speed := lerpf(v_min, v_max, frac) * _body.sprint_scale(PlayerSprint.WALL_JUMP_V)
	return exit_dir * h_speed + Vector3.UP * v_speed

## Fracción 0-1 de potencia del rebote: tu velocidad a lo largo del muro medida contra el techo del
## slide, saturando en `full_power_percent` de ese techo. Esa saturación es lo que da la MESETA
## arriba: no hay que clavar un frame exacto para sacar el salto pleno, todo el tramo final de la
## rampa (y la ventana de hold que le sigue) ya entrega el 100%.
##
## Mide `_slide_speed` —la rampa— y NO la velocidad del cuerpo: así cuenta igual deslizar de costado
## que trepar (las dos son la misma rampa apuntando distinto), y deja afuera la caída por gravedad,
## que se acumula sola con el tiempo. Si la caída contara, colgarse de la pared valdría más que
## deslizarla bien: el incentivo al revés.
func _wall_jump_power_frac(normal: Vector3) -> float:
	var full := _slide_power_ceiling() \
			* _body.tuning.wall_slide_wall_jump_full_power_percent * 0.01
	var speed := 0.0
	if is_impulsing:
		# En el carril la rampa del slide está apagada (_slide_speed = 0): la velocidad real es la
		# del riel. Sin esto el rebote desde un Wall Impulse saldría siempre al mínimo.
		speed = _impulse_velocity.length()
	elif is_sliding:
		speed = _slide_speed
	else:
		# Re-agarre: el slide ya se cortó este frame y no hay rampa que leer, así que se cae a la
		# velocidad real sobre el plano del muro.
		speed = _along_wall_velocity(normal).length()
	return clampf(speed / maxf(0.001, full), 0.0, 1.0)

## Techo AHORA MISMO de la velocidad a lo largo del muro: el destino más alto al que puede llegar la
## rampa con el sprint actual, o el del Wall Impulse si estás en un carril más rápido. Es la unidad
## contra la que se miden tanto la potencia del rebote como el brillo, así que si cambia el tuning o
## entra el sprint, las dos cosas se mueven solas y "pleno" sigue significando lo mismo.
func _slide_power_ceiling() -> float:
	# En un carril el techo es SOLO el del carril, no el máximo de los dos: el riel tiene sus propios
	# rangos de rebote y su propia velocidad, así que "pleno" tiene que significar "vas a tope EN
	# ESTE riel". Tomar el mayor haría que en un carril lento nunca se llegue al rebote pleno.
	if _impulse_tuning != null:
		return _impulse_tuning.max_speed * _body.sprint_scale(PlayerSprint.WALL_IMPULSE)
	return _body.tuning.wall_slide_final_speed_max \
			* _body.sprint_scale(PlayerSprint.WALL_SLIDE_FINAL)

## Velocidad actual A LO LARGO del muro (sin componente contra la pared ni vertical): da el rumbo del
## rebote y su potencia.
func _along_wall_velocity(normal: Vector3) -> Vector3:
	var horizontal := _body.velocity
	horizontal.y = 0.0
	var along := horizontal.slide(normal)
	along.y = 0.0
	return along

## Durante el rebote el impulso de la pared manda: el input de movimiento queda
## bloqueado un instante para que aplastar hacia el muro no cancele el empuje.
func blocks_move_input() -> bool:
	return _body != null and World.now() < _move_lock_until and not _body.is_on_floor()

## Despegue VOLUNTARIO (stick hacia afuera): corta el slide y bloquea el re-enganche por
## `wall_slide_reattach_cooldown`. Va aparte de cancel() a propósito — cancel() también corre al
## tocar suelo y al perder contacto por geometría, y ahí un bloqueo estorbaría: en una esquina hay
## que poder reenganchar en el acto.
##
## Reusa el mismo `_ignore_until` que el wall jump, así los dos bloqueos son el mismo mecanismo y no
## se pisan: si ya había un bloqueo más largo corriendo, se respeta.
func _release_by_input() -> void:
	_ignore_until = maxf(_ignore_until, World.now() + _body.tuning.wall_slide_reattach_cooldown)
	cancel()

func cancel() -> void:
	is_sliding = false
	wall_normal = Vector3.ZERO
	_slide_direction = Vector3.ZERO
	_slide_speed = 0.0
	_slide_final_speed = 0.0
	_falling = false
	_fall_hold_until = -999.0
	_fall_velocity = 0.0
	impulse_direction = Vector3.ZERO
	_impulse_velocity = Vector3.ZERO
	_impulse_tuning = null
	is_impulsing = false
	_set_impulse_surface(null)
	_set_glow(false)
	_set_smoke(false)
	_update_arrow()

func _carry_impulse_into_air() -> void:
	if _body == null or not is_impulsing or _impulse_velocity.length_squared() < 0.0001:
		return
	# Igual que el wall jump: la velocidad del carril es del jugador, su techo acompaña al sprint.
	_body.add_momentum(_impulse_velocity, true)

## Se usa `material_overlay` y no `set_surface_override_material`: el override REEMPLAZA el material
## del modelo y dejaria al personaje como una silueta verde plana. El overlay se dibuja ENCIMA, en
## modo aditivo, asi el personaje se sigue viendo y el brillo se le suma.
func _set_glow(active: bool) -> void:
	if _glow_meshes.is_empty() or active == _glow_active:
		return
	_glow_active = active
	if active and _glow_material == null:
		_glow_material = StandardMaterial3D.new()
		_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if active:
		_update_glow_color(glow_energy_min)
	for mesh in _glow_meshes:
		mesh.material_overlay = _glow_material if active else null

## La intensidad se empuja por el COLOR (rgb multiplicado), no por emission_energy: el overlay es
## unshaded y aditivo, asi que lo que manda es el albedo. Pasado 1.0 el color entra en HDR y lo
## levanta el glow del WorldEnvironment, que es de donde sale el bloom (ver Colores de mundo).
func _update_glow_color(energy: float) -> void:
	if _glow_material == null:
		return
	_glow_material.albedo_color = Color(
			glow_color.r * energy, glow_color.g * energy, glow_color.b * energy, glow_color.a)

## La intensidad se refresca por frame (aparte de prender/apagar el material, que es una sola vez):
## el brillo tiene que seguir la velocidad a lo largo del muro mientras deslizás, no congelarse en
## el valor que tenía al enganchar.
func _update_glow() -> void:
	if not _glow_active or _glow_material == null:
		return
	# Se usa EXACTAMENTE la misma fracción que la potencia del wall jump, no una escala aparte: así
	# brillo pleno significa literalmente "el rebote sale al 100%", meseta incluida. El brillo deja
	# de ser decorado y pasa a ser el indicador de cuándo saltar.
	_update_glow_color(lerpf(glow_energy_min, glow_energy_max, _wall_jump_power_frac(wall_normal)))

func _set_smoke(active: bool) -> void:
	if _smoke == null:
		return
	if active and not _smoke.emitting:
		_smoke.restart()
		_smoke.emitting = true
	elif not active and _smoke.emitting:
		# Como PushSmoke: corta la emision, no las nubes que ya estan disolviendose.
		_smoke.emitting = false

## Flecha de debug creada por código (top_level, se dibuja en espacio de mundo). Arranca oculta.
func _build_arrow() -> void:
	_arrow_mesh = ImmediateMesh.new()
	_arrow_material = StandardMaterial3D.new()
	_arrow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arrow_material.albedo_color = Color(1.0, 0.85, 0.15)
	_arrow_material.no_depth_test = true  # visible a través de la geometría, es ayuda de tuning
	_arrow = MeshInstance3D.new()
	_arrow.mesh = _arrow_mesh
	_arrow.material_override = _arrow_material
	_arrow.top_level = true
	_arrow.visible = false
	_body.add_child(_arrow)

## Mientras deslizás (y con el toggle prendido) apunta al ángulo de lanzamiento del wall jump ahora
## mismo. Reusa _wall_jump_velocity, así la flecha muestra exactamente hacia dónde vas a salir.
func _update_arrow() -> void:
	if _arrow == null:
		return
	var show_arrow := is_sliding and _body.tuning.wall_slide_show_jump_arrow
	_arrow.visible = show_arrow
	if not show_arrow:
		return
	var launch := _wall_jump_velocity(wall_normal)
	var dir := launch.normalized() if launch.length_squared() > 0.0001 else wall_normal
	_arrow.global_position = _body.global_position + Vector3.UP
	var tip := dir * ARROW_LENGTH
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized() * 0.25
	var back := tip - dir * 0.5
	_arrow_mesh.clear_surfaces()
	_arrow_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_arrow_mesh.surface_add_vertex(Vector3.ZERO)  # arranca en el player
	_arrow_mesh.surface_add_vertex(tip)
	_arrow_mesh.surface_add_vertex(tip)           # punta de flecha
	_arrow_mesh.surface_add_vertex(back + side)
	_arrow_mesh.surface_add_vertex(tip)
	_arrow_mesh.surface_add_vertex(back - side)
	_arrow_mesh.surface_end()

func _find_wall_normal() -> Vector3:
	for index in range(_body.get_slide_collision_count()):
		var collision := _body.get_slide_collision(index)
		if collision == null:
			continue
		var collider := collision.get_collider() as CollisionObject3D
		if collider != null and (collider.collision_layer & World.LAYER_WORLD) == 0:
			continue
		var normal := collision.get_normal()
		if absf(normal.y) > 0.2:
			continue
		normal.y = 0.0
		if normal.length_squared() >= 0.0001:
			return normal.normalized()
	return Vector3.ZERO

func _find_wall_impulse_surface() -> WallImpulseSurface:
	for index in range(_body.get_slide_collision_count()):
		var collision := _body.get_slide_collision(index)
		if collision == null:
			continue
		var collider := collision.get_collider() as CollisionObject3D
		if collider != null and (collider.collision_layer & World.LAYER_WORLD) == 0:
			continue
		var normal := collision.get_normal()
		if absf(normal.y) <= 0.2:
			var surface := _wall_impulse_surface_for(collider)
			if surface != null:
				return surface
	return null

func _wall_impulse_surface_for(collider: CollisionObject3D) -> WallImpulseSurface:
	if collider == null:
		return null
	for child in collider.get_children():
		if child is WallImpulseSurface:
			return child as WallImpulseSurface
	return null

func _set_impulse_surface(surface: WallImpulseSurface) -> void:
	if surface == _impulse_surface:
		return
	if _impulse_surface != null:
		_impulse_surface.set_impulse_active(false)
	_impulse_surface = surface
	# Al pasar de la curva marcada a una pared recta sin marcador, el carril sigue vivo:
	# conserva rumbo, velocidad y altura hasta que el wall slide pierda contacto por completo.
	if is_impulsing:
		if surface != null and surface.tuning != null:
			_impulse_tuning = surface.tuning
			surface.set_impulse_active(true)
		return
	impulse_direction = Vector3.ZERO
	_impulse_velocity = Vector3.ZERO
	_impulse_tuning = null
	is_impulsing = false

func _update_wall_impulse(input_dir: Vector3, normal: Vector3, delta: float) -> void:
	# La pared toma SOLO el primer input que tenga componente a lo largo del muro.
	# Input directo hacia/afuera de la pared no define rumbo porque no es horizontal tangencial.
	var captured_now := false
	if not is_impulsing:
		if _impulse_surface == null or _impulse_surface.tuning == null:
			return
		var tangent_input := input_dir.slide(normal)
		tangent_input.y = 0.0
		if tangent_input.length_squared() < 0.0001:
			return
		impulse_direction = tangent_input.normalized()
		is_impulsing = true
		captured_now = true
		_impulse_tuning = _impulse_surface.tuning
		# El carril manda: la rampa del slide se apaga para que no curve el rumbo capturado.
		_slide_speed = 0.0
		_slide_final_speed = 0.0
		_impulse_velocity = impulse_direction * _impulse_tuning.initial_speed
		_impulse_surface.set_impulse_active(true)
	if _impulse_tuning == null:
		return
	# El primer input elige el SENTIDO, pero en una curva el vector debe seguir la tangente
	# local de la pared. Si conservaramos el vector mundial original, cada cambio de normal
	# proyectaria parte de la velocidad contra el muro y el player se frenaria.
	var wall_tangent := Vector3.UP.cross(normal)
	wall_tangent.y = 0.0
	if wall_tangent.length_squared() > 0.0001:
		wall_tangent = wall_tangent.normalized()
		if wall_tangent.dot(impulse_direction) < 0.0:
			wall_tangent = -wall_tangent
		impulse_direction = wall_tangent
	# El angulo gira la tangente alrededor de la normal: 0 = horizontal; negativo apunta
	# hacia abajo y positivo hacia arriba. La vertical se entrega al motor por separado.
	var travel_direction := impulse_direction.rotated(
			normal, deg_to_rad(_impulse_tuning.angle_degrees)).normalized()
	# El sprint escala el carril entero (arranque, aceleración y techo) con un solo canal: la pared
	# sigue mandando la forma del riel, el sprint solo decide qué tan rápido lo recorrés.
	var impulse_scale := _body.sprint_scale(PlayerSprint.WALL_IMPULSE)
	if captured_now:
		_impulse_velocity = travel_direction * _impulse_tuning.initial_speed * impulse_scale
	else:
		# La curvatura solo ROTA el rumbo, nunca lo frena: se conserva la rapidez actual sobre
		# la tangente nueva y la aceleracion trabaja solo sobre la magnitud. (Perseguir con
		# move_toward un vector objetivo recorta la cuerda del giro y en curva sostenida la
		# rapidez decae sin que ningun input lo pida.)
		var speed := move_toward(_impulse_velocity.length(),
				_impulse_tuning.max_speed * impulse_scale,
				_impulse_tuning.acceleration * impulse_scale * delta)
		_impulse_velocity = travel_direction * speed
	_body.vertical_velocity = _impulse_velocity.y
	# El emisor visual sigue el punto de contacto cada frame; no queda abandonado en el origen
	# de una pared curva o larga.
	if _impulse_surface != null:
		_impulse_surface.set_impulse_active(true, _body.global_position, normal)

## True solo si el jugador dirige el stick claramente HACIA AFUERA de la pared (alineado con
## la normal). Input neutro devuelve false → el slide se mantiene sin apretar (assist).
func _presses_away_from_wall(input_dir: Vector3, normal: Vector3) -> bool:
	input_dir.y = 0.0
	if input_dir.length_squared() < 0.0001:
		return false
	return input_dir.normalized().dot(normal) >= _body.tuning.wall_slide_input_dot
