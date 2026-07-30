class_name WeaponBase extends Node3D
## Arma abstracta (ex WeaponBase.cs). Estado propio: kills, nivel; la ventana de daño
## de cada swing y el motor genérico de cadenas de golpes (combos terrestre y aéreo
## comparten el mismo runner; cada arma pone solo su coreografía). Tap/hold por slot
## (World.Slot); el tuning numérico vive en un Resource en data/ (WeaponTuning).
##
## La ventana de daño reemplaza los trace-hitboxes muestreados de v1: el Hitbox de la hoja es un
## Area3D que barre físicamente con el arma (Jolt lo samplea cada physics frame, mismo grano que el
## trace de v1). En el aire se suma el disco.
##
## HAY UNA SOLA ESPADA. Hasta el refactor de animación había dos: la que se veía colgaba del hueso
## de la mano y seguía el clip, y la que golpeaba era invisible, orbitaba al player y la movían
## tweens de quaternion sobre un nodo `Hand`. Nunca coincidieron. Hoy PlayerAnimationController saca
## los meshes Y el BladeHitbox de la escena del arma y los cuelga del BoneAttachment3D del hueso:
## el arma golpea donde la animación la pone.
##
## Convención de escena de un arma (ver sword.tscn). Los nodos que van a la mano se marcan con el
## grupo `hand_attachment_payload`; lo que no, se queda en el arma y sigue centrado en el player.
##   Arma (WeaponBase)
##   ├── Hand/Pivot (Node3D)           ← percha vacía tras el reparent (ver _pivot)
##   │   ├── BladeMesh                 ← grupo hand_attachment_payload → al hueso
##   │   └── BladeHitbox (Hitbox)      ← grupo hand_attachment_payload → al hueso
##   └── AirDiscHitbox (Hitbox)        ← NO va al hueso: es un disco alrededor del player
##
## Cuándo abre y cierra el hitbox lo declara el AttackClip del golpe (`hitbox_open`/`hitbox_close`),
## no el arma. Los gestos que todavía no tienen AttackClip abren la ventana el golpe entero.

## Un golpe arrancó y muestra este tramo de clip UAL sobre el maniquí del player. Lo consume
## PlayerAnimationController, que se lo pasa a AttackClipPlayer. Viaja el AttackClip ENTERO y no
## cuatro floats sueltos: antes el controller reconstruía uno con `hitbox_open`/`hitbox_close` en
## sus defaults, así que la ventana de daño declarada en el dato se perdía en el camino.
signal visual_clip_started(clip: AttackClip)

## El golpe terminó antes de lo previsto (ej: la caída del Y aéreo del Mazo impacta antes
## del techo): la capa de animación suelta el clip y vuelve a locomoción/aire.
signal visual_clip_ended

@export var tuning: WeaponTuning

## Juice de carga: la hoja emite este color al mantener un ataque (glow proporcional a
## buffer.charge_progress()). Greybox, sin assets: emission sobre el material de la hoja.
@export var charge_glow_color := Color(1.0, 0.82, 0.28)
@export var charge_glow_max_energy := 2.5

var level := 1
var kill_count := 0
## El cargado que esta saliendo se solto dentro de la ventana de sweet spot (lo arma
## PlayerCombat al disparar el hold). Cada arma decide que efecto extra le cuelga.
var sweet_spot := false

var _player: Player
## Golpeados de la ventana de daño en curso (el finisher aéreo los spikea/empuja).
var _window_hits: Array[Hurtbox] = []
## PushSettings de la ventana en curso una vez cumplido su delay (null = sin armar).
var _armed_push: PushSettings
var _shared_dedup: Array[Hurtbox] = []
var _window_id := 0
var _routine_id := 0
var _combo_playing := false
var _combo_window_open := false
## Hasta cuándo dura el recovery post-combo (World.now): ver tuning.combo_recovery.
var _combo_recovery_until := 0.0
## Cuánto (s) se esperó entre el fin del golpe anterior y el tap que encadenó el paso
## actual (0 en el paso 1). La coreografía de cada arma puede leerlo en begin_step para
## ramificar por espera en CUALQUIER paso, no solo en branch_step (ej: el plunge de la
## Espada, X X espera X).
var chain_wait_before_step := 0.0
var _combo_queued := false
var _combo_queued_time := 0.0
var _combo_kind := &""
## La cadena en curso es un GESTO (AttackSequence.auto_chain), no un combo: no acepta encolar.
var _combo_auto := false
var _vertical_window_id := 0
var _vertical_player_mover: MoverSettings
var _vertical_enemy_mover: MoverSettings
var _vertical_starts_lying := false
# El Stun solo consulta el poise antes del dano. El perfil vertical es externo.
var _vertical_stun: StunSettings
var _active_vertical_hitbox: Hitbox
## Perfil de movimiento del ataque en curso (ver data/attack_movement_profile.gd). Uno solo: la
## rutina activa es su unica dueña, y el id de rutina define cuando caduca. Reemplaza los ids
## sueltos que cada arma guardaba por gesto para reconectar sus Movers y Floaters.
var _movement_profile: AttackMovementProfile
var _movement_profile_routine_id := -1
## Si el gesto en curso pago RT. Se guarda al armar el movimiento y no se vuelve a leer el input:
## los slots diferidos (proyectil, hang del enemigo por golpe) tienen que cobrarse con la misma
## variante con la que arranco el golpe, aunque el jugador suelte el boton a mitad de la rutina.
var _movement_profile_with_meter := false
## El proyectil se cobra una sola vez al cerrar el recorrido; una cancelacion tambien lo quema, para
## no dejar disparos tardios de un recorrido abortado.
var _movement_profile_travel_done := false

## Sigue existiendo en la escena, pero ya no orbita: PlayerAnimationController le saca los meshes y
## el BladeHitbox al hueso de la mano en cuanto el arma entra al árbol. Queda como percha de lo que
## se crea en runtime (las motas de sweet spot), que el controller también reparenta.
@onready var _pivot: Node3D = $Hand/Pivot
@onready var _blade_hitbox: Hitbox = $Hand/Pivot/BladeHitbox
@onready var _air_disc_hitbox: Hitbox = get_node_or_null("AirDiscHitbox")
@onready var _blade_mesh: MeshInstance3D = _find_charge_glow_mesh()

var _blade_material: StandardMaterial3D
## Aura de motas de la ventana de sweet spot: se crea la primera vez que la ventana abre y
## queda colgada de la hoja, prendiendo/apagando su emitting (ver set_sweet_spot_window).
var _sweet_spot_motes: GPUParticles3D

func _ready() -> void:
	if tuning == null:
		tuning = _default_tuning()
	_setup_blade_glow()

