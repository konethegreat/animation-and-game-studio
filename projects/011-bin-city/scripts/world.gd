extends "res://scripts/district.gd"

const PLAZA := Rect2(-20.0, -13.0, 40.0, 27.0)
const PILE_SPOTS := [
	Vector3(-1.0, 0.0, -3.0),
	Vector3(5.0, 0.0, -5.5),
	Vector3(-9.0, 0.0, 5.5),
	Vector3(8.0, 0.0, 3.2),
]

var lamps: Array[Dictionary] = []
var plants: Array[Dictionary] = []
var weeds: Array[Node3D] = []
var flags: Array[Dictionary] = []
var string_lights: Array[Dictionary] = []
var robots: Array[Dictionary] = []
var ground_mat: StandardMaterial3D
var water_mat: ShaderMaterial
var _time := 0.0
var _cobble: ImageTexture
var _stripe_a: ImageTexture
var _stripe_b: ImageTexture
var _stripe_c: ImageTexture


func _ready() -> void:
	bounds = PLAZA
	spawn = Vector3(2.0, 0.0, 2.0)
	skip_pos = Vector3(16.0, 0.0, 9.5)
	music = "market"
	ambience = "market"
	title = "DAWN MARKET"
	mood = "dawn"
	interiors = [
		{
			"id": "depot", "title": "BUREAU DEPOT",
			"pos": Vector3(-9.0, 0.0, -13.1), "return_pos": Vector3(-9.0, 0.0, -10.0),
		},
		{
			"id": "bakery", "title": "BAKERY",
			"pos": Vector3(-18.0, 0.0, -13.1), "return_pos": Vector3(-18.0, 0.0, -10.0),
		},
	]
	_cobble = K.make_cobble()
	_stripe_a = K.make_stripes(K.CORAL, K.CREAM)
	_stripe_b = K.make_stripes(K.TEAL, K.CREAM)
	_stripe_c = K.make_stripes(K.OCHRE, K.CREAM)
	_build_ground()
	_build_canal()
	_build_facades()
	_build_entrance()
	_build_doors()
	_build_stalls()
	_build_statue()
	_build_depots()
	_build_skip()
	_build_lamps()
	_build_bunting()
	_build_plants()
	_build_puddles()
	_build_bounds()
	add_dust()
	add_leaves()
	set_clean(0.0)


func _process(delta: float) -> void:
	_time += delta
	for flag in flags:
		var node: Node3D = flag.node
		node.rotation.z = sin(_time * 1.6 + float(flag.phase)) * 0.11
	for robot in robots:
		var head: Node3D = robot.head
		var body: Node3D = robot.body
		body.position.y = float(robot.base_y) + sin(_time * 1.4 + float(robot.phase)) * 0.035
		head.rotation.y = sin(_time * 0.7 + float(robot.phase)) * 0.35
		head.position.y = float(robot.head_y) + sin(_time * 1.4 + float(robot.phase) + 0.4) * 0.018
	for lamp in lamps:
		if bool(lamp.flicker):
			var light: OmniLight3D = lamp.light
			var base := float(lamp.base_energy)
			var flick := 0.82 + 0.18 * sin(_time * 9.0) * sin(_time * 3.1 + 1.0)
			light.light_energy = base * flick


func set_clean(value: float) -> void:
	clean_level = clampf(value, 0.0, 1.0)
	var t := clean_level
	if ground_mat:
		ground_mat.albedo_color = Color(0.9, 0.87, 0.82).lerp(Color(1.16, 1.11, 1.03), smoothstep(0.0, 0.85, t))
	for item in lamps:
		var lit := smoothstep(0.32, 0.72, t)
		var bulb: MeshInstance3D = item.bulb
		var mat := bulb.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 0.35 + lit * 2.6
		var light: OmniLight3D = item.light
		var base := 1.1 * lit
		item.base_energy = base
		light.light_energy = base
		var pool: MeshInstance3D = item.pool
		var pool_mat := pool.material_override as StandardMaterial3D
		if pool_mat:
			pool_mat.albedo_color = Color(1.0, 0.82, 0.55, 0.02 + lit * 0.2)
	for item in plants:
		var foliage: Node3D = item.foliage
		var bloom: Node3D = item.bloom
		var mat: StandardMaterial3D = item.material
		foliage.scale = Vector3.ONE * (0.55 + 0.62 * smoothstep(0.0, 0.8, t))
		foliage.rotation.z = (1.0 - t) * 0.18
		if mat:
			mat.albedo_color = K.color_lerp(Color(0.36, 0.34, 0.22), Color(0.34, 0.56, 0.28), smoothstep(0.0, 0.65, t))
		if bloom:
			bloom.scale = Vector3.ONE * clampf((t - 0.42) / 0.5, 0.001, 1.0)
	for node in weeds:
		node.scale = Vector3.ONE * maxf(0.01, 1.0 - smoothstep(0.1, 0.7, t))
	for item in puddles:
		var node: Node3D = item.node
		var s := maxf(0.01, 1.0 - smoothstep(0.0, 0.78, t) * 0.92)
		node.scale = Vector3(s, 1.0, s)
		node.visible = t < 0.86
		var mesh := node.get_child(0) as MeshInstance3D
		if mesh:
			var mat := mesh.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color = Color(0.44, 0.55, 0.58, 0.32 * (1.0 - t * 0.8))
	for item in string_lights:
		var bulb: MeshInstance3D = item.bulb
		var mat := bulb.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 0.18 + 1.8 * smoothstep(0.2, 0.7, t)
	if water_mat:
		water_mat.set_shader_parameter("light_water", Color(0.28, 0.48, 0.45).lerp(Color(0.62, 0.78, 0.68), t))


