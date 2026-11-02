extends SceneTree

const GameData = preload("res://scripts/data.gd")
const LITTER = preload("res://scripts/litter.gd")

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
	_check("night shift flagged", bool(GameData.shift(3).get("night", false)) and bool(GameData.shift(4).get("night", false)))
	_check("boss shift sits at the plant district", str(GameData.shift(5).get("district", "")) == "neon_arcade")
	_check("every shift has a brief", str(GameData.shift(1).get("brief", "")) != "" and str(GameData.shift(5).get("brief", "")) != "")
	state.unlock_shift(3)
	_check("shift unlock raises the floor", state.unlocked_shift == 3)
	state.unlock_shift(99)
	_check("shift unlock clamps to five", state.unlocked_shift == 5)
	state.unlocked_shift = 1
	state.save()

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
	for entry in market.interiors:
		_check("door %s has a title" % entry.id, str(entry.title) != "")
		_check("door %s returns to a free spot" % entry.id, market.is_free(entry.return_pos))
	market.queue_free()
	await process_frame

	var interiors = load("res://scripts/interiors.gd")
	var room_ids := ["depot", "bakery", "boathouse", "arcade", "plant"]
	for id in room_ids:
		var room = interiors.build(id)
		root.add_child(room)
		await process_frame
		_check("room %s builds" % id, room.title != "" and room.greeting != "")
		_check("room %s spawn is free" % id, room.is_free(room.spawn))
		_check("room %s exit is at the door" % id, room.exit_pos.z > room.spawn.z)
		_check("room %s seats a crowd" % id, room.crowd_points().size() >= 3)
		_check("room %s is parked far away" % id, room.position == interiors.OFFSET)
		_check("room %s has a tip" % id, interiors.tip(id) != "")
		if id == "depot":
			_check("depot keeps the save desk", room.has_save)
			_check("depot fronts a desk", room.stations.size() >= 1)
		room.queue_free()
		await process_frame

	var canal = load("res://scripts/canal_quarter.gd").new()
	root.add_child(canal)
	await process_frame
	_check("canal builds a quarter", canal.title == "CANAL QUARTER")
	_check("canal spawn is free", canal.is_free(canal.spawn))
	_check("canal seats a crowd", canal.crowd_points().size() >= 8)
	_check("canal has three drains", canal.drains.size() == 3)
	for i in canal.drains.size():
		_check("canal drain %d starts clogged" % i, bool(canal.drains[i].clogged))
		_check("canal drain %d sits on dry land" % i, not canal.is_water(canal.drains[i].pos))
	_check("canal door has a title", str(canal.interiors[0].title) != "")
	_check("canal door returns to a free spot", canal.is_free(canal.interiors[0].return_pos))
	var canal_rng := RandomNumberGenerator.new()
	canal_rng.seed = 47
	for i in 12:
		var spot: Vector3 = canal.float_spot(canal_rng)
		_check("canal float spot %d is on water" % i, canal.is_water(spot))
	for i in 3:
		_check("canal grime spot %d is on dry land" % i, not canal.is_water(canal.next_grime_spot()))
	canal.clear_drain(1)
	_check("canal drain can be cleared", not bool(canal.drains[1].clogged))
	canal.set_night(true)
	_check("canal night flips the mood", canal.mood == "night")
	canal.queue_free()
	await process_frame

	var grime_litter = load("res://scripts/litter.gd").new()
	var kind_rng := RandomNumberGenerator.new()
	kind_rng.seed = 5
	grime_litter.build("grime", kind_rng)
	_check("grime is compost litter", grime_litter.sort_kind == "compost" and grime_litter.kind == "grime")
	grime_litter.queue_free()
	var float_litter = load("res://scripts/litter.gd").new()
	float_litter.build("float_bottle", kind_rng)
	_check("float bottle knows it floats", float_litter.floating and float_litter.kind == "float_bottle")
	float_litter.queue_free()
	var token_litter = load("res://scripts/litter.gd").new()
	token_litter.build("token", kind_rng)
	_check("token is metal litter", token_litter.sort_kind == "metal" and token_litter.kind == "token")
	token_litter.queue_free()
	await process_frame

	var neon = load("res://scripts/neon_arcade.gd").new()
	root.add_child(neon)
	await process_frame
	_check("neon strip has a title", neon.title == "NEON ARCADE")
	_check("neon spawn is free", neon.is_free(neon.spawn))
	_check("neon seats a crowd", neon.crowd_points().size() >= 10)
	_check("neon has three live puddles", neon.electric_puddles.size() == 3)
	for i in neon.electric_puddles.size():
		var entry: Dictionary = neon.electric_puddles[i]
		_check("neon puddle %d starts hazardous" % i, bool(entry.hazard))
		_check("neon puddle %d has a shorting sign" % i, entry.sign_light != null and entry.sparks != null)
	_check("neon hides a roof token", neon.roof_token_pos.y > 1.0)
	neon.set_night(true)
	_check("neon night brings rain", neon.raining)
	neon.litter_puddle(neon.electric_puddles[0].pos)
	_check("neon puddle clears when litter goes", not bool(neon.electric_puddles[0].hazard))
	_check("neon door has a title", str(neon.interiors[0].title) != "")
	neon.queue_free()
	await process_frame

	var shock_player = load("res://scripts/player.gd").new()
	root.add_child(shock_player)
	await process_frame
	shock_player.set_rank(3)
	var carried = LITTER.new()
	carried.build("crate", kind_rng)
	root.add_child(carried)
	shock_player.add_to_stack(carried)
	_check("shock drops a stack item", shock_player.stack_count() == 1)
	shock_player.slip_timer = 0.0
	shock_player.apply_shock()
	_check("shock stuns the sweeper", shock_player.slip_timer > 0.3)
	_check("shock tumbles the load", shock_player.stack_count() == 0)
	shock_player.queue_free()
	carried.queue_free()
	await process_frame

	var story_dlg = D.new()
	root.add_child(story_dlg)
	_check("pip roof tree exists", story_dlg.TREES.has("pip_high_score"))
	_check("sullage taunt exists", story_dlg.TREES.has("sullage_taunt"))
	_check("nell ending exists", story_dlg.TREES.has("nell_ending"))
	state.reset_quest("high_score")
	state.set_flag("met_pip")
	state.flags.erase("met_pip")
	story_dlg.start("pip_high_score")
	story_dlg.advance()
	_check("pip roof offers the quest", state.quest_status("high_score") == "active")
	_check("pip roof sets the flag", state.has_flag("met_pip"))
	story_dlg.advance()
	_check("pip roof tree ends", not story_dlg.is_active())
	state.start_quest("cat")
	state.reset_quest("cat")
	state.start_quest("cat")
	story_dlg.start("miso")
	story_dlg.advance()
	_check("miso step completes the cat quest", state.quest_status("cat") == "done")
	story_dlg.queue_free()
	await process_frame

	var picker = Player.new()
	root.add_child(picker)
	await process_frame
	picker.set_rank(3)
	var sack_a = LITTER.new()
	sack_a.build("sack", kind_rng)
	root.add_child(sack_a)
	picker.add_to_stack(sack_a)
	var crate_b = LITTER.new()
	crate_b.build("crate", kind_rng)
	root.add_child(crate_b)
	picker.add_to_stack(crate_b)
	_check("remove_kind pulls only sacks", picker.remove_kind("sack") == 1 and picker.stack_count() == 1)
	_check("crate stays on the stack", picker.stack_count() == 1 and picker.remove_kind("crate") == 1 and picker.stack_count() == 0)
	picker.queue_free()
	await process_frame

	state.delete_save()
	print("failures: ", failures)
	quit(0 if failures == 0 else 1)
