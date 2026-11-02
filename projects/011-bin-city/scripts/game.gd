extends Node3D

const K = preload("res://scripts/kit.gd")
const PLAYER = preload("res://scripts/player.gd")
const UI = preload("res://scripts/ui.gd")
const LITTER = preload("res://scripts/litter.gd")
const PILE = preload("res://scripts/pile.gd")
const RAT = preload("res://scripts/rat.gd")
const POSTFX = preload("res://scripts/postfx.gd")
const Data = preload("res://scripts/data.gd")
const CROWD = preload("res://scripts/crowd.gd")
const INTERIORS = preload("res://scripts/interiors.gd")
const TRANSITION = preload("res://scripts/transition.gd")
const BOSS = preload("res://scripts/boss.gd")
const CUTSCENE = preload("res://scripts/cutscene.gd")

const MOODS := {
	"dawn": {
		"zenith": Color(0.26, 0.43, 0.62), "horizon": Color(1.0, 0.79, 0.57),
		"ground": Color(0.47, 0.41, 0.35), "sun": Color(1.0, 0.8, 0.55),
		"sun_angle": Vector3(-31.0, -40.0, 0.0), "sun_energy": 1.85,
		"ambient": 0.52, "ambient_colour": Color(0.4, 0.5, 0.68),
		"fog": Color(0.9, 0.79, 0.63), "fog_density": 0.0007,
		"exposure": 0.74, "glow": false,
	},
	"canal": {
		"zenith": Color(0.28, 0.48, 0.55), "horizon": Color(0.82, 0.9, 0.84),
		"ground": Color(0.32, 0.42, 0.4), "sun": Color(0.95, 0.98, 0.9),
		"sun_angle": Vector3(-42.0, -18.0, 0.0), "sun_energy": 1.15,
		"ambient": 0.6, "ambient_colour": Color(0.46, 0.58, 0.64),
		"fog": Color(0.76, 0.86, 0.83), "fog_density": 0.004,
		"exposure": 0.93, "glow": false,
	},
	"night": {
		"zenith": Color(0.04, 0.08, 0.16), "horizon": Color(0.14, 0.26, 0.3),
		"ground": Color(0.05, 0.06, 0.08), "sun": Color(0.52, 0.68, 0.9),
		"sun_angle": Vector3(-38.0, 24.0, 0.0), "sun_energy": 0.32,
		"ambient": 0.3, "ambient_colour": Color(0.26, 0.36, 0.55),
		"fog": Color(0.16, 0.24, 0.3), "fog_density": 0.0044,
		"exposure": 1.12, "glow": false,
	},
	"neon": {
		"zenith": Color(0.03, 0.04, 0.12), "horizon": Color(0.22, 0.07, 0.24),
		"ground": Color(0.04, 0.04, 0.08), "sun": Color(0.6, 0.5, 0.9),
		"sun_angle": Vector3(-30.0, 36.0, 0.0), "sun_energy": 0.34,
		"ambient": 0.46, "ambient_colour": Color(0.38, 0.28, 0.58),
		"fog": Color(0.16, 0.1, 0.24), "fog_density": 0.0046,
		"exposure": 1.16, "glow": true,
	},
	"boss": {
		"zenith": Color(0.06, 0.05, 0.05), "horizon": Color(0.3, 0.16, 0.1),
		"ground": Color(0.06, 0.05, 0.05), "sun": Color(1.0, 0.6, 0.35),
		"sun_angle": Vector3(-24.0, 12.0, 0.0), "sun_energy": 0.55,
		"ambient": 0.28, "ambient_colour": Color(0.44, 0.3, 0.3),
		"fog": Color(0.24, 0.16, 0.12), "fog_density": 0.006,
		"exposure": 1.1, "glow": true,
	},
	"interior": {
		"zenith": Color(0.16, 0.13, 0.11), "horizon": Color(0.3, 0.24, 0.19),
		"ground": Color(0.12, 0.1, 0.08), "sun": Color(1.0, 0.82, 0.6),
		"sun_angle": Vector3(-40.0, 20.0, 0.0), "sun_energy": 0.2,
		"ambient": 0.34, "ambient_colour": Color(0.55, 0.42, 0.32),
		"fog": Color(0.22, 0.17, 0.13), "fog_density": 0.0008,
		"exposure": 1.08, "glow": false,
	},
}

const AREA_SCRIPTS := {
	"dawn_market": preload("res://scripts/world.gd"),
	"canal_quarter": preload("res://scripts/canal_quarter.gd"),
	"neon_arcade": preload("res://scripts/neon_arcade.gd"),
}

const SPAWN := Vector3(2.0, 0.0, 2.0)
const AREA_INTRO := {
	"dawn_market": "The market opens in an hour. Get the street 90% clean before the shutters go up.",
	"canal_quarter": "The tide brought the whole city's rubbish to your banks. Get the quarter 90% clean before the barge leaves.",
	"neon_arcade": "Neon rain over the arcade strip. Get it 90% clean and watch the live wires.",
}
const GOAL := 0.9
const FLOW_WINDOW := 14.0
const BASE_HOPPER := 12

const SHIFT_OBJECTIVES := {
	1: [
		{"id": "clean", "text": "GET THE MARKET 90% CLEAN"},
		{"id": "meet_nell", "flag": "met_nell", "text": "CHECK IN WITH NELL AT THE DEPOT"},
	],
	2: [
		{"id": "clean", "text": "GET THE QUARTER 82% CLEAN"},
		{"id": "drain", "text": "CLEAR A CLOGGED DRAIN"},
		{"id": "help_rook", "flag": "rook_rival", "text": "HELP ROOK ON THE BRIDGE"},
	],
	3: [
		{"id": "clean", "text": "GET THE QUARTER 88% CLEAN"},
		{"id": "drains", "text": "CLEAR ALL THREE DRAINS"},
		{"id": "gates", "text": "REACH THE TIDE LOCK GATES"},
	],
	4: [
		{"id": "clean", "text": "GET THE STRIP 90% CLEAN"},
		{"id": "meet_pip", "flag": "met_pip", "text": "CLIMB TO PIP'S ROOFTOP"},
		{"id": "cabinet", "quest": "high_score", "text": "BEAT THE TAPED-UP CABINET"},
	],
	5: [
		{"id": "clean", "text": "GET THE STRIP 90% CLEAN"},
		{"id": "boss", "text": "FACE THE GULPER UNDER THE PLANT"},
	],
}
const GATES_POS := Vector3(-19.0, 0.0, 7.0)

var phase := "title"
var world
var area
var area_id := "dawn_market"
var postfx
var _debug_label: Label
var _debug_ms := PackedFloat32Array()
var env: Environment
var sun_light: DirectionalLight3D
var sky_material: ShaderMaterial
var player
var ui
var crowd
var talking := false
var outdoor
var interior = null
var inside_interior := false
var interior_id := ""
var transitioning := false
var transition
var entered_door: Dictionary = {}
var outdoor_camera_distance := 8.8
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
var xp_milestones := 0
var sort_start := 0
var sort_mistakes := 0
var sort_correct := 0
var camera_distance := 8.8
var cam_kick := 0.0
var title_time := 0.0
var rat_spawn_marks := [35.0, 95.0]
var rat_spawned := [false, false]
var finished := false
var start_area := "dawn_market"
var start_night := false
var _prompt_cache := ""
var rain_quad: MeshInstance3D
var rain_mat: ShaderMaterial
var rain_timer := 0.0
var _puddle_state := {}
var shift_index := 1
var shift_goal := GOAL
var objectives: Array = []
var _drains_cleared := 0
var _nest_pending := false
var _nest_node: Node3D = null
var boss = null
var _boss_grime: Array[Node3D] = []
var _boss_grime_alive := 0
var cutscene = null


