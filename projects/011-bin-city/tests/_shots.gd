extends SceneTree

# Temporary capture harness: boots the real game, photographs the cold open
# cutscene, skips it, photographs each district with the visual pass applied,
# then starts shift 5 and photographs the boss intro.

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

	print("STAGE  market play")
	await create_timer(2.4).timeout
	if scene._debug_label != null:
		scene._debug_label.visible = true
	await _shot("28-market-play")

	print("STAGE  canal")
	scene.load_area("canal_quarter", Vector3.ZERO)
	scene.player.global_position = Vector3(3.0, 0.0, 7.0)
	scene.player.rotation.y = PI / 2.0
	await create_timer(1.8).timeout
	await _shot("29-canal")

	print("STAGE  neon")
	scene.load_area("neon_arcade", Vector3.ZERO)
	scene.player.global_position = Vector3(-4.0, 0.0, 11.0)
	scene.player.rotation.y = PI
	await create_timer(1.8).timeout
	await _shot("30-neon")

	print("STAGE  bakery")
	scene.load_area("dawn_market", Vector3.ZERO)
	scene.player.global_position = scene.world.spawn
	await create_timer(0.8).timeout
	scene._enter_interior("bakery")
	var guard := 0
	while not scene.inside_interior and guard < 240:
		await process_frame
		guard += 1
	await create_timer(1.4).timeout
	print("STAGE  bakery inside=", scene.inside_interior)
	await _shot("31-bakery")
	scene._exit_interior()
	guard = 0
	while scene.inside_interior and guard < 240:
		await process_frame
		guard += 1

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
