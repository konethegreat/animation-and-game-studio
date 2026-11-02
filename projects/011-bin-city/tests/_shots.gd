extends SceneTree

# Temporary capture harness: opens the real game, walks it into a doorway and
# saves frames so the rooms and the loading card can be checked by eye.

var scene: Node


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	print("SHOT-BEGIN  ", name)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var err := image.save_png("res://tests/shots/%s.png" % name)
	print("SHOT-END  ", name, "  ", err)


func _place(point: Vector3, face_yaw: float, cam_yaw_angle: float) -> void:
	scene.player.global_position = point
	scene.player.velocity = Vector3.ZERO
	scene.player.rotation.y = face_yaw
	scene.cam_yaw.global_position = point + Vector3(0, 1.55, 0)
	scene.cam_yaw.rotation.y = cam_yaw_angle
	scene.cam_pitch.rotation.x = -0.18


func _run() -> void:
	print("STAGE  boot")
	root.get_node("Sound").muted = true
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene._start_shift()
	await create_timer(0.6).timeout
	print("STAGE  door")
	_place(Vector3(-9.0, 0.0, -9.3), 0.0, 0.0)
	await create_timer(0.6).timeout
	await _shot("01-door")

	print("STAGE  enter")
	scene._enter_interior.bind("depot").call_deferred()
	await create_timer(0.42).timeout
	await _shot("02-loading")
	print("STAGE  waiting for room")
	while not scene.inside_interior:
		await process_frame
	while scene.transitioning:
		await process_frame
	print("STAGE  room is in")
	await create_timer(0.7).timeout
	await _shot("03-depot")

	_place(scene.world.to_global(Vector3(0.4, 0.0, 0.6)), PI, 0.0)
	await create_timer(0.5).timeout
	await _shot("04-depot-wide")

	print("STAGE  leave")
	scene._exit_interior.call_deferred()
	while scene.inside_interior:
		await process_frame
	while scene.transitioning:
		await process_frame
	await create_timer(0.6).timeout
	await _shot("05-back-outside")

	print("STAGE  bakery")
	scene._enter_interior.bind("bakery").call_deferred()
	while not scene.inside_interior:
		await process_frame
	while scene.transitioning:
		await process_frame
	await create_timer(0.7).timeout
	print("CAST ", scene.interior_id, " members=", scene.crowd.members.size())
	_place(scene.world.to_global(Vector3(-3.6, 0.0, 0.4)), PI, 0.0)
	await create_timer(0.4).timeout
	await _shot("07-baker-close")
	_place(scene.world.to_global(Vector3(0.2, 0.0, 0.8)), PI, 0.0)
	await create_timer(0.4).timeout
	await _shot("06-bakery")

	print("STAGE  done")
	quit(0)
