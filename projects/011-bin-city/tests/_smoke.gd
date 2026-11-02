extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("PASS  ", name)
	else:
		failures += 1
		print("FAIL  ", name, "  ", detail)


func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game._start_shift()
	await process_frame
	if game.cutscene.active:
		game.cutscene.skip()
		while game.cutscene.active:
			await process_frame
	game.player.locked = false
	await process_frame

	var barrel = load("res://scripts/litter.gd").new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	barrel.build("barrel", rng)
	game.add_child(barrel)
	barrel.global_position = game.world.skip_pos + Vector3(-1.5, 0.0, 1.0)
	await process_frame

	game.player.global_position = barrel.global_position + Vector3(-0.5, 0.0, 0.0)
	await process_frame
	game._lift(barrel)
	await process_frame
	_check("lift fills the stack", game.player.stack_count() == 1)

	var clean_before: float = game.clean_progress
	var score_before: int = game.score
	game.player.global_position = game.world.skip_pos + Vector3(-2.0, 0.0, 1.0)
	await process_frame
	game._interact()
	await process_frame
	_check("unload empties the stack", game.player.stack_count() == 0)
	_check("unload cleans the street", game.clean_progress > clean_before, "%s -> %s" % [clean_before, game.clean_progress])
	_check("unload scores the load", game.score > score_before, "%s -> %s" % [score_before, game.score])

	print("failures: ", failures)
	quit(0 if failures == 0 else 1)