func setup(player: Player) -> void:
	_player = player
	for hitbox: Hitbox in [_blade_hitbox, _air_disc_hitbox]:
		if hitbox == null:
			continue
		hitbox.source = player
		hitbox.damage = 1.0
		hitbox.stun = tuning.stun
		hitbox.share_already_hit(_shared_dedup)
		hitbox.landed.connect(_on_hit)
	# El cierre del recorrido del Player es lo que detona los slots diferidos del perfil de
	# movimiento (hang TRAVEL_END y proyectil), asi que el enganche vive aca y no en cada arma.
	player.mover.mover_finished.connect(_on_player_mover_finished)
	player.mover.mover_cancelled.connect(_on_player_mover_cancelled)
	# Hoja y disco aéreo se parrian (decisión de diseño: v1 solo parriaba la hoja; acá
	# también el disco). El hitbox vertical no (ver Sword.setup).
	# ponytail: v1 además solo dejaba parriar en la mitad del propio swing (CanParryAt →
	# "clash" mutuo). Acá es parriable todo el swing y la ventana estrecha del enemigo ya
	# acota; afinar el clash mid-swing cuando haya Godot para tunear.

## Manda un AttackClip declarado en datos a la capa de animación (ver visual_clip_started).
## `duration` pisa la del clip cuando quien llama ya sabe cuánto dura el paso; -1 respeta la del
## Resource. No duplica el clip: el override se copia aparte para no escribir en el .tres.
func play_attack_clip(clip: AttackClip, duration := -1.0) -> void:
	if clip == null or clip.clip == &"":
		return
	if duration > 0.0 and not is_equal_approx(duration, clip.duration):
		var stretched := clip.duplicate() as AttackClip
		stretched.duration = duration
		visual_clip_started.emit(stretched)
		return
	visual_clip_started.emit(clip)

## Atajo para los gestos que todavía tienen su tramo hardcodeado en constantes del arma (los
## especiales: cargados, launchers, direccionales). Arma un AttackClip al vuelo con la ventana de
## daño completa —0 a 1, o sea el comportamiento de siempre— porque esos gestos aún abren su ventana
## por temporizador. Cuando cada especial tenga su AttackClip en el tuning, esto se borra.
func play_visual_clip(clip: StringName, start_time := 0.0, end_time := -1.0,
		duration := -1.0) -> void:
	var built := AttackClip.new()
	built.clip = clip
	built.start_time = start_time
	built.end_time = end_time
	built.duration = maxf(0.0, duration)
	visual_clip_started.emit(built)

func end_visual_clip() -> void:
	visual_clip_ended.emit()

# ---- API que enruta PlayerCombat (cada arma define sus personalidades) ----

func tap(_slot: World.Slot) -> void:
	pass

func hold(_slot: World.Slot, _level: int) -> void:
	pass

## Gancho opcional para gestos direccionales que PlayerCombat haya reconocido. Devuelve true
## solo si el arma consumio el input y ya arranco su ataque especial.
func try_lock_back_y_launcher() -> bool:
	return false

## Duracion del buffer para el gesto "tap atras + Y". Cero lo desactiva para esta arma.
func lock_back_y_launcher_window() -> float:
	return 0.0

## Gancho para tap adelante + Y relativo al lock-on. Las armas que no lo usan lo dejan apagado.
func try_lock_forward_y_push() -> bool:
	return false

func lock_forward_y_push_window() -> float:
	return 0.0

## Ganchos para tap adelante/atras + X relativo al lock-on. Las armas que no los usan los dejan
## apagados y PlayerCombat cae al tap normal del slot X.
func try_lock_forward_x_static_spin() -> bool:
	return false

func lock_forward_x_static_spin_window() -> float:
	return 0.0

func try_lock_back_x_retreat() -> bool:
	return false

func lock_back_x_retreat_window() -> float:
	return 0.0

## PlayerCombat llama esto antes de resetear la pose del arma en un press.
## Si hay una cadena activa, ese press puede ser solo un input encolado para el próximo
## golpe: resetear la rotación acá hace que armas pesadas como el Mazo parezcan reiniciar
## el swing con cada click. La Espada ya se sentía bien por timing, pero el contrato correcto
## es no tocar la pose mientras el runner de combo sigue vivo.
func should_reset_pose_on_press() -> bool:
	return not _combo_playing

## Nivel de carga (1-based) para una duración de hold sostenida. Default: un solo
## nivel (comportamiento actual de la Espada, que ignora _level). El Mazo lo
## sobreescribe para sus 3 niveles de vueltas cargadas.
func charge_level(_held_time: float) -> int:
	return 1

## Barras que costaría soltar AHORA el cargado de este slot. Es SOLO el preview del HUD (ver
## PlayerCombat.charge_meter_preview): el cobro real lo sigue haciendo cada rutina con
## spend_charged. Default: el precio de lista de un cargado. Cada arma cuyo cargado salga gratis,
## escale por nivel o lleve descuento lo sobreescribe — si esto miente, el HUD marca barras que
## no se van a gastar, que es peor que no mostrar nada.
func charged_meter_cost(_slot: World.Slot, _held_time: float) -> float:
	return _player.tuning.meter_charged_cost if _player != null else 0.0

# ---- Motor genérico de cadenas de golpes (ex PlayAerialCombo, hoy también terrestre) ----

## Un tap mientras corre una cadena del mismo tipo: encola el siguiente golpe si la
## ventana está abierta (si no, mid-swing, se ignora). Devuelve true si el tap fue
## consumido; false si no hay cadena de este tipo corriendo y hay que arrancar una.
func try_queue_combo(kind: StringName) -> bool:
	# Un gesto no encadena por input, así que encolarle un tap se lo TRAGA: devolvería true (input
	# consumido) y después el runner nunca lo mira. Devolver false deja que el tap arranque su combo,
	# que es lo que ya pasa hoy cuando un tap interrumpe un cargado.
	if not _combo_playing or _combo_auto or _combo_kind != kind:
		return false
	if _combo_window_open:
		_combo_queued = true
		_combo_queued_time = World.now()
	return true