func _ready() -> void:
	rng.seed = 20261102
	_setup_input()
	_build_light()
	postfx = POSTFX.new()
	postfx.name = "PostFX"
	add_child(postfx)
	var state = get_node_or_null("/root/GameState")
	if state != null:
		postfx.set_quality(str(state.settings.get("quality", "standard")))
		if OS.has_feature("web"):
			var forced := int(JavaScriptBridge.eval("Number(new URLSearchParams(location.search).get('rank')) || 0", true))
			if forced >= 1 and forced <= Data.RANKS.size():
				state.rank = forced
				state.xp = maxi(state.xp, state.xp_floor(forced))
			var forced_area := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('area') || ''", true))
			if AREA_SCRIPTS.has(forced_area):
				start_area = forced_area
			start_night = bool(JavaScriptBridge.eval("location.search.indexOf('night=1') >= 0", true))
	_apply_mood("dawn")
	var world_script = AREA_SCRIPTS[start_area]
	world = world_script.new()
	world.name = start_area.to_pascal_case()
	add_child(world)
	if start_night and world.has_method("set_night"):
		world.set_night(true)
	area = world
	outdoor = world
	area_id = start_area
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
	ui.shift_pressed.connect(begin_shift)
	ui.restart_pressed.connect(_restart)
	ui.title_pressed.connect(_show_title)
	ui.resume_pressed.connect(_resume)
	ui.mute_pressed.connect(_toggle_mute)
	ui.pause_pressed.connect(_pause)
	ui.sort_choice.connect(_on_sort_choice)
	ui.sort_closed.connect(_close_sort)
	ui.interact_pressed.connect(_interact)
	ui.look_pad.looked.connect(_on_look)
	ui.dialogue_next.connect(_advance_dialogue)
	ui.dialogue_choice.connect(_choose_dialogue)
	var dialogue = get_node_or_null("/root/Dialogue")
	if dialogue != null:
		var debug_layer := CanvasLayer.new()
		debug_layer.name = "DebugLayer"
		add_child(debug_layer)
		_debug_label = Label.new()
		_debug_label.visible = false
		_debug_label.position = Vector2(12, 60)
		_debug_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
		debug_layer.add_child(_debug_label)
		dialogue.started.connect(_on_dialogue_started)
		dialogue.line.connect(_on_dialogue_line)
		dialogue.finished.connect(_on_dialogue_finished)
	crowd = CROWD.new()
	crowd.name = "Crowd"
	add_child(crowd)
	transition = TRANSITION.new()
	transition.name = "Transition"
	add_child(transition)
	cutscene = CUTSCENE.new()
	cutscene.name = "Cutscene"
	add_child(cutscene)
	cutscene._game = self
	cutscene.finished.connect(_on_cutscene_finished)
	ui.skip_pressed.connect(cutscene.skip)
	player.stack_tumbled.connect(_on_tumble)
	player.pulse_requested.connect(_on_pulse)
	player.dash_started.connect(_on_dash)
	player.landed.connect(_on_landed)
	if state != null:
		state.rank_changed.connect(_on_rank_changed)
		state.story_changed.connect(_on_story_flag)
		state.quest_changed.connect(_on_quest_changed)
		shift_index = clampi(int(state.shift_index), 1, Data.SHIFTS.size())
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
	if transitioning:
		return
	if cutscene != null and cutscene.active:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("pause"):
			cutscene.skip()
		_update_hud()
		return
	if talking:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("vacuum"):
			_advance_dialogue()
		_update_camera(delta)
		_update_hud()
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
	_update_drains(delta)
	_update_rain(delta)
	_update_puddles(delta)
	_update_boss(delta)
	_update_objectives()
	_update_rats(delta)
	_check_slip()
	_check_progress()
	_update_prompt()
	_update_hud()
	if crowd != null:
		crowd.update_player(player.global_position, player.vacuuming)
		crowd.watch_clean(clean_progress / maxf(total_weight, 0.001))
	_update_debug_frame()


func _update_debug_frame() -> void:
	if _debug_label == null or not _debug_label.visible:
		return
	var ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_debug_ms.append(ms)
	if _debug_ms.size() > 90:
		_debug_ms.remove_at(0)
	var peak := 0.0
	for sample in _debug_ms:
		peak = maxf(peak, sample)
	_debug_label.text = "fps %d  frame %.1f ms  peak %.1f ms  draw %d" % [
		Engine.get_frames_per_second(), ms, peak,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
	]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		if postfx != null:
			postfx.rect.visible = not postfx.rect.visible
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		if _debug_label != null:
			_debug_label.visible = not _debug_label.visible
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
	_bind("jump", [_key(KEY_SPACE), _pad(JOY_BUTTON_A)])
	_bind("dash", [_key(KEY_CTRL), _pad(JOY_BUTTON_B)])
	_bind("pulse", [_key(KEY_Q), _pad(JOY_BUTTON_Y)])
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
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.5, 0.68)
	env.ambient_light_energy = 0.52
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.95, 0.86, 0.72)
	env.fog_light_energy = 0.5
	env.fog_density = 0.001
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 120.0
	env.fog_sky_affect = 0.18
	env.glow_enabled = false
	env.glow_intensity = 0.35
	env.glow_strength = 0.75
	env.glow_bloom = 0.04
	env.glow_mix = 0.15
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.99
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.16
	var holder := WorldEnvironment.new()
	holder.environment = env
	add_child(holder)

	sun_light = DirectionalLight3D.new()
	sun_light.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	sun_light.light_color = Color(1.0, 0.87, 0.68)
	sun_light.light_energy = 1.05
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun_light.directional_shadow_max_distance = 46.0
	sun_light.directional_shadow_blend_splits = true
	sun_light.shadow_bias = 0.03
	sun_light.shadow_normal_bias = 1.1
	sun_light.shadow_blur = 1.2
	add_child(sun_light)


func _apply_mood(mood: String) -> void:
	if env == null:
		return
	var cfg: Dictionary = MOODS.get(mood, MOODS["dawn"])
	sky_material.set_shader_parameter("zenith", cfg.zenith)
	sky_material.set_shader_parameter("horizon", cfg.horizon)
	sky_material.set_shader_parameter("ground", cfg.ground)
	sky_material.set_shader_parameter("sun_colour", cfg.sun)
	var sun_angle: Vector3 = cfg.sun_angle
	sun_light.rotation_degrees = sun_angle
	var sun_basis := Basis.from_euler(Vector3(deg_to_rad(sun_angle.x), deg_to_rad(sun_angle.y), 0.0))
	sky_material.set_shader_parameter("sun_direction", sun_basis.z)
	env.ambient_light_energy = float(cfg.ambient)
	env.ambient_light_color = cfg.ambient_colour
	env.fog_light_color = cfg.fog
	env.fog_light_energy = 0.22
	env.fog_density = float(cfg.fog_density)
	env.tonemap_exposure = float(cfg.exposure)
	env.glow_enabled = bool(cfg.glow)
	sun_light.light_color = cfg.sun
	sun_light.light_energy = float(cfg.sun_energy)
	if postfx != null:
		postfx.set_mood(mood)


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
	rain_mat = ShaderMaterial.new()
	rain_mat.shader = load("res://scripts/rain.gdshader")
	rain_mat.set_shader_parameter("intensity", 0.55)
	rain_mat.set_shader_parameter("tint", Color(0.62, 0.78, 0.95))
	rain_quad = MeshInstance3D.new()
	rain_quad.name = "Rain"
	rain_quad.mesh = QuadMesh.new()
	rain_quad.mesh.size = Vector2(3.6, 2.4)
	rain_quad.material_override = rain_mat
	rain_quad.position = Vector3(0, 0, -1.3)
	rain_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain_quad.visible = false
	camera.add_child(rain_quad)


# ---------------------------------------------------------------- state

func _show_title() -> void:
	get_tree().paused = false
	_leave_room_now()
	_clear_run()
	phase = "title"
	finished = false
	player.visible = false
	player.locked = true
	player.global_position = SPAWN
	player.rotation.y = 0.0
	rank = _saved_rank()
	hopper_capacity = _hopper_for_rank(rank)
	player.set_rank(rank)
	cam_yaw.rotation.y = 0.0
	cam_pitch.rotation.x = -0.3
	cam_yaw.global_position = SPAWN + Vector3(0, 1.55, 0)
	world.set_clean(0.0)
	title_time = 0.0
	title_cam.current = true
	var state = get_node_or_null("/root/GameState")
	var note := ""
	if state != null and state.has_flag("gulper_calmed"):
		note = "THE GULPER SLEEPS  /  THE CITY IS CLEAN  /  THANK YOU FOR PLAYING"
	ui.show_shifts(_title_shifts(), note)
	ui.set_phase("title")
	ui.set_muted(Sound.muted)
	Sound.set_vacuum(false)
	Sound.play_music("market", 2.0)
	Sound.play_ambience("market")


func current_shift() -> Dictionary:
	return Data.shift(shift_index)


func begin_shift(index: int) -> void:
	var state = get_node_or_null("/root/GameState")
	if state != null:
		state.shift_index = clampi(index, 1, Data.SHIFTS.size())
	shift_index = clampi(index, 1, Data.SHIFTS.size())
	start_area = str(current_shift().get("district", "dawn_market"))
	_start_shift()


func _title_shifts() -> Array:
	var state = get_node_or_null("/root/GameState")
	var unlocked := 1
	var latest := 1
	if state != null:
		unlocked = clampi(int(state.unlocked_shift), 1, Data.SHIFTS.size())
		latest = clampi(int(state.shift_index), 1, unlocked)
	var entries := []
	for i in Data.SHIFTS.size():
		var index := i + 1
		entries.append({
			"index": index,
			"title": str(Data.SHIFTS[i].get("title", "SHIFT")),
			"unlocked": index <= unlocked,
			"done": state != null and state.has_flag("shift_%d_done" % index),
			"latest": latest,
		})
	return entries


