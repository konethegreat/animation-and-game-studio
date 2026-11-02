extends "res://scripts/district.gd"

const QUARTER := Rect2(-22.0, -17.0, 44.0, 34.0)
const WATER_Z_FROM := 3.0
const WATER_Z_TO := 11.0
const WATER_Y := -0.75
const BRIDGES := [-13.0, 3.0, 14.0]

var drains: Array[Dictionary] = []
var lamps: Array[Dictionary] = []
var wash: Array[Dictionary] = []
var mist: Array[Dictionary] = []
var weeds: Array[Node3D] = []
var ground_mat: StandardMaterial3D
var water_mat: ShaderMaterial
var night := false
var _time := 0.0
var _grime_spots: Array[Vector3] = []
var _cobble: ImageTexture
var _stripe_a: ImageTexture
var _stone: ImageTexture


func _ready() -> void:
	bounds = QUARTER
	spawn = Vector3(-19.0, 0.0, -1.0)
	skip_pos = Vector3(-18.0, 0.0, -10.5)
	music = "market"
	ambience = "market"
	title = "CANAL QUARTER"
	mood = "canal"
	light_count = 84
	heavy_count = 10
	pile_count = 3
	grime_count = 3
	interiors = [
		{
			"id": "boathouse", "title": "BOATHOUSE",
			"pos": Vector3(9.0, 0.0, 13.6), "return_pos": Vector3(9.0, 0.0, 12.0),
		},
	]
	_cobble = K.make_cobble()
	_stone = K.make_stripes(Color(0.62, 0.66, 0.64), Color(0.56, 0.6, 0.58))
	_stripe_a = K.make_stripes(K.TEAL, K.CREAM)
	_build_ground()
	_build_water()
	_build_banks()
	_build_bridges()
	_build_lock()
	_build_terraces()
	_build_boathouse()
	_build_stalls()
	_build_bottle_machine()
	_build_depots()
	_build_drains()
	_build_lamps()
	_build_washing_lines()
	_build_boats()
	_build_mist()
	_build_puddles()
	_build_bounds()
	set_clean(0.0)


func _process(delta: float) -> void:
	_time += delta
	for item in wash:
		var cloth: Node3D = item.cloth
		cloth.rotation.x = sin(_time * 1.1 + float(item.phase)) * 0.16
	for i in mist.size():
		var entry: Dictionary = mist[i]
		var plane: MeshInstance3D = entry.node
		var home: Vector3 = entry.home
		plane.position.x = home.x + sin(_time * (0.05 + 0.02 * float(i)) + float(i) * 2.0) * 2.4
	for weed in weeds:
		weed.rotation.y = sin(_time * 0.8 + weed.position.x) * 0.06
	for lamp in lamps:
		if bool(lamp.flicker):
			var light: OmniLight3D = lamp.light
			light.light_energy = float(lamp.base_energy) * (0.86 + 0.14 * sin(_time * 7.0) * sin(_time * 2.7))


func item_home(plane: MeshInstance3D) -> Vector3:
	return plane.get_meta("home", Vector3.ZERO)


func set_clean(value: float) -> void:
	clean_level = clampf(value, 0.0, 1.0)
	var t := clean_level
	if ground_mat:
		ground_mat.albedo_color = Color(0.88, 0.9, 0.86).lerp(Color(1.12, 1.1, 1.04), smoothstep(0.0, 0.85, t))
	if water_mat:
		water_mat.set_shader_parameter("light_water", Color(0.3, 0.5, 0.48).lerp(Color(0.56, 0.74, 0.68), t))
		water_mat.set_shader_parameter("deep", Color(0.1, 0.26, 0.28).lerp(Color(0.2, 0.42, 0.42), t))
	for item in lamps:
		var lit: float = 1.0 if night else smoothstep(0.3, 0.7, t)
		var bulb: MeshInstance3D = item.bulb
		var mat := bulb.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 0.3 + lit * 2.8
		var light: OmniLight3D = item.light
		item.base_energy = 1.35 * lit
		light.light_energy = float(item.base_energy)
		var pool: MeshInstance3D = item.pool
		var pool_mat := pool.material_override as StandardMaterial3D
		if pool_mat:
			pool_mat.albedo_color = Color(0.62, 0.86, 0.82, 0.02 + lit * 0.22)
	for node in weeds:
		node.scale = Vector3.ONE * maxf(0.01, 1.0 - smoothstep(0.1, 0.7, t))