## Cadena de N golpes, UN tap por golpe, con ventana de encadene entre golpes.
## begin_step(step, finisher, wait_branch) pone la coreografía del golpe; la ventana de
## daño y el ComboTracker los pone el motor. Tras branch_step, tardar al menos
## branch_threshold (dentro de la ventana) en encadenar activa la rama "espera".
## finish(wait_branch) corre al completar el finisher (si es válida). Arrancar una
## cadena invalida cualquier otra en curso (routine_id compartido).
## wait_branch_extra_steps: si la rama "espera" se activa en branch_step, el total
## de golpes de esta corrida pasa de steps a steps + wait_branch_extra_steps (0 =
## la rama solo cambia coreografía, no cantidad — comportamiento de la Espada).
func run_combo_chain(kind: StringName, steps: int, step_time: float, chain_window: float,
		branch_step: int, branch_threshold: float,
		begin_step: Callable, finish := Callable(), wait_branch_extra_steps := 0) -> void:
	# Recovery post-combo: completar un combo deja esta ventana muerta; los taps que
	# intentan arrancar otro se ignoran (los cargados no pasan por acá y siguen saliendo).
	if World.now() < _combo_recovery_until:
		return
	var id := begin_routine()
	_combo_playing = true
	_combo_kind = kind
	chain_wait_before_step = 0.0
	var wait_branch := false
	var total_steps := steps

	var step := 1
	while step <= total_steps:
		_combo_queued = false
		_combo_window_open = false
		var finisher := step == total_steps
		begin_step.call(step, finisher, wait_branch)
		begin_damage_window(step_time)
		ComboTracker.register_hit()
		await wait_seconds(step_time)
		if id != _routine_id:
			return
		var step_end := World.now()

		if finisher:
			if finish.is_valid():
				finish.call(wait_branch)
			# Combo COMPLETO: se cobra el recovery. Cortar la cadena a mitad no lo cobra.
			_combo_recovery_until = World.now() + tuning.combo_recovery
			break

		# Ventana de encadene: esperar el siguiente tap o cortar la cadena.
		_combo_window_open = true
		var expiry := World.now() + chain_window
		while World.now() < expiry and not _combo_queued:
			await get_tree().process_frame
			if id != _routine_id:
				return
		_combo_window_open = false
		if not _combo_queued:
			break
		chain_wait_before_step = maxf(0.0, _combo_queued_time - step_end)
		if step == branch_step:
			wait_branch = chain_wait_before_step >= branch_threshold
			if wait_branch:
				total_steps += wait_branch_extra_steps
		step += 1

	_combo_playing = false
	_combo_window_open = false

# ---- Motor de secuencias declaradas en datos (reemplaza a run_combo_chain) ----

## Corre una cadena de golpes descrita por un AttackSequence. Es el sucesor de run_combo_chain: en
## vez de recibir la forma de la cadena como seis parámetros y delegar la coreografía en Callables,
## recorre los AttackStep del Resource, que traen su clip, su duración, su daño y su movimiento.
##
## LA DIFERENCIA DE FONDO ES UNA VENTANA DE DAÑO POR PASO. run_combo_chain abría UNA ventana estirada
## sobre toda la cadena, así que N golpes cobraban una sola vez — el tap adelante + X ya salía con
## dos vueltas y un solo impacto. Acá cada paso abre y cierra la suya, y como Hitbox.begin_swing()
## limpia el dedup, el mismo enemigo vuelve a ser golpeable en el paso siguiente: N golpes son N
## impactos, N register_hit y N aplicaciones de stun. El daño total se controla por paso con
## AttackStep.damage_scale, no bajando el daño base del arma (que también afecta a los especiales).
##
## CORRE LAS DOS FORMAS DE GOLPE, y la diferencia es un bool del Resource:
##
##   - COMBO (`auto_chain` apagado): cada paso se gana con un tap dentro de `chain_window`, y puede
##     ramificar por espera. Es lo que hacen tap X terrestre y aéreo.
##   - GESTO (`auto_chain` prendido): los pasos salen solos, uno tras otro. Es lo que permite que un
##     cargado o una secuencia de RT sean N animaciones con N ventanas de daño y un Mover en el paso
##     que se quiera, en vez de un clip suelto con una ventana estirada encima.
##
## El arma sigue decidiendo lo que NO es dibujo ni daño: si el gesto cuesta barra, si requiere estar
## en el aire, a dónde apunta. Eso se resuelve antes de llamar acá.
##
## Arrancar una cadena invalida cualquier otra en curso (routine_id compartido).
func run_attack_sequence(kind: StringName, sequence: AttackSequence) -> void:
	if sequence == null or sequence.steps.is_empty() or _player == null:
		return
	# Recovery post-cadena: completarla deja esta ventana muerta. Cortarla a mitad no la cobra.
	# Solo frena COMBOS. Un gesto (auto_chain) es un move deliberado que además ya pagó su barra:
	# que se lo coma la cola de un combo se siente roto, y hasta hoy no pasaba porque los cargados
	# no corrían por acá. El gesto sigue dejando SU recovery al terminar, eso no cambia.
	if not sequence.auto_chain and World.now() < _combo_recovery_until:
		return
	var id := begin_routine()
	_combo_playing = true
	_combo_kind = kind
	_combo_auto = sequence.auto_chain
	chain_wait_before_step = 0.0

	var steps := sequence.steps
	var index := 0
	# Número de golpe dentro de la CADENA, no dentro del array: tras ramificar el índice vuelve a
	# cero pero la numeración sigue. Es lo que ve la coreografía del arma (on_sequence_step), no
	# lo que decide las ramas — esas cuelgan del paso.
	var chain_step := 1

	while index < steps.size():
		var step := steps[index]
		var finisher := index == steps.size() - 1
		_combo_queued = false
		_combo_window_open = false
		var duration := _step_duration(step, sequence)
		_begin_sequence_step(step, chain_step, finisher, duration, id)
		await wait_seconds(duration)
		if id != _routine_id:
			return
		var step_end := World.now()

		if finisher:
			_combo_recovery_until = World.now() + sequence.recovery_seconds(tuning.combo_recovery)
			break

		# Un GESTO de varios tramos (un cargado, una secuencia de RT) no pide input entre pasos: ya se
		# decidió cuando se disparó. Sin esto se quedaba esperando un tap que nunca llega y el gesto
		# salía con su primer paso nada más. Un gesto tampoco ramifica: no hay espera que medir.
		if sequence.auto_chain:
			index += 1
			chain_step += 1
			continue

		# Ventana de encadene: esperar el siguiente tap o cortar la cadena.
		_combo_window_open = true
		var expiry := World.now() + sequence.chain_window
		while World.now() < expiry and not _combo_queued:
			await get_tree().process_frame
			if id != _routine_id:
				return
		_combo_window_open = false
		if not _combo_queued:
			break

		chain_wait_before_step = maxf(0.0, _combo_queued_time - step_end)
		# Ramificar es LOCAL al paso que acaba de salir: si declaró una espera y se cumplió, sus
		# wait_steps reemplazan todo lo que venía después. Como cada paso lleva sus propias ramas,
		# la cadena puede ramificar tantas veces como golpes tenga (X X espera X espera X X X).
		if step.wait_threshold > 0.0 and not step.wait_steps.is_empty() \
				and chain_wait_before_step >= step.wait_threshold:
			steps = step.wait_steps
			index = -1
		index += 1
		chain_step += 1

	_combo_playing = false
	_combo_window_open = false
	_combo_auto = false

