extends SceneTree

# Temporary capture harness: boots the real game, photographs the cold open
# cutscene, skips it, then starts shift 5 and photographs the boss intro.

var scene: Node


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	print("SHOT-BEGIN  ", name)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var err := image.save_png("res://tests/shots/%s.png" % name)
	print("SHOT-END  ", name, "  ", err)


func _run() -> void:
	print("STAGE  boot")
	root.get_node("Sound").muted = true
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await create_timer(0.6).timeout

	print("STAGE  cold open")
	root.get_node("GameState").reset_new_game()
	scene.begin_shift(1)
	while not scene.cutscene.active:
		await process_frame
	await create_timer(4.2).timeout
	await _shot("25-cold-open")
	scene.cutscene.skip()
	while scene.cutscene.active:
		await process_frame
	await create_timer(0.6).timeout
	print("STAGE  playable after skip  locked=", scene.player.locked)
	await _shot("26-after-skip")

	print("STAGE  boss intro")
	root.get_node("GameState").set_flag("seen_neon_arcade")
	scene.begin_shift(5)
	while scene.player.locked:
		await process_frame
	await create_timer(0.4).timeout
	scene._enter_interior("plant")
	while not scene.cutscene.active:
		await process_frame
	await create_timer(3.4).timeout
	print("STAGE  intro cutscene=", scene.cutscene.active, " boss active=", scene.boss.active if scene.boss != null else false)
	await _shot("27-boss-intro")

	print("STAGE  done")
	quit(0)
