extends SceneTree


func _initialize() -> void:
	var packed: PackedScene = load("res://main.tscn")
	if packed == null:
		push_error("SMOKE FAIL: could not load main.tscn")
		quit(1)
		return
	var node := packed.instantiate()
	root.add_child(node)
	await process_frame

	if node.get_child_count() < 7:
		push_error("SMOKE FAIL: sky or audio nodes missing")
		quit(1)
		return

	if int(node.get("state")) != 0:
		push_error("SMOKE FAIL: game did not start on the menu")
		quit(1)
		return

	node.call("_start")
	if int(node.get("state")) != 1:
		push_error("SMOKE FAIL: start did not enter play")
		quit(1)
		return
	if int(node.get("lives")) != 3 or int(node.get("score")) != 0:
		push_error("SMOKE FAIL: run did not reset")
		quit(1)
		return

	node.set("target_radius", 120.0)
	for i in 30:
		await process_frame
	if float(node.get("radius")) >= 150.0:
		push_error("SMOKE FAIL: radial input did not move the orbit")
		quit(1)
		return

	var start_score := int(node.get("score"))
	node.call("_collect", node.call("_polar", 0.0, 160.0))
	if int(node.get("score")) <= start_score:
		push_error("SMOKE FAIL: collecting a star did not score")
		quit(1)
		return
	if int(node.get("combo")) < 2:
		push_error("SMOKE FAIL: combo did not build")
		quit(1)
		return

	var hit_at = node.call("_polar", 0.5, 160.0)
	node.set("invulnerable", 0.0)
	node.call("_take_hit", hit_at)
	if int(node.get("shields")) != 0 or int(node.get("lives")) != 3:
		push_error("SMOKE FAIL: shield did not absorb the first hit")
		quit(1)
		return

	node.set("invulnerable", 0.0)
	node.call("_take_hit", hit_at)
	if int(node.get("lives")) != 2:
		push_error("SMOKE FAIL: a hit did not cost a life")
		quit(1)
		return

	node.call("_start")
	if int(node.get("score")) != 0 or int(node.get("lives")) != 3 or int(node.get("combo")) != 1:
		push_error("SMOKE FAIL: restart did not reset the run")
		quit(1)
		return

	print("SMOKE OK")
	quit(0)