func set_night(value: bool) -> void:
	night = value
	mood = "night" if value else "canal"
	set_clean(clean_level)
	for item in lamps:
		var mat: StandardMaterial3D = (item.bulb as MeshInstance3D).material_override
		if mat:
			mat.emission = Color(1.0, 0.74, 0.42) if value else Color(1.0, 0.86, 0.62)
		var light: OmniLight3D = item.light
		light.light_color = Color(1.0, 0.68, 0.4) if value else Color(0.85, 0.95, 0.9)


func litter_mix() -> Array:
	return [
		"float_bottle", "float_bottle", "float_bag", "bottle_cap",
		"paper", "paper", "cup", "can", "bottle", "leaf", "bag",
		"paper", "can", "bottle_cap", "cup", "leaf", "paper", "can",
	]


func heavy_mix() -> Array:
	return ["sack", "crate", "planks", "tyre", "barrel", "sack"]


func pile_spots() -> Array:
	return [
		Vector3(-15.0, 0.0, -6.0),
		Vector3(8.0, 0.0, -8.0),
		Vector3(-2.0, 0.0, 14.5),
	]


func crowd_points() -> Array:
	return [
		Vector3(-18.0, 0.0, -4.0), Vector3(-10.0, 0.0, -6.0), Vector3(-2.0, 0.0, -8.0),
		Vector3(6.0, 0.0, -6.0), Vector3(13.0, 0.0, -4.0), Vector3(18.0, 0.0, 0.0),
		Vector3(-16.0, 0.0, 0.5), Vector3(0.0, 0.0, 1.0), Vector3(11.0, 0.0, 0.0),
		Vector3(-12.0, 0.0, 13.5), Vector3(-4.0, 0.0, 14.0), Vector3(16.0, 0.0, 13.0),
		Vector3(19.0, 0.0, 4.0), Vector3(-19.0, 0.0, 6.0),
	]


func is_water(point: Vector3) -> bool:
	return point.z > WATER_Z_FROM - 0.1 and point.z < WATER_Z_TO + 0.1 and absf(point.x) < 21.0


func float_spot(rng: RandomNumberGenerator) -> Vector3:
	for attempt in 40:
		var x := rng.randf_range(-19.0, 19.0)
		var on_bridge := false
		for bridge in BRIDGES:
			if absf(x - bridge) < 2.4:
				on_bridge = true
				break
		if on_bridge:
			continue
		var side := 1.0 if rng.randf() > 0.5 else -1.0
		var z := 0.0
		if side > 0.0:
			z = rng.randf_range(WATER_Z_TO - 1.4, WATER_Z_TO - 0.3)
		else:
			z = rng.randf_range(WATER_Z_FROM + 0.3, WATER_Z_FROM + 1.4)
		return Vector3(x, WATER_Y + 0.2, z)
	return Vector3(-6.0, WATER_Y + 0.2, 4.0)


func next_grime_spot() -> Vector3:
	if _grime_spots.is_empty():
		if drains.is_empty():
			return random_walkable(RandomNumberGenerator.new())
		var entry: Dictionary = drains[0]
		return entry.pos + Vector3(0.0, 0.0, -1.0)
	return _grime_spots.pop_front()


func clear_drain(index: int) -> void:
	if index < 0 or index >= drains.size():
		return
	drains[index].clogged = false
	var grate: MeshInstance3D = drains[index].sludge
	if grate != null and is_instance_valid(grate):
		grate.visible = false


