extends SceneTree

# Temporary capture harness: opens the real game, walks it into the neon
# arcade strip and saves frames so the district can be checked by eye.

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


func _place_local(local: Vector3, face_yaw: float, cam_yaw_angle: float) -> void:
	_place(scene.world.to_global(local), face_yaw, cam_yaw_angle)


func _run() -> void:
	print("STAGE  boot")
	root.get_node("Sound").muted = true
	scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	scene.start_area = "neon_arcade"
	scene._start_shift()
	await create_timer(0.8).timeout
	print("STAGE  area=", scene.area_id, " mood=", scene.world.mood, " puddles=", scene.world.electric_puddles.size())

	print("STAGE  strip view")
	_place(Vector3(0.0, 0.0, 8.0), 0.15, 0.15)
	await create_timer(0.6).timeout
	await _shot("14-neon-strip")

	print("STAGE  live puddle")
	_place(Vector3(-11.5, 0.0, -2.5), 1.03, 1.03)
	await create_timer(0.8).timeout
	await _shot("15-neon-puddle")

	print("STAGE  rooftop pip")
	scene.camera_distance = 6.4
	_place(Vector3(13.4, 2.4, 12.6), -1.42, -1.42)
	await create_timer(0.6).timeout
	await _shot("16-neon-roof")

	print("STAGE  rain night")
	scene.camera_distance = 8.8
	scene.world.set_night(true)
	await create_timer(1.2).timeout
	_place(Vector3(1.0, 0.0, 4.0), 0.25, 0.25)
	await create_timer(0.8).timeout
	print("STAGE  raining=", scene.world.raining, " rain quad=", scene.rain_quad.visible)
	await _shot("17-neon-rain")

	print("STAGE  enter arcade")
	scene._enter_interior.bind("arcade").call_deferred()
	while not scene.inside_interior:
		await process_frame
	while scene.transitioning:
		await process_frame
	await create_timer(0.7).timeout
	_place_local(Vector3(-6.5, 0.0, -3.6), 0.0, 0.0)
	await create_timer(0.6).timeout
	await _shot("18-arcade-inside")

	print("STAGE  done")
	quit(0)
