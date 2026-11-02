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

	_check("five ranks defined", GameData.RANKS.size() == 5)
	_check("three districts defined", GameData.DISTRICTS.size() >= 3)
	_check("five shifts defined", GameData.SHIFTS.size() == 5)
	_check("rank title lookup", GameData.rank_title(3) == "SCRAP KNIGHT")
	_check("shift lookup", str(GameData.shift(2).id) == "shift_2")

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
