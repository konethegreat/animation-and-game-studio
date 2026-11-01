extends Node3D

const K = preload("res://scripts/kit.gd")
const WORLD = preload("res://scripts/world.gd")
const PLAYER = preload("res://scripts/player.gd")
const UI = preload("res://scripts/ui.gd")
const LITTER = preload("res://scripts/litter.gd")
const PILE = preload("res://scripts/pile.gd")
const RAT = preload("res://scripts/rat.gd")

const SPAWN := Vector3(2.0, 0.0, 2.0)
const LIGHT_COUNT := 96
const HEAVY_COUNT := 12
const PILE_COUNT := 4
const LIGHT_KINDS := [
	"paper", "paper", "cup", "carton", "can", "can", "bottle",
	"leaf", "bag", "paper", "can", "bottle", "cup", "leaf",
]
const HEAVY_KINDS := ["crate", "barrel", "sack", "tyre", "planks"]
const PILE_SPOTS := [
	Vector3(-1.0, 0.0, -3.0),
	Vector3(5.0, 0.0, -5.5),
	Vector3(-9.0, 0.0, 5.5),
	Vector3(8.0, 0.0, 3.2),
]
const GOAL := 0.9
const RANK_TWO_AT := 0.42
const FLOW_WINDOW := 14.0
const BASE_HOPPER := 12
const BIG_HOPPER := 20

var phase := "title"
var world
var player
var ui
var cam_yaw: Node3D
var cam_pitch: Node3D
var camera: Camera3D
var title_cam: Camera3D
var cam_probe := SphereShape3D.new()
var cam_query := PhysicsShapeQueryParameters3D.new()

var litter_nodes: Array[Node3D] = []
var piles: Array[Dictionary] = []
var rats: Array[Dictionary] = []

var rng := RandomNumberGenerator.new()
var timer := 0.0
var score := 0
var best := 0
var rank := 1
var clean_progress := 0.0
var total_weight := 1.0
var hopper: Array[Dictionary] = []
var hopper_capacity := BASE_HOPPER
var charge := 100.0
var charge_lock := false
var vacuum_time := 0.0
var flow_chain := 0
var flow_time := 0.0
var sorted_total := 0
var sort_start := 0
var sort_mistakes := 0
var sort_correct := 0
var camera_distance := 8.8
var title_time := 0.0
var rat_spawn_marks := [35.0, 95.0]
var rat_spawned := [false, false]
var finished := false
var _prompt_cache := ""


func _ready() -> void:
	rng.seed = 20261102
	_setup_input()
	_build_light()
	world = WORLD.new()
	world.name = "DawnMarket"
	add_child(world)
	player = PLAYER.new()
	player.name = "Collector"
	add_child(player)
	player.global_position = SPAWN
	player.rotation.y = 0.0
	player.visible = false
	player.locked = true
	_build_cameras()
	ui = UI.new()
	add_child(ui)
	ui.play_pressed.connect(_start_shift)
	ui.restart_pressed.connect(_restart)
	ui.title_pressed.connect(_show_title)
	ui.resume_pressed.connect(_resume)
	ui.mute_pressed.connect(_toggle_mute)
	ui.pause_pressed.connect(_pause)
	ui.sort_choice.connect(_on_sort_choice)
	ui.sort_closed.connect(_close_sort)
	ui.interact_pressed.connect(_interact)
	ui.look_pad.looked.connect(_on_look)
	player.stack_tumbled.connect(_on_tumble)
	_load_best()
	if _wants_poster():
		_poster_mode()
	else:
		_show_title()


func _wants_poster() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval("location.search.indexOf('poster=1') >= 0", true))


