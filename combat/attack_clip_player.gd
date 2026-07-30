class_name AttackClipPlayer extends Node
## Reproduce el tramo de animación que declara un AttackClip: recorta de `start_time` a `end_time`
## y estira o comprime el tramo con speed_scale para que entre en `duration`. No conoce armas, daño
## ni Hitbox.
##
## POR QUE NO ABRE EL HITBOX. Nació con dos señales, `hitbox_should_open` y `hitbox_should_close`,
## para que el arma colgara su ventana de daño de la animación. Se quitaron al integrarlo:
##
##   1. La ventana la tiene que abrir el arma igual, porque los gestos que todavía no tienen
##      AttackClip (todos los especiales) no pasan por acá. Dos caminos para lo mismo.
##   2. `play_attack_clip` emite la apertura EN EL ACTO cuando `hitbox_open` es 0, que es el caso
##      normal. El arma nunca llegaría a tiempo a conectarse: se perdería el golpe entero.
##   3. Este nodo es uno solo, colgado del Player, y no sabe qué arma pidió el clip. Habría que
##      enrutar la señal de vuelta al arma correcta.
##
## Los dos relojes son el mismo reloj: este cuenta `_elapsed` en segundos y WeaponBase espera con
## timers los mismos segundos, los dos derivados de `duration`. No hay de qué desincronizarse.
## WeaponBase.begin_damage_window lee `hitbox_open`/`hitbox_close` del mismo AttackClip.
signal clip_finished

var _animation_player: AnimationPlayer
var _playing := false
var _elapsed := 0.0
var _duration := 0.0
var _playback_id := 0

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed = minf(_elapsed + delta, _duration)
	if _elapsed >= _duration:
		_finish(_playback_id)

func play_attack_clip(c: AttackClip) -> void:
	cancel()
	if c == null:
		push_warning("AttackClipPlayer recibió un AttackClip nulo.")
		return
	if _animation_player == null:
		push_warning("AttackClipPlayer no tiene AnimationPlayer asignado.")
		return
	if not _animation_player.has_animation(c.clip):
		push_warning("AttackClipPlayer no encontró el clip '%s'." % c.clip)
		return

	var animation := _animation_player.get_animation(c.clip)
	var start := clampf(c.start_time, 0.0, animation.length)
	var end := animation.length if c.end_time < 0.0 \
			else clampf(c.end_time, start, animation.length)
	var span := end - start
	var real_duration := c.duration if c.duration > 0.0 else span

	_playback_id += 1
	_elapsed = 0.0
	_duration = maxf(0.0, real_duration)
	_playing = true

	_animation_player.speed_scale = span / _duration if _duration > 0.0 else 1.0
	_animation_player.play(c.clip)
	_animation_player.seek(start, true)
	set_process(true)

	if _duration <= 0.0:
		_finish(_playback_id)

func cancel() -> void:
	_playback_id += 1
	_playing = false
	_elapsed = 0.0
	_duration = 0.0
	set_process(false)
	if _animation_player != null:
		_animation_player.speed_scale = 1.0
		_animation_player.stop()

## Inyección interna usada por PlayerAnimationController. No forma parte del contrato
## que consumen las armas.
func _bind_animation_player(animation_player: AnimationPlayer) -> void:
	cancel()
	_animation_player = animation_player

func _finish(id: int) -> void:
	if id != _playback_id or not _playing:
		return
	_playing = false
	set_process(false)
	if _animation_player != null:
		_animation_player.pause()
		_animation_player.speed_scale = 1.0
	clip_finished.emit()