func _start_shift() -> void:
	get_tree().paused = false
	_leave_room_now()
	_clear_run()
	var shift := current_shift()
	shift_goal = float(shift.get("goal", GOAL))
	objectives = []
	for entry in SHIFT_OBJECTIVES.get(shift_index, [{"id": "clean", "text": "GET THE STREET CLEAN"}]):
		var copy: Dictionary = entry.duplicate()
		copy["done"] = false
		objectives.append(copy)
	_drains_cleared = 0
	if world == null or not is_instance_valid(world) or area_id != start_area:
		load_area(start_area, Vector3.ZERO)
	if world.has_method("set_night"):
		world.set_night(bool(shift.get("night", false)))
	_spawn_market()
	crowd.watch_clean(0.0)
	_build_crowd()
	timer = 0.0
	score = 0
	rank = _saved_rank()
	clean_progress = 0.0
	xp_milestones = 0
	hopper.clear()
	hopper_capacity = _hopper_for_rank(rank)
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
	player.reset_player(world.spawn)
	player.rotation.y = 0.0
	player.set_rank(rank)
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
	Sound.play("click")
	Sound.set_vacuum(false)
	_update_hud()
	_show_briefing()


func _show_briefing() -> void:
	if _wants_poster():
		ui.subtitle(str(AREA_INTRO.get(area_id, AREA_INTRO["dawn_market"])), 6.0)
		return
	var shift := current_shift()
	var lines := []
	for entry in objectives:
		lines.append(str(entry.get("text", "")))
	player.locked = true
	transition.cover("SHIFT %d  %s" % [shift_index, str(shift.get("title", "ON SHIFT")).to_upper()], str(shift.get("brief", "The street needs you.")), "   /   ".join(lines))
	await get_tree().create_timer(2.8).timeout
	transition.reveal()
	await transition.revealed
	if phase == "play" and not talking:
		player.locked = false
	var state = get_node_or_null("/root/GameState")
	if _wants_poster() or state == null:
		ui.subtitle(str(AREA_INTRO.get(area_id, AREA_INTRO["dawn_market"])), 6.0)
		return
	var seen: bool = state.has_flag("seen_" + area_id)
	if shift_index == 1 and not state.has_flag("cold_open"):
		_cold_open()
	elif not seen:
		_district_pan()
	else:
		ui.subtitle(str(AREA_INTRO.get(area_id, AREA_INTRO["dawn_market"])), 6.0)


func _cold_open() -> void:
	var center: Vector3 = player.global_position
	var high := center + Vector3(-12.0, 9.5, 13.0)
	var close := center + Vector3(1.6, 2.3, 5.2)
	cutscene.play("cold_open", [
		{"t": "cam", "pos": high, "look": center + Vector3(0.0, 1.0, -6.0), "s": 3.2},
		{"t": "line", "speaker": "NELL", "text": "Radio: Bin City Sanitation, shift one. The whole market dumped overnight. Again."},
		{"t": "line", "speaker": "NELL", "text": "Radio: Vacuum it, sort it, bank the XP. And keep an eye on the drains. Something is clogging them on purpose."},
		{"t": "line", "speaker": "NELL", "text": "Radio: Welcome to Bin City, sweeper. Try not to smell the river."},
		{"t": "cam", "pos": close, "look": center + Vector3(0.0, 1.3, 0.0), "s": 3.0},
		{"t": "line", "speaker": "", "text": "BIN CITY"},
		{"t": "flag", "name": "cold_open"},
		{"t": "flag", "name": "seen_dawn_market"},
		{"t": "release"},
	])


func _district_pan() -> void:
	var state = get_node_or_null("/root/GameState")
	if state != null:
		state.set_flag("seen_" + area_id)
	var center: Vector3 = player.global_position
	var wide := center + Vector3(-9.0, 6.5, 11.0)
	var sweep := center + Vector3(9.0, 5.0, 11.0)
	var line := str(AREA_INTRO.get(area_id, AREA_INTRO["dawn_market"]))
	cutscene.play("district", [
		{"t": "cam", "pos": wide, "look": center + Vector3(0.0, 1.2, -4.0), "s": 2.6},
		{"t": "line", "speaker": "NELL", "text": "Radio: %s" % line},
		{"t": "cam", "pos": sweep, "look": center + Vector3(0.0, 1.2, -2.0), "s": 2.8},
		{"t": "release"},
	])


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
	if crowd != null:
		crowd.clear()


func load_area(id: String, spawn_at: Vector3) -> void:
	if area != null:
		area.queue_free()
	area = null
	world = null
	var script = AREA_SCRIPTS.get(id, AREA_SCRIPTS["dawn_market"])
	var node = script.new()
	node.name = id.to_pascal_case()
	add_child(node)
	area = node
	world = node
	area_id = id
	start_area = id
	_apply_mood(node.mood)
	total_weight = 0.0
	clean_progress = 0.0
	player.global_position = spawn_at
	Sound.play_music(str(node.music))
	Sound.play_ambience(str(node.ambience))

func _enter_interior(id: String) -> void:
	if transitioning or inside_interior or phase != "play":
		return
	transitioning = true
	entered_door = _nearest_door()
	player.locked = true
	player.vacuuming = false
	Sound.set_vacuum(false)
	Sound.play("door", 0.95, -3.0)
	ui.prompt("")
	_prompt_cache = ""
	var room = INTERIORS.build(id)
	await transition.cover(str(room.title), str(room.greeting), INTERIORS.tip(id))
	if not is_inside_tree():
		if is_instance_valid(room):
			room.free()
		return
	if crowd != null:
		crowd.clear()
	outdoor = world
	outdoor.visible = false
	outdoor.process_mode = Node.PROCESS_MODE_DISABLED
	interior = room
	interior_id = id
	add_child(interior)
	inside_interior = true
	world = interior
	if id == "bakery":
		_deliver_sacks()
		_maybe_spawn_nest()
	_apply_mood(world.mood)
	Sound.play_ambience("plant" if id == "plant" else "interior")
	outdoor_camera_distance = camera_distance
	camera_distance = 6.4
	player.global_position = world.to_global(world.spawn)
	player.velocity = Vector3.ZERO
	player.rotation.y = PI
	cam_yaw.global_position = player.global_position + Vector3(0, 1.55, 0)
	cam_pitch.rotation.x = -0.24
	cam_yaw.rotation.y = 0.0
	_build_crowd()
	_update_hud()
	await get_tree().process_frame
	transition.reveal()
	await transition.revealed
	Sound.play("reveal", 1.0, -10.0)
	transitioning = false
	if phase == "play":
		player.locked = false
	if id == "plant" and shift_index == 5:
		_start_boss()
	else:
		ui.subtitle("%s. E at the door when you are ready to leave." % str(world.title), 4.5)


func _exit_interior() -> void:
	if transitioning or not inside_interior or phase != "play":
		return
	transitioning = true
	player.locked = true
	player.vacuuming = false
	Sound.set_vacuum(false)
	ui.prompt("")
	_prompt_cache = ""
	await transition.cover(str(outdoor.title), "Back out into the shift. The street has not cleaned itself.", "TIP  The doors sit on the north wall, under their signs.")
	if not is_inside_tree():
		return
	if crowd != null:
		crowd.clear()
	if interior != null and is_instance_valid(interior):
		interior.queue_free()
	interior = null
	inside_interior = false
	interior_id = ""
	world = outdoor
	world.visible = true
	world.process_mode = Node.PROCESS_MODE_INHERIT
	_apply_mood(world.mood)
	Sound.play_ambience(str(world.ambience))
	camera_distance = outdoor_camera_distance
	if entered_door.is_empty():
		player.global_position = world.to_global(world.spawn)
		player.rotation.y = PI
		cam_yaw.rotation.y = 0.0
	else:
		player.global_position = entered_door.get("return_pos", world.spawn)
		player.rotation.y = 0.0
		cam_yaw.rotation.y = PI
	player.velocity = Vector3.ZERO
	cam_yaw.global_position = player.global_position + Vector3(0, 1.55, 0)
	cam_pitch.rotation.x = -0.3
	world.set_clean(_clean())
	_build_crowd()
	await get_tree().process_frame
	transition.reveal()
	await transition.revealed
	Sound.play("reveal", 0.9, -11.0)
	transitioning = false
	player.locked = false
	Sound.play("door", 1.05, -7.0)
	ui.subtitle("Back on the street. The shift still needs you.", 3.5)


func _leave_room_now() -> void:
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	_boss_grime.clear()
	if ui != null:
		ui.hide_boss()
	if not inside_interior:
		return
	if crowd != null:
		crowd.clear()
	if interior != null and is_instance_valid(interior):
		interior.queue_free()
	interior = null
	inside_interior = false
	interior_id = ""
	world = outdoor
	if world != null:
		world.visible = true
		world.process_mode = Node.PROCESS_MODE_INHERIT
		world.set_clean(_clean())
	camera_distance = outdoor_camera_distance
	_apply_mood(world.mood if world != null else "dawn")
	if world != null:
		Sound.play_music(str(world.music), 1.5)
		Sound.play_ambience(str(world.ambience))


