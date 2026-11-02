extends Node

# Timeline player for scripted camera moves and radio lines. While active it
# owns the game camera; on finish (or skip) it restores the camera transform
# saved at start. Skip still applies every remaining flag step.

signal finished(id: String)

var active := false
var _id := ""
var _steps: Array = []
var _index := 0
var _skip_requested := false
var _cam_hold := false
var _saved_cam: Transform3D
var _held_pos := Vector3.ZERO
var _held_basis := Basis.IDENTITY
var _shake_amount := 0.0
var _shake_time := 0.0
var _shake_dur := 0.0
var _game: Node = null


func play(id: String, steps: Array) -> void:
	if active:
		_finish()
	_id = id
	_steps = steps
	_index = 0
	_skip_requested = false
	active = true
	if _game == null:
		active = false
		return
	_game.player.locked = true
	_saved_cam = _game.camera.transform
	_held_pos = _game.camera.global_position
	_held_basis = _game.camera.global_basis
	_cam_hold = true
	_game.ui.show_skip(true)
	_run.call_deferred()


func skip() -> void:
	if active:
		_skip_requested = true


func _process(delta: float) -> void:
	if not active or not _cam_hold:
		return
	var offset := Vector3.ZERO
	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		var strength := _shake_amount * (_shake_time / maxf(_shake_dur, 0.01))
		offset = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
	_game.camera.global_transform = Transform3D(_held_basis, _held_pos + offset)


func _run() -> void:
	for i in _steps.size():
		_index = i
		var step: Dictionary = _steps[i]
		var kind := str(step.get("t", ""))
		if _skip_requested and kind != "flag":
			continue
		match kind:
			"wait":
				await _wait(float(step.get("s", 1.0)))
			"line":
				await _line(step)
			"cam":
				await _cam(step)
			"flag":
				_apply_flag(str(step.get("name", "")))
			"shake":
				_shake_amount = float(step.get("amount", 0.2))
				_shake_dur = float(step.get("s", 0.5))
				_shake_time = _shake_dur
			"music":
				var sound = _game.get_node_or_null("Sound")
				if sound != null and sound.has_method("play_music"):
					sound.play_music(str(step.get("track", "")))
			"release":
				_release_cam()
	_finish()


func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds and not _skip_requested:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _line(step: Dictionary) -> void:
	var speaker := str(step.get("speaker", ""))
	var text := str(step.get("text", ""))
	if speaker != "":
		var sound = _game.get_node_or_null("Sound")
		if sound != null and sound.has_method("blip"):
			sound.blip(speaker)
	var full := "%s: %s" % [speaker, text] if speaker != "" else text
	var dur := clampf(1.8 + text.length() * 0.055, 2.6, 6.5)
	_game.ui.subtitle(full, dur)
	await _wait(dur * 0.82)


func _cam(step: Dictionary) -> void:
	var target_pos: Vector3 = step.get("pos", _held_pos)
	var look: Vector3 = step.get("look", target_pos + Vector3(0.0, 0.0, -1.0))
	var dur := maxf(float(step.get("s", 1.0)), 0.01)
	var direction := look - target_pos
	if direction.length() < 0.01:
		direction = Vector3(0.0, 0.0, 1.0)
	var end := Transform3D(Basis.IDENTITY.looking_at(direction.normalized(), Vector3.UP), target_pos)
	var start := Transform3D(_held_basis, _held_pos)
	var elapsed := 0.0
	while elapsed < dur and not _skip_requested:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var k := clampf(elapsed / dur, 0.0, 1.0)
		_held_basis = start.basis.slerp(end.basis, k)
		_held_pos = start.origin.lerp(end.origin, k)
	_held_basis = end.basis
	_held_pos = end.origin


func _release_cam() -> void:
	_game.camera.transform = _saved_cam
	_cam_hold = false
	_shake_time = 0.0


func _apply_flag(name: String) -> void:
	if name.is_empty():
		return
	var state = _game.get_node_or_null("/root/GameState")
	if state != null:
		state.set_flag(name)


func _finish() -> void:
	for i in range(_index, _steps.size()):
		var step: Dictionary = _steps[i]
		if str(step.get("t", "")) == "flag":
			_apply_flag(str(step.get("name", "")))
	if _game != null and is_instance_valid(_game.camera):
		_game.camera.transform = _saved_cam
		_game.ui.show_skip(false)
	_cam_hold = false
	_shake_time = 0.0
	active = false
	finished.emit(_id)