func crowd_points() -> Array:
	return [
		Vector3(-12.4, 0.0, -4.6), Vector3(-3.2, 0.0, -6.0), Vector3(7.4, 0.0, -5.4),
		Vector3(15.6, 0.0, -0.6), Vector3(-16.4, 0.0, 4.8), Vector3(-1.4, 0.0, 9.2),
		Vector3(4.2, 0.0, 7.4), Vector3(8.6, 0.0, 5.0), Vector3(-7.2, 0.0, 3.4),
		Vector3(1.2, 0.0, -1.4), Vector3(-9.2, 0.0, 0.2), Vector3(12.4, 0.0, -6.0),
		Vector3(18.0, 0.0, 6.0), Vector3(-18.2, 0.0, -6.2),
	]


func pile_spots() -> Array:
	return PILE_SPOTS


func _build_ground() -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	add_child(ground)
	ground_mat = K.texture_material(_cobble, Vector3(14, 10, 1), Color(1.0, 0.98, 0.94))
	K.plane(ground, Vector2(44, 29), Vector3(0, 0, 0.2), K.STONE, ground_mat)
	K.collider(ground, Vector3(44, 1, 29), Vector3(0, -0.5, 0.2))

	# A dusty apron around the plaza, split so the canal stays open water.
	var apron_mat := K.material(Color(0.5, 0.46, 0.39))
	for piece in [
		{"size": Vector2(110, 22), "pos": Vector3(0, -0.06, -25.5)},
		{"size": Vector2(110, 22), "pos": Vector3(0, -0.06, 40.0)},
		{"size": Vector2(22, 80), "pos": Vector3(-33, -0.06, 7)},
		{"size": Vector2(22, 80), "pos": Vector3(33, -0.06, 7)},
	]:
		var apron := K.plane(ground, piece.size, piece.pos, K.STONE_DARK, apron_mat)
		apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# The far bank promenade, reached over the bridge.
	K.plane(ground, Vector2(44, 8), Vector3(0, 0, 27.0), K.STONE, ground_mat)
	K.collider(ground, Vector3(44, 1, 8), Vector3(0, -0.5, 27.0))

	# Worn patches so the plaza is not a single flat colour.
	var patch := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 3.0
	disc.bottom_radius = 3.2
	disc.height = 0.02
	disc.radial_segments = 22
	patch.mesh = disc
	patch.material_override = K.clear_material(Color(0.38, 0.33, 0.26), 0.09)
	patch.position = Vector3(-2, 0.012, 2)
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.add_child(patch)


func _build_canal() -> void:
	var canal := Node3D.new()
	canal.name = "Canal"
	add_child(canal)
	var shader := load("res://scripts/water.gdshader") as Shader
	water_mat = ShaderMaterial.new()
	water_mat.shader = shader
	var water := K.plane(canal, Vector2(70, 8.5), Vector3(0, -0.6, 19.0), K.WATER, water_mat)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Stone banks and a level bridge.
	K.box(canal, Vector3(70, 1.4, 0.6), Vector3(0, -0.7, 14.6), K.STONE_DARK)
	K.box(canal, Vector3(70, 1.4, 0.6), Vector3(0, -0.7, 23.4), K.STONE_DARK)
	K.box(canal, Vector3(3.8, 0.24, 10.2), Vector3(10, -0.12, 19.0), K.STONE)
	K.box(canal, Vector3(3.9, 0.08, 10.3), Vector3(10, 0.02, 19.0), K.PAPER)
	K.collider(canal, Vector3(3.9, 0.6, 10.2), Vector3(10, -0.3, 19.0))

	for side in [-1.0, 1.0]:
		var x: float = 10.0 + float(side) * 1.85
		for i in 5:
			K.box(canal, Vector3(0.16, 1.0, 0.16), Vector3(x, 0.5, 14.6 + i * 2.2), K.WOOD_DARK)
		K.box(canal, Vector3(0.14, 0.1, 9.0), Vector3(x, 1.0, 19.0), K.WOOD_DARK)
		K.collider(canal, Vector3(0.24, 1.2, 9.6), Vector3(x, 0.6, 19.0))

	# Parapets, with a gap for the bridge.
	for segment in [Rect2(-22, 14.2, 30.0, 0.5), Rect2(12, 14.2, 10.0, 0.5)]:
		K.box(canal, Vector3(segment.size.x, 0.72, segment.size.y), Vector3(segment.position.x + segment.size.x / 2.0, 0.36, segment.position.y), K.STONE)
		K.collider(canal, Vector3(segment.size.x, 0.9, 0.5), Vector3(segment.position.x + segment.size.x / 2.0, 0.45, segment.position.y))
	for segment in [Rect2(-22, 23.0, 30.0, 0.5), Rect2(12, 23.0, 10.0, 0.5)]:
		K.box(canal, Vector3(segment.size.x, 0.72, segment.size.y), Vector3(segment.position.x + segment.size.x / 2.0, 0.36, segment.position.y), K.STONE)
		K.collider(canal, Vector3(segment.size.x, 0.9, 0.5), Vector3(segment.position.x + segment.size.x / 2.0, 0.45, segment.position.y))

	# A moored canal boat, low and long, with a little chimney.
	var boat := Node3D.new()
	boat.position = Vector3(-8.0, -0.32, 19.0)
	canal.add_child(boat)
	K.box(boat, Vector3(9.0, 0.55, 2.2), Vector3.ZERO, K.TEAL_DARK)
	K.box(boat, Vector3(4.2, 0.9, 1.7), Vector3(-0.8, 0.55, 0), K.CREAM)
	for i in 4:
		K.box(boat, Vector3(0.7, 0.36, 0.05), Vector3(-2.2 + i * 0.9, 0.72, 0.87), K.INK)
	K.cylinder(boat, 0.16, 1.8, Vector3(0.9, 1.2, 0), K.INK)
	K.box(boat, Vector3(0.2, 0.16, 0.2), Vector3(1.0, 1.9, 0), K.CORAL)
	K.box(boat, Vector3(1.2, 0.1, 0.4), Vector3(3.4, 0.28, 0), K.WOOD)


