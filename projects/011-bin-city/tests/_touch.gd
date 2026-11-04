extends SceneTree

# Headless touch acceptance test for phones. Every pad has to be reachable
# with any finger, the pads must not sit on top of each other or the copy,
# and the real game must walk and jump from a simulated finger.

var failures := 0
var xf := Transform2D.IDENTITY
var ui: CanvasLayer = null
var missing := {}

var interact_hits := 0
var pause_hits := 0
var shift_hits: Array = []
var sort_choice_hits: Array = []
var sort_close_hits := 0
var dialogue_next_hits := 0
var dialogue_choice_hits: Array = []
var skip_hits := 0
var looked_total := Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS  ", name)
	else:
		failures += 1
		print("FAIL  ", name, "  ", detail)


# ------------------------------------------------------------------ helpers

func _size(want: Vector2i) -> void:
	root.size = want
	await process_frame
	await process_frame
	xf = root.get_final_transform()


func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = xf * at
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await process_frame


func _drag(index: int, from: Vector2, to: Vector2) -> void:
	await _drag_raw(index, to, xf.basis_xform(to - from))


func _drag_raw(index: int, at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = xf * at
	event.relative = relative
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await process_frame
	await process_frame


func _tap(index: int, at: Vector2) -> void:
	await _touch(index, at, true)
	await _touch(index, at, false)


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.device = 0
	move.position = xf * at
	move.global_position = move.position
	Input.parse_input_event(move)
	Input.flush_buffered_events()
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.device = 0
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = xf * at
		event.global_position = event.position
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	await process_frame


func _pad(name: String) -> Control:
	if ui == null or ui.touch_root == null:
		return null
	return ui.touch_root.find_child(name, true, false) as Control


func _button_with_text(node: Node, text: String) -> BaseButton:
	if node == null:
		return null
	if node is BaseButton and (node as BaseButton).text == text:
		return node
	for child in node.get_children():
		var found := _button_with_text(child, text)
		if found != null:
			return found
	return null


func _center(node: Control) -> Vector2:
	return node.get_global_rect().get_center()


func _overlap(a: Rect2, b: Rect2) -> bool:
	return a.intersection(b).get_area() > 0.01


func _touch_on() -> bool:
	return ui != null and ui.get("touch_mode") == true


func _call(method: String, args: Array = []) -> bool:
	if ui != null and ui.has_method(method):
		ui.callv(method, args)
		return true
	if not missing.has(method):
		missing[method] = true
		_check("ui exposes " + method, false)
	return false


func _visible(name: String) -> bool:
	var pad := _pad(name)
	return pad != null and pad.visible


# -------------------------------------------------------------------- run

func _run() -> void:
	await _size(Vector2i(1600, 720))
	ui = load("res://scripts/ui.gd").new()
	root.add_child(ui)
	await process_frame
	await process_frame
	ui.interact_pressed.connect(func() -> void: interact_hits += 1)
	ui.pause_pressed.connect(func() -> void: pause_hits += 1)
	ui.shift_pressed.connect(func(index: int) -> void: shift_hits.append(index))
	ui.sort_choice.connect(func(kind: String) -> void: sort_choice_hits.append(kind))
	ui.sort_closed.connect(func() -> void: sort_close_hits += 1)
	ui.dialogue_next.connect(func() -> void: dialogue_next_hits += 1)
	ui.dialogue_choice.connect(func(index: int) -> void: dialogue_choice_hits.append(index))
	ui.skip_pressed.connect(func() -> void: skip_hits += 1)
	ui.look_pad.looked.connect(func(relative: Vector2) -> void: looked_total += relative)

	await _test_activation()
	await _test_visibility()
	await _test_layout()
	await _test_rank_gates()
	await _test_holds()
	await _test_use()
	await _test_stick()
	await _test_look()
	await _test_reset()
	await _test_sort()
	await _test_dialogue()
	await _test_title()
	await _test_hud()

	ui.queue_free()
	ui = null
	await process_frame
	await process_frame

	await _test_end_to_end()

	print("failures: ", failures)
	quit(0 if failures == 0 else 1)


# --------------------------------------------------------------- activation

func _test_activation() -> void:
	ui.set_phase("title")
	await process_frame
	_check("touch stays off on a desktop boot", ui.get("touch_mode") != true, "touch_mode=%s" % ui.get("touch_mode"))
	_check("the pads are hidden before a touch", not ui.touch_root.is_visible_in_tree())
	ui.set_phase("play")
	await process_frame
	await _tap(0, Vector2(800, 60))
	var mode: bool = ui.get("touch_mode") == true
	_check("a tap turns touch mode on", mode, "touch_mode=%s" % ui.get("touch_mode"))
	_check("touch_available follows the mode", ui.touch_available() == true)
	_check("the pads show in play", ui.touch_root.is_visible_in_tree())


# --------------------------------------------------------------- visibility

func _test_visibility() -> void:
	if not _touch_on():
		return
	for phase in ["title", "sort", "pause", "results"]:
		ui.set_phase(phase)
		await process_frame
		_check("the pads hide in " + phase, not ui.touch_root.is_visible_in_tree())
	ui.set_phase("play")
	await process_frame
	_check("the pads show in play", ui.touch_root.is_visible_in_tree())
	ui.open_dialogue("NELL QUILL", "Morning.", [])
	await process_frame
	_check("the pads hide during dialogue", not ui.touch_root.is_visible_in_tree())
	ui.close_dialogue()
	await process_frame
	_check("the pads return after dialogue", ui.touch_root.is_visible_in_tree())
	ui.show_skip(true)
	await process_frame
	_check("the pads hide for the skip label", not ui.touch_root.is_visible_in_tree())
	ui.show_skip(false)
	await process_frame
	_check("the pads return after the skip label", ui.touch_root.is_visible_in_tree())


# ------------------------------------------------------------------- layout

func _test_layout() -> void:
	if not _touch_on():
		return
	_call("set_touch_rank", [5])
	for size in [Vector2i(1280, 720), Vector2i(1600, 720), Vector2i(1280, 960)]:
		await _layout_case(size)


func _layout_case(size: Vector2i) -> void:
	await _size(size)
	ui.set_phase("play")
	await process_frame
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	ui.prompt("PAD CHECK %s" % size)
	ui.subtitle("Keep the flow alive.", 30.0)
	await process_frame
	await process_frame
	_check("the prompt shows in touch mode at %s" % size, ui.prompt_panel.is_visible_in_tree())
	_check("the subtitle shows at %s" % size, ui.subtitle_panel.is_visible_in_tree())
	var prompt_rect: Rect2 = ui.prompt_panel.get_global_rect()
	var subtitle_rect: Rect2 = ui.subtitle_panel.get_global_rect()
	var stick_rect: Rect2 = ui.stick.get_global_rect()
	var pads: Array = []
	for name in ["Vacuum", "Jump", "Use", "Dash", "Pulse"]:
		var pad := _pad(name)
		_check("%s pad exists at %s" % [name, size], pad != null)
		if pad == null:
			continue
		pads.append(pad)
		_check("%s pad is visible at %s" % [name, size], pad.is_visible_in_tree())
		var rect := pad.get_global_rect()
		_check("%s pad stays on screen at %s" % [name, size], screen.encloses(rect), str(rect))
		_check("%s pad clears the prompt at %s" % [name, size], not _overlap(rect, prompt_rect), str(rect))
		_check("%s pad clears the subtitle at %s" % [name, size], not _overlap(rect, subtitle_rect), str(rect))
		_check("%s pad clears the stick zone at %s" % [name, size], not _overlap(rect, stick_rect), str(rect))
	for i in pads.size():
		for j in range(i + 1, pads.size()):
			var a: Control = pads[i]
			var b: Control = pads[j]
			_check("%s and %s do not overlap at %s" % [a.name, b.name, size], not _overlap(a.get_global_rect(), b.get_global_rect()))
	var look_rect: Rect2 = ui.look_pad.get_global_rect()
	_check("the stick and look zones do not overlap at %s" % size, not _overlap(stick_rect, look_rect))
	var top_right := ui.hud.find_child("TopRight", true, false) as Control
	_check("the HUD top right panel is named at %s" % size, top_right != null)
	if top_right != null:
		_check("the stick zone clears the HUD at %s" % size, not _overlap(stick_rect, top_right.get_global_rect()))
		_check("the look zone clears the HUD at %s" % size, not _overlap(look_rect, top_right.get_global_rect()))


# --------------------------------------------------------------- rank gates

func _test_rank_gates() -> void:
	if not _touch_on():
		return
	await _size(Vector2i(1600, 720))
	ui.set_phase("play")
	await process_frame
	_call("set_touch_rank", [1])
	await process_frame
	_check("rank 1 shows vacuum", _visible("Vacuum"))
	_check("rank 1 shows jump", _visible("Jump"))
	_check("rank 1 shows use", _visible("Use"))
	_check("rank 1 hides dash", not _visible("Dash"))
	_check("rank 1 hides pulse", not _visible("Pulse"))
	_call("set_touch_rank", [3])
	await process_frame
	_check("rank 3 shows dash", _visible("Dash"))
	_check("rank 3 hides pulse", not _visible("Pulse"))
	_call("set_touch_rank", [5])
	await process_frame
	_check("rank 5 shows dash", _visible("Dash"))
	_check("rank 5 shows pulse", _visible("Pulse"))


# ------------------------------------------------------------------- holds

func _test_holds() -> void:
	if not _touch_on():
		return
	_call("set_touch_rank", [5])
	ui.set_phase("play")
	await process_frame
	var vacuum := _pad("Vacuum")
	if vacuum == null or ui.stick == null:
		return
	var vc := _center(vacuum)
	await _touch(0, vc, true)
	_check("vacuum holds with one finger", ui.touch_wants_vacuum())
	await _touch(0, vc, false)
	_check("vacuum releases", not ui.touch_wants_vacuum())
	var sc := _center(ui.stick)
	await _touch(0, sc, true)
	await _drag(0, sc, sc + Vector2(0, -160))
	_check("the stick holds while a second finger works", ui.touch_move().y > 0.9, str(ui.touch_move()))
	for pair in [["Jump", "jump"], ["Dash", "dash"], ["Pulse", "pulse"], ["Vacuum", "vacuum"]]:
		var pad := _pad(pair[0])
		if pad == null:
			continue
		var pc := _center(pad)
		await _touch(1, pc, true)
		_check("%s presses with a second finger" % pair[0], _wants(pair[1]))
		await _touch(1, pc, false)
		_check("%s releases with a second finger" % pair[0], not _wants(pair[1]))
		_check("the stick survives a tap on %s" % pair[0], ui.touch_move().y > 0.9)
	await _touch(0, sc + Vector2(0, -160), false)
	_check("the stick stops when the finger lifts", ui.touch_move() == Vector2.ZERO)


func _wants(kind: String) -> bool:
	match kind:
		"jump":
			return ui.touch_wants_jump()
		"dash":
			return ui.touch_wants_dash()
		"pulse":
			return ui.touch_wants_pulse()
		"vacuum":
			return ui.touch_wants_vacuum()
	return false


# --------------------------------------------------------------------- use

func _test_use() -> void:
	if not _touch_on():
		return
	var use := _pad("Use")
	if use == null:
		return
	interact_hits = 0
	await _tap(0, _center(use))
	_check("a tap fires USE", interact_hits == 1, str(interact_hits))
	var sc := _center(ui.stick)
	await _touch(0, sc, true)
	await _drag(0, sc, sc + Vector2(0, -160))
	await _tap(1, _center(use))
	_check("a second finger fires USE while walking", interact_hits == 2, str(interact_hits))
	await _touch(0, sc + Vector2(0, -160), false)


# ------------------------------------------------------------------- stick

func _test_stick() -> void:
	if not _touch_on():
		return
	var sc := _center(ui.stick)
	await _touch(0, sc, true)
	await _drag(0, sc, sc + Vector2(0, -50))
	var move: Vector2 = ui.touch_move()
	_check("a half push walks forward", move.y > 0.5, str(move))
	_check("a half push stays centred", absf(move.x) < 0.2, str(move))
	_check("a half push does not sprint", not ui.touch_wants_sprint())
	await _drag(0, sc + Vector2(0, -50), sc + Vector2(0, -160))
	_check("a full push sprints", ui.touch_wants_sprint())
	_check("a full push walks forward hard", ui.touch_move().y > 0.9, str(ui.touch_move()))
	await _drag(0, sc + Vector2(0, -160), sc + Vector2(50, 0))
	_check("a side push strafes right", ui.touch_move().x > 0.5, str(ui.touch_move()))
	var held: Vector2 = ui.touch_move()
	var vacuum := _pad("Vacuum")
	if vacuum != null:
		var vc := _center(vacuum)
		await _touch(1, vc, true)
		await _drag(1, vc, vc + Vector2(20, 20))
		_check("a second finger on vacuum leaves the stick alone", absf(ui.touch_move().x - held.x) < 0.01 and absf(ui.touch_move().y - held.y) < 0.01, str(ui.touch_move()))
		await _touch(1, vc + Vector2(20, 20), false)
	await _touch(0, sc + Vector2(50, 0), false)
	_check("a released stick reports zero", ui.touch_move() == Vector2.ZERO, str(ui.touch_move()))


# -------------------------------------------------------------------- look

func _test_look() -> void:
	if not _touch_on():
		return
	looked_total = Vector2.ZERO
	var sc := _center(ui.stick)
	var look := Vector2(1200, 324)
	await _touch(0, sc, true)
	await _touch(1, look, true)
	await _drag_raw(1, look + Vector2(30, 0), Vector2(500, 0))
	await _drag_raw(1, look + Vector2(60, 0), Vector2(500, 0))
	_check("look follows the finger, not the browser delta", absf(looked_total.x - 60.0) <= 1.0, str(looked_total))
	await _touch(1, look + Vector2(60, 0), false)
	await _touch(0, sc, false)


# ------------------------------------------------------------------- reset

func _test_reset() -> void:
	if not _touch_on():
		return
	var sc := _center(ui.stick)
	await _touch(0, sc, true)
	await _drag(0, sc, sc + Vector2(0, -160))
	var vacuum := _pad("Vacuum")
	if vacuum == null:
		return
	var vc := _center(vacuum)
	await _touch(1, vc, true)
	ui.set_phase("sort")
	await process_frame
	_check("the sort screen hides the pads", not ui.touch_root.is_visible_in_tree())
	_check("a phase change clears the stick", ui.touch_move() == Vector2.ZERO, str(ui.touch_move()))
	_check("a phase change clears vacuum", not ui.touch_wants_vacuum())
	ui.set_phase("play")
	await process_frame
	_check("the pads do not stick after a phase change", ui.touch_move() == Vector2.ZERO and not ui.touch_wants_vacuum())
	await _touch(0, sc + Vector2(0, -160), false)
	await _touch(1, vc, false)
	var v2 := _center(vacuum)
	await _touch(2, v2, true)
	_check("a later finger can vacuum", ui.touch_wants_vacuum())
	await _touch(2, v2, false)
	var s2 := _center(ui.stick)
	await _touch(3, s2, true)
	await _drag(3, s2, s2 + Vector2(40, 0))
	_check("a later finger can steer", absf(ui.touch_move().x) > 0.2, str(ui.touch_move()))
	await _touch(3, s2 + Vector2(40, 0), false)


# -------------------------------------------------------------------- sort

func _test_sort() -> void:
	if not _touch_on():
		return
	ui.set_phase("sort")
	ui.open_sort({"name": "Tin can", "swatch": Color.GRAY, "kind": "metal"}, 0, 4, 1.0)
	await process_frame
	await process_frame
	sort_choice_hits.clear()
	sort_close_hits = 0
	var expected := {"glass": 1, "metal": 2, "paper": 3, "compost": 4}
	for kind in ["glass", "metal", "paper", "compost"]:
		var button := ui.sort_buttons[kind] as Control
		await _tap(0, _center(button))
		_check("a tap sorts %s" % kind, sort_choice_hits.size() == int(expected[kind]), str(sort_choice_hits))
	var paper := ui.sort_buttons["paper"] as Control
	await _touch(0, Vector2(40, 40), true)
	await _tap(1, _center(paper))
	_check("a second finger sorts while the dimmer is held", sort_choice_hits.size() == 5, str(sort_choice_hits))
	await _touch(0, Vector2(40, 40), false)
	var close := _button_with_text(ui.sort_layer, "CLOSE AND KEEP THE HOPPER")
	_check("the sort screen offers a close button", close != null)
	if close != null:
		await _tap(0, _center(close))
		_check("a tap closes the sort screen", sort_close_hits == 1, str(sort_close_hits))
	await _click(_center(ui.sort_buttons["glass"] as Control))
	_check("a mouse click still sorts", sort_choice_hits.size() == 6, str(sort_choice_hits))
	ui.set_phase("play")
	await process_frame


# ---------------------------------------------------------------- dialogue

func _test_dialogue() -> void:
	if not _touch_on():
		return
	ui.set_phase("play")
	await process_frame
	dialogue_next_hits = 0
	ui.open_dialogue("NELL QUILL", "Morning, sweeper.", [])
	await process_frame
	await _tap(0, _center(ui.dialogue_panel))
	_check("a tap advances the dialogue", dialogue_next_hits == 1, str(dialogue_next_hits))
	await _touch(0, Vector2(40, 40), true)
	await _tap(1, _center(ui.dialogue_panel))
	_check("a second finger advances the dialogue", dialogue_next_hits == 2, str(dialogue_next_hits))
	await _touch(0, Vector2(40, 40), false)
	await _click(_center(ui.dialogue_panel))
	_check("a mouse click does not double advance", dialogue_next_hits == 2, str(dialogue_next_hits))
	ui.open_dialogue("NELL QUILL", "Pick one.", [{"label": "Yes"}, {"label": "No"}])
	await process_frame
	ui.finish_typing()
	await process_frame
	await process_frame
	var yes := _button_with_text(ui.dialogue_panel, "YES")
	var no := _button_with_text(ui.dialogue_panel, "NO")
	_check("choices appear after the reveal", yes != null and no != null and yes.visible and no.visible)
	if yes != null:
		dialogue_next_hits = 0
		dialogue_choice_hits.clear()
		await _tap(0, _center(yes))
		_check("a tap picks a choice", dialogue_choice_hits == [0], str(dialogue_choice_hits))
		_check("a choice does not also advance", dialogue_next_hits == 0, str(dialogue_next_hits))
	ui.close_dialogue()
	await process_frame


# ------------------------------------------------------------------- title

func _test_title() -> void:
	if not _touch_on():
		return
	ui.set_phase("title")
	ui.show_shifts([{"index": 1, "unlocked": true, "title": "DAWN MARKET", "latest": 1}])
	await process_frame
	await process_frame
	var row := _button_with_text(ui.title_layer, "SHIFT 1   DAWN MARKET")
	_check("the title offers the shift", row != null)
	if row == null:
		return
	shift_hits.clear()
	await _tap(0, _center(row))
	_check("a tap starts a shift", shift_hits == [1], str(shift_hits))
	await _touch(0, Vector2(1200, 100), true)
	await _tap(1, _center(row))
	_check("a second finger starts a shift", shift_hits == [1, 1], str(shift_hits))
	await _touch(0, Vector2(1200, 100), false)
	await _click(_center(row))
	_check("a mouse click still starts a shift", shift_hits == [1, 1, 1], str(shift_hits))
	ui.set_phase("play")
	await process_frame


# --------------------------------------------------------------------- hud

func _test_hud() -> void:
	if not _touch_on():
		return
	ui.set_phase("play")
	await process_frame
	pause_hits = 0
	var pause := _button_with_text(ui.hud, "PAUSE")
	_check("the pause button is reachable", pause != null)
	if pause == null:
		return
	var sc := _center(ui.stick)
	await _touch(0, sc, true)
	await _tap(1, _center(pause))
	_check("a second finger pauses while walking", pause_hits == 1, str(pause_hits))
	await _touch(0, sc, false)
	skip_hits = 0
	ui.show_skip(true)
	await process_frame
	var skip := _button_with_text(ui.hud, "SKIP  >>")
	_check("the skip button is reachable", skip != null)
	if skip != null:
		await _tap(0, _center(skip))
		_check("a tap skips the cutscene", skip_hits == 1, str(skip_hits))
	ui.show_skip(false)
	await process_frame


# --------------------------------------------------------------- end to end

func _test_end_to_end() -> void:
	var state = root.get_node_or_null("GameState")
	_check("GameState autoload survives", state != null)
	if state == null:
		return
	state.save_path = "user://bincity_touch_test.cfg"
	state.delete_save()
	state.reset_new_game()
	state.rank = 3
	state.xp = state.xp_floor(3)
	state.set_flag("cold_open")
	state.set_flag("seen_dawn_market")
	var sound = root.get_node_or_null("Sound")
	if sound != null:
		sound.muted = true
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	await _size(Vector2i(1600, 720))
	game._start_shift()
	var started := false
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		if game.cutscene.active:
			game.cutscene.skip()
		if not game.transitioning and not game.transition.is_covering() and not game.player.locked and game.phase == "play":
			started = true
			break
		await process_frame
	_check("the shift starts headless", started, "phase=" + str(game.phase))
	if not started:
		game.queue_free()
		state.delete_save()
		return
	await _tap(0, Vector2(800, 60))
	_check("the real game turns touch on after a tap", game.ui.touch_available())
	var dash: Control = game.ui.touch_root.find_child("Dash", true, false) as Control
	var pulse: Control = game.ui.touch_root.find_child("Pulse", true, false) as Control
	_check("rank 3 shows dash in the real game", dash != null and dash.visible)
	_check("rank 3 hides pulse in the real game", pulse != null and not pulse.visible)
	var stick: Control = game.ui.stick
	var start_pos: Vector3 = game.player.global_position
	var cam: Camera3D = game.get_viewport().get_camera_3d()
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var sc := _center(stick)
	await _touch(0, sc, true)
	await _drag(0, sc, sc + Vector2(0, -160))
	await create_timer(0.7).timeout
	var moved: Vector3 = game.player.global_position - start_pos
	moved.y = 0.0
	_check("the stick walks the player forward", moved.dot(fwd) > 0.4, "moved=%s fwd=%s" % [moved, fwd])
	await _touch(0, sc + Vector2(0, -160), false)
	await process_frame
	var jumped := [0]
	game.player.jumped.connect(func(_double: bool) -> void: jumped[0] += 1)
	var jump: Control = game.ui.touch_root.find_child("Jump", true, false) as Control
	_check("the real game shows a jump pad", jump != null and jump.visible)
	if jump != null:
		var jc := _center(jump)
		await _touch(1, jc, true)
		await create_timer(0.2).timeout
		await _touch(1, jc, false)
		_check("a tap on jump makes the player jump", jumped[0] > 0, str(jumped[0]))
	game.queue_free()
	state.delete_save()
	await process_frame