func _poster_mode() -> void:
	_start_shift()
	ui.capture_mode()
	player.global_position = SPAWN + Vector3(0.0, 0.0, 0.6)
	cam_yaw.rotation.y = -0.32
	cam_pitch.rotation.x = -0.26
	cam_yaw.global_position = player.global_position + Vector3(0, 1.55, 0)
	camera_distance = 7.4
	camera.position = Vector3(0, 0, camera_distance)
	phase = "poster"


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("mute"):
		_toggle_mute()
	if phase == "title":
		title_time += delta
		var angle := 0.62 + title_time * 0.03
		var target := Vector3(-2.0, 2.0, 1.0)
		title_cam.global_position = Vector3(target.x + cos(angle) * 23.0, 8.6, target.z + sin(angle) * 23.0)
		title_cam.look_at(target, Vector3.UP)
		if Input.is_action_just_pressed("ui_accept"):
			_start_shift()
		return
	if phase == "sort":
		_sort_input()
		return
	if phase == "poster":
		return
	if phase == "results":
		if Input.is_action_just_pressed("restart"):
			_restart()
		return
	if phase != "play":
		return
	if Input.is_action_just_pressed("pause"):
		_pause()
		return
	if Input.is_action_just_pressed("restart"):
		_restart()
		return
	if Input.is_action_just_pressed("interact"):
		_interact()
	timer += delta
	flow_time = maxf(0.0, flow_time - delta)
	if flow_time <= 0.0:
		flow_chain = 0
	_update_camera(delta)
	_update_vacuum(delta)
	_update_rats(delta)
	_check_slip()
	_check_progress()
	_update_prompt()
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = clampf(camera_distance - 0.7, 4.6, 12.5)
		elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = clampf(camera_distance + 0.7, 4.6, 12.5)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			cam_yaw.rotation.y -= motion.relative.x * 0.0032
			cam_pitch.rotation.x = clampf(cam_pitch.rotation.x - motion.relative.y * 0.0024, -1.05, -0.07)


# ---------------------------------------------------------------- setup

