extends Node3D

const CREAM := Color(0.98, 0.965, 0.925)
const INK := Color(0.09, 0.10, 0.11)
const STONE := Color(0.86, 0.82, 0.75)
const LIME := Color(0.655, 0.85, 0.29)
const CORAL := Color(0.96, 0.42, 0.32)
const SPEED := 7.0

var player: CharacterBody3D
var camera: Camera3D
var label: Label
var pickups: Array[MeshInstance3D] = []
var score := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_build_world()
	_build_player()
	_build_camera()
	_build_hud()
	for i in 8:
		_spawn_pickup()


func _build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = CREAM
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.83, 0.78)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	_solid_box(Vector3(40, 0.4, 40), Vector3(0, -0.2, 0), STONE)
	for spot in [Vector3(-6, 1.5, -4), Vector3(6, 1.5, -8), Vector3(-9, 1.5, 7), Vector3(8, 1.5, 6)]:
		_solid_box(Vector3(1.4, 3.0, 1.4), spot, CORAL)


func _solid_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = _material(color)
	body.add_child(mesh)
	add_child(body)


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0, 0.9, 0)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	player.add_child(shape)

	var mesh := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 1.8
	mesh.mesh = body_mesh
	mesh.material_override = _material(LIME)
	player.add_child(mesh)
	add_child(player)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.position = Vector3(0, 5.5, 8.0)
	add_child(camera)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	label = Label.new()
	label.position = Vector2(28, 22)
	label.text = "PICKUPS  0"
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", INK)
	layer.add_child(label)

	var hint := Label.new()
	hint.position = Vector2(28, 58)
	hint.text = "WASD or the left stick to move"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.09, 0.10, 0.11, 0.55))
	layer.add_child(hint)


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat


func _spawn_pickup() -> void:
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	orb.mesh = sphere
	orb.material_override = _material(CORAL)
	var angle := rng.randf_range(0.0, TAU)
	var reach := rng.randf_range(4.0, 13.0)
	orb.position = Vector3(cos(angle) * reach, 1.0, sin(angle) * reach)
	add_child(orb)
	pickups.append(orb)


func _move_input() -> Vector2:
	var x := Input.get_axis("ui_left", "ui_right")
	var y := Input.get_axis("ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A):
		x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		y += 1.0
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y),
	)
	if stick.length() > 0.2:
		return stick.limit_length(1.0)
	return Vector2(x, y).limit_length(1.0)


func _physics_process(delta: float) -> void:
	var direction := _move_input()
	if player.is_on_floor():
		player.velocity.y = 0.0
	else:
		player.velocity.y -= 24.0 * delta
	player.velocity.x = direction.x * SPEED
	player.velocity.z = direction.y * SPEED
	player.move_and_slide()

	var goal := player.global_position + Vector3(0, 5.5, 8.0)
	camera.global_position = camera.global_position.lerp(goal, 1.0 - exp(-6.0 * delta))
	camera.look_at(player.global_position + Vector3(0, 0.8, 0))


func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() * 0.002
	for orb in pickups:
		orb.rotation.y += delta * 1.6
		orb.position.y = 1.0 + sin(now + orb.position.x) * 0.08
		if orb.global_position.distance_to(player.global_position) < 1.15:
			pickups.erase(orb)
			orb.queue_free()
			score += 1
			label.text = "PICKUPS  %d" % score
			_spawn_pickup()
			return