## Segundos de un paso: manda su propio clip, después el default de la cadena, y al final el
## swing_time del arma. Así un paso puede ser más lento que sus vecinos sin tocar a nadie más.
func _step_duration(step: AttackStep, sequence: AttackSequence) -> float:
	if step.clip != null and step.clip.duration > 0.0:
		return step.clip.duration
	if sequence.step_time > 0.0:
		return sequence.step_time
	return tuning.swing_time

## Arranca un paso: daño, clip, coreografía del arma, avance, empuje, movimiento y ventana. Es
## fire-and-forget igual que el resto de la coreografía; quien mide el tiempo es el runner.
func _begin_sequence_step(step: AttackStep, chain_step: int, finisher: bool, duration: float,
		id: int) -> void:
	# El perfil de daño se rearma en CADA paso en vez de multiplicarse encima del anterior: si no,
	# una cadena de cuatro con damage_scale 0.6 terminaría en 0.13 del daño base por acumulación.
	reset_hit_profile()
	_apply_step_damage(step)
	play_attack_clip(step.clip, duration)
	on_sequence_step(step, chain_step, finisher)
	if step.advances:
		_player.attack_step(duration)
	if step.pushes:
		arm_push(tuning.push, duration * tuning.push_at)
	# Se llama SIEMPRE, también con movement en null: así el perfil del paso anterior no sobrevive al
	# siguiente. Sin esto un paso sin movimiento heredaría el perfil del previo —misma rutina, mismo
	# id, o sea "vigente"— y el cierre de su ventana cobraría hooks que no le pertenecen.
	run_attack_movement(step.movement, id)
	# Los hooks de cierre (EnemyTravelAt.WINDOW_END, player_travel_at_window_end) se cobran al cerrar
	# el último paso Y al cerrar cualquier paso que traiga perfil propio. Lo segundo es lo que hace
	# que "el Mover sale en el tercer golpe" funcione de verdad: si solo los cobrara el finisher, un
	# paso intermedio con recorrido diferido lo declararía y no pasaría nada. Un paso sin perfil no
	# cobra nada aunque se lo pidas — _run_window_end_travel no hace nada si no hay nada declarado.
	begin_damage_window(duration, finisher or step.movement != null, step.clip)
	ComboTracker.register_hit()
	if step.fires_projectile:
		var launcher: MoverSettings = null
		if step.movement != null:
			launcher = step.movement.rt_projectile_enemy_mover
		_fire_attack_projectile(launcher)

## Mismo recorte en 0 que los bonos del perfil (ver _rt_scale): un daño negativo no significa nada.
## La local NO se llama `scale`: eso sombrearía la propiedad de Node3D.
func _apply_step_damage(step: AttackStep) -> void:
	if is_equal_approx(step.damage_scale, 1.0):
		return
	var factor := maxf(0.0, step.damage_scale)
	_blade_hitbox.damage *= factor
	if _air_disc_hitbox != null:
		_air_disc_hitbox.damage *= factor

## Gancho por paso para lo que NO es tuning: el arco procedural de la mano mientras siga existiendo
## (cada arma traduce AttackStep.choreography a su tween) y las mecánicas propias del arma que no
## tienen sentido como campo genérico — estirar los hitboxes de un finisher, sostener al Player en
## el aire durante el combo terrestre. Default no-op.
func on_sequence_step(_step: AttackStep, _chain_step: int, _finisher: bool) -> void:
	pass

# ---- Combo aéreo (la coreografía la define cada arma) ----

## Cuántos golpes tiene el combo aéreo de esta arma (0 = no tiene). El último es el finisher.
func air_steps() -> int:
	return 0

## Swing visual del golpe aéreo N (1-based). wait_branch = tras el golpe 1 se esperó
## (rama de vueltas + empuje en vez de diagonal + spike). Default no-op.
func play_air_step(_step: int, _finisher: bool, _wait_branch: bool) -> void:
	pass

## N golpes aéreos sobre el motor genérico. Si tapeás rápido tras el golpe 1 → rama
## base (finisher spikea al suelo). Si esperás → rama de vueltas (finisher empuja).
func play_aerial_combo() -> void:
	if air_steps() <= 0 or _player == null:
		return
	if try_queue_combo(&"air"):
		return
	run_combo_chain(&"air", air_steps(), tuning.air_step_time, tuning.air_combo_window,
			1, tuning.air_wait_branch_threshold, _begin_air_step, _finish_air_combo)

func _begin_air_step(step: int, finisher: bool, wait_branch: bool) -> void:
	play_air_step(step, finisher, wait_branch)
	if finisher and wait_branch:
		arm_push(tuning.push, tuning.air_step_time * tuning.push_at)
	_player.attack_step(tuning.air_step_time)  # avanza hacia el lockeado / al frente, igual que en tierra
	# Sin hit no se aplica control vertical: la caída conserva gravedad normal.

## Solo lo lanzable reacciona (has_method): una pared golpeada se ignora.
func _finish_air_combo(wait_branch: bool) -> void:
	if wait_branch:
		return  # el push ya lo armó _begin_air_step
	for hurtbox in _window_hits.duplicate():
		var target: Node = hurtbox.owner_node
		if target.has_method("slam"):
			target.call("slam", tuning.air_spike_down_speed)

# ---- Ventana de daño ----

