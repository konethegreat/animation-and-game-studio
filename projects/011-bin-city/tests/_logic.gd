extends SceneTree

const GameData = preload("res://scripts/data.gd")

var failures := 0


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS  ", name)
	else:
		failures += 1
		print("FAIL  ", name, "  ", detail)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var state = root.get_node_or_null("GameState")
	_check("state autoload exists", state != null)
	if state == null:
		print("failures: ", failures + 1)
		quit(1)
		return

	state.save_path = "user://bincity_test.cfg"
	state.delete_save()
	state.reset_new_game()
	_check("starts at rank 1", state.rank == 1)
	_check("rank 2 floor", state.rank_for_xp(600) == 2)
	_check("rank 5 floor", state.rank_for_xp(6000) == 5)
	_check("progress at start", state.rank_progress() == 0.0)
	state.add_xp(600)
	_check("xp raises rank", state.rank == 2)
	_check("rank 2 progress", state.rank_progress() == 0.0)
	state.set_flag("met_nell")
	_check("flag set", state.has_flag("met_nell"))
	state.start_quest("bakery")
	_check("quest active", state.quest_status("bakery") == "active")
	state.advance_quest("bakery", 3)
	_check("quest completes at goal", state.quest_status("bakery") == "done")
	_check("quest awards xp", state.xp == 900)
	state.save()
	state.reset_new_game()
	_check("reset clears rank", state.rank == 1)
	_check("load restores rank", state.load_save() and state.rank == 2)
	_check("load restores xp", state.xp == 900)
	_check("load restores flag", state.has_flag("met_nell"))
	_check("load restores quest", state.quest_status("bakery") == "done")
	_check("save file exists", state.has_save())

	var D = load("res://scripts/dialogue.gd")
	var dlg = D.new()
	root.add_child(dlg)
	dlg.TREES["test"] = {"lines": [
		{"speaker": "NELL", "text": "First line."},
		{"speaker": "NELL", "text": "Second line.", "flag": "heard_nell"},
	]}
	var seen := []
	dlg.line.connect(func(speaker, text, choices): seen.append(text))
	dlg.start("test")
	_check("dialogue starts", dlg.is_active())
	_check("first line emitted", seen.size() == 1)
	dlg.advance()
	_check("flag fires", state.has_flag("heard_nell"))
	dlg.advance()
	_check("dialogue ends", not dlg.is_active())
	dlg.TREES["choice"] = {
		"lines": [{"speaker": "ROOK", "text": "Pick.", "choices": [
			{"label": "A", "next": "answer", "flag": "picked_a"},
			{"label": "B", "next": ""},
		]}],
		"answer": {"lines": [{"speaker": "ROOK", "text": "Good."}]},
	}
	dlg.start("choice")
	dlg.choose(0)
	_check("choice fires flag", state.has_flag("picked_a"))
	_check("choice branches", seen.size() == 4)
	dlg.advance()
	_check("branch ends dialogue", not dlg.is_active())
	dlg.queue_free()
	await process_frame

	_check("five ranks defined", GameData.RANKS.size() == 5)
	_check("three districts defined", GameData.DISTRICTS.size() >= 3)
	_check("five shifts defined", GameData.SHIFTS.size() == 5)
	_check("rank title lookup", GameData.rank_title(3) == "SCRAP KNIGHT")
	_check("shift lookup", str(GameData.shift(2).id) == "shift_2")

	for action in ["sprint", "jump", "dash", "pulse", "vacuum", "interact"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var Player = load("res://scripts/player.gd")
	var p = Player.new()
	root.add_child(p)
	await process_frame
	p.set_rank(1)
	_check("rank 1 carry", p.max_stack == 1)
	_check("rank 1 no dash", not p.can_dash)
	p.set_rank(2)
	_check("rank 2 carry", p.max_stack == 3)
	_check("rank 2 sprint", p.ability("sprint"))
	p.set_rank(3)
	_check("rank 3 magnet", p.ability("magnet"))
	_check("rank 3 carry", p.max_stack == 5)
	_check("rank 3 dash", p.can_dash)
	_check("rank 3 parts", p.rank_parts.size() >= 9 and p.rank_parts["plates"].visible)
	p.set_rank(4)
	_check("rank 4 double jump", p.can_double_jump)
	_check("rank 4 crown", p.rank_parts["crown"].visible and p.rank_parts["cape"].visible)
	p.set_rank(5)
	_check("rank 5 pulse", p.ability("cleanse_pulse"))
	_check("rank 5 carry", p.max_stack == 12)
	_check("rank 5 bins", p.rank_parts["bins"].visible and p.rank_parts["visor"].visible)
	_check("rank five is the cap", p.rank == 5)
	p.set_rank(9)
	_check("rank clamps to five", p.rank == 5)
	p.queue_free()
	await process_frame

	var district = load("res://scripts/district.gd")
	_check("district base loads", district != null)
	var market = load("res://scripts/world.gd").new()
	root.add_child(market)
	await process_frame
	var walk_rng := RandomNumberGenerator.new()
	walk_rng.seed = 11
	var walk: Vector3 = market.random_walkable(walk_rng)
	_check("market exposes a spawn", market.spawn is Vector3)
	_check("market exposes stations", market.stations.size() >= 2)
	_check("market walks a point", walk is Vector3)
	_check("market point is free", market.is_free(walk))
	_check("market has interiors", market.interiors.size() >= 2)
	market.queue_free()
	await process_frame

	state.delete_save()
	print("failures: ", failures)
	quit(0 if failures == 0 else 1)