func _build_facades() -> void:
	var specs := [
		{"pos": Vector3(-18, 0, -17), "rot": 0.0, "w": 8.0, "h": 8.0, "color": Color(0.78, 0.55, 0.42), "name": "BAKERY"},
		{"pos": Vector3(-9, 0, -17), "rot": 0.0, "w": 8.0, "h": 11.0, "color": Color(0.66, 0.58, 0.47), "name": "DEPOT"},
		{"pos": Vector3(0, 0, -18), "rot": 0.0, "w": 9.0, "h": 9.5, "color": Color(0.83, 0.68, 0.5), "name": "LAUNDRY"},
		{"pos": Vector3(9, 0, -17), "rot": 0.0, "w": 8.0, "h": 12.0, "color": Color(0.6, 0.66, 0.63), "name": "CINEMA"},
		{"pos": Vector3(18, 0, -17), "rot": 0.0, "w": 8.0, "h": 8.0, "color": Color(0.72, 0.48, 0.44), "name": "TOOLS"},
		{"pos": Vector3(23, 0, -8), "rot": -PI / 2.0, "w": 8.0, "h": 9.0, "color": Color(0.62, 0.6, 0.48), "name": "TAILOR"},
		{"pos": Vector3(23, 0, 2), "rot": -PI / 2.0, "w": 8.0, "h": 7.5, "color": Color(0.8, 0.63, 0.48), "name": "COFFEE"},
		{"pos": Vector3(23, 0, 12), "rot": -PI / 2.0, "w": 8.0, "h": 10.0, "color": Color(0.58, 0.55, 0.5), "name": "BOOKS"},
		{"pos": Vector3(-23, 0, -8), "rot": PI / 2.0, "w": 8.0, "h": 10.0, "color": Color(0.7, 0.52, 0.38), "name": "BAKER"},
		{"pos": Vector3(-23, 0, 2), "rot": PI / 2.0, "w": 8.0, "h": 8.5, "color": Color(0.65, 0.68, 0.58), "name": "PLANTS"},
		{"pos": Vector3(-23, 0, 12), "rot": PI / 2.0, "w": 8.0, "h": 11.0, "color": Color(0.76, 0.58, 0.47), "name": "REPAIRS"},
		{"pos": Vector3(-11, 0, 31), "rot": PI, "w": 10.0, "h": 7.0, "color": Color(0.74, 0.6, 0.46), "name": "POST"},
		{"pos": Vector3(1, 0, 31), "rot": PI, "w": 9.0, "h": 9.0, "color": Color(0.63, 0.66, 0.57), "name": "HOTEL"},
		{"pos": Vector3(13, 0, 31), "rot": PI, "w": 10.0, "h": 8.0, "color": Color(0.8, 0.56, 0.43), "name": "CAFE"},
	]
	for spec in specs:
		_facade(spec.pos, float(spec.rot), float(spec.w), float(spec.h), spec.color, str(spec.name))