## Prende el Hitbox de la hoja durante el swing (+ disco aéreo si el player está en el
## aire, como v1). Los golpeados quedan en _window_hits. Fire-and-forget: se llama sin await.
##
## `runs_profile_hooks` en false deja el cierre MUDO para el AttackMovementProfile. Lo usa el runner
## de secuencias en los pasos que no son el último: el perfil describe el gesto completo, así que un
## recorrido WINDOW_END tiene que salir una vez al terminar la cadena y no una vez por golpe.
##
## `clip` recorta la ventana al tramo que el dato declara: el hitbox abre en `hitbox_open` y cierra
## en `hitbox_close`, los dos normalizados sobre `duration`. Sin clip la ventana dura el golpe
## entero, que es lo que hacían TODOS los gestos antes de este refactor y lo que siguen haciendo los
## especiales. El golpe siempre termina a los `duration` segundos aunque el hitbox cierre antes: el
## recorrido WINDOW_END del perfil marca el fin del GESTO, no el fin del daño.
func begin_damage_window(duration: float, runs_profile_hooks := true,
		clip: AttackClip = null) -> void:
	_window_id += 1
	var id := _window_id
	_window_hits.clear()
	var open_delay := 0.0 if clip == null else clip.open_delay(duration)
	var open_time := duration if clip == null else clip.open_seconds(duration)
	# El umbral no es 0 sino un milisegundo: wait_seconds tiene piso de 0.01s, así que esperar un
	# residuo de coma flotante retrasaría el golpe un frame entero por nada.
	if open_delay > 0.001:
		await wait_seconds(open_delay)
		if id != _window_id:
			return
	_blade_hitbox.begin_swing()
	if _air_disc_hitbox != null and _player != null and _player.is_airborne():
		_air_disc_hitbox.begin_swing()
	await wait_seconds(open_time)
	if id != _window_id:
		return  # otro swing ya arrancó: él es dueño de los hitboxes ahora
	_blade_hitbox.end_swing()
	if _air_disc_hitbox != null:
		_air_disc_hitbox.end_swing()
	# El sobrante entre el cierre del hitbox y el fin del golpe. Con la ventana completa es 0 y esto
	# no espera nada, así que el timing de los especiales no se mueve.
	var tail := duration - open_delay - open_time
	if tail > 0.001:
		await wait_seconds(tail)
		if id != _window_id:
			return
	# Los recorridos WINDOW_END del perfil se cobran acá y no en cada arma: es el único punto que
	# sabe que la ventana cerró bien. Si el perfil no pidió ese momento, no hace nada.
	if runs_profile_hooks:
		_run_window_end_travel()

func end_damage_window() -> void:
	_window_id += 1
	_window_hits.clear()
	if _blade_hitbox != null:
		_blade_hitbox.end_swing()
	if _air_disc_hitbox != null:
		_air_disc_hitbox.end_swing()

func end_vertical_window() -> void:
	_vertical_window_id += 1
	if _active_vertical_hitbox != null:
		_active_vertical_hitbox.end_swing()
		_active_vertical_hitbox = null

## Arma el push de esta ventana. Tras `delay` segundos empuja a todo lo golpeado hasta
## ese momento y queda armado: lo que conecte después se empuja en el instante del hit.
func arm_push(settings: PushSettings, delay: float) -> void:
	if settings == null:
		return
	var id := _routine_id
	await wait_seconds(delay)
	if not is_routine_current(id):
		return
	_armed_push = settings
	_push_window_hits(settings)

## Empuja a los golpeados de la ventana en curso.
func _push_window_hits(settings: PushSettings) -> void:
	for hurtbox in _window_hits.duplicate():
		if is_instance_valid(hurtbox):
			_push_target(hurtbox, settings)

## Solo lo empujable reacciona (has_method): una pared golpeada se ignora.
func _push_target(hurtbox: Hurtbox, settings: PushSettings) -> void:
	var target: Node = hurtbox.owner_node
	if is_instance_valid(target) and target.has_method("push"):
		target.call("push", _player.forward(), settings)

## Reacción común a cualquier golpe conectado del arma (hoja, disco, vertical, dash
## cargado): air-hit-stall + meter + progresión de kills.
func register_weapon_hit(hurtbox: Hurtbox, died: bool, cuts_air_momentum := true,
		triggers_player_float := true) -> void:
	# Conectar en el aire contra algo que lo dispara ralentiza la caída del jugador, y (si el golpe
	# es normal) le come momentum horizontal. Los cargados pasan cuts_air_momentum = false; cada
	# ruta puede desactivar triggers_player_float si ya tiene un Mover/Floater propio.
	if triggers_player_float and hurtbox.triggers_air_hit_stall:
		_register_air_hit_float(cuts_air_momentum)
	var meter := _player.meter
	if meter != null:
		meter.gain_on_hit(tuning.meter_gain_on_hit)
		if died:
			meter.gain_on_kill(tuning.meter_gain_on_kill)
	if died:
		if _player.is_airborne():
			_player.apply_air_kill_reset()
		on_kill()

func _register_air_hit_float(cuts_momentum: bool) -> void:
	if _player.is_on_floor():
		return
	if cuts_momentum:
		_player.bump_velocity *= clampf(tuning.air_hit_momentum_keep, 0.0, 1.0)
		_player.locomotion.scale_air_velocity(tuning.air_hit_momentum_keep)
	var f := tuning.air_hit_player_floater
	if f == null:
		return
	_player.request_float(f.duration, f.fall_scale)

## Hay un move CARGADO en curso sobre este hitbox. Lo usa el corte de momentum aéreo para dejar
## pasar los cargados (que mueven al jugador a propósito). Cada arma lo sobreescribe con su flag;
## los hitbox exclusivos de un cargado no necesitan esto: llaman register_weapon_hit con false.
func is_charged_move_active() -> bool:
	return false

func _on_hit(hurtbox: Hurtbox, died: bool) -> void:
	_window_hits.append(hurtbox)
	if _armed_push != null:
		_push_target(hurtbox, _armed_push)
	# Recorrido ON_HIT del perfil: sale para cualquier golpe del arma sin que la rutina pida nada,
	# así prenderlo o apagarlo es solo poner/sacar el Mover en el inspector.
	request_profile_enemy_travel(hurtbox)
	register_weapon_hit(hurtbox, died, not is_charged_move_active())
	VfxInjector.spawn_impact(tuning.hit_vfx_scene, _player.get_parent(), hurtbox.global_position,
			tuning.hit_vfx_scale)

# ---- Progresión ----

func on_kill() -> void:
	kill_count += 1
	if level < tuning.max_level and kill_count >= tuning.kills_to_upgrade * level:
		level += 1

# ---- Juice: glow de carga en la hoja ----

## Prepara un material propio en la hoja con emission apagada (energy 0), listo para el
## glow de carga. Duplica el material base para no pisar otras instancias del arma.
func _find_charge_glow_mesh() -> MeshInstance3D:
	var preferred := get_node_or_null("Hand/Pivot/BladeMesh") as MeshInstance3D
	if preferred != null:
		return preferred
	# El Mazo no tiene BladeMesh: su parte visible/cargable es la cabeza.
	preferred = get_node_or_null("Hand/Pivot/HeadMesh") as MeshInstance3D
	if preferred != null:
		return preferred
	return get_node_or_null("Hand/Pivot/HandleMesh") as MeshInstance3D

func _setup_blade_glow() -> void:
	if _blade_mesh == null:
		return
	var base := _blade_mesh.get_active_material(0)
	if base is StandardMaterial3D:
		_blade_material = (base as StandardMaterial3D).duplicate()
	else:
		_blade_material = StandardMaterial3D.new()
	_blade_material.emission_enabled = true
	_blade_material.emission = charge_glow_color
	_blade_material.emission_energy_multiplier = 0.0
	_blade_mesh.set_surface_override_material(0, _blade_material)