func _build_crowd() -> void:
	if crowd == null:
		return
	crowd.clear()
	var points: Array = []
	for point in world.crowd_points():
		if world.is_free(point):
			points.append(world.to_global(point) + Vector3(rng.randf_range(-0.7, 0.7), 0.0, rng.randf_range(-0.7, 0.7)))
	var fallback := 3 if inside_interior else 6
	for i in fallback:
		points.append(world.to_global(world.random_walkable(rng)))
	var budget := 5 if inside_interior else 12
	crowd.build(points, budget, rng)
	for entry in _cast_for_area():
		crowd.spawn(str(entry.role), world.to_global(entry.pos), str(entry.dialogue), str(entry.name), rng)


func _cast_for_area() -> Array:
	var key := interior_id if inside_interior else area_id
	match key:
		"depot":
			var nell_id := "nell"
			if shift_index == 1:
				nell_id = "nell_intro"
			elif shift_index == 2:
				nell_id = "nell_shift_2"
			return [{"role": "nell", "pos": Vector3(3.6, 0.0, -5.1), "dialogue": nell_id, "name": "NELL QUILL"}]
		"bakery":
			return [{"role": "baker", "pos": Vector3(-3.6, 0.0, -3.2), "dialogue": "baker", "name": "BAKER"}]
		"boathouse":
			var odo_id := "ferryman"
			if shift_index == 2:
				odo_id = "odo_bottles"
			return [{"role": "ferryman", "pos": Vector3(4.8, 0.0, 3.6), "dialogue": odo_id, "name": "FERRYMAN"}]
		"arcade":
			return [{"role": "arcade_kid", "pos": Vector3(-1.3, 0.0, -4.2), "dialogue": "arcade_kid", "name": "JOYSTICK"}]
		"plant":
			return [{"role": "keeper", "pos": Vector3(3.4, 0.0, 1.6), "dialogue": "keeper_0", "name": "PLANT KEEPER"}]
		"canal_quarter":
			var rook_id := "rook"
			if shift_index >= 2:
				rook_id = "rook_meet"
			return [
				{"role": "rook", "pos": Vector3(-8.0, 0.0, 0.2), "dialogue": rook_id, "name": "ROOK"},
				{"role": "keeper", "pos": Vector3(-17.0, 0.0, 1.2), "dialogue": "keeper_1", "name": "LOCK KEEPER"},
				{"role": "cat", "pos": Vector3(12.0, 0.0, 14.2), "dialogue": "miso", "name": "MISO"},
			]
		"neon_arcade":
			var pip_id := "pip"
			if shift_index >= 4:
				pip_id = "pip_high_score"
			return [
				{"role": "pip", "pos": Vector3(15.4, 2.4, 12.9), "dialogue": pip_id, "name": "PIP"},
				{"role": "arcade_kid", "pos": Vector3(-2.0, 0.0, -8.6), "dialogue": "arcade_kid", "name": "JOYSTICK"},
				{"role": "cat", "pos": Vector3(9.0, 0.0, 13.4), "dialogue": "miso", "name": "MISO"},
			]
	return [
		{"role": "nell", "pos": Vector3(7.4, 0.0, 3.4), "dialogue": "nell", "name": "NELL QUILL"},
		{"role": "rook", "pos": Vector3(-7.0, 0.0, 5.6), "dialogue": "rook", "name": "ROOK"},
		{"role": "baker", "pos": Vector3(-12.4, 0.0, 0.6), "dialogue": "baker", "name": "BAKER"},
		{"role": "cat", "pos": Vector3(-4.6, 0.0, 10.4), "dialogue": "miso", "name": "MISO"},
	]


func _spawn_market() -> void:
	world.set_clean(0.0)
	total_weight = 0.0
	var mix: Array = world.litter_mix()
	for i in int(world.light_count):
		_spawn_litter(str(mix[rng.randi_range(0, mix.size() - 1)]))
	var heavies: Array = world.heavy_mix()
	for i in int(world.heavy_count):
		_spawn_litter(str(heavies[i % heavies.size()]))
	var spots: Array = world.pile_spots()
	for i in int(world.pile_count):
		if spots.is_empty():
			break
		var spot: Vector3 = spots[i % spots.size()]
		var pile = PILE.new()
		pile.position = spot
		world.add_child(pile)
		piles.append({"node": pile})
		total_weight += float(pile.get("base_weight"))
	var grime_total := int(world.get("grime_count"))
	for i in grime_total:
		_spawn_litter("grime")
	var token_value = world.get("token_count")
	var token_total := int(token_value) if token_value != null else 0
	for i in token_total:
		_spawn_litter("token")
	if world.get("roof_token_pos") != null and not inside_interior:
		var roof_token = LITTER.new()
		roof_token.build("token", rng)
		roof_token.position = world.get("roof_token_pos")
		world.add_child(roof_token)
		litter_nodes.append(roof_token)
		total_weight += float(roof_token.get("weight"))
	if world.has_method("litter_puddle"):
		for entry in world.get("electric_puddles"):
			var node = LITTER.new()
			node.build("bottle", rng)
			node.position = entry.pos + Vector3(rng.randf_range(-0.4, 0.4), 0.0, rng.randf_range(-0.3, 0.3))
			world.add_child(node)
			litter_nodes.append(node)
			total_weight += float(node.get("weight"))


func _spawn_litter(kind: String) -> void:
	var node = LITTER.new()
	node.build(kind, rng)
	if bool(node.get("floating")) and world.has_method("float_spot"):
		node.position = world.float_spot(rng)
	elif kind == "grime" and world.has_method("next_grime_spot"):
		node.position = world.next_grime_spot()
	else:
		node.position = _free_spot(1.15)
	world.add_child(node)
	litter_nodes.append(node)
	total_weight += float(node.get("weight"))


func _free_spot(clearance: float) -> Vector3:
	var home: Vector3 = world.spawn
	var spots: Array = world.pile_spots()
	var fallback: Vector3 = world.random_walkable(rng)
	for attempt in 60:
		var point: Vector3 = world.random_walkable(rng)
		if Vector2(point.x - home.x, point.z - home.z).length() < 3.4:
			continue
		var clear := true
		for spot in spots:
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


func _update_drains(delta: float) -> void:
	if inside_interior or world == null or not world.has_method("clear_drain"):
		return
	var drains: Array = world.get("drains")
	for entry in drains:
		if not bool(entry.clogged):
			continue
		entry.timer = float(entry.timer) + delta
		var target = entry.get("target")
		if target == null or not _available(target):
			entry.target = null
			if float(entry.timer) >= 2.5:
				entry.timer = 0.0
				var grate: Vector3 = entry.pos
				var found = _nearest_floating(grate, 4.5)
				if found != null:
					entry.target = found
		else:
			var grate: Vector3 = entry.pos
			target.call("pull", grate, delta * 0.9)
			var flat := Vector2(target.position.x - grate.x, target.position.z - grate.z)
			if flat.length() < 0.55:
				_swallow(target)
				entry.target = null


func _update_rain(delta: float) -> void:
	var raining := false
	if not inside_interior and world != null:
		var rain_value = world.get("raining")
		raining = bool(rain_value) if rain_value != null else false
	if rain_quad != null:
		rain_quad.visible = raining
	if player != null:
		player.traction = 0.85 if raining else 1.0
	if not raining:
		return
	rain_timer -= delta
	if rain_timer <= 0.0:
		rain_timer = 0.22
		_spawn_ripple()


func _spawn_ripple() -> void:
	var node = LITTER.new()
	node.build("bottle_cap", rng)
	node.position = _free_spot(1.0) + Vector3(0, 0.02, 0)
	node.scale = Vector3(1.6, 0.4, 1.6)
	world.add_child(node)
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector3(0.1, 0.05, 0.1), 0.7)
	tween.tween_callback(node.queue_free)


func _update_puddles(delta: float) -> void:
	if inside_interior or world == null or not world.has_method("litter_puddle"):
		return
	var puddles: Array = world.get("electric_puddles")
	if puddles.is_empty():
		return
	for i in puddles.size():
		var entry: Dictionary = puddles[i]
		if not bool(entry.get("hazard", false)):
			continue
		var pos: Vector3 = entry.pos
		var live := false
		for node in litter_nodes:
			if not _available(node) or bool(node.get("heavy")):
				continue
			if Vector2(node.position.x - pos.x, node.position.z - pos.z).length() < float(entry.get("radius", 1.25)):
				live = true
				break
		var sparks = entry.get("sparks")
		if live:
			if sparks != null and is_instance_valid(sparks):
				sparks.visible = true
				sparks.rotation.y += delta * 9.0
			entry.crackle = float(entry.get("crackle", 0.4)) - delta
			if float(entry.crackle) <= 0.0:
				entry.crackle = rng.randf_range(0.35, 0.9)
				Sound.play("zap", rng.randf_range(0.8, 1.15), -8.0)
			var light = entry.get("sign_light")
			if light != null and is_instance_valid(light):
				light.light_energy = 1.6 + sin(timer * 21.0 + i * 2.4) * 0.7
			var flat := Vector2(player.global_position.x - pos.x, player.global_position.z - pos.z)
			if flat.length() < float(entry.get("radius", 1.25)) * 0.85 and player.is_on_floor() and player.slip_timer <= 0.0:
				player.apply_shock()
				Sound.play("zap", 1.0, -2.0)
				ui.subtitle("Live wire! Vacuum the litter out of the puddle.", 4.0)
		else:
			if bool(entry.get("was_live", false)):
				entry.was_live = false
				if world.has_method("litter_puddle"):
					world.litter_puddle(pos)
				_grant_xp(15)
				ui.subtitle("Puddle safe. The sign steadies back to neon.", 3.5)
				Sound.play("burst", 0.9, -5.0)
		entry.was_live = live
		entry.active = live