func _build_ground() -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	add_child(ground)
	ground_mat = K.texture_material(_cobble, Vector3(16, 12, 1), Color(0.98, 0.98, 0.95))
	K.plane(ground, Vector2(44, 20.5), Vector3(0, 0, -7.2), K.STONE, ground_mat)
	K.collider(ground, Vector3(44, 1, 20.5), Vector3(0, -0.5, -7.2))
	K.plane(ground, Vector2(44, 5.7), Vector3(0, 0, 14.1), K.STONE, ground_mat)
	K.collider(ground, Vector3(44, 1, 5.7), Vector3(0, -0.5, 14.1))
	var apron_mat := K.material(Color(0.44, 0.47, 0.42))
	for piece in [
		{"size": Vector2(120, 24), "pos": Vector3(0, -0.06, -30.0)},
		{"size": Vector2(120, 24), "pos": Vector3(0, -0.06, 42.0)},
		{"size": Vector2(28, 80), "pos": Vector3(-36, -0.06, 6.0)},
		{"size": Vector2(28, 80), "pos": Vector3(36, -0.06, 6.0)},
	]:
		var apron := K.plane(ground, piece.size, piece.pos, K.STONE_DARK, apron_mat)
		apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var path := K.plane(ground, Vector2(40, 2.4), Vector3(0, 0.005, 0.6), K.STONE, K.texture_material(_stone, Vector3(10, 1, 1)))
	path.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_water() -> void:
	var canal := Node3D.new()
	canal.name = "Canal"
	add_child(canal)
	var shader := load("res://scripts/water.gdshader") as Shader
	water_mat = ShaderMaterial.new()
	water_mat.shader = shader
	var water := K.plane(canal, Vector2(42, 8.0), Vector3(0, WATER_Y, 7.0), K.WATER, water_mat)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.collider(canal, Vector3(42, 0.2, 8.0), Vector3(0, WATER_Y - 0.2, 7.0))


func _bank_segments() -> Array:
	var segments: Array = []
	var edges := [-22.0]
	edges.append_array(BRIDGES)
	edges.append(22.0)
	for i in edges.size() - 1:
		var a: float = edges[i] + (2.0 if i > 0 else 0.0)
		var b: float = edges[i + 1] - (2.0 if i < edges.size() - 2 else 0.0)
		if b - a > 1.0:
			segments.append([a, b])
	return segments


func _build_banks() -> void:
	for side in [-1.0, 1.0]:
		var z: float = 2.7 if side < 0.0 else 11.3
		for segment in _bank_segments():
			var a: float = segment[0]
			var b: float = segment[1]
			var length := b - a
			var center := (a + b) / 2.0
			K.box(self, Vector3(length, 0.9, 0.55), Vector3(center, -0.05, z), K.STONE_DARK)
			K.box(self, Vector3(length, 0.12, 0.65), Vector3(center, 0.4, z), K.STONE)
			K.collider(self, Vector3(length, 1.0, 0.55), Vector3(center, 0.0, z))
			for x in range(int(a) + 1, int(b), 3):
				K.box(self, Vector3(0.12, 0.5, 0.12), Vector3(x, 0.75, z), K.INK)
			K.box(self, Vector3(length, 0.07, 0.07), Vector3(center, 1.0, z), K.INK)


func _build_bridges() -> void:
	for bridge in BRIDGES:
		var node := Node3D.new()
		node.position = Vector3(bridge, 0, 0)
		add_child(node)
		K.box(node, Vector3(3.6, 0.44, 9.4), Vector3(0, -0.22, 7.0), K.STONE)
		K.collider(node, Vector3(3.6, 0.44, 9.4), Vector3(0, -0.22, 7.0))
		K.box(node, Vector3(3.8, 0.1, 9.6), Vector3(0, 0.02, 7.0), K.PAPER)
		for side in [-1.0, 1.0]:
			var x: float = side * 1.8
			K.box(node, Vector3(0.14, 0.6, 9.6), Vector3(x, 0.4, 7.0), K.STONE_DARK)
			K.collider(node, Vector3(0.2, 1.0, 9.6), Vector3(x, 0.5, 7.0))
			for i in 4:
				K.cylinder(node, 0.07, 0.85, Vector3(x, 0.85, 2.9 + i * 2.6), K.INK, Vector3.ZERO, 8)
			K.box(node, Vector3(0.1, 0.08, 9.6), Vector3(x, 1.2, 7.0), K.INK)