## Intensidad del glow de carga, 0→1 (lo llama PlayerCombat con buffer.charge_progress()).
func set_charge_glow(t: float) -> void:
	if _blade_material != null:
		_blade_material.emission_energy_multiplier = clampf(t, 0.0, 1.0) * charge_glow_max_energy

# ---- Sweet spot: ventana de timing al cargar ----

## La ventana de sweet spot esta abierta AHORA (lo llama PlayerCombat mientras se carga):
## la hoja escupe motas mientras dure. Es el unico aviso de "solta ahora", asi que se prende
## y se apaga en el mismo frame que la ventana real que lee arm_sweet_spot.
func set_sweet_spot_window(open: bool) -> void:
	if not tuning.sweet_spot_particles_enabled:
		return
	if _sweet_spot_motes == null:
		if not open:
			return  # todavia no hizo falta: no armamos el emisor hasta la primera ventana
		_sweet_spot_motes = World.make_color_motes(tuning.sweet_spot_particle_color,
				tuning.sweet_spot_particle_emission, tuning.sweet_spot_particle_amount,
				tuning.sweet_spot_particle_lifetime, tuning.sweet_spot_particle_size,
				tuning.sweet_spot_particle_radius, tuning.sweet_spot_particle_rise_speed)
		_pivot.add_child(_sweet_spot_motes)
	_sweet_spot_motes.emitting = open

## Marca si el cargado que sale ahora es sweet spot, segun cuanto se sostuvo el press.
## Lo llama PlayerCombat justo antes de hold(): el arma lee `sweet_spot` en su rutina.
func arm_sweet_spot(held_time: float) -> void:
	sweet_spot = tuning.in_sweet_spot(held_time)
	set_sweet_spot_window(false)

# ---- Movimiento por ataque (ver data/attack_movement_profile.gd) ----
## Arma el movimiento de un gesto desde su perfil. Lo que pasa en el acto (recorrido del Player, hang
## de inicio) sale aca; todo lo diferido —recorrido del Enemy en cualquiera de sus tres momentos,
## hang del enemigo por golpe, proyectil— lo cobra este mismo nodo cuando llega su momento, leyendo
## el perfil activo. Por eso el arma no tiene que pedir nada por gesto: agregar o sacar un Mover es
## poner o vaciar un slot en el inspector. Un perfil nuevo reemplaza al anterior y el id de rutina lo
## hace caducar solo.
##
## `with_meter` es el eje RT: elige si los bonos porcentuales del perfil entran o valen 1.0. No
## cambia QUE hace el golpe salvo por `rt_only`, que es el unico caso donde el recorrido existe solo
## con barra.
##
## `profile` en null es un caso valido y esperado: significa "este golpe no mueve a nadie".
##
## Devuelve true solo si realmente arranco un recorrido del Player. El arma lo necesita para saber
## si tiene que esperar un `mover_finished`: darlo por hecho mirando `player_travel != null` deja el
## bookkeeping colgado cuando el recorrido no sale (perfil `rt_only` sin barra, facing degenerado, o
## un recorrido diferido a WINDOW_END, que todavia no arranco).
##
## `start_player_now` en false arma el perfil sin tocar al Player. Lo usan las ventanas verticales,
## que arrancan el recorrido ellas mismas tras su propio delay (ver run_vertical_window_from_profile).
func run_attack_movement(profile: AttackMovementProfile, routine_id: int,
		with_meter := false, start_player_now := true) -> bool:
	_movement_profile = profile
	_movement_profile_routine_id = routine_id
	_movement_profile_with_meter = with_meter
	_movement_profile_travel_done = false
	if profile == null or not start_player_now:
		return false
	_warn_if_hang_is_shadowed(profile)
	if not _profile_is_payable(profile, with_meter):
		return false
	if profile.player_travel_at_window_end:
		return false  # lo arranca _run_window_end_travel al cerrar la ventana de dano
	return _start_player_travel(profile, with_meter)

## `rt_only`: el movimiento se escribe en la base pero solo se cobra con RT. Un perfil que no se paga
## no mueve a nadie, ni al Player ni al Enemy.
func _profile_is_payable(profile: AttackMovementProfile, with_meter: bool) -> bool:
	return not profile.rt_only or with_meter

func _start_player_travel(profile: AttackMovementProfile, with_meter: bool) -> bool:
	var started := false
	if profile.player_travel != null:
		var travel := _resolve_travel(profile, with_meter)
		if travel != null:
			_player.request_mover(travel)
			started = true
	_request_player_hang(profile, with_meter)
	return started

## Multiplicador de un bono porcentual del perfil: 1.0 sin RT, 1 + bono/100 con RT. Mismo modelo que
## PlayerSprint.scale — el bono se aplica en el consumidor y nunca sobre el .tres, asi el valor base
## sigue leyendose tal cual en el inspector. Se recorta en 0 para que un -100 apague el canal en vez
## de invertirlo (una duracion o una distancia negativas no significan nada).
func _rt_scale(bonus_percent: float, with_meter: bool) -> float:
	if not with_meter:
		return 1.0
	return maxf(0.0, 1.0 + bonus_percent * 0.01)

## Clona el recorrido y le aplica de una vez las dos cosas que se resuelven en runtime: la direccion
## (avances y retrocesos se orientan contra el facing, que el gesto ya fijo al objetivo lockeado) y
## los bonos de RT. Se clona SIEMPRE que haya algo que reescribir, para no mutar el recurso
## compartido del .tres. Devuelve null si el facing quedo degenerado.
func _resolve_travel(profile: AttackMovementProfile, with_meter: bool) -> MoverSettings:
	var settings := profile.player_travel
	var mode := profile.player_direction
	var direction := Vector3.ZERO
	if mode != AttackMovementProfile.Direction.PROFILE:
		direction = _player.forward()
		if mode == AttackMovementProfile.Direction.PLAYER_BACK:
			direction = -direction
		direction.y = 0.0
		if direction.length_squared() < 0.0001:
			return null
		direction = direction.normalized()
	if direction == Vector3.ZERO and not with_meter:
		return settings  # nada que reescribir: se usa el recurso tal cual
	var resolved := settings.duplicate() as MoverSettings
	if direction != Vector3.ZERO:
		resolved.direction = direction
	resolved.distance *= _rt_scale(profile.rt_player_travel_distance_bonus, with_meter)
	resolved.speed *= _rt_scale(profile.rt_player_travel_speed_bonus, with_meter)
	resolved.acceleration *= _rt_scale(profile.rt_player_travel_acceleration_bonus, with_meter)
	# El hang que dispara el propio Mover al terminar es el MISMO canal que `player_hang`: un solo
	# slider los cubre a los dos, asi el diseñador no tiene que acordarse de cual uso este golpe.
	resolved.float_duration *= _rt_scale(profile.rt_player_hang_bonus, with_meter)
	return resolved

