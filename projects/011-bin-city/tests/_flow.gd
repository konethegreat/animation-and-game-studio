extends SceneTree

# Exercises the staged loading path end to end without a render context:
# staged shift start, a district swap, an interior round trip and the boss room.

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS  ", name)
	else:
		failures += 1
		print("FAIL  ", name, "  ", detail)


func _wait_until(check: Callable, limit_ms := 20000) -> bool:
	var started := Time.get_ticks_msec()
	while not check.call():
		await process_frame
		if Time.get_ticks_msec() - started > limit_ms:
			return false
	return true


func _run() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	root.get_node("Sound").muted = true
	root.get_node("GameState").reset_new_game()

	scene.area_id = "canal_quarter"
	scene.begin_shift(1)
	_check("staged shift locks input", scene.transitioning)
	var built := await _wait_until(func() -> bool: return not scene.transitioning and scene.phase == "play")
	_check("staged shift finishes", built)
	_check("staged shift built the district", scene.area_id == "dawn_market", scene.area_id)

	if scene.cutscene.active:
		scene.cutscene.skip()
	await _wait_until(func() -> bool: return not scene.cutscene.active)

	scene._enter_interior("bakery")
	var entered := await _wait_until(func() -> bool: return scene.inside_interior and not scene.transitioning)
	_check("bakery opens after the loading card", entered)
	_check("bakery is the active world", str(scene.world.title).to_upper().contains("BAKERY"), str(scene.world.title) if scene.world != null else "null")

	scene._exit_interior()
	var left := await _wait_until(func() -> bool: return not scene.inside_interior and not scene.transitioning)
	_check("bakery closes cleanly", left)

	root.get_node("GameState").set_flag("seen_neon_arcade")
	scene.begin_shift(5)
	var ready := await _wait_until(func() -> bool: return scene.area_id == "neon_arcade" and not scene.player.locked, 30000)
	_check("shift five reaches neon arcade", ready)

	scene._enter_interior("plant")
	var plant := await _wait_until(func() -> bool: return scene.inside_interior and scene.boss != null and scene.boss.active, 120000)
	_check("plant builds and the boss starts", plant)

	print("failures: ", failures)
	quit(0 if failures == 0 else 1)