func _build_lock() -> void:
	var node := Node3D.new()
	node.position = Vector3(-20.4, 0, 7.0)
	add_child(node)
	for side in [-1.0, 1.0]:
		var z: float = side * 2.6
		K.box(node, Vector3(3.2, 5.2, 2.2), Vector3(0, 2.6, z), K.STONE_DARK)
		K.box(node, Vector3(3.4, 0.3, 2.4), Vector3(0, 5.3, z), K.STONE)
		K.collider(node, Vector3(3.2, 5.4, 2.2), Vector3(0, 2.7, z))
		K.cylinder(node, 0.35, 0.5, Vector3(0, 5.7, z), K.TEAL_DARK, Vector3.ZERO, 10)
		K.sphere(node, 0.12, Vector3(0, 6.1, z), K.CORAL).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_block(node.position + Vector3(0, 0, z), 2.2)
	for side in [-1.0, 1.0]:
		var leaf := K.box(node, Vector3(0.26, 4.2, 2.4), Vector3(0.9, 1.6, side * 1.2), K.WOOD_DARK, Vector3(0, side * 0.24, 0))
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(node, Vector3(0.4, 0.5, 0.1), Vector3(0, 4.9, -2.5), K.INK)
	K.label(node, "TIDE LOCK 3", Vector3(0, 4.6, -2.6), 26, K.CREAM, Vector3(0, PI, 0))
	K.label(node, "MIND THE GATES", Vector3(0, 3.4, 2.75), 20, K.CREAM)


func _build_terraces() -> void:
	var north := [
		{"pos": Vector3(-15, 0, -13.4), "w": 10.0, "h": 8.0, "color": Color(0.62, 0.52, 0.42), "name": "ROPE & TAR"},
		{"pos": Vector3(-4, 0, -13.6), "w": 9.0, "h": 10.0, "color": Color(0.55, 0.58, 0.5), "name": "CHANDLER"},
		{"pos": Vector3(6, 0, -13.4), "w": 9.0, "h": 7.5, "color": Color(0.68, 0.52, 0.38), "name": "FISH & CHIPS"},
		{"pos": Vector3(15.5, 0, -13.4), "w": 8.0, "h": 9.0, "color": Color(0.6, 0.64, 0.58), "name": "BOAT PARTS"},
	]
	for spec in north:
		_terrace(spec.pos, 0.0, float(spec.w), float(spec.h), spec.color, str(spec.name))
	var south := [
		{"pos": Vector3(-16, 0, 16.4), "w": 9.0, "h": 8.5, "color": Color(0.66, 0.56, 0.44), "name": "NET MENDER"},
		{"pos": Vector3(-6, 0, 16.4), "w": 9.0, "h": 7.0, "color": Color(0.58, 0.6, 0.52), "name": "TEA BARGE"},
	]
	for spec in south:
		_terrace(spec.pos, PI, float(spec.w), float(spec.h), spec.color, str(spec.name))


func _terrace(pos: Vector3, rot: float, width: float, height: float, color: Color, name: String) -> void:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = rot
	add_child(node)
	_block(pos, 4.2)
	K.box(node, Vector3(width, height, 4.4), Vector3(0, height / 2.0, 0), color)
	K.box(node, Vector3(width + 0.4, 0.3, 4.6), Vector3(0, height + 0.1, 0), K.STONE_DARK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.collider(node, Vector3(width, height, 4.4), Vector3(0, height / 2.0, 0))
	K.box(node, Vector3(width * 0.9, 2.2, 0.14), Vector3(0, 1.3, 2.28), color.darkened(0.22))
	K.box(node, Vector3(width * 0.5, 1.3, 0.1), Vector3(0, 1.4, 2.34), K.INK)
	var glow := K.quad(node, Vector2(width * 0.46, 1.2), Vector3(0, 1.4, 2.42), Color(0.98, 0.84, 0.6))
	var glow_mat := glow.material_override as StandardMaterial3D
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.76, 0.44)
	glow_mat.emission_energy_multiplier = 0.4
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var awning := K.box(node, Vector3(width * 0.8, 0.08, 1.4), Vector3(0, 2.9, 2.9), K.CREAM, Vector3(-0.14, 0, 0), K.texture_material(_stripe_a, Vector3(2.4, 1, 1)))
	awning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(node, Vector3(width * 0.62, 0.44, 0.1), Vector3(0, 3.5, 2.32), K.INK)
	K.label(node, name, Vector3(0, 3.5, 2.4), 34, K.CREAM)
	var cols := 3
	var rows := maxi(1, int((height - 4.0) / 2.0))
	for row in rows:
		for col in cols:
			var wx := -width * 0.32 + col * width * 0.32
			var wy := 4.0 + row * 2.0
			if wy > height - 1.0:
				continue
			K.box(node, Vector3(1.0, 1.2, 0.12), Vector3(wx, wy, 2.24), K.INK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var lit := (row + col + int(abs(pos.x))) % 3 != 0
			var pane := K.quad(node, Vector2(0.8, 1.0), Vector3(wx, wy, 2.31), Color(0.99, 0.84, 0.6) if lit else Color(0.15, 0.2, 0.22))
			if lit:
				var mat := pane.material_override as StandardMaterial3D
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.74, 0.42)
				mat.emission_energy_multiplier = 0.35
			pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if height > 8.5:
		K.cylinder(node, 0.34, 1.1, Vector3(width * 0.32, height + 0.75, 0), K.BRICK, Vector3.ZERO, 10)
		K.cylinder(node, 0.4, 0.16, Vector3(width * 0.32, height + 1.32, 0), K.STONE_DARK, Vector3.ZERO, 10)