func _nearest_floating(origin: Vector3, radius: float):
	var best_node = null
	var best := radius
	for node in litter_nodes:
		if not _available(node) or not bool(node.get("floating")):
			continue
		var distance := Vector2(node.global_position.x - origin.x, node.global_position.z - origin.z).length()
		if distance < best:
			best = distance
			best_node = node
	return best_node


func _swallow(node: Node3D) -> void:
	total_weight = maxf(1.0, total_weight - float(node.get("weight")))
	node.set("collected", true)
	node.queue_free()
	Sound.play("rustle", 0.7, -7.0)


func _clear_drain_at(pos: Vector3) -> void:
	var index := _nearest_clogged_drain(3.2, pos)
	if index < 0:
		return
	var drains: Array = world.get("drains")
	var grate: Vector3 = drains[index].pos
	world.clear_drain(index)
	_grant_xp(40)
	_drains_cleared += 1
	_objective_done("drain")
	if world.has_method("clear_drain"):
		var all_clear := true
		for entry in drains:
			if bool(entry.clogged):
				all_clear = false
				break
		if all_clear:
			_objective_done("drains")
	for release_kind in ["float_bottle", "float_bag", "bottle_cap"]:
		_spawn_litter(release_kind)
		var node = litter_nodes[litter_nodes.size() - 1]
		node.position = grate + Vector3(rng.randf_range(-0.8, 0.8), 0.0, rng.randf_range(1.0, 1.7))
	ui.subtitle("Drain clear. The trapped bottles bob loose by the grate.", 4.0)
	Sound.play("burst", 0.85, -4.0)


func _nearest_clogged_drain(radius: float, origin := Vector3(1.0e9, 0.0, 0.0)) -> int:
	if world == null or not world.has_method("clear_drain"):
		return -1
	if origin.x > 1.0e8:
		origin = player.global_position
	var best := -1
	var best_distance := radius
	var drains: Array = world.get("drains")
	for i in drains.size():
		var entry: Dictionary = drains[i]
		if not bool(entry.clogged):
			continue
		var grate: Vector3 = entry.pos
		var distance := Vector2(origin.x - grate.x, origin.z - grate.z).length()
		if distance < best_distance:
			best_distance = distance
			best = i
	return best


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
		var reach: float = 3.2 + float(player.vacuum_radius)
		var grab: float = 1.15 + 0.09 * float(player.rank)
		for node in litter_nodes:
			if not _available(node) or bool(node.get("heavy")):
				continue
			var offset: Vector3 = node.global_position - origin
			offset.y = 0.0
			var distance := offset.length()
			if distance > reach:
				continue
			if distance > 0.4 and facing.dot(offset / distance) < 0.28:
				continue
			node.call("pull", origin + facing * 0.75, delta)
			if distance < grab:
				_collect(node)
		if hopper.size() >= hopper_capacity and vacuum_time > 0.2:
			_release_vacuum(false)
			ui.subtitle("Hopper full. The depot bins are waiting.", 4.0)
	else:
		if player.vacuuming:
			_release_vacuum(room)
		charge = minf(100.0, charge + 28.0 * delta)
		if player.can_magnet and phase == "play":
			var facing: Vector3 = -player.global_transform.basis.z
			facing.y = 0.0
			facing = facing.normalized()
			for node in litter_nodes:
				if not _available(node) or bool(node.get("heavy")):
					continue
				var offset: Vector3 = node.global_position - player.global_position
				offset.y = 0.0
				if offset.length() < player.vacuum_radius:
					node.call("pull", player.global_position + facing * 0.5, delta * 0.3)


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
	var was_grime := str(node.get("kind")) == "grime"
	var was_pos: Vector3 = node.global_position
	var item := {
		"name": str(node.get("display")),
		"kind": str(node.get("sort_kind")),
		"swatch": node.get("tint"),
		"weight": float(node.get("weight")),
	}
	hopper.append(item)
	node.queue_free()
	if was_grime:
		_clear_drain_at(was_pos)
	if node.has_meta("nest"):
		_grant_xp(150)
		ui.subtitle("Nest cleared. The storeroom airs out and the rats relocate to the canal.", 5.0)
	if str(node.get("kind")) == "token":
		Sound.play("token", 1.0, -2.0)
		var state = get_node_or_null("/root/GameState")
		if state != null and state.quest_status("high_score") == "active":
			state.advance_quest("high_score", 1)
			var left := int(state.quests["high_score"]["goal"]) - int(state.quests["high_score"]["progress"])
			if left > 0:
				ui.subtitle("Arcade token! %d to go before the cabinet will listen." % left, 4.0)
	score += 2
	_grant_xp(8)
	flow_time = FLOW_WINDOW
	Sound.play("pickup", rng.randf_range(0.92, 1.12))
	if hopper.size() == 1:
		ui.subtitle("Litter goes in the hopper. Sorting happens at a depot.", 4.5)
	if hopper.size() >= hopper_capacity:
		var station_label := "A DEPOT"
		if world.stations.size() > 0:
			station_label = str(world.stations[0].get("label", "A DEPOT"))
		ui.subtitle("Hopper full. Head for %s." % station_label, 5.0)


# ---------------------------------------------------------------- carry and sort

func _interact() -> void:
	if talking:
		_advance_dialogue()
		return
	if phase != "play" or player.locked:
		return
	if crowd != null:
		var npc = crowd.nearest(player.global_position, 2.8)
		if npc != null:
			var info: Dictionary = npc.talk()
			if str(info.get("id", "")) == "ferryman":
				_turn_in_bottles()
			var dialogue = get_node_or_null("/root/Dialogue")
			if dialogue != null and dialogue.start(str(info.get("id", ""))):
				return
	var door := _nearest_door()
	if not door.is_empty():
		if inside_interior:
			if interior_id == "plant" and boss != null and is_instance_valid(boss) and boss.active:
				ui.subtitle("The door is jammed from the shake. The Gulper is still awake.", 4.0)
				Sound.play("click")
				return
			_exit_interior()
		else:
			_enter_interior(str(door.get("id", "depot")))
		return
	if boss != null and is_instance_valid(boss) and boss.active:
		if boss.phase == 3 and not hopper.is_empty():
			var mouth: Vector3 = boss.mouth_position()
			if Vector2(mouth.x - player.global_position.x, mouth.z - player.global_position.z).length() < 3.2:
				_feed_boss_core()
				return
		elif boss.phase != 3:
			var chute: Dictionary = _nearest_boss_chute(2.4)
			if not chute.is_empty():
				if bool(chute.get("open", false)):
					_feed_boss(str(chute.get("kind", "")))
				else:
					ui.subtitle("That chute is shut. Wait for a lamp to turn green.", 3.5)
					Sound.play("click")
				return
	if _near_save():
		_save_at_desk()
		return
	if inside_interior and interior_id == "arcade" and _near_arcade_cabinet():
		_play_cabinet()
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


func _turn_in_bottles() -> void:
	var state = get_node_or_null("/root/GameState")
	if state == null or state.quest_status("bottles") != "active":
		return
	var glass := 0
	for i in range(hopper.size() - 1, -1, -1):
		if str(hopper[i].get("kind")) == "glass":
			hopper.remove_at(i)
			glass += 1
	if glass <= 0:
		return
	state.advance_quest("bottles", glass)
	Sound.play("pickup", 0.9, -4.0)
	var quest: Dictionary = state.quests.get("bottles", {})
	var left := int(quest.get("goal", 5)) - int(quest.get("progress", 0))
	if left > 0:
		ui.subtitle("Odo counts %d bottle%s into the crate. %d to go." % [glass, "s" if glass > 1 else "", left], 4.5)
	else:
		ui.subtitle("Five bottles home. Odo taps the crate twice, which is a standing ovation.", 5.0)


func _deliver_sacks() -> void:
	var state = get_node_or_null("/root/GameState")
	if state == null or state.quest_status("bakery") != "active":
		return
	var delivered: int = player.remove_kind("sack")
	if delivered <= 0:
		return
	state.advance_quest("bakery", delivered)
	Sound.play("throw", 1.1, -4.0)
	var quest: Dictionary = state.quests.get("bakery", {})
	var left := int(quest.get("goal", 3)) - int(quest.get("progress", 0))
	if left > 0:
		ui.subtitle("Flour sack delivered. %d to go." % left, 4.0)
	else:
		_nest_pending = true
		ui.subtitle("That is the last sack. Something rustles in the storeroom.", 5.0)


