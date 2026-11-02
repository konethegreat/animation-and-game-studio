extends SceneTree

# Temporary capture harness: boots the real game, starts shift 5, enters the
# plant and photographs each Gulper phase, then the calmed core.

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

	print("STAGE  shift 5")
	scene.begin_shift(5)
	while scene.player.locked:
		await process_frame
	await create_timer(0.5).timeout
	print("STAGE  entering plant")
	scene._enter_interior("plant")
	while scene.boss == null:
		await process_frame
	await create_timer(2.5).timeout
	print("STAGE  boss phase ", scene.boss.phase, " health ", scene.boss.health)
	await _shot("22-boss-phase1")

	scene.boss.health = 200.0
	scene.boss._check_phase()
	await create_timer(1.6).timeout
	print("STAGE  boss phase ", scene.boss.phase)
	await _shot("23-boss-phase2")

	scene.boss.health = 100.0
	scene.boss._check_phase()
	await create_timer(1.6).timeout
	print("STAGE  boss phase ", scene.boss.phase, " core ", scene.boss.core_open)
	await _shot("24-boss-phase3")

	print("STAGE  done")
	quit(0)