func _build_boathouse() -> void:
	var node := Node3D.new()
	node.position = Vector3(9.0, 0, 16.0)
	add_child(node)
	_block(Vector3(6.2, 0, 16.0), 3.3)
	_block(Vector3(11.8, 0, 16.0), 3.3)
	K.box(node, Vector3(10.0, 5.4, 4.6), Vector3(0, 2.7, 0), Color(0.42, 0.5, 0.5))
	K.box(node, Vector3(10.4, 0.34, 5.0), Vector3(0, 5.5, 0), K.WOOD_DARK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.collider(node, Vector3(10.0, 5.6, 4.6), Vector3(0, 2.8, 0))
	for i in 4:
		K.box(node, Vector3(0.24, 4.6, 0.24), Vector3(-4.4 + i * 2.9, 2.3, -2.1), K.WOOD_DARK)
	var door_entry: Dictionary = interiors[0]
	var pos: Vector3 = door_entry.pos
	var door := Node3D.new()
	door.position = pos
	door.rotation.y = PI
	add_child(door)
	_block(pos + Vector3(0, 0, -0.5), 1.1)
	K.box(door, Vector3(3.4, 2.7, 0.14), Vector3(0, 1.35, 0.02), K.INK)
	K.box(door, Vector3(2.5, 2.4, 0.16), Vector3(0, 1.2, 0.16), K.WOOD)
	for row in 2:
		for col in 2:
			K.box(door, Vector3(0.95, 0.8, 0.06), Vector3(-0.58 + col * 1.16, 0.72 + row * 1.0, 0.25), K.WOOD_DARK)
	K.cylinder(door, 0.05, 0.09, Vector3(0.92, 1.2, 0.26), K.OCHRE, Vector3(PI / 2, 0, 0), 8)
	for side in [-1.0, 1.0]:
		K.box(door, Vector3(0.26, 2.9, 0.3), Vector3(side * 1.56, 1.45, 0.1), K.WOOD_DARK)
		K.box(door, Vector3(0.64, 0.16, 0.7), Vector3(side * 1.56, 0.08, 0.28), K.STONE)
	K.box(door, Vector3(3.5, 0.3, 0.36), Vector3(0, 2.9, 0.1), K.WOOD_DARK)
	K.box(door, Vector3(2.7, 0.46, 0.1), Vector3(0, 2.9, 0.29), K.INK)
	K.label(door, str(door_entry.title), Vector3(0, 2.9, 0.36), 28, K.CREAM)
	K.label(door, "SMELLS OF PITCH", Vector3(0, 2.66, 0.36), 12, K.OCHRE)
	K.box(door, Vector3(3.2, 0.1, 0.7), Vector3(0, 0.05, 0.42), K.STONE)
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
	door.add_child(light)
	K.collider(door, Vector3(3.3, 2.9, 0.4), Vector3(0, 1.45, 0.1))
	var net := K.torus(node, 0.5, 0.62, Vector3(-4.6, 2.2, 2.5), K.INK, Vector3(PI / 2, 0, 0))
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 5:
		K.cylinder(node, 0.01, 1.0, Vector3(-5.1 + i * 0.25, 2.2, 2.5), Color(0.5, 0.48, 0.44), Vector3(PI / 2, 0, 1.2), 3).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_stalls() -> void:
	_stall(Vector3(3.0, 0, -2.6), "HOOK & BATTER", Color(0.72, 0.36, 0.2))
	_stall(Vector3(-11.0, 0, 13.2), "TIDE TABLE", K.TEAL)


func _stall(pos: Vector3, sign: String, accent: Color) -> void:
	var node := Node3D.new()
	node.position = pos
	add_child(node)
	_block(pos, 2.8)
	K.box(node, Vector3(3.6, 0.9, 1.4), Vector3(0, 0.45, 0), K.WOOD_DARK)
	K.box(node, Vector3(3.9, 0.12, 1.6), Vector3(0, 0.95, 0), K.WOOD)
	K.collider(node, Vector3(3.8, 1.4, 1.6), Vector3(0, 0.7, 0))
	K.box(node, Vector3(4.2, 1.7, 0.14), Vector3(0, 1.9, -0.7), K.WOOD)
	var canopy := K.box(node, Vector3(4.6, 0.1, 2.2), Vector3(0, 2.8, 0.1), K.CREAM, Vector3(-0.12, 0, 0), K.texture_material(_stripe_a, Vector3(2.2, 1, 1)))
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(node, Vector3(3.4, 0.6, 0.1), Vector3(0, 3.4, -0.62), K.INK)
	K.label(node, sign, Vector3(0, 3.4, -0.55), 40, K.CREAM)
	for i in 3:
		K.sphere(node, 0.13, Vector3(-1.2 + i * 0.6, 1.15, 0.2), accent, Vector3(1, 0.8, 0.8)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(node, Vector3(0.5, 0.4, 0.4), Vector3(1.5, 1.2, 0.1), K.PAPER).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_bottle_machine() -> void:
	var node := Node3D.new()
	node.position = Vector3(-6.5, 0, 1.4)
	node.rotation.y = 0.2
	add_child(node)
	_block(Vector3(-6.5, 0, 1.4), 1.5)
	K.box(node, Vector3(1.6, 2.1, 0.9), Vector3(0, 1.05, 0), K.TEAL_DARK)
	K.collider(node, Vector3(1.7, 2.2, 1.0), Vector3(0, 1.1, 0))
	K.box(node, Vector3(1.7, 0.14, 1.0), Vector3(0, 2.14, 0), K.INK)
	var slot := K.box(node, Vector3(0.5, 0.7, 0.08), Vector3(0, 1.4, 0.47), K.INK)
	slot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := K.quad(node, Vector2(1.1, 0.4), Vector3(0, 2.5, 0.0), K.CREAM)
	glow.material_override = _glow_mat(Color(0.5, 0.95, 0.85), 0.8)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.label(node, "BOTTLE RETURN", Vector3(0, 0.55, 0.47), 22, K.CREAM)
	K.box(node, Vector3(0.3, 0.3, 0.2), Vector3(0.55, 0.35, 0.5), K.METAL)
	for i in 3:
		K.cylinder(node, 0.06, 0.2, Vector3(-0.5 + i * 0.18, 0.35, 0.55), Color(0.4, 0.62, 0.48), Vector3(PI / 2, 0, 0), 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


func _build_depots() -> void:
	var node := Node3D.new()
	node.position = Vector3(-1.5, 0, 14.6)
	node.rotation.y = PI
	add_child(node)
	_block(Vector3(-1.5, 0, 14.6), 3.2)
	K.box(node, Vector3(3.6, 1.0, 1.1), Vector3(0, 0.5, -0.6), K.WOOD_DARK)
	K.box(node, Vector3(3.8, 0.1, 1.25), Vector3(0, 1.02, -0.6), K.WOOD)
	K.box(node, Vector3(3.2, 0.7, 0.1), Vector3(0, 2.0, -1.12), K.INK)
	K.collider(node, Vector3(3.8, 1.5, 1.4), Vector3(0, 0.75, 0))
	K.label(node, "TIDE LOCK SORTING", Vector3(0, 2.0, -1.05), 26, K.CREAM)
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
		K.box(node, Vector3(0.82, 1.25, 0.82), Vector3(x, 0.62, 0.5), color)
		K.box(node, Vector3(0.9, 0.16, 0.9), Vector3(x, 1.3, 0.5), color.darkened(0.2))
		K.label(node, names[i], Vector3(x, 1.85, 0.92), 24, K.CREAM)
	stations = [{"pos": Vector3(-1.5, 0, 12.8), "label": "TIDE LOCK SORTING"}]


func _build_drains() -> void:
	var spots := [
		Vector3(-16.0, 0, 2.5), Vector3(0.5, 0, 2.5), Vector3(13.5, 0, 2.5),
	]
	for i in spots.size():
		var pos: Vector3 = spots[i]
		var node := Node3D.new()
		node.position = pos
		add_child(node)
		K.box(node, Vector3(1.0, 0.06, 0.6), Vector3(0, 0.03, 0), K.INK)
		for j in 5:
			K.box(node, Vector3(0.08, 0.08, 0.5), Vector3(-0.4 + j * 0.2, 0.06, 0), K.METAL).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sludge := K.box(node, Vector3(0.8, 0.12, 0.45), Vector3(0, 0.1, 0), Color(0.3, 0.28, 0.22))
		sludge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		drains.append({"node": node, "pos": pos, "clogged": true, "sludge": sludge, "timer": randf_range(3.0, 7.0)})
		_grime_spots.append(pos + Vector3(0.4, 0.0, -0.9))


func _build_lamps() -> void:
	var spots := [
		Vector3(-19, 0, 1.4), Vector3(-9, 0, 1.4), Vector3(7.5, 0, 1.4), Vector3(17.5, 0, 1.4),
		Vector3(-19, 0, 12.6), Vector3(-4, 0, 12.6), Vector3(12, 0, 12.6), Vector3(19, 0, 12.6),
	]
	for i in spots.size():
		var spot: Vector3 = spots[i]
		var node := Node3D.new()
		node.position = spot
		add_child(node)
		_block(spot, 0.5)
		K.cylinder(node, 0.12, 3.9, Vector3(0, 1.95, 0), K.INK, Vector3.ZERO, 8)
		K.cylinder(node, 0.26, 0.2, Vector3(0, 0.14, 0), K.INK, Vector3.ZERO, 8)
		K.box(node, Vector3(0.7, 0.09, 0.09), Vector3(0.3, 3.82, 0), K.INK)
		K.cone(node, 0.09, 0.3, 0.32, Vector3(0.62, 3.7, 0), K.INK, Vector3.ZERO, 8)
		var bulb_mat := StandardMaterial3D.new()
		bulb_mat.albedo_color = Color(1.0, 0.9, 0.66)
		bulb_mat.emission_enabled = true
		bulb_mat.emission = Color(1.0, 0.86, 0.62)
		bulb_mat.emission_energy_multiplier = 0.3
		var bulb := K.sphere(node, 0.16, Vector3(0.62, 3.52, 0), Color(1, 0.9, 0.66))
		bulb.material_override = bulb_mat
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light := OmniLight3D.new()
		light.position = Vector3(0.62, 3.45, 0)
		light.light_color = Color(0.85, 0.95, 0.9)
		light.omni_range = 8.5
		light.light_energy = 0.0
		light.shadow_enabled = false
		node.add_child(light)
		var pool := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 1.6
		disc.bottom_radius = 1.6
		disc.height = 0.02
		disc.radial_segments = 20
		pool.mesh = disc
		pool.material_override = K.clear_material(Color(0.62, 0.86, 0.82), 0.02)
		pool.position = Vector3(0.62, 0.015, 0)
		pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(pool)
		lamps.append({"bulb": bulb, "light": light, "pool": pool, "base_energy": 0.0, "flicker": i == 2})


func _build_washing_lines() -> void:
	var lines := [
		{"a": Vector3(-19, 3.3, -11.2), "b": Vector3(-10, 3.3, -11.2)},
		{"a": Vector3(2, 3.1, -11.4), "b": Vector3(10, 3.1, -11.4)},
	]
	for line in lines:
		var a: Vector3 = line.a
		var b: Vector3 = line.b
		var count := int(a.distance_to(b) / 1.0)
		for i in count + 1:
			var t := float(i) / count
			var point := a.lerp(b, t)
			point.y -= sin(t * PI) * 0.4
			if i < count:
				var next := a.lerp(b, float(i + 1) / count)
				next.y -= sin(float(i + 1) / count * PI) * 0.4
				var mid := (point + next) * 0.5
				var seg := K.cylinder(self, 0.008, point.distance_to(next), mid, Color(0.5, 0.52, 0.5), Vector3.ZERO, 4)
				seg.look_at(next, Vector3.UP)
				seg.rotate_object_local(Vector3.RIGHT, PI / 2)
				seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if i % 2 == 0:
				var cloth := K.quad(self, Vector2(0.42, 0.55), point + Vector3(0, -0.3, 0), [K.CREAM, K.TEAL, K.CORAL][i % 3])
				cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				wash.append({"cloth": cloth, "phase": float(i) * 0.8})


func _build_boats() -> void:
	_boat(Vector3(-5.5, WATER_Y + 0.2, 4.6), 0.06)
	_boat(Vector3(10.5, WATER_Y + 0.2, 9.4), -0.12)
	_boat(Vector3(-13.0, WATER_Y + 0.2, 8.6), 3.12)


func _boat(pos: Vector3, rot: float) -> void:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = rot
	add_child(node)
	K.box(node, Vector3(6.4, 0.5, 1.8), Vector3.ZERO, Color(0.38, 0.34, 0.3))
	K.box(node, Vector3(6.6, 0.12, 2.0), Vector3(0, 0.28, 0), K.WOOD)
	K.box(node, Vector3(2.6, 0.8, 1.5), Vector3(-0.8, 0.68, 0), K.CREAM)
	for i in 3:
		K.box(node, Vector3(0.5, 0.3, 0.05), Vector3(-1.7 + i * 0.75, 0.8, 0.75), K.INK)
	K.cylinder(node, 0.12, 1.4, Vector3(0.7, 1.2, 0), K.INK)
	K.box(node, Vector3(0.18, 0.14, 0.18), Vector3(0.7, 1.9, 0), K.CORAL)
	K.box(node, Vector3(0.9, 0.08, 0.3), Vector3(2.5, 0.24, 0), K.WOOD)
	K.torus(node, 0.22, 0.3, Vector3(2.9, 0.3, 0.6), K.INK, Vector3(PI / 2, 0, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_mist() -> void:
	for i in 3:
		var plane := K.plane(self, Vector2(16.0, 3.4), Vector3(-6.0 + i * 6.0, 0.25, 5.0 + i * 1.2), Color(0.85, 0.9, 0.88), K.clear_material(Color(0.85, 0.9, 0.88), 0.06))
		plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mist.append({"node": plane, "home": plane.position})


func _build_puddles() -> void:
	var spots := [
		{"pos": Vector3(-12.0, 0, -3.0), "r": 1.2},
		{"pos": Vector3(9.0, 0, -6.0), "r": 1.0},
		{"pos": Vector3(14.0, 0, 13.0), "r": 0.9},
		{"pos": Vector3(-17.0, 0, 13.5), "r": 1.1},
	]
	for item in spots:
		var pos: Vector3 = item.pos
		var radius: float = item.r
		var node := Node3D.new()
		node.position = pos + Vector3(0, 0.02, 0)
		add_child(node)
		var disc := K.plane(node, Vector2(radius * 2.1, radius * 1.5), Vector3.ZERO, Color(0.42, 0.52, 0.54), K.clear_material(Color(0.42, 0.52, 0.54), 0.32))
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puddles.append({"pos": pos, "radius": radius, "node": node})


func _build_bounds() -> void:
	var walls := [
		{"size": Vector3(1, 3, 34), "pos": Vector3(-22, 1.5, 0)},
		{"size": Vector3(1, 3, 34), "pos": Vector3(22, 1.5, 0)},
		{"size": Vector3(45, 3, 1), "pos": Vector3(0, 1.5, -17.6)},
		{"size": Vector3(45, 3, 1), "pos": Vector3(0, 1.5, 17.6)},
	]
	for wall in walls:
		K.collider(self, wall.size, wall.pos)
	var weed_spots := [
		Vector3(-20.5, 0, -14.0), Vector3(20.5, 0, -14.0), Vector3(-20.5, 0, 0.0),
		Vector3(20.5, 0, 12.0), Vector3(18.5, 0, 16.2),
	]
	for spot in weed_spots:
		var weed := Node3D.new()
		weed.position = spot
		add_child(weed)
		for i in 4:
			var angle := i * 1.6
			var blade := K.cone(weed, 0.0, 0.07, 0.55, Vector3(cos(angle) * 0.18, 0.26, sin(angle) * 0.18), Color(0.44, 0.46, 0.28), Vector3(cos(angle) * 0.3, 0, sin(angle) * 0.3), 4)
			blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		weeds.append(weed)
