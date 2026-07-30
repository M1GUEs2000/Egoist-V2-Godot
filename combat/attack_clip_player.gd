class_name AttackClipPlayer extends Node
## Reproduce un tramo de animación y emite los límites temporales declarados por AttackClip.
## No conoce armas, daño ni Hitbox: sus señales son la única salida de gameplay.

signal hitbox_should_open
signal hitbox_should_close
signal clip_finished

var _animation_player: AnimationPlayer
var _playing := false
var _elapsed := 0.0
var _duration := 0.0
var _hitbox_open_at := 0.0
var _hitbox_close_at := 0.0
var _hitbox_opened := false
var _hitbox_closed := false
var _playback_id := 0

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if not _playing:
		return
	var id := _playback_id
	_elapsed = minf(_elapsed + delta, _duration)
	if not _emit_due_hitbox_signals(id):
		return
	if _elapsed >= _duration:
		_finish(id)

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
	var open_normalized := clampf(c.hitbox_open, 0.0, 1.0)
	var close_normalized := clampf(c.hitbox_close, open_normalized, 1.0)

	_playback_id += 1
	_elapsed = 0.0
	_duration = maxf(0.0, real_duration)
	_hitbox_open_at = _duration * open_normalized
	_hitbox_close_at = _duration * close_normalized
	_hitbox_opened = false
	_hitbox_closed = false
	_playing = true

	_animation_player.speed_scale = span / _duration if _duration > 0.0 else 1.0
	_animation_player.play(c.clip)
	_animation_player.seek(start, true)
	set_process(true)

	var id := _playback_id
	if not _emit_due_hitbox_signals(id):
		return
	if _duration <= 0.0:
		_finish(id)

func cancel() -> void:
	_playback_id += 1
	var should_close := _playing and _hitbox_opened and not _hitbox_closed
	_playing = false
	_elapsed = 0.0
	_duration = 0.0
	_hitbox_closed = should_close or _hitbox_closed
	set_process(false)
	if _animation_player != null:
		_animation_player.speed_scale = 1.0
		_animation_player.stop()
	if should_close:
		hitbox_should_close.emit()

## Inyección interna usada por PlayerAnimationController. No forma parte del contrato
## que consumen las armas.
func _bind_animation_player(animation_player: AnimationPlayer) -> void:
	cancel()
	_animation_player = animation_player

## False indica que un receptor inició o canceló otra reproducción durante una señal.
func _emit_due_hitbox_signals(id: int) -> bool:
	if not _hitbox_opened and _elapsed >= _hitbox_open_at:
		_hitbox_opened = true
		hitbox_should_open.emit()
		if id != _playback_id:
			return false
	if not _hitbox_closed and _elapsed >= _hitbox_close_at:
		_hitbox_closed = true
		hitbox_should_close.emit()
		if id != _playback_id:
			return false
	return true

func _finish(id: int) -> void:
	if id != _playback_id or not _playing:
		return
	_playing = false
	set_process(false)
	if _animation_player != null:
		_animation_player.pause()
		_animation_player.speed_scale = 1.0
	clip_finished.emit()
