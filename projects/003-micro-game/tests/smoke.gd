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
	if node.get_child_count() < 2:
		push_error("SMOKE FAIL: audio players missing")
		quit(1)
		return
	print("SMOKE OK")
	quit(0)