func _maybe_spawn_nest() -> void:
	if not _nest_pending:
		return
	if _nest_node != null and is_instance_valid(_nest_node):
		return
	_nest_pending = false
	var node = LITTER.new()
	node.build("grime", rng)
	node.set_meta("nest", true)
	node.position = Vector3(3.4, 0.0, -3.4)
	world.add_child(node)
	litter_nodes.append(node)
	total_weight += float(node.get("weight"))
	_nest_node = node
	ui.subtitle("A rat nest in the flour dust. Vacuum it out.", 4.5)


func _start_boss() -> void:
	if boss != null and is_instance_valid(boss):
		return
	boss = BOSS.new()
	world.add_child(boss)
	boss.setup(world)
	boss.damaged.connect(func(_health: float) -> void: Sound.play("burst", 0.8, -4.0))
	boss.stomp.connect(_on_boss_stomp)
	boss.suction.connect(_on_boss_suction)
	boss.volley.connect(_on_boss_volley)
	boss.phase_changed.connect(_on_boss_phase)
	boss.defeated.connect(_ending)
	var mouth: Vector3 = boss.mouth_position()
	var player_local: Vector3 = world.to_local(player.global_position)
	var cam_wide: Vector3 = world.to_global(player_local + Vector3(3.8, 2.6, 2.4))
	var cam_close: Vector3 = world.to_global(player_local + Vector3(-2.6, 2.2, 3.4))
	cutscene.play("boss_intro", [
		{"t": "shake", "amount": 0.3, "s": 1.2},
		{"t": "cam", "pos": cam_wide, "look": mouth, "s": 1.8},
		{"t": "line", "speaker": "SULLAGE", "text": "Radio: Well, well. The little sweeper. You are standing on my gravy train."},
		{"t": "line", "speaker": "SULLAGE", "text": "Radio: The Gulper eats what I dump and I dump what the city pays me to lose. Keep it dirty, keep me rich."},
		{"t": "line", "speaker": "NELL", "text": "Radio: That is a Sullage Haulage band, broadcasting from under your feet. Calm the Gulper and his ledger is ours."},
		{"t": "flag", "name": "sullage_overclock"},
		{"t": "cam", "pos": cam_close, "look": player.global_position + Vector3(0.0, 1.4, 0.0), "s": 1.4},
		{"t": "release"},
	])


func _update_boss(delta: float) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	if boss.suction_on and player != null:
		var mouth: Vector3 = boss.mouth_position()
		var flat := Vector2(mouth.x - player.global_position.x, mouth.z - player.global_position.z)
		var distance := maxf(flat.length(), 0.4)
		var pull := 10.0 / distance
		pull = clampf(pull, 1.2, 7.5)
		player.external_pull = Vector3(flat.x / distance, 0.0, flat.y / distance) * pull * delta * 60.0
	boss.set_chute_lights(boss.open_kinds())
	if boss.grime_blocked:
		var alive := 0
		for node in _boss_grime:
			if is_instance_valid(node):
				alive += 1
		if alive == 0:
			boss.grime_blocked = false
			_boss_grime.clear()
			ui.subtitle("The chutes are clear. Keep feeding it.", 4.0)
			Sound.play("pickup", 1.2, -4.0)
	var strip := ""
	if boss.phase == 3:
		strip = "CORE OPEN  /  CALM %d OF %d  /  E AT THE CORE" % [int(boss.calm), int(boss.CALM_GOAL)]
	elif boss.grime_blocked:
		strip = "GRIME BLOCKS THE CHUTES  /  VACUUM IT OUT"
	else:
		var kinds: Array = boss.open_kinds()
		if kinds.is_empty():
			strip = "CHUTES CLOSED  /  DODGE THE VOLLEYS"
		else:
			var labels := []
			for kind in kinds:
				labels.append(str(kind).to_upper())
			strip = "OPEN CHUTES  /  " + " + ".join(labels)
	ui.update_boss(boss.health, boss.MAX_HEALTH, boss.phase, strip)


func _nearest_boss_chute(max_distance: float) -> Dictionary:
	if boss == null or not is_instance_valid(boss):
		return {}
	var best: Dictionary = {}
	var best_distance := max_distance
	for point in boss.chute_points():
		var pos: Vector3 = point.pos
		var distance := Vector2(pos.x - player.global_position.x, pos.z - player.global_position.z).length()
		if distance < best_distance:
			best_distance = distance
			best = point
	return best


func _feed_boss(kind: String) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var items: Array[Dictionary] = []
	for i in range(hopper.size() - 1, -1, -1):
		if str(hopper[i].get("kind", "")) == kind:
			items.append(hopper[i])
			hopper.remove_at(i)
	if items.is_empty():
		ui.subtitle("The %s chute wants %s litter. Vacuum some up." % [kind.to_upper(), kind], 4.0)
		Sound.play("click")
		return
	var result: Dictionary = boss.feed(kind, items)
	if result.damage <= 0.0:
		return
	Sound.play("throw", 0.9, -2.0)
	ui.boss_warn()
	var left := int(boss.health / boss.HIT_DAMAGE + 0.99)
	if result.stomp:
		ui.subtitle("It staggers. Every third feed makes it stomp. Jump the shockwave.", 4.5)
	else:
		ui.subtitle("Direct hit. About %d more good feeds." % left, 3.0)


func _feed_boss_core() -> void:
	if boss == null or not is_instance_valid(boss) or hopper.is_empty():
		return
	var items: Array[Dictionary] = hopper.duplicate()
	hopper.clear()
	boss.feed_core(items)
	Sound.play("throw", 0.7, -2.0)
	ui.subtitle("The core drinks it in. Calm %d of %d." % [int(boss.calm), int(boss.CALM_GOAL)], 3.5)


func _on_boss_stomp() -> void:
	Sound.play("stomp", 0.95, 0.0)
	ui.boss_warn()
	if player != null and player.is_on_floor():
		player.apply_shock()
		ui.subtitle("Shockwave. Jump when it rears up.", 3.5)
	else:
		ui.subtitle("Airborne. The shockwave rolls under you.", 3.0)


func _on_boss_suction(on: bool) -> void:
	if on:
		Sound.play("dash", 0.55, 0.0)
		ui.boss_warn()
		ui.subtitle("Suction. Sprint or dash against the pull.", 3.0)


func _on_boss_volley(origin: Vector3) -> void:
	Sound.play("pile", 0.9, -2.0)
	for i in 2:
		var node = LITTER.new()
		var kind: String = BOSS.CHUTE_KINDS[rng.randi_range(0, BOSS.CHUTE_KINDS.size() - 1)]
		node.build(kind, rng)
		var offset := Vector3(rng.randf_range(-1.4, 1.4), 0.0, rng.randf_range(-0.6, 1.6))
		node.position = world.to_local(origin + offset)
		world.add_child(node)
		litter_nodes.append(node)
		total_weight += float(node.get("weight"))


func _on_boss_phase(phase_number: int) -> void:
	Sound.set_boss_layer(phase_number)
	Sound.play("roar", 1.0 + (phase_number - 1) * 0.08, 0.0)
	ui.boss_warn()
	if phase_number == 2:
		boss.grime_blocked = true
		_boss_grime.clear()
		var points: Array = boss.chute_points()
		for i in [0, 2]:
			if i >= points.size():
				break
			var node = LITTER.new()
			node.build("grime", rng)
			node.position = world.to_local(points[i].pos)
			world.add_child(node)
			litter_nodes.append(node)
			total_weight += float(node.get("weight"))
			_boss_grime.append(node)
		ui.subtitle("It overclocks. Grime slams the chutes shut. Vacuum it clear.", 5.0)
	elif phase_number == 3:
		ui.subtitle("It slows. The core hatch hangs open. Empty the hopper into it.", 5.5)


func _ending() -> void:
	if boss != null and is_instance_valid(boss):
		boss.active = false
	ui.hide_boss()
	Sound.play("finish", 0.8, -2.0)
	var state = get_node_or_null("/root/GameState")
	if state != null:
		state.set_flag("gulper_calmed")
		state.add_xp(800)
	_objective_done("boss")
	var mouth: Vector3 = boss.mouth_position() if boss != null and is_instance_valid(boss) else player.global_position + Vector3(0.0, 1.5, -6.0)
	var player_local: Vector3 = world.to_local(player.global_position)
	var cam_wide: Vector3 = world.to_global(player_local + Vector3(-4.4, 3.4, 3.6))
	var cam_close: Vector3 = world.to_global(player_local + Vector3(0.6, 2.4, 4.2))
	cutscene.play("ending", [
		{"t": "music", "track": "ending"},
		{"t": "cam", "pos": cam_wide, "look": mouth, "s": 2.2},
		{"t": "line", "speaker": "", "text": "The drum winds down. Steam sighs out of the stacks. The Gulper sleeps."},
		{"t": "line", "speaker": "SULLAGE", "text": "Radio: No. No, no, no. Do you know what that machine was worth? That was my retirement."},
		{"t": "line", "speaker": "NELL", "text": "Radio: Whole city heard that confession. Sanitation office, new badge, and the Sullage ledger. Promoted, sweeper."},
		{"t": "flag", "name": "promoted"},
		{"t": "cam", "pos": cam_close, "look": player.global_position + Vector3(0.0, 1.4, 0.0), "s": 2.2},
		{"t": "line", "speaker": "", "text": "Bin City is clean. For tonight, anyway."},
		{"t": "release"},
	])