func _facade(pos: Vector3, rot: float, width: float, height: float, color: Color, name: String) -> void:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = rot
	add_child(node)
	var depth := 5.0
	K.box(node, Vector3(width, height, depth), Vector3(0, height / 2.0, -depth / 2.0), color)
	K.box(node, Vector3(width + 0.5, 0.35, depth + 0.5), Vector3(0, height + 0.12, -depth / 2.0), K.STONE_DARK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Ground floor shop.
	var shop_color := color.darkened(0.18)
	K.box(node, Vector3(width * 0.98, 2.6, 0.12), Vector3(0, 1.5, 0.02), shop_color)
	K.box(node, Vector3(1.5, 2.1, 0.1), Vector3(-width * 0.28, 1.05, 0.1), K.WOOD_DARK)
	K.box(node, Vector3(width * 0.38, 1.4, 0.08), Vector3(width * 0.16, 1.5, 0.1), K.INK)
	var shop_light := K.quad(node, Vector2(width * 0.36, 1.3), Vector3(width * 0.16, 1.5, 0.16), Color(0.98, 0.79, 0.5))
	var shop_mat := shop_light.material_override as StandardMaterial3D
	shop_mat.emission_enabled = true
	shop_mat.emission = Color(1.0, 0.72, 0.38)
	shop_mat.emission_energy_multiplier = 0.5
	shop_light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Shop awning and sign.
	var awning := K.box(node, Vector3(width * 0.72, 0.08, 1.7), Vector3(0, 3.1, 0.8), K.CREAM, Vector3(-0.16, 0, 0), K.texture_material(_stripe_a, Vector3(3, 1, 1)))
	awning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(node, Vector3(3.2, 0.5, 0.1), Vector3(0, 3.65, 0.12), K.INK)
	K.label(node, name, Vector3(0, 3.65, 0.2), 44, K.CREAM)

	# Windows, some lit, with a sill and a shutter.
	var cols := 3
	var rows := maxi(1, int((height - 4.0) / 2.0))
	for row in rows:
		for col in cols:
			var wx := -width * 0.32 + col * (width * 0.32)
			var wy := 4.2 + row * 2.0
			if wy > height - 1.0:
				continue
			var lit := (row + col + int(abs(pos.x)) + int(abs(pos.z))) % 3 != 0
			var win := K.box(node, Vector3(1.0, 1.25, 0.12), Vector3(wx, wy, 0.02), K.INK)
			win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var pane := K.quad(node, Vector2(0.82, 1.06), Vector3(wx, wy, 0.09), Color(0.99, 0.82, 0.56) if lit else Color(0.16, 0.2, 0.22))
			if lit:
				var mat := pane.material_override as StandardMaterial3D
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.72, 0.4)
				mat.emission_energy_multiplier = 0.35
			pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			K.box(node, Vector3(1.16, 0.1, 0.22), Vector3(wx, wy - 0.72, 0.08), K.STONE_DARK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if (row + col) % 4 == 0:
				K.box(node, Vector3(0.32, 1.2, 0.08), Vector3(wx - 0.72, wy, 0.08), color.darkened(0.28)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if height > 9.0:
		K.box(node, Vector3(1.0, 1.4, 1.0), Vector3(width * 0.3, height + 0.9, -2.2), K.BRICK)
		K.box(node, Vector3(1.2, 0.16, 1.2), Vector3(width * 0.3, height + 1.6, -2.2), K.STONE_DARK)


func _build_entrance() -> void:
	var arch := Node3D.new()
	arch.position = Vector3(0, 0, -12.8)
	add_child(arch)
	for side in [-1.0, 1.0]:
		K.box(arch, Vector3(0.5, 4.4, 0.5), Vector3(side * 4.2, 2.2, 0), K.WOOD_DARK)
		K.box(arch, Vector3(0.9, 0.2, 0.9), Vector3(side * 4.2, 0.1, 0), K.STONE)
		_block(Vector3(side * 4.2, 0, -12.8), 0.7)
	K.box(arch, Vector3(9.4, 0.9, 0.4), Vector3(0, 4.4, 0), K.WOOD_DARK)
	K.box(arch, Vector3(8.8, 0.66, 0.12), Vector3(0, 4.4, 0.24), K.CREAM)
	K.label(arch, "DAWN MARKET", Vector3(0, 4.4, 0.31), 84, K.INK)
	for i in 7:
		K.sphere(arch, 0.09, Vector3(-3.9 + i * 1.3, 3.9, 0.2), K.CORAL)


func _build_doors() -> void:
	for entry in interiors:
		var pos: Vector3 = entry.pos
		var door := Node3D.new()
		door.position = pos
		add_child(door)
		_block(pos + Vector3(0, 0, 0.5), 1.6)

		# A recessed municipal doorway set into the boundary wall.
		K.box(door, Vector3(3.4, 2.7, 0.14), Vector3(0, 1.35, 0.02), K.INK)
		var leaf := K.box(door, Vector3(2.5, 2.4, 0.16), Vector3(0, 1.2, 0.16), K.WOOD)
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for row in 2:
			for col in 2:
				K.box(door, Vector3(0.95, 0.8, 0.06), Vector3(-0.58 + col * 1.16, 0.72 + row * 1.0, 0.25), K.WOOD_DARK)
		K.cylinder(door, 0.05, 0.09, Vector3(0.92, 1.2, 0.26), K.OCHRE, Vector3(PI / 2, 0, 0), 8)
		for side in [-1.0, 1.0]:
			K.box(door, Vector3(0.26, 2.9, 0.3), Vector3(side * 1.56, 1.45, 0.1), K.WOOD_DARK)
			K.box(door, Vector3(0.64, 0.16, 0.7), Vector3(side * 1.56, 0.08, 0.28), K.STONE)
		K.box(door, Vector3(3.5, 0.3, 0.36), Vector3(0, 2.9, 0.1), K.WOOD_DARK)
		K.box(door, Vector3(2.7, 0.46, 0.1), Vector3(0, 2.9, 0.29), K.INK)
		K.label(door, str(entry.title), Vector3(0, 2.9, 0.36), 28, K.CREAM)
		K.label(door, "OPEN LATE", Vector3(0, 2.66, 0.36), 12, K.OCHRE)
		K.box(door, Vector3(3.2, 0.1, 0.7), Vector3(0, 0.05, 0.42), K.STONE)
		var mat := K.plane(door, Vector2(2.4, 1.1), Vector3(0, 0.08, 1.0), Color(0.2, 0.32, 0.3), K.clear_material(Color(0.18, 0.3, 0.28), 0.55))
		mat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bulb := K.sphere(door, 0.1, Vector3(0, 3.18, 0.24), Color(1.0, 0.86, 0.58))
		var bulb_mat := StandardMaterial3D.new()
		bulb_mat.albedo_color = Color(1.0, 0.86, 0.58)
		bulb_mat.emission_enabled = true
		bulb_mat.emission = Color(1.0, 0.72, 0.38)
		bulb_mat.emission_energy_multiplier = 1.4
		bulb.material_override = bulb_mat
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light := OmniLight3D.new()
		light.position = Vector3(0, 3.0, 0.6)
		light.light_color = Color(1.0, 0.78, 0.46)
		light.light_energy = 0.9
		light.omni_range = 5.0
		light.shadow_enabled = false
		door.add_child(light)
		K.collider(door, Vector3(3.3, 2.9, 0.4), Vector3(0, 1.45, 0.1))


func _stall(pos: Vector3, sign: String, stripe: Texture2D, accent: Color, fruit: Color, tall := false) -> void:
	var node := Node3D.new()
	node.position = pos
	var to_center := Vector2(-pos.x, -pos.z)
	node.rotation.y = atan2(to_center.x, to_center.y)
	add_child(node)
	_block(pos, 3.1)

	K.box(node, Vector3(4.2, 0.95, 1.5), Vector3(0, 0.48, 0), K.WOOD_DARK)
	var top := K.box(node, Vector3(4.5, 0.12, 1.7), Vector3(0, 1.0, 0), K.WOOD)
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(node, Vector3(4.3, 0.05, 1.55), Vector3(0, 1.07, 0), K.CREAM)
	for x in [-1.9, 1.9]:
		for z in [-0.6, 0.6]:
			K.cylinder(node, 0.09, 3.3, Vector3(x, 1.65, z), K.WOOD_DARK, Vector3.ZERO, 6)
	K.box(node, Vector3(4.8, 2.0, 0.14), Vector3(0, 2.2, -0.78), K.WOOD)
	K.collider(node, Vector3(4.4, 1.7, 1.7), Vector3(0, 0.85, 0))
	var canopy := K.box(node, Vector3(5.0, 0.1, 2.6), Vector3(0, 3.25, 0.0), K.CREAM, Vector3(-0.13, 0, 0), K.texture_material(stripe, Vector3(2.2, 1, 1)))
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(node, Vector3(5.0, 0.5, 0.08), Vector3(0, 3.02, 1.22), K.CREAM, Vector3.ZERO, K.texture_material(stripe, Vector3(2.2, 1, 1))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(node, Vector3(4.0, 0.66, 0.1), Vector3(0, 3.9, -0.2), K.INK)
	K.label(node, sign, Vector3(0, 3.9, -0.13), 48, K.CREAM)

	# Crates and goods.
	for i in 3:
		var cx := -1.4 + i * 1.3
		K.box(node, Vector3(0.9, 0.35, 0.75), Vector3(cx, 1.28, 0.1), K.WOOD)
		for j in 4:
			var bx := cx - 0.3 + (j % 2) * 0.6
			var bz := -0.1 + (j / 2) * 0.48
			K.sphere(node, 0.16, Vector3(bx, 1.55, bz), fruit.lightened(0.05 * (j % 3)), Vector3(1, 0.85, 1))
	K.box(node, Vector3(0.7, 0.5, 0.6), Vector3(-1.7, 0.25, 0.9), K.WOOD_DARK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 5:
		K.sphere(node, 0.1, Vector3(-1.85 + (i % 3) * 0.18, 0.58, 0.82 + (i / 3) * 0.16), accent)
	if tall:
		K.cylinder(node, 0.02, 2.2, Vector3(2.4, 2.2, 0.7), K.INK, Vector3(0, 0, 0.1), 5)
		K.quad(node, Vector2(1.4, 0.5), Vector3(2.95, 3.25, 0.7), accent, Vector3(0, PI, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_stalls() -> void:
	_stall(Vector3(-14, 0, -7), "STRAWBERRIES", _stripe_a, K.CORAL, Color(0.79, 0.16, 0.2), true)
	_stall(Vector3(-4, 0, -10), "BREAD & CO", _stripe_c, K.OCHRE, Color(0.79, 0.55, 0.26))
	_stall(Vector3(7, 0, -9), "RIZZO'S RAPID PIZZA", _stripe_a, K.CORAL, Color(0.86, 0.42, 0.16), true)
	_stall(Vector3(17, 0, -3), "FLOWERS", _stripe_b, K.PLUM, Color(0.77, 0.33, 0.5))
	_stall(Vector3(-17, 0, 2), "FISH? MAYBE.", _stripe_b, K.TEAL, Color(0.56, 0.7, 0.72))
	_stall(Vector3(-3, 0, 11), "POTATOES", _stripe_c, K.OLIVE, Color(0.72, 0.58, 0.33))

	# Rizzo, a rat with a delivery cap, on the pizza stall.
	var rat := Node3D.new()
	rat.position = Vector3(8.9, 1.1, -8.1)
	rat.rotation.y = 0.3
	add_child(rat)
	K.sphere(rat, 0.22, Vector3(0, 0.2, 0), Color(0.55, 0.54, 0.52), Vector3(1.2, 0.9, 1))
	K.sphere(rat, 0.14, Vector3(0.16, 0.38, 0), Color(0.58, 0.57, 0.55))
	K.sphere(rat, 0.07, Vector3(0.04, 0.46, 0.1), K.CORAL)
	K.sphere(rat, 0.07, Vector3(0.2, 0.5, 0), Color(0.55, 0.54, 0.52), Vector3(1, 0.6, 1))
	K.box(rat, Vector3(0.3, 0.08, 0.3), Vector3(0.18, 0.47, 0), K.CORAL)
	K.box(rat, Vector3(0.22, 0.12, 0.22), Vector3(0.18, 0.55, 0), K.CORAL)
	K.box(rat, Vector3(0.3, 0.05, 0.3), Vector3(0.18, 0.62, 0), K.CREAM)
	K.box(rat, Vector3(0.42, 0.06, 0.42), Vector3(-0.18, 0.2, -0.24), K.CREAM, Vector3(0.2, 0, 0))
	K.sphere(rat, 0.05, Vector3(-0.34, 0.2, -0.42), K.CORAL)
	K.cylinder(rat, 0.02, 0.5, Vector3(-0.3, 0.05, 0.02), Color(0.5, 0.48, 0.47), Vector3(PI / 2, 0, 0), 6)

	# A shop cat asleep on a crate by the flowers.
	var cat := Node3D.new()
	cat.position = Vector3(16.1, 1.25, -1.8)
	add_child(cat)
	K.sphere(cat, 0.24, Vector3.ZERO, Color(0.72, 0.53, 0.33), Vector3(1.5, 0.7, 0.9))
	K.sphere(cat, 0.15, Vector3(0.25, 0.1, 0), Color(0.75, 0.56, 0.36))
	K.cone(cat, 0.0, 0.07, 0.12, Vector3(0.2, 0.24, 0.08), Color(0.72, 0.53, 0.33), Vector3.ZERO, 5)
	K.cone(cat, 0.0, 0.07, 0.12, Vector3(0.2, 0.24, -0.08), Color(0.72, 0.53, 0.33), Vector3.ZERO, 5)
	K.cylinder(cat, 0.025, 0.4, Vector3(-0.28, 0.02, 0.02), Color(0.66, 0.48, 0.3), Vector3(PI / 2, 0, 0.4), 5)


func _build_statue() -> void:
	var node := Node3D.new()
	node.position = Vector3(-8, 0, 1)
	add_child(node)
	_block(Vector3(-8, 0, 1), 2.3)
	K.cylinder(node, 1.5, 0.4, Vector3(0, 0.2, 0), K.STONE, Vector3.ZERO, 12)
	K.cylinder(node, 1.05, 0.7, Vector3(0, 0.7, 0), K.STONE_DARK, Vector3.ZERO, 12)
	K.box(node, Vector3(1.5, 0.14, 1.5), Vector3(0, 1.05, 0), K.PAPER)
	K.sphere(node, 1.05, Vector3(0, 2.1, 0), K.CREAM, Vector3(1, 1.15, 1))
	K.sphere(node, 1.02, Vector3(0, 2.72, 0), K.PLUM, Vector3(1, 0.6, 1))
	K.cone(node, 0.0, 0.28, 0.6, Vector3(0, 1.2, 0), K.CREAM, Vector3(PI, 0, 0), 8)
	for i in 5:
		var angle := i * TAU / 5.0
		K.cone(node, 0.0, 0.2, 1.15, Vector3(cos(angle) * 0.32, 3.45, sin(angle) * 0.32), Color(0.34, 0.55, 0.3), Vector3(cos(angle) * 0.45, 0, sin(angle) * 0.45), 6)
	K.box(node, Vector3(1.5, 0.55, 0.1), Vector3(0, 0.75, 0.73), K.INK)
	K.label(node, "THE DAWN TURNIP", Vector3(0, 0.75, 0.8), 30, K.CREAM)
	K.collider(node, Vector3(2.4, 1.4, 2.4), Vector3(0, 0.7, 0))


func _build_depots() -> void:
	_depot(Vector3(13, 0, 2), -1.72, "VIBES UNIT 7", true)
	_depot(Vector3(-15, 0, 10), 2.5, "SORT IT RIGHT", false)
	stations = [
		{"pos": Vector3(10.5, 0, 0.4), "label": "VIBES UNIT 7"},
		{"pos": Vector3(-13.5, 0, 8.0), "label": "SORT IT RIGHT"},
	]


func _depot(pos: Vector3, rot: float, name: String, robot: bool) -> void:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = rot
	add_child(node)
	_block(pos, 3.0)
	K.box(node, Vector3(3.6, 1.0, 1.1), Vector3(0, 0.5, -1.1), K.WOOD_DARK)
	K.box(node, Vector3(3.8, 0.1, 1.25), Vector3(0, 1.02, -1.1), K.WOOD)
	K.box(node, Vector3(3.2, 0.7, 0.1), Vector3(0, 2.0, -1.62), K.INK)
	K.collider(node, Vector3(3.8, 1.5, 1.4), Vector3(0, 0.75, -0.35))
	K.label(node, name, Vector3(0, 2.0, -1.55), 34, K.CREAM)
	var bin_colors := {
		"GLASS": Color(0.32, 0.6, 0.55),
		"METAL": Color(0.63, 0.66, 0.67),
		"PAPER": Color(0.42, 0.55, 0.72),
		"COMPOST": Color(0.45, 0.52, 0.29),
	}
	var names := ["GLASS", "METAL", "PAPER", "COMPOST"]
	for i in 4:
		var x := -1.5 + i * 1.0
		var color: Color = bin_colors[names[i]]
		K.box(node, Vector3(0.82, 1.25, 0.82), Vector3(x, 0.62, 0.3), color)
		K.box(node, Vector3(0.9, 0.16, 0.9), Vector3(x, 1.3, 0.3), color.darkened(0.2))
		K.box(node, Vector3(0.6, 0.08, 0.2), Vector3(x, 1.18, 0.68), K.INK)
		K.label(node, names[i], Vector3(x, 1.85, 0.72), 26, K.CREAM)
	if robot:
		var bot := Node3D.new()
		bot.position = Vector3(2.35, 1.05, 0.1)
		bot.rotation.y = -0.5
		node.add_child(bot)
		var body := K.box(bot, Vector3(0.72, 0.9, 0.52), Vector3(0, 0, 0), Color(0.72, 0.7, 0.64))
		K.box(bot, Vector3(0.76, 0.08, 0.56), Vector3(0, 0.1, 0), Color(0.9, 0.86, 0.76))
		K.box(bot, Vector3(0.16, 0.5, 0.1), Vector3(-0.18, 0.25, 0.3), K.OCHRE)
		K.box(bot, Vector3(0.16, 0.6, 0.1), Vector3(0.2, 0.15, 0.3), K.OCHRE)
		var head := Node3D.new()
		head.position = Vector3(0, 0.62, 0)
		bot.add_child(head)
		K.box(head, Vector3(0.58, 0.42, 0.46), Vector3.ZERO, Color(0.82, 0.8, 0.72))
		K.sphere(head, 0.14, Vector3(0, 0.02, 0.24), K.CORAL, Vector3(1.3, 1, 0.6))
		var eye := K.sphere(head, 0.06, Vector3(0, 0.02, 0.36), K.INK)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		K.box(head, Vector3(0.3, 0.06, 0.1), Vector3(0.12, 0.18, 0.24), Color(0.95, 0.92, 0.82), Vector3(0, 0, 0.4))
		K.cylinder(head, 0.02, 0.3, Vector3(-0.2, 0.32, 0), K.INK, Vector3.ZERO, 5)
		K.sphere(head, 0.05, Vector3(-0.2, 0.48, 0), K.CORAL)
		var arm_left := K.box(bot, Vector3(0.16, 0.56, 0.16), Vector3(-0.5, 0.0, 0.14), Color(0.68, 0.66, 0.6), Vector3(0, 0, 0.25))
		var arm_right := K.box(bot, Vector3(0.16, 0.5, 0.16), Vector3(0.5, 0.05, 0.14), Color(0.68, 0.66, 0.6), Vector3(0, 0, -0.3))
		arm_left.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arm_right.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		robots.append({"body": bot, "head": head, "base_y": bot.position.y, "head_y": head.position.y, "phase": 0.0 if pos.x > 0 else 2.0})
		# Tape repairs say everything about this machine's maintenance budget.
		K.box(bot, Vector3(0.1, 0.34, 0.06), Vector3(0.2, -0.1, 0.27), Color(0.94, 0.9, 0.78), Vector3(0, 0, 0.5)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_skip() -> void:
	var node := Node3D.new()
	node.position = skip_pos
	add_child(node)
	_block(skip_pos, 2.5)
	K.box(node, Vector3(3.4, 1.5, 1.9), Vector3(0, 0.75, 0), Color(0.31, 0.38, 0.39))
	K.box(node, Vector3(3.1, 0.1, 1.6), Vector3(0, 0.6, 0), K.INK)
	var lid := K.box(node, Vector3(3.4, 0.12, 1.95), Vector3(0, 1.56, -0.55), Color(0.26, 0.32, 0.34), Vector3(-0.55, 0, 0))
	lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 4:
		K.cylinder(node, 0.18, 0.12, Vector3(-1.2 + i * 0.8, 1.62, 0.5), K.OCHRE, Vector3(PI / 2, 0, 0), 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(node, Vector3(1.5, 0.55, 0.08), Vector3(0, 0.95, 0.98), K.INK)
	K.label(node, "SKIP", Vector3(0, 0.95, 1.03), 44, K.CREAM)
	# A painted drop zone so the skip reads as somewhere to stand, not just scenery.
	K.torus(node, 3.0, 3.24, Vector3(0, 0.05, 0.0), K.CORAL, Vector3(PI / 2, 0, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1.0, 1.0]:
		K.cylinder(node, 0.22, 0.3, Vector3(side * 1.3, 0.22, 0.7), K.INK, Vector3(PI / 2, 0, 0), 8)
	K.collider(node, Vector3(3.5, 1.6, 2.0), Vector3(0, 0.8, 0))


func _build_lamps() -> void:
	var spots := [
		Vector3(-19, 0, -11), Vector3(0, 0, -12), Vector3(19, 0, -11),
		Vector3(-19, 0, 1), Vector3(19, 0, 1), Vector3(-18, 0, 11.5),
		Vector3(0, 0, 11.5), Vector3(18, 0, 11.5),
	]
	for i in spots.size():
		var spot: Vector3 = spots[i]
		var node := Node3D.new()
		node.position = spot
		add_child(node)
		_block(spot, 0.55)
		K.cylinder(node, 0.13, 3.5, Vector3(0, 1.75, 0), K.INK, Vector3.ZERO, 8)
		K.cylinder(node, 0.28, 0.22, Vector3(0, 0.16, 0), K.INK, Vector3.ZERO, 8)
		K.box(node, Vector3(0.8, 0.1, 0.1), Vector3(0.32, 3.42, 0), K.INK)
		K.cone(node, 0.1, 0.34, 0.36, Vector3(0.66, 3.28, 0), K.INK, Vector3.ZERO, 8)
		var bulb_mat := StandardMaterial3D.new()
		bulb_mat.albedo_color = Color(1.0, 0.9, 0.66)
		bulb_mat.emission_enabled = true
		bulb_mat.emission = Color(1.0, 0.72, 0.35)
		bulb_mat.emission_energy_multiplier = 0.35
		var bulb := K.sphere(node, 0.17, Vector3(0.66, 3.08, 0), Color(1, 0.9, 0.66))
		bulb.material_override = bulb_mat
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light := OmniLight3D.new()
		light.position = Vector3(0.66, 3.0, 0)
		light.light_color = Color(1.0, 0.78, 0.48)
		light.omni_range = 8.0
		light.light_energy = 0.0
		light.shadow_enabled = false
		node.add_child(light)
		var pool := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 1.7
		disc.bottom_radius = 1.7
		disc.height = 0.02
		disc.radial_segments = 20
		pool.mesh = disc
		pool.material_override = K.clear_material(Color(1.0, 0.78, 0.45), 0.02)
		pool.position = Vector3(0.66, 0.015, 0)
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(pool)
		lamps.append({"bulb": bulb, "light": light, "pool": pool, "base_energy": 0.0, "flicker": i == 3})


func _build_bunting() -> void:
	var lines := [
		{"a": Vector3(-19, 5.6, 1), "b": Vector3(19, 5.6, 1), "color": K.CORAL},
		{"a": Vector3(-19, 5.6, -11), "b": Vector3(0, 5.6, -12), "color": K.TEAL},
		{"a": Vector3(0, 5.6, -12), "b": Vector3(19, 5.6, -11), "color": K.OCHRE},
		{"a": Vector3(-18, 5.6, 11.5), "b": Vector3(18, 5.6, 11.5), "color": K.PLUM},
	]
	for line in lines:
		var a: Vector3 = line.a
		var b: Vector3 = line.b
		var count := int(a.distance_to(b) / 1.1)
		for i in count + 1:
			var t := float(i) / count
			var point := a.lerp(b, t)
			point.y -= sin(t * PI) * 0.55
			if i < count:
				var next := a.lerp(b, float(i + 1) / count)
				next.y -= sin(float(i + 1) / count * PI) * 0.55
				var mid := (point + next) * 0.5
				var seg := K.cylinder(self, 0.009, point.distance_to(next), mid, Color(0.58, 0.5, 0.4), Vector3.ZERO, 4)
				seg.look_at(next, Vector3.UP)
				seg.rotate_object_local(Vector3.RIGHT, PI / 2)
				seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if i % 2 == 0:
				var color: Color = line.color if i % 4 == 0 else K.CREAM
				var flag := K.quad(self, Vector2(0.32, 0.42), point + Vector3(0, -0.24, 0), color)
				flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				flags.append({"node": flag, "phase": float(i) * 0.7 + a.x})

	# String lights between the depot and the skip, and along the stall row.
	_string_lights(Vector3(11, 4.9, 6), Vector3(16, 4.9, 8), 8)
	_string_lights(Vector3(-16, 4.9, -5), Vector3(-5, 4.9, -8), 9)
	_string_lights(Vector3(6, 4.9, -7), Vector3(16, 4.9, -1), 9)


func _string_lights(a: Vector3, b: Vector3, count: int) -> void:
	for i in count:
		var t := float(i) / maxf(1.0, float(count - 1))
		var point := a.lerp(b, t)
		point.y -= sin(t * PI) * 0.45
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.88, 0.6)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.72, 0.4)
		mat.emission_energy_multiplier = 0.2
		var bulb := K.sphere(self, 0.06, point, Color(1, 0.9, 0.7))
		bulb.material_override = mat
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		string_lights.append({"bulb": bulb})


func _build_plants() -> void:
	var spots := [
		Vector3(-11.5, 0, -3.5), Vector3(-5.5, 0, 4.5), Vector3(4.5, 0, -3.5),
		Vector3(12.5, 0, -10.5), Vector3(-11.5, 0, 6.5), Vector3(6.5, 0, 7.5),
		Vector3(-5.5, 0, -8.0), Vector3(17.0, 0, 6.0),
	]
	for i in spots.size():
		var spot: Vector3 = spots[i]
		var node := Node3D.new()
		node.position = spot
		add_child(node)
		_block(spot, 1.1)
		K.box(node, Vector3(1.2, 0.55, 1.2), Vector3(0, 0.27, 0), K.WOOD)
		K.box(node, Vector3(1.05, 0.08, 1.05), Vector3(0, 0.55, 0), K.WOOD_DARK)
		K.collider(node, Vector3(1.2, 0.6, 1.2), Vector3(0, 0.3, 0))
		var foliage := Node3D.new()
		foliage.position = Vector3(0, 0.72, 0)
		node.add_child(foliage)
		var leaf_mat := StandardMaterial3D.new()
		leaf_mat.albedo_color = Color(0.36, 0.34, 0.22)
		leaf_mat.roughness = 0.9
		for j in 3:
			var leaf := K.sphere(foliage, 0.36, Vector3(-0.25 + j * 0.25, 0.2 + (j % 2) * 0.22, 0.05 * j), Color(0.36, 0.5, 0.3), Vector3(0.8, 1.2, 0.8))
			leaf.material_override = leaf_mat
			leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bloom := Node3D.new()
		bloom.position = Vector3(0, 0.25, 0)
		foliage.add_child(bloom)
		for j in 5:
			var angle := j * TAU / 5.0
			K.sphere(bloom, 0.075, Vector3(cos(angle) * 0.32, 0.42 + sin(j * 2.0) * 0.06, sin(angle) * 0.32), [K.CORAL, K.OCHRE, K.PLUM][j % 3]).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plants.append({"foliage": foliage, "bloom": bloom, "material": leaf_mat})

	for spot in [Vector3(-18, 0, 13), Vector3(-6, 0, 13), Vector3(16, 0, 13)]:
		var tree := Node3D.new()
		tree.position = spot
		add_child(tree)
		_block(spot, 0.9)
		K.cylinder(tree, 0.16, 2.6, Vector3(0, 1.3, 0), K.WOOD_DARK, Vector3.ZERO, 7)
		var canopy := K.sphere(tree, 1.15, Vector3(0, 3.0, 0), Color(0.42, 0.52, 0.3), Vector3(1.1, 0.85, 1.1))
		canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		K.sphere(tree, 0.7, Vector3(0.75, 3.5, 0.2), Color(0.46, 0.57, 0.33), Vector3(1, 0.8, 1)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		K.collider(tree, Vector3(0.5, 2.2, 0.5), Vector3(0, 1.1, 0))

	# Dry weeds in the corners, cleared as the market comes back to life.
	var weed_spots := [
		Vector3(-19, 0, -9), Vector3(19, 0, -9), Vector3(-19, 0, 8), Vector3(19, 0, 8),
		Vector3(-11, 0, -11.5), Vector3(12, 0, -11.5), Vector3(-1, 0, 13.2), Vector3(16, 0, 12.5),
	]
	for spot in weed_spots:
		var weed := Node3D.new()
		weed.position = spot
		add_child(weed)
		for i in 4:
			var angle := i * 1.6
			var blade := K.cone(weed, 0.0, 0.07, 0.55, Vector3(cos(angle) * 0.18, 0.26, sin(angle) * 0.18), Color(0.48, 0.42, 0.24), Vector3(cos(angle) * 0.3, 0, sin(angle) * 0.3), 4)
			blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		weeds.append(weed)


func _build_puddles() -> void:
	var spots := [
		{"pos": Vector3(-6, 0, -2), "r": 1.3},
		{"pos": Vector3(9, 0, 5), "r": 1.0},
		{"pos": Vector3(-13, 0, 6), "r": 1.15},
		{"pos": Vector3(4, 0, -6), "r": 0.9},
		{"pos": Vector3(14, 0, -7), "r": 1.0},
	]
	for item in spots:
		var pos: Vector3 = item.pos
		var radius: float = item.r
		var node := Node3D.new()
		node.position = pos + Vector3(0, 0.02, 0)
		add_child(node)
		var disc := K.plane(node, Vector2(radius * 2.1, radius * 1.5), Vector3.ZERO, Color(0.44, 0.55, 0.58), K.clear_material(Color(0.44, 0.55, 0.58), 0.32))
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shine := K.plane(node, Vector2(radius * 1.4, radius * 0.22), Vector3(0.05, 0.005, -radius * 0.2), Color(0.9, 0.92, 0.86), K.clear_material(Color(0.95, 0.95, 0.88), 0.3))
		shine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puddles.append({"pos": pos, "radius": radius, "node": node})


func _build_bounds() -> void:
	var walls := [
		{"size": Vector3(1, 3, 28), "pos": Vector3(-21, 1.5, 0)},
		{"size": Vector3(1, 3, 28), "pos": Vector3(21, 1.5, 0)},
		{"size": Vector3(43, 3, 1), "pos": Vector3(0, 1.5, -13.6)},
		{"size": Vector3(1, 3, 8), "pos": Vector3(-21, 1.5, 27)},
		{"size": Vector3(1, 3, 8), "pos": Vector3(21, 1.5, 27)},
		{"size": Vector3(43, 3, 1), "pos": Vector3(0, 1.5, 30.8)},
	]
	for wall in walls:
		K.collider(self, wall.size, wall.pos)
