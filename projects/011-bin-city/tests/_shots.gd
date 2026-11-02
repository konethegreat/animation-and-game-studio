extends SceneTree

# Temporary capture harness: boots the real game, photographs the title
# shift select and the shift briefing card, then starts shift 2 for a HUD
# shot with the objective line.

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
	print("STAGE  title")
	await _shot("19-title-shifts")

	print("STAGE  briefing")
	scene.begin_shift(2)
	await create_timer(1.4).timeout
	await _shot("20-briefing")
	while scene.player.locked:
		await process_frame
	await create_timer(0.8).timeout
	print("STAGE  area=", scene.area_id, " shift=", scene.shift_index, " night=", scene.world.raining if scene.world.get("raining") != null else "n/a")
	await _shot("21-shift2-hud")

	print("STAGE  done")
	quit(0)