func _near_arcade_cabinet() -> bool:
	if player == null or world == null:
		return false
	var local: Vector3 = world.to_local(player.global_position)
	var flat := Vector2(local.x + 6.5, local.z + 4.9)
	return flat.length() < 1.6


func _play_cabinet() -> void:
	var state = get_node_or_null("/root/GameState")
	if state == null:
		return
	if state.quest_status("high_score") != "active":
		ui.subtitle("The taped-up cabinet hums. It only listens to token hunters.", 4.0)
		Sound.play("click", 0.9)
		return
	var quest: Dictionary = state.quests.get("high_score", {})
	if int(quest.get("progress", 0)) < 3:
		ui.subtitle("The cabinet wants three tokens fed first. Check the litter out there.", 4.5)
		Sound.play("click", 0.9)
		return
	state.advance_quest("high_score", 1)
	ui.subtitle("Three tokens in. The cabinet wakes up and coughs out a high score. Pip owes you a roof route.", 5.5)
	Sound.play("burst", 1.0, -3.0)
	Sound.play("pickup", 1.3, -6.0)


func _lift(node: Node3D) -> void:
	if player.stack_count() >= player.max_stack:
		return
	node.set("collected", true)
	player.add_to_stack(node)
	Sound.play("lift", rng.randf_range(0.9, 1.05))
	score += 3
	_grant_xp(14)
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
	_grant_xp(int(weight) * 3)
	flow_chain += 1
	flow_time = FLOW_WINDOW
	Sound.play("throw", 0.9)
	ui.subtitle("Load tipped. %d more of the street is gone." % int(weight), 3.5)
	_refresh_clean()


func _bag_pile(pile: Node3D) -> void:
	var weight := float(pile.call("total_weight"))
	clean_progress += weight
	score += 45 + int(weight * 5.0)
	_grant_xp(45)
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
		_grant_xp(22)
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

func _update_objectives() -> void:
	for entry in objectives:
		if bool(entry.get("done", false)):
			continue
		match str(entry.get("id", "")):
			"gates":
				if not inside_interior and area_id == "canal_quarter":
					if Vector2(player.global_position.x - GATES_POS.x, player.global_position.z - GATES_POS.z).length() < 3.2:
						_objective_done("gates")
						ui.subtitle("TIDE LOCK 3. Fresh dump slurry on the gates. Sullage's foreman was here tonight.", 6.0)


func _check_slip() -> void:
	if player.slip_timer > 0.1:
		return
	if Vector2(player.velocity.x, player.velocity.z).length() < 5.8:
		return
	if world.near_puddle(player.global_position, 0.15):
		player.apply_slip()
		Sound.play("slip", rng.randf_range(0.9, 1.05))
		ui.subtitle("Wet cobbles. Sprint somewhere dry.", 2.8)


func _on_pulse(origin: Vector3, radius: float) -> void:
	if phase != "play":
		return
	var taken := 0
	for node in litter_nodes:
		if taken >= 8 or hopper.size() >= hopper_capacity:
			break
		if not _available(node) or bool(node.get("heavy")):
			continue
		if node.global_position.distance_to(origin) <= radius:
			_collect(node)
			taken += 1
	for entry in rats:
		var rat = entry.get("node")
		if is_instance_valid(rat) and rat.global_position.distance_to(origin) < radius * 1.6:
			_scare_rat(entry)
	_burst_ring(origin)
	flow_time = FLOW_WINDOW
	ui.subtitle("Cleanse pulse. The street remembers who runs it.", 3.0)


func _on_dash() -> void:
	if phase != "play":
		return
	cam_kick = 0.22
	_burst_ring(player.global_position)


func _on_landed(hard: bool) -> void:
	if not hard or phase != "play":
		return
	_burst_ring(player.global_position)
	cam_kick = maxf(cam_kick, 0.1)


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
	if inside_interior:
		return
	var clean := _clean()
	var marks := [0.25, 0.5, 0.75, 0.9]
	while xp_milestones < marks.size() and clean >= float(marks[xp_milestones]):
		xp_milestones += 1
		_grant_xp(60)
	if phase == "play" and clean >= shift_goal and not finished:
		_finish()


func _refresh_clean() -> void:
	world.set_clean(_clean())
	_check_progress()


func _clean() -> float:
	return clampf(clean_progress / maxf(total_weight, 1.0), 0.0, 1.0)


func _grant_xp(amount: int) -> void:
	var state = get_node_or_null("/root/GameState")
	if state == null or amount <= 0:
		return
	state.add_xp(amount)


func _saved_rank() -> int:
	var state = get_node_or_null("/root/GameState")
	if state == null:
		return 1
	return clampi(int(state.rank), 1, Data.RANKS.size())


func _hopper_for_rank(value: int) -> int:
	return BASE_HOPPER + (value - 1) * 4


func _rank_line(value: int) -> String:
	match value:
		2:
			return "Bigger hopper, quicker boots, and a coat that means business."
		3:
			return "Sign plate armour, a magnet gauntlet, and a dash on Ctrl or B."
		4:
			return "Twin turbines, a tarpaulin cape, and a double jump on Space or A."
		5:
			return "Orbit bins, a comet broom, and the cleanse pulse on Q or Y."
	return "Straw cap, a broom, and a quiet kind of pride."


func _on_rank_changed(value: int) -> void:
	rank = clampi(value, 1, Data.RANKS.size())
	hopper_capacity = _hopper_for_rank(rank)
	if player != null:
		player.set_rank(rank)
	if crowd != null:
		crowd.cheer()
	if ui == null:
		return
	Sound.play("rank", 1.0, -2.0)
	ui.show_rank(rank, _rank_line(rank))
	if phase == "play":
		ui.subtitle("RANK UP. %s. %s" % [Data.rank_title(rank), _rank_line(rank)], 6.5)
		if cutscene != null and not cutscene.active and not talking and not inside_interior:
			var center: Vector3 = player.global_position
			var yaw := cam_yaw.rotation.y
			var from := center + Vector3(sin(yaw) * 5.2, 2.3, cos(yaw) * 5.2)
			var to := center + Vector3(sin(yaw + PI) * 5.2, 2.3, cos(yaw + PI) * 5.2)
			cutscene.play("rank", [
				{"t": "cam", "pos": from, "look": center + Vector3(0.0, 1.2, 0.0), "s": 0.05},
				{"t": "cam", "pos": to, "look": center + Vector3(0.0, 1.2, 0.0), "s": 2.2},
				{"t": "release"},
			])


# ---------------------------------------------------------------- dialogue

func _on_dialogue_started(_id: String) -> void:
	talking = true
	if player != null:
		player.locked = true
		player.vacuuming = false
	Sound.set_vacuum(false)
	ui.prompt("")
	Sound.play("click", 1.1, -6.0)


func _on_dialogue_line(speaker: String, text: String, choices: Array) -> void:
	ui.open_dialogue(speaker, text, choices)
	if speaker == "MISO":
		Sound.play("cat", 1.0, -2.0)
	elif speaker == "PIGEON":
		Sound.play("pigeon", 1.0, -2.0)
	else:
		Sound.blip(speaker)


func _on_cutscene_finished(id: String) -> void:
	if id == "ending":
		_finish()
		return
	if id == "boss_intro" and boss != null and is_instance_valid(boss):
		boss.begin()
		ui.show_boss("THE GULPER")
		ui.subtitle("The Gulper wakes. Feed each chute the litter it asks for.", 6.0)
		Sound.play_music("boss", 0.5)
		Sound.play("roar", 0.9, -2.0)
	if phase == "play" and not talking and player != null:
		player.locked = false


func _on_dialogue_finished(id: String) -> void:
	talking = false
	ui.close_dialogue()
	if id == "nell" or id == "nell_intro" or id == "nell_shift_2":
		_objective_done("meet_nell")
	if player != null and phase == "play":
		player.locked = false


func _advance_dialogue() -> void:
	if ui == null:
		return
	if ui.dialogue_typing():
		ui.finish_typing()
		return
	if ui.dialogue_open():
		var dialogue = get_node_or_null("/root/Dialogue")
		if dialogue != null:
			dialogue.advance()


func _choose_dialogue(index: int) -> void:
	var dialogue = get_node_or_null("/root/Dialogue")
	if dialogue == null:
		return
	if ui.dialogue_typing():
		ui.finish_typing()
	dialogue.choose(index)