func _request_player_hang(profile: AttackMovementProfile, with_meter: bool) -> void:
	var settings := profile.player_hang
	if settings == null:
		return
	var duration := settings.duration * _rt_scale(profile.rt_player_hang_bonus, with_meter)
	if duration > 0.0:
		_player.request_float(duration, settings.fall_scale)

## Un `player_hang` junto a un `player_travel` no se aplica NUNCA: mientras corre el Mover, el Mover
## es dueno de la vertical (en TOTAL el loop del Player hace return antes de leer el Floater; en
## PARTIAL lo sobreescribe el mismo frame). El hang de despues de un recorrido va en
## `player_travel.float_duration`. Se avisa en vez de fallar en silencio, que es como falla hoy.
func _warn_if_hang_is_shadowed(profile: AttackMovementProfile) -> void:
	if profile.player_travel == null or profile.player_hang == null:
		return
	if profile.player_hang.duration <= 0.0:
		return
	push_warning("%s: perfil con player_travel y player_hang a la vez. El hang no se aplica (el " % name
			+ "Mover es dueno de la vertical mientras recorre). Usar player_travel.float_duration.")

## Mover del Enemy que el perfil activo pide en ESTE momento, o null. Un perfil de otra rutina ya
## caduco y no cobra nada, y uno `rt_only` sin barra tampoco.
func _profile_enemy_travel(at: AttackMovementProfile.EnemyTravelAt) -> MoverSettings:
	if not _movement_profile_is_current():
		return null
	if _movement_profile.enemy_travel_at != at:
		return null
	if not _profile_is_payable(_movement_profile, _movement_profile_with_meter):
		return null
	return _movement_profile.enemy_travel

## Recorrido ON_HIT: el enemigo que acaba de conectar se mueve DESPUES del dano. Lo llama _on_hit
## para cualquier golpe del arma, asi que un spike se prende y se apaga solo desde el inspector.
## Devuelve true si hubo Mover que pedir.
func request_profile_enemy_travel(hurtbox: Hurtbox) -> bool:
	var settings := _profile_enemy_travel(AttackMovementProfile.EnemyTravelAt.ON_HIT)
	if settings == null:
		return false
	_move_enemy(hurtbox.owner_node, settings)
	return true

## Cierre de la ventana de dano: arranca lo que el perfil dejo esperando a este momento — el
## recorrido del Player si lo difirio, y el del Enemy sobre TODO lo golpeado en la ventana. Es el
## plunge: arrancarlos durante el swing saca al objetivo del alcance del propio golpe.
func _run_window_end_travel() -> void:
	if not _movement_profile_is_current():
		return
	var profile := _movement_profile
	var with_meter := _movement_profile_with_meter
	if not _profile_is_payable(profile, with_meter):
		return
	if profile.player_travel_at_window_end:
		# Se ignora el retorno: el gesto que difiere su recorrido ya no esta esperando el swing, y
		# el cierre lo avisa igual _on_player_mover_finished.
		_start_player_travel(profile, with_meter)
	var settings := _profile_enemy_travel(AttackMovementProfile.EnemyTravelAt.WINDOW_END)
	if settings == null:
		return
	for hurtbox in _window_hits.duplicate():
		if is_instance_valid(hurtbox):
			_move_enemy(hurtbox.owner_node, settings)

## Le pide un Mover a un cuerpo golpeado, por duck typing (el dummy de pruebas no es EnemyBase).
## Si el perfil pide alinear, el objetivo se sube/baja a la altura del Player ANTES de arrancar,
## pero solo si el Mover realmente va a poder entrar: alinear a un enemigo entero seria
## teletransportarlo y dejarlo ahi parado.
func _move_enemy(target: Node, settings: MoverSettings) -> void:
	if not is_instance_valid(target) or not target.has_method("request_mover"):
		return
	if _movement_profile.enemy_travel_aligns_y:
		if not _enemy_can_take_travel(target):
			return
		if target is Node3D:
			(target as Node3D).global_position.y = _player.global_position.y
	if target is EnemyBase:
		(target as EnemyBase).request_mover(settings)
	else:
		target.call("request_mover", settings)

## Mismas condiciones que EnemyBase.can_accept_vertical_control, por duck typing.
func _enemy_can_take_travel(target: Node) -> bool:
	if target.has_method("is_airborne") and not target.call("is_airborne"):
		return false
	if target.has_method("is_stunned") and not target.call("is_stunned"):
		return false
	return true

## Hang del enemigo que acaba de conectar, si el perfil activo define uno propio. Devuelve false
## cuando no lo define, para que el arma caiga a su hold generico (air_hit_enemy_floater).
func request_profile_enemy_hang(hurtbox: Hurtbox) -> bool:
	if not _movement_profile_is_current():
		return false
	var settings := _movement_profile.enemy_on_hit
	if settings == null or settings.duration <= 0.0:
		return false
	var duration := settings.duration \
			* _rt_scale(_movement_profile.rt_enemy_hang_bonus, _movement_profile_with_meter)
	# Un bono de -100 apaga el hang pero el perfil SIGUE siendo su dueno: se devuelve true para que
	# el arma no caiga a su hold generico. "Con RT el enemigo no cuelga" es una decision del gesto.
	if duration > 0.0:
		var target: Node = hurtbox.owner_node
		if target is EnemyBase:
			(target as EnemyBase).request_float(duration, settings.fall_scale)
		elif target.has_method("request_float"):
			target.call("request_float", duration, settings.fall_scale)
	return true

## True si el golpe en curso se hace cargo de la vertical del Player por su cuenta. Lo consultan el
## corte de momentum aereo y el air-hit-stall generico para no pisarle el Mover/Floater propio.
func attack_movement_overrides_air_hit() -> bool:
	return _movement_profile_is_current() and _movement_profile.overrides_air_hit

func _movement_profile_is_current() -> bool:
	return _movement_profile != null and _movement_profile_routine_id == _routine_id

## El recorrido del Player cerro bien: se cobran los slots que lo esperaban. El hook corre siempre,
## haya perfil o no, porque las armas lo usan para su propio bookkeeping de combo.
func _on_player_mover_finished(_reason: int) -> void:
	_on_attack_movement_ended()
	if not _movement_profile_is_current() or _movement_profile_travel_done:
		return
	_movement_profile_travel_done = true
	# El hang de salida ya lo detono el propio Mover desde su `float_duration` (ver combat/mover.gd):
	# aca solo queda el proyectil, que es premio de RT y por eso pide las dos condiciones.
	if _movement_profile.rt_fires_projectile and _movement_profile_with_meter:
		_fire_attack_projectile(_movement_profile.rt_projectile_enemy_mover)