func _setup_input() -> void:
	_bind("move_forward", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)])
	_bind("move_back", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)])
	_bind("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)])
	_bind("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)])
	_bind("sprint", [_key(KEY_SHIFT), _pad(JOY_BUTTON_LEFT_STICK)])
	_bind("vacuum", [
		_mouse(MOUSE_BUTTON_LEFT), _key(KEY_F),
		_pad(JOY_BUTTON_RIGHT_SHOULDER), _axis(JOY_AXIS_TRIGGER_RIGHT, 0.5),
	])
	_bind("interact", [_key(KEY_E), _pad(JOY_BUTTON_X)])
	_bind("pause", [_key(KEY_ESCAPE), _pad(JOY_BUTTON_START)])
	_bind("restart", [_key(KEY_R)])
	_bind("mute", [_key(KEY_M)])
	_bind("sort_glass", [_key(KEY_1), _pad(JOY_BUTTON_DPAD_LEFT)])
	_bind("sort_metal", [_key(KEY_2), _pad(JOY_BUTTON_DPAD_UP)])
	_bind("sort_paper", [_key(KEY_3), _pad(JOY_BUTTON_DPAD_RIGHT)])
	_bind("sort_compost", [_key(KEY_4), _pad(JOY_BUTTON_DPAD_DOWN)])
	_bind("look_left", [_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_bind("look_right", [_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_bind("look_up", [_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_bind("look_down", [_axis(JOY_AXIS_RIGHT_Y, 1.0)])


func _bind(action: String, events: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.22)
	for event in events:
		InputMap.action_add_event(action, event)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


func _build_light() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.52, 0.66)
	sky_mat.sky_horizon_color = Color(0.98, 0.82, 0.62)
	sky_mat.ground_horizon_color = Color(0.86, 0.78, 0.64)
	sky_mat.ground_bottom_color = Color(0.42, 0.38, 0.32)
	sky_mat.sun_angle_max = 18.0
	sky_mat.sun_curve = 0.18
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.88
	env.fog_enabled = true
	env.fog_light_color = Color(0.93, 0.83, 0.69)
	env.fog_light_energy = 0.35
	env.fog_density = 0.0032
	env.fog_sky_affect = 0.2
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	var holder := WorldEnvironment.new()
	holder.environment = env
	add_child(holder)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46.0, -34.0, 0.0)
	sun.light_color = Color(1.0, 0.87, 0.68)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 46.0
	add_child(sun)


func _build_cameras() -> void:
	cam_yaw = Node3D.new()
	cam_yaw.name = "CameraYaw"
	add_child(cam_yaw)
	cam_pitch = Node3D.new()
	cam_pitch.name = "CameraPitch"
	cam_yaw.add_child(cam_pitch)
	camera = Camera3D.new()
	camera.name = "PlayCamera"
	camera.position = Vector3(0, 0, camera_distance)
	camera.fov = 58.0
	camera.near = 0.08
	camera.far = 180.0
	cam_pitch.add_child(camera)
	cam_pitch.rotation.x = -0.3
	cam_probe.radius = 0.3
	cam_query.shape = cam_probe
	cam_query.collision_mask = 1
	cam_query.exclude = [player.get_rid()]
	title_cam = Camera3D.new()
	title_cam.name = "TitleCamera"
	title_cam.fov = 54.0
	title_cam.near = 0.1
	title_cam.far = 220.0
	add_child(title_cam)
	title_cam.current = true


# ---------------------------------------------------------------- state

func _show_title() -> void:
	get_tree().paused = false
	_clear_run()
	phase = "title"
	finished = false
	player.visible = false
	player.locked = true
	player.global_position = SPAWN
	player.rotation.y = 0.0
	player.set_rank(1)
	player.speed_bonus = 0.0
	cam_yaw.rotation.y = 0.0
	cam_pitch.rotation.x = -0.3
	cam_yaw.global_position = SPAWN + Vector3(0, 1.55, 0)
	world.set_clean(0.0)
	title_time = 0.0
	title_cam.current = true
	ui.set_phase("title")
	ui.set_muted(Sound.muted)
	Sound.set_vacuum(false)
	if not Sound.muted and not Sound.music.playing:
		Sound.music.play()


func _start_shift() -> void:
	get_tree().paused = false
	_clear_run()
	_spawn_market()
	timer = 0.0
	score = 0
	rank = 1
	clean_progress = 0.0
	hopper.clear()
	hopper_capacity = BASE_HOPPER
	charge = 100.0
	charge_lock = false
	vacuum_time = 0.0
	flow_chain = 0
	flow_time = 0.0
	sort_mistakes = 0
	sort_correct = 0
	sorted_total = 0
	finished = false
	rat_spawned[0] = false
	rat_spawned[1] = false
	_prompt_cache = ""
	player.reset_player(SPAWN)
	player.rotation.y = 0.0
	player.set_rank(1)
	player.speed_bonus = 0.0
	player.visible = true
	player.locked = false
	player.vacuuming = false
	player.touch_input = Vector2.ZERO
	cam_yaw.rotation.y = 0.0
	cam_pitch.rotation.x = -0.3
	cam_yaw.global_position = player.global_position + Vector3(0, 1.55, 0)
	camera.current = true
	phase = "play"
	ui.set_phase("play")
	ui.set_muted(Sound.muted)
	ui.subtitle("The market opens in an hour. Get the street 90% clean before the shutters go up.", 6.0)
	Sound.play("click")
	Sound.set_vacuum(false)
	if not Sound.muted and not Sound.music.playing:
		Sound.music.play()
	_update_hud()


func _pause() -> void:
	if phase != "play":
		return
	phase = "pause"
	player.locked = true
	player.vacuuming = false
	Sound.set_vacuum(false)
	ui.set_phase("pause")
	get_tree().paused = true


func _resume() -> void:
	get_tree().paused = false
	phase = "play"
	player.locked = false
	ui.set_phase("play")


func _restart() -> void:
	get_tree().paused = false
	phase = "idle"
	_start_shift()


func _toggle_mute() -> void:
	var muted := Sound.toggle_mute()
	ui.set_muted(muted)
	if not muted and not Sound.music.playing:
		Sound.music.play()


# ---------------------------------------------------------------- spawn

func _clear_run() -> void:
	if player:
		player.vacuuming = false
		for item in player.take_stack():
			if is_instance_valid(item):
				item.queue_free()
	for node in litter_nodes:
		if is_instance_valid(node):
			node.queue_free()
	litter_nodes.clear()
	for entry in piles:
		var pile = entry.get("node")
		if is_instance_valid(pile):
			pile.queue_free()
	piles.clear()
	for entry in rats:
		var rat = entry.get("node")
		if is_instance_valid(rat):
			rat.queue_free()
	rats.clear()
	clean_progress = 0.0
	total_weight = 1.0
	flow_chain = 0
	flow_time = 0.0
	vacuum_time = 0.0
	charge_lock = false
	Sound.set_vacuum(false)


func _spawn_market() -> void:
	world.set_clean(0.0)
	total_weight = 0.0
	for i in LIGHT_COUNT:
		var kind: String = LIGHT_KINDS[rng.randi_range(0, LIGHT_KINDS.size() - 1)]
		_spawn_litter(kind)
	for i in HEAVY_COUNT:
		var kind: String = HEAVY_KINDS[i % HEAVY_KINDS.size()]
		_spawn_litter(kind)
	for i in PILE_COUNT:
		var spot: Vector3 = PILE_SPOTS[i % PILE_SPOTS.size()]
		var pile = PILE.new()
		pile.position = spot
		world.add_child(pile)
		piles.append({"node": pile})
		total_weight += float(pile.get("base_weight"))


func _spawn_litter(kind: String) -> void:
	var node = LITTER.new()
	node.build(kind, rng)
	node.position = _free_spot(1.15)
	world.add_child(node)
	litter_nodes.append(node)
	total_weight += float(node.get("weight"))


func _free_spot(clearance: float) -> Vector3:
	var fallback: Vector3 = world.random_walkable(rng)
	for attempt in 60:
		var point: Vector3 = world.random_walkable(rng)
		if Vector2(point.x - SPAWN.x, point.z - SPAWN.z).length() < 3.4:
			continue
		var clear := true
		for spot in PILE_SPOTS:
			if Vector2(point.x - spot.x, point.z - spot.z).length() < 2.2:
				clear = false
				break
		if clear:
			for node in litter_nodes:
				if not is_instance_valid(node):
					continue
				if Vector2(node.position.x - point.x, node.position.z - point.z).length() < clearance:
					clear = false
					break
		if clear:
			return point
	return fallback


# ---------------------------------------------------------------- vacuum

func _update_vacuum(delta: float) -> void:
	var wants: bool = Input.is_action_pressed("vacuum") or ui.touch_wants_vacuum()
	var room := hopper.size() < hopper_capacity
	if charge <= 0.01:
		charge_lock = true
	if charge_lock and charge >= 18.0:
		charge_lock = false
	var can: bool = wants and room and not charge_lock
	if can:
		charge = maxf(0.0, charge - 17.0 * delta)
		vacuum_time += delta
		player.vacuuming = true
		Sound.set_vacuum(true, 0.65 + 0.35 * (float(hopper.size()) / float(hopper_capacity)))
		var facing: Vector3 = -player.global_transform.basis.z
		facing.y = 0.0
		facing = facing.normalized()
		var origin: Vector3 = player.global_position
		for node in litter_nodes:
			if not _available(node) or bool(node.get("heavy")):
				continue
			var offset: Vector3 = node.global_position - origin
			offset.y = 0.0
			var distance := offset.length()
			if distance > 5.4:
				continue
			if distance > 0.4 and facing.dot(offset / distance) < 0.28:
				continue
			node.call("pull", origin + facing * 0.75, delta)
			if distance < 1.25:
				_collect(node)
		if hopper.size() >= hopper_capacity and vacuum_time > 0.2:
			_release_vacuum(false)
			ui.subtitle("Hopper full. The depot bins are waiting.", 4.0)
	else:
		if player.vacuuming:
			_release_vacuum(room)
		charge = minf(100.0, charge + 28.0 * delta)


func _release_vacuum(allow_burst: bool) -> void:
	var held_for := vacuum_time
	player.vacuuming = false
	Sound.set_vacuum(false)
	vacuum_time = 0.0
	if allow_burst and held_for > 0.3 and charge > 24.0:
		charge = maxf(0.0, charge - 26.0)
		_burst()


func _burst() -> void:
	Sound.play("burst")
	var origin: Vector3 = player.global_position
	var facing: Vector3 = -player.global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()
	for node in litter_nodes:
		if not _available(node) or bool(node.get("heavy")):
			continue
		var offset: Vector3 = node.global_position - origin
		offset.y = 0.0
		if offset.length() < 4.8 and facing.dot(offset.normalized()) > -0.2:
			node.call("pull", origin + facing * 0.9, 0.16)
	for entry in rats:
		var rat = entry.get("node")
		if is_instance_valid(rat) and rat.global_position.distance_to(origin) < 6.5:
			_scare_rat(entry)
	flow_time = FLOW_WINDOW
	_burst_ring(origin)


func _burst_ring(origin: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.7
	mesh.outer_radius = 0.9
	mesh.rings = 20
	mesh.ring_segments = 6
	ring.mesh = mesh
	var mat := K.clear_material(Color(0.72, 0.96, 0.88), 0.55)
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(ring)
	ring.global_position = origin + Vector3(0, 0.4, 0)
	ring.scale = Vector3(0.4, 0.4, 0.4)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(3.4, 1.0, 3.4), 0.38)
	tween.tween_property(mat, "albedo_color", Color(0.72, 0.96, 0.88, 0.0), 0.38)
	tween.set_parallel(false)
	tween.tween_callback(ring.queue_free)


func _collect(node: Node3D) -> void:
	if hopper.size() >= hopper_capacity:
		return
	if not _available(node):
		return
	node.set("collected", true)
	var item := {
		"name": str(node.get("display")),
		"kind": str(node.get("sort_kind")),
		"swatch": node.get("tint"),
		"weight": float(node.get("weight")),
	}
	hopper.append(item)
	node.queue_free()
	score += 2
	flow_time = FLOW_WINDOW
	Sound.play("pickup", rng.randf_range(0.92, 1.12))
	if hopper.size() == 1:
		ui.subtitle("Litter goes in the hopper. Sorting happens at a depot.", 4.5)
	if hopper.size() >= hopper_capacity:
		ui.subtitle("Hopper full. Head for VIBES UNIT 7 or SORT IT RIGHT.", 5.0)


# ---------------------------------------------------------------- carry and sort

func _interact() -> void:
	if phase != "play" or player.locked:
		return
	var heavy = _nearest_heavy()
	if heavy != null and player.stack_count() < player.max_stack:
		_lift(heavy)
		return
	if player.stack_count() > 0 and _near_skip():
		_unload_stack()
		return
	var pile = _nearest_pile()
	if pile != null:
		_bag_pile(pile)
		return
	var station := _nearest_station()
	if not station.is_empty():
		if hopper.is_empty():
			ui.subtitle("The hopper is empty. Vacuum some litter first.", 4.0)
			Sound.play("click")
		else:
			_begin_sort()
		return
	if player.stack_count() >= player.max_stack:
		ui.subtitle("Stack full. The skip is by the canal bridge.", 3.5)
	elif hopper.size() >= hopper_capacity:
		ui.subtitle("Hopper full. The depot bins are marked in the square.", 3.5)


func _lift(node: Node3D) -> void:
	if player.stack_count() >= player.max_stack:
		return
	node.set("collected", true)
	player.add_to_stack(node)
	Sound.play("lift", rng.randf_range(0.9, 1.05))
	score += 3
	flow_time = FLOW_WINDOW
	if player.stack_count() >= player.max_stack:
		ui.subtitle("Arms full. Take the load to the skip.", 3.0)


func _unload_stack() -> void:
	var items: Array = player.take_stack()
	if items.is_empty():
		return
	var weight := 0.0
	for item in items:
		if not is_instance_valid(item):
			continue
		weight += float(item.get("weight"))
		item.queue_free()
	clean_progress += weight
	score += int(weight * 8.0) + int(_multiplier() * 10.0)
	flow_chain += 1
	flow_time = FLOW_WINDOW
	Sound.play("throw", 0.9)
	ui.subtitle("Load tipped. %d more of the street is gone." % int(weight), 3.5)
	_refresh_clean()


func _bag_pile(pile: Node3D) -> void:
	var weight := float(pile.call("total_weight"))
	clean_progress += weight
	score += 45 + int(weight * 5.0)
	flow_chain += 1
	flow_time = FLOW_WINDOW
	pile.visible = false
	pile.queue_free()
	Sound.play("throw", 0.85)
	Sound.play("rustle", 1.1, -6.0)
	ui.subtitle("Pile bagged. %d points of mess off the street." % int(weight), 3.5)
	_refresh_clean()


func _begin_sort() -> void:
	if hopper.is_empty():
		return
	phase = "sort"
	player.locked = true
	player.vacuuming = false
	Sound.set_vacuum(false)
	sort_start = hopper.size()
	sort_correct = 0
	sort_mistakes = 0
	ui.set_phase("sort")
	ui.open_sort(hopper[0], 0, sort_start, _multiplier())
	Sound.play("click")


func _on_sort_choice(kind: String) -> void:
	if phase != "sort" or hopper.is_empty():
		return
	var item: Dictionary = hopper[0]
	if str(item.get("kind", "")) == kind:
		score += int(28.0 * _multiplier())
		clean_progress += float(item.get("weight", 1.0))
		hopper.pop_front()
		sort_correct += 1
		sorted_total += 1
		flow_chain += 1
		flow_time = FLOW_WINDOW
		Sound.play("correct", rng.randf_range(0.98, 1.06))
		ui.sort_result(true, flow_chain)
		_refresh_clean()
		_advance_sort_soon()
	else:
		sort_mistakes += 1
		flow_chain = 0
		flow_time = 0.0
		score = maxi(0, score - 4)
		Sound.play("wrong", rng.randf_range(0.9, 1.0))
		ui.sort_result(false, 0)


func _advance_sort_soon() -> void:
	await get_tree().create_timer(0.24).timeout
	if phase != "sort":
		return
	if hopper.is_empty():
		_end_sort(false)
	else:
		ui.open_sort(hopper[0], sort_correct, sort_start, _multiplier())


func _end_sort(_closed_early: bool) -> void:
	var perfect := sort_mistakes == 0 and sort_correct == sort_start and sort_correct > 0
	phase = "play"
	player.locked = false
	ui.set_phase("play")
	ui.sort_done(sort_correct, perfect)
	Sound.play("finish" if perfect else "click", 1.0, -6.0)
	_refresh_clean()


func _close_sort() -> void:
	if phase != "sort":
		return
	_end_sort(true)


func _sort_input() -> void:
	if Input.is_action_just_pressed("sort_glass"):
		_on_sort_choice("glass")
	elif Input.is_action_just_pressed("sort_metal"):
		_on_sort_choice("metal")
	elif Input.is_action_just_pressed("sort_paper"):
		_on_sort_choice("paper")
	elif Input.is_action_just_pressed("sort_compost"):
		_on_sort_choice("compost")
	elif Input.is_action_just_pressed("pause"):
		_close_sort()


func _multiplier() -> float:
	return 1.0 + minf(float(flow_chain), 10.0) * 0.2


# ---------------------------------------------------------------- rats

func _update_rats(delta: float) -> void:
	if timer > float(rat_spawn_marks[0]) and not bool(rat_spawned[0]):
		rat_spawned[0] = true
		_spawn_rat()
	if timer > float(rat_spawn_marks[1]) and not bool(rat_spawned[1]):
		rat_spawned[1] = true
		_spawn_rat()
	for entry in rats:
		var node = entry.get("node")
		if not is_instance_valid(node):
			continue
		var state := str(entry.get("state"))
		if state == "seek":
			entry["timer"] = float(entry.get("timer", 0.0)) - delta
			if float(entry.get("timer", 0.0)) > 0.0:
				continue
			var target = _nearest_light(node.global_position, 30.0)
			if target == null:
				entry["timer"] = 3.0
				continue
			entry["target"] = target
			entry["state"] = "walk"
		elif state == "walk":
			var target = entry.get("target")
			if not _available(target):
				entry["state"] = "seek"
				entry["timer"] = 2.0
				entry["target"] = null
				continue
			var distance := float(node.call("walk_to", target.global_position, delta, 2.5))
			if distance < 0.85:
				target.set("collected", true)
				target.visible = false
				node.call("set_loot", true)
				Sound.play("rat", rng.randf_range(1.1, 1.3), -8.0)
				entry["state"] = "carry"
		elif state == "carry":
			var target = entry.get("target")
			var pile = _nearest_pile_from(node.global_position, 40.0)
			if pile == null:
				_drop_rat_loot(entry)
				entry["state"] = "seek"
				entry["timer"] = 8.0
				continue
			var distance := float(node.call("walk_to", pile.global_position, delta, 2.8))
			if distance < 1.3:
				pile.call("add_held", 1.0)
				if is_instance_valid(target):
					target.queue_free()
				node.call("set_loot", false)
				entry["state"] = "seek"
				entry["timer"] = 10.0
				entry["target"] = null
		elif state == "flee":
			entry["timer"] = float(entry.get("timer", 0.0)) - delta
			node.call("flee_from", player.global_position, delta, 5.4)
			if float(entry.get("timer", 0.0)) <= 0.0:
				entry["state"] = "seek"
				entry["timer"] = 12.0
		if node.global_position.distance_to(player.global_position) < 4.2 and player.vacuuming:
			_scare_rat(entry)


func _spawn_rat() -> void:
	var node = RAT.new()
	node.position = Vector3(-1.0, 0.0, -3.0)
	var pile = _nearest_pile_from(SPAWN, 60.0)
	if is_instance_valid(pile):
		node.position = pile.global_position + Vector3(0.9, 0.0, 0.9)
	world.add_child(node)
	rats.append({"node": node, "state": "seek", "timer": 6.0, "target": null})
	Sound.play("rat", 1.0, -6.0)
	ui.subtitle("A rat nipped in. The vacuum sends it running.", 4.5)


func _scare_rat(entry: Dictionary) -> void:
	if str(entry.get("state")) == "flee":
		return
	_drop_rat_loot(entry)
	entry["state"] = "flee"
	entry["timer"] = 2.6
	Sound.play("rat", rng.randf_range(0.9, 1.05), -4.0)


func _drop_rat_loot(entry: Dictionary) -> void:
	var state := str(entry.get("state"))
	if state != "carry":
		entry["target"] = null
		return
	var target = entry.get("target")
	var node = entry.get("node")
	if is_instance_valid(target) and is_instance_valid(node):
		target.set("collected", false)
		target.visible = true
		target.global_position = Vector3(node.global_position.x, 0.0, node.global_position.z) + Vector3(0.8, 0.0, 0.4)
		node.call("set_loot", false)
	entry["target"] = null


# ---------------------------------------------------------------- progress

func _check_slip() -> void:
	if player.slip_timer > 0.1:
		return
	if Vector2(player.velocity.x, player.velocity.z).length() < 5.8:
		return
	if world.near_puddle(player.global_position, 0.15):
		player.apply_slip()
		Sound.play("slip", rng.randf_range(0.9, 1.05))
		ui.subtitle("Wet cobbles. Sprint somewhere dry.", 2.8)


func _on_tumble(item) -> void:
	if not is_instance_valid(item):
		return
	if item.get_parent() == player.stack_anchor:
		item.reparent(self, true)
	item.scale = Vector3.ONE
	item.global_position = Vector3(item.global_position.x, 0.0, item.global_position.z)
	item.rotation = Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)
	item.visible = true
	item.set("collected", false)
	item.set_process(true)
	Sound.play("throw", 0.85, -3.0)
	ui.subtitle("The stack went over. Take the corner slower next time.", 3.2)


func _check_progress() -> void:
	var clean := _clean()
	if rank == 1 and clean >= RANK_TWO_AT:
		_rank_up()
	if phase == "play" and clean >= GOAL and not finished:
		_finish()


func _refresh_clean() -> void:
	world.set_clean(_clean())
	_check_progress()


func _clean() -> float:
	return clampf(clean_progress / maxf(total_weight, 1.0), 0.0, 1.0)


func _rank_up() -> void:
	rank = 2
	hopper_capacity = BIG_HOPPER
	player.set_rank(2)
	player.speed_bonus = 0.35
	Sound.play("rank", 1.0, -2.0)
	ui.show_rank(2, "Bigger hopper, faster boots, and a coat that means business.")
	ui.subtitle("RANK UP. BAG BARON. The hopper holds twenty and your boots are quicker.", 6.0)


func _finish() -> void:
	finished = true
	phase = "results"
	player.locked = true
	player.vacuuming = false
	Sound.set_vacuum(false)
	best = maxi(best, score)
	_save_best()
	Sound.play("finish", 1.0, -2.0)
	ui.set_phase("results")
	ui.show_results({
		"time": timer,
		"score": score,
		"best": best,
		"sorted": sorted_total,
		"rank": rank,
		"clean": _clean(),
	})


func _load_best() -> void:
	var config := ConfigFile.new()
	if config.load("user://bincity.cfg") == OK:
		best = int(config.get_value("score", "best", 0))


func _save_best() -> void:
	var config := ConfigFile.new()
	config.load("user://bincity.cfg")
	config.set_value("score", "best", best)
	config.save("user://bincity.cfg")


# ---------------------------------------------------------------- update loops

func _update_camera(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() > 0.08:
		cam_yaw.rotation.y -= look.x * delta * 2.6
		cam_pitch.rotation.x = clampf(cam_pitch.rotation.x - look.y * delta * 1.8, -1.05, -0.07)
	var head := cam_yaw.global_position
	var desired := cam_pitch.to_global(Vector3(0, 0, camera_distance))
	cam_query.transform = Transform3D(Basis(), head)
	cam_query.motion = desired - head
	var sweep := get_world_3d().direct_space_state.cast_motion(cam_query)
	camera.position.z = maxf(1.5, camera_distance * sweep[0] - 0.12)
	var target: Vector3 = player.global_position + Vector3(0, 1.55, 0)
	cam_yaw.global_position = cam_yaw.global_position.lerp(target, minf(1.0, delta * 9.0))
	if ui.touch_available():
		player.touch_input = ui.touch_move()
		player.touch_sprint = ui.touch_wants_sprint()
	else:
		player.touch_input = Vector2.ZERO
		player.touch_sprint = false


func _on_look(relative: Vector2) -> void:
	if phase != "play":
		return
	cam_yaw.rotation.y -= relative.x * 0.004
	cam_pitch.rotation.x = clampf(cam_pitch.rotation.x - relative.y * 0.003, -1.05, -0.07)


func _update_prompt() -> void:
	var text := ""
	if hopper.size() >= hopper_capacity:
		text = "HOPPER FULL  /  SORT AT A DEPOT"
	else:
		var heavy = _nearest_heavy()
		if heavy != null and player.stack_count() < player.max_stack:
			text = "E  LIFT %s" % str(heavy.get("display")).to_upper()
		elif player.stack_count() > 0 and _near_skip():
			text = "E  UNLOAD THE LOAD"
		else:
			var pile = _nearest_pile()
			if pile != null:
				text = "E  BAG THE PILE"
			else:
				var station := _nearest_station()
				if not station.is_empty():
					if hopper.is_empty():
						text = "HOPPER EMPTY  /  VACUUM THE STREET"
					else:
						text = "E  SORT %d ITEMS AT %s" % [hopper.size(), str(station.get("label", "THE DEPOT"))]
				elif player.stack_count() >= player.max_stack:
					text = "STACK FULL  /  HEAD FOR THE SKIP"
				elif player.stack_count() > 0:
					text = "CARRY THE LOAD TO THE SKIP"
	if text != _prompt_cache:
		_prompt_cache = text
		ui.prompt(text)


func _update_hud() -> void:
	ui.update_hud({
		"score": score,
		"rank": rank,
		"clean": _clean(),
		"bag": hopper.size(),
		"bag_max": hopper_capacity,
		"charge": charge,
		"multiplier": _multiplier(),
		"flow_time": flow_time,
		"stack": player.stack_count(),
		"max_stack": player.max_stack,
		"lean": player.lean.length(),
		"time": timer,
	})


func _available(node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not bool(node.get("collected"))


func _nearest_heavy(radius := 2.4):
	var best_node = null
	var best := radius
	var origin: Vector3 = player.global_position
	for node in litter_nodes:
		if not _available(node) or not bool(node.get("heavy")):
			continue
		var distance := Vector2(node.global_position.x - origin.x, node.global_position.z - origin.z).length()
		if distance < best:
			best = distance
			best_node = node
	return best_node


func _nearest_light(origin: Vector3, radius: float):
	var best_node = null
	var best := radius
	for node in litter_nodes:
		if not _available(node) or bool(node.get("heavy")):
			continue
		var distance := Vector2(node.global_position.x - origin.x, node.global_position.z - origin.z).length()
		if distance < best:
			best = distance
			best_node = node
	return best_node


func _nearest_pile(radius := 2.8):
	var best_node = null
	var best := radius
	var origin: Vector3 = player.global_position
	for entry in piles:
		var node = entry.get("node")
		if not is_instance_valid(node) or not node.visible:
			continue
		var distance := Vector2(node.global_position.x - origin.x, node.global_position.z - origin.z).length()
		if distance < best:
			best = distance
			best_node = node
	return best_node


func _nearest_pile_from(origin: Vector3, radius: float):
	var best_node = null
	var best := radius
	for entry in piles:
		var node = entry.get("node")
		if not is_instance_valid(node) or not node.visible:
			continue
		var distance := Vector2(node.global_position.x - origin.x, node.global_position.z - origin.z).length()
		if distance < best:
			best = distance
			best_node = node
	return best_node


func _nearest_station() -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 3.4
	var origin: Vector3 = player.global_position
	for station in world.stations:
		var point: Vector3 = station.get("pos", Vector3.ZERO)
		var distance := Vector2(origin.x - point.x, origin.z - point.z).length()
		if distance < best_distance:
			best_distance = distance
			best = station
	return best


func _near_skip() -> bool:
	var skip: Vector3 = world.skip_pos
	return Vector2(player.global_position.x - skip.x, player.global_position.z - skip.z).length() < 4.4