const SHIFT_RESULTS_LINES := {
	1: "The nine o'clock bell rings on a clean market. Nell checks the bins twice. They were emptied last night, and the street was still full. Someone is dumping.",
	2: "The barge leaves with nothing left to collect. Odo tips his hat. Rook owes you a manifest with a Sullage Haulage stamp on it.",
	3: "The lock holds and the lamps burn all night. Rook sweeps beside you now. The manifest points at the sorting plant under the neon strip.",
	4: "The strip shines through the rain. Pip salutes from the roof. Under the plant, something enormous is turning in its sleep.",
	5: "The drum winds down and the core goes dark. The Gulper sleeps, the rain stops, and the city finally smells like morning.",
}

func _finish() -> void:
	finished = true
	phase = "results"
	player.locked = true
	player.vacuuming = false
	Sound.set_vacuum(false)
	best = maxi(best, score)
	_save_best()
	_grant_xp(220 + (80 if _clean() >= shift_goal else 0))
	var shift := current_shift()
	var state = get_node_or_null("/root/GameState")
	if state != null:
		state.set_flag("shift_%d_done" % shift_index)
		if shift_index < Data.SHIFTS.size():
			state.unlock_shift(shift_index + 1)
		var key := area_id
		state.best_scores[key] = maxi(int(state.best_scores.get(key, 0)), score)
		state.save()
	_objective_done("clean")
	Sound.play("finish", 1.0, -2.0)
	Sound.play("bell", 0.9, -6.0)
	Sound.play("unlock", 1.0, -9.0)
	ui.set_phase("results")
	var next := 0
	var next_title := ""
	if shift_index < 4:
		next = shift_index + 1
		next_title = str(Data.shift(next).get("title", "ONWARDS"))
	ui.show_results({
		"title": str(shift.get("title", "STREET RESTORED")).to_upper(),
		"line": str(SHIFT_RESULTS_LINES.get(shift_index, "The street is clean and the bell is still ringing.")),
		"time": timer,
		"score": score,
		"best": best,
		"sorted": sorted_total,
		"rank": rank,
		"clean": _clean(),
		"next": next,
		"next_title": next_title,
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
	if cutscene != null and cutscene.active:
		return
	cam_kick = maxf(0.0, cam_kick - delta)
	camera.fov = lerpf(camera.fov, 58.0 + clampf(cam_kick / 0.22, 0.0, 1.0) * 7.0, minf(1.0, delta * 14.0))
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
		player.touch_jump = ui.touch_wants_jump()
		player.touch_dash = ui.touch_wants_dash()
		player.touch_pulse = ui.touch_wants_pulse()
	else:
		player.touch_input = Vector2.ZERO
		player.touch_sprint = false
		player.touch_jump = false
		player.touch_dash = false
		player.touch_pulse = false


func _on_look(relative: Vector2) -> void:
	if phase != "play":
		return
	cam_yaw.rotation.y -= relative.x * 0.004
	cam_pitch.rotation.x = clampf(cam_pitch.rotation.x - relative.y * 0.003, -1.05, -0.07)


func _update_prompt() -> void:
	var text := ""
	var door := _nearest_door()
	var npc = crowd.nearest(player.global_position, 2.8) if crowd != null else null
	if not door.is_empty():
		if inside_interior:
			text = "E  EXIT TO %s" % str(world.title)
		else:
			text = "E  ENTER %s" % str(door.get("title", "THE ROOM"))
	elif _near_save():
		text = "E  SAVE THE SHIFT"
	elif inside_interior and interior_id == "arcade" and _near_arcade_cabinet():
		text = "E  PLAY THE TAPED-UP CABINET"
	elif not inside_interior and _nearest_clogged_drain(2.8) >= 0:
		text = "DRAIN CLOGGED  /  VACUUM THE GRIME"
	elif not inside_interior and _nearest_live_puddle(3.2):
		text = "SPARKING PUDDLE  /  VACUUM THE LITTER OUT"
	elif boss != null and is_instance_valid(boss) and boss.active and inside_interior and interior_id == "plant":
		if boss.phase == 3:
			if not hopper.is_empty():
				var mouth: Vector3 = boss.mouth_position()
				if Vector2(mouth.x - player.global_position.x, mouth.z - player.global_position.z).length() < 3.2:
					text = "E  EMPTY THE HOPPER INTO THE CORE"
			if text.is_empty():
				text = "VACUUM LITTER  /  FEED THE CORE"
		else:
			var chute: Dictionary = _nearest_boss_chute(2.4)
			if not chute.is_empty():
				if bool(chute.get("open", false)):
					text = "E  FEED THE %s CHUTE" % str(chute.get("kind", "")).to_upper()
				else:
					text = "CHUTE CLOSED  /  WAIT FOR THE GREEN LAMP"
	elif hopper.size() >= hopper_capacity:
		if inside_interior:
			text = "HOPPER FULL  /  SORT AT THE FRONT DESK"
		else:
			text = "HOPPER FULL  /  SORT AT A DEPOT"
	else:
		var heavy = _nearest_heavy()
		if npc != null and heavy == null:
			text = "E  TALK TO %s" % str(npc.display_name)
		elif heavy != null and player.stack_count() < player.max_stack:
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
		"objective": _objective_text(),
	})


func _objective_text() -> String:
	for entry in objectives:
		if not bool(entry.get("done", false)):
			return "NEXT  " + str(entry.get("text", ""))
	return ""


func _objective_done(id: String) -> void:
	for entry in objectives:
		if str(entry.get("id", "")) == id and not bool(entry.get("done", false)):
			entry["done"] = true
			Sound.play("pickup", 1.4, -6.0)
			ui.subtitle("OBJECTIVE DONE  %s" % str(entry.get("text", "")), 4.0)


func _on_story_flag(flag: String) -> void:
	for entry in objectives:
		if str(entry.get("flag", "")) == flag:
			_objective_done(str(entry.get("id", "")))


func _on_quest_changed(id: String) -> void:
	var state = get_node_or_null("/root/GameState")
	if state == null:
		return
	if state.quest_status(id) == "done":
		var quest := Data.quest(id)
		if not str(quest.get("title", "")).is_empty():
			ui.subtitle("QUEST COMPLETE  %s" % str(quest.get("title", "")).to_upper(), 5.0)
	for entry in objectives:
		if str(entry.get("quest", "")) == id and state.quest_status(id) == "done":
			_objective_done(str(entry.get("id", "")))


func _available(node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not bool(node.get("collected"))


func _nearest_live_puddle(radius: float):
	if world == null or not world.has_method("litter_puddle"):
		return false
	var puddles: Array = world.get("electric_puddles")
	if puddles.is_empty():
		return false
	var origin: Vector3 = player.global_position
	for entry in puddles:
		if not bool(entry.get("hazard", false)) or not bool(entry.get("active", false)):
			continue
		if Vector2(entry.pos.x - origin.x, entry.pos.z - origin.z).length() < radius:
			return true
	return false


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
		var point: Vector3 = world.to_global(station.get("pos", Vector3.ZERO))
		var distance := Vector2(origin.x - point.x, origin.z - point.z).length()
		if distance < best_distance:
			best_distance = distance
			best = station
	return best


func _near_skip() -> bool:
	var skip: Vector3 = world.to_global(world.skip_pos)
	return Vector2(player.global_position.x - skip.x, player.global_position.z - skip.z).length() < 4.4


func _nearest_door() -> Dictionary:
	var origin: Vector3 = player.global_position
	if inside_interior:
		var exit_point: Vector3 = world.to_global(world.exit_pos)
		if Vector2(origin.x - exit_point.x, origin.z - exit_point.z).length() < 2.6:
			return {"id": "__exit", "title": str(world.title)}
		return {}
	var best: Dictionary = {}
	var best_distance := 2.9
	for entry in world.interiors:
		var point: Vector3 = world.to_global(entry.pos)
		var distance := Vector2(origin.x - point.x, origin.z - point.z).length()
		if distance < best_distance:
			best_distance = distance
			best = entry
	return best


func _near_save() -> bool:
	if not inside_interior or not bool(world.get("has_save")):
		return false
	var point: Vector3 = world.to_global(world.save_pos)
	return Vector2(player.global_position.x - point.x, player.global_position.z - point.z).length() < 2.2


func _save_at_desk() -> void:
	var state = get_node_or_null("/root/GameState")
	if state != null:
		state.save()
		var next := 0
		if state.rank < Data.RANKS.size():
			next = state.xp_floor(state.rank + 1) - state.xp
		var board := "RANK %d  %s" % [state.rank, Data.rank_title(state.rank)]
		if next > 0:
			board += "  /  %d XP TO RANK %d" % [next, state.rank + 1]
		else:
			board += "  /  TOP OF THE LADDER"
		var shift := current_shift()
		ui.subtitle("%s. %s. Nell stamps the file and points at the radio for a briefing replay." % [board, str(shift.get("title", "ON SHIFT")).to_upper()], 6.0)
	Sound.play("click", 1.05, -2.0)
	Sound.play("door", 1.15, -12.0)