## Recorrido abortado (stun, muerte, Mover nuevo, regla del ataque): quema los slots diferidos sin
## cobrarlos. El hang del enemigo NO se toca: sigue vivo mientras dure la rutina del golpe.
func _on_player_mover_cancelled(_reason: int) -> void:
	_movement_profile_travel_done = true
	_on_attack_movement_ended()

## Hook para que el arma cierre su propio bookkeeping cuando el recorrido del Player termina, sin
## importar si fue exito o cancelacion.
func _on_attack_movement_ended() -> void:
	pass

## Dispara el proyectil del ataque. Solo lo implementan las armas que tienen uno.
func _fire_attack_projectile(_enemy_mover: MoverSettings) -> void:
	pass

# ---- Ventana vertical genérica (cono/área que mueve antes de golpear) ----
## Cablea un Hitbox vertical: nunca se parria, mueve al objetivo ANTES del daño
## (about_to_hit) así el golpe ya ve is_airborne = true, y alimenta meter/air-hit-stall
## al conectar (landed → _on_hit). Cada arma llama esto en su setup() para su propio
## hitbox vertical.
func setup_vertical_hitbox(hitbox: Hitbox, deals_damage: bool, stun_settings: StunSettings,
		starts_lying := false) -> void:
	hitbox.source = _player
	hitbox.damage = 1.0 if deals_damage else 0.0
	hitbox.stun = stun_settings
	hitbox.can_be_parried = false
	_vertical_stun = stun_settings
	_vertical_starts_lying = starts_lying
	hitbox.about_to_hit.connect(_on_vertical_about_to_hit)
	hitbox.landed.connect(_on_hit)

## El perfil del Enemy se pide antes del dano para que el Stun vea al objetivo en el aire.
func _on_vertical_about_to_hit(hurtbox: Hurtbox) -> void:
	var target: Node = hurtbox.owner_node
	if _vertical_enemy_mover == null:
		return
	if target is EnemyBase:
		(target as EnemyBase).request_mover(_vertical_enemy_mover, _vertical_stun,
				_vertical_starts_lying, true)
	elif target.has_method("request_mover"):
		target.call("request_mover", _vertical_enemy_mover)

## Ventana vertical desde un AttackMovementProfile: es la forma que usan los ataques migrados, con
## run_vertical_window abajo como mecanismo. Arma el perfil SIN arrancar el recorrido del Player —en
## un launcher ese recorrido sale con el hitbox, tras el delay, no al empezar el golpe— y le entrega
## los dos Movers ya resueltos. El del Enemy se pasa solo si el perfil pidio BEFORE_DAMAGE: es el
## unico momento que esta ventana sabe cobrar (los otros dos los cobran _on_hit y el cierre de la
## ventana de dano). Que el Player se mueva o no sale de que su slot este puesto, no de un bool.
func run_vertical_window_from_profile(hitbox: Hitbox, profile: AttackMovementProfile,
		routine_id: int, duration: float, delay := 0.05, with_meter := false) -> void:
	run_attack_movement(profile, routine_id, with_meter, false)
	var player_mover: MoverSettings = null
	var enemy_mover: MoverSettings = null
	if profile != null and _profile_is_payable(profile, with_meter):
		if profile.player_travel != null:
			player_mover = _resolve_travel(profile, with_meter)
		if profile.enemy_travel_at == AttackMovementProfile.EnemyTravelAt.BEFORE_DAMAGE:
			enemy_mover = profile.enemy_travel
	run_vertical_window(hitbox, player_mover, enemy_mover, duration, delay, player_mover != null)

## Ventana de daño vertical con id-guard: espera `delay`, opcionalmente mueve al Player y
## prende el hitbox `duration` segundos. Una ventana nueva invalida la anterior.
func run_vertical_window(hitbox: Hitbox, player_mover: MoverSettings, enemy_mover: MoverSettings,
		duration: float, delay := 0.05, moves_player := true) -> void:
	_vertical_window_id += 1
	var id := _vertical_window_id
	_vertical_player_mover = player_mover
	_vertical_enemy_mover = enemy_mover
	await wait_seconds(delay)
	if id != _vertical_window_id:
		return
	if moves_player and _vertical_player_mover != null:
		_player.request_mover(_vertical_player_mover)
	_active_vertical_hitbox = hitbox
	hitbox.begin_swing()
	ComboTracker.register_hit()
	await wait_seconds(duration)
	if id != _vertical_window_id:
		return
	hitbox.end_swing()
	if _active_vertical_hitbox == hitbox:
		_active_vertical_hitbox = null

# ---- Helpers ----

## Arranca una rutina cancelable: invalida cualquier otra en curso (combo, vueltas
## cargadas, ventanas de sweet spot) y devuelve el id con el que hay que chequear tras
## cada await (`is_routine_current`). TODA entrada de ataque debe pasar por acá: si una
## rutina vieja sobrevive, sigue pisando el hitbox y el Pivot de la que arrancó recién.
func begin_routine() -> int:
	_routine_id += 1
	end_damage_window()
	end_vertical_window()
	_armed_push = null
	_combo_playing = false
	_combo_window_open = false
	_combo_auto = false
	_combo_kind = &""
	return _routine_id

## False si otra rutina arrancó mientras esta esperaba: hay que retornar sin tocar nada
## (el hitbox y el Pivot ya son de la rutina nueva).
func is_routine_current(id: int) -> bool:
	return id == _routine_id

## Hook de los gestos direccionales que permiten cargar durante su animacion. El arma concreta
## devuelve true hasta que su movimiento actual termina; PlayerCombat retiene el hold mientras tanto.
func directional_special_is_active() -> bool:
	return false

## Invalida las rutinas en curso (combos): cada una chequea su id tras cada await.
func cancel_routines() -> void:
	begin_routine()

## Devuelve hoja y disco aéreo a su perfil de daño/stun base. Toda entrada de ataque la
## llama antes de customizarlo: así una rutina cancelada a mitad (que dejó damage 0.0 o
## el stun congelante puesto, ver Mazo) no contamina el golpe siguiente.
func reset_hit_profile() -> void:
	for hitbox: Hitbox in [_blade_hitbox, _air_disc_hitbox]:
		if hitbox != null:
			hitbox.damage = 1.0
			hitbox.stun = tuning.stun

func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(maxf(0.01, seconds)).timeout

func _default_tuning() -> WeaponTuning:
	return WeaponTuning.new()
