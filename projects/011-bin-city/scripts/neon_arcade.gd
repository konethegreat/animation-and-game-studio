extends "res://scripts/district.gd"

# The Neon Arcade strip: a covered market street at night, arcade hall on the
# north wall, a rooftop hideout over the east block reached by a fire escape,
# neon signage, rain, and three shorting puddles that spark while litter sits
# in them.

const STRIP := Rect2(-22.0, -17.0, 44.0, 34.0)

var electric_puddles: Array[Dictionary] = []
var token_count := 3
var roof_token_pos := Vector3(12.2, 2.55, 12.4)
var raining := false

var signs: Array[Dictionary] = []
var lamps: Array[Dictionary] = []
var fans: Array[Dictionary] = []
var lanterns: Array[Dictionary] = []
var ground_mat: StandardMaterial3D
var _time := 0.0
var _antenna_bulb: MeshInstance3D
var _antenna_mat: StandardMaterial3D
var _asphalt: ImageTexture
var _stripe: ImageTexture
var _neon_shader: Shader


func _ready() -> void:
	bounds = STRIP
	spawn = Vector3(0.0, 0.0, 10.0)
	skip_pos = Vector3(-19.0, 0.0, 10.0)
	music = "market"
	ambience = "market"
	title = "NEON ARCADE"
	mood = "neon"
	light_count = 78
	heavy_count = 10
	pile_count = 3
	grime_count = 0
	interiors = [
		{"id": "arcade", "title": "ARCADE", "pos": Vector3(-8.0, 0.0, -12.4), "return_pos": Vector3(-8.0, 0.0, -10.8)},
		{"id": "plant", "title": "SORTING PLANT", "pos": Vector3(19.5, 0.0, -12.1), "return_pos": Vector3(19.5, 0.0, -10.5)},
	]
	_neon_shader = load("res://scripts/neon.gdshader")
	_asphalt = K.make_cobble()
	_stripe = K.make_stripes(Color(0.34, 0.2, 0.36), Color(0.16, 0.16, 0.22))
	_build_ground()
	_build_north_row()
	_build_cabinet_wall()
	_build_south_row()
	_build_rooftop()
	_build_fire_escape()
	_build_canopy()
	_build_signs()
	_build_cables()
	_build_pole_lamps()
	_build_vents()
	_build_depot()
	_build_skip()
	_build_slip_puddles()
	_build_electric_puddles()
	_build_bounds()
	set_clean(0.0)


func _process(delta: float) -> void:
	_time += delta
	for entry in fans:
		var blades: Node3D = entry.node
		blades.rotation.y += delta * float(entry.speed)
	for entry in lanterns:
		var node: Node3D = entry.node
		node.rotation.x = sin(_time * 1.3 + float(entry.phase)) * 0.12
		node.rotation.z = sin(_time * 0.9 + float(entry.phase) * 1.7) * 0.09
	if _antenna_mat:
		_antenna_mat.emission_energy_multiplier = 0.8 + maxf(0.0, sin(_time * 2.4)) * 2.2
	var flicker_on := raining
	for entry in lamps:
		if not bool(entry.flicker):
			continue
		var light: OmniLight3D = entry.light
		var target := float(entry.base_energy)
		if flicker_on:
			target *= 0.82 + 0.18 * sin(_time * 9.0) * sin(_time * 3.1)
		light.light_energy = target


func set_clean(value: float) -> void:
	clean_level = clampf(value, 0.0, 1.0)
	var t := clean_level
	if ground_mat:
		ground_mat.albedo_color = Color(0.62, 0.64, 0.74).lerp(Color(0.86, 0.88, 0.98), smoothstep(0.0, 0.85, t))
	var boost := (0.78 + smoothstep(0.15, 0.9, t) * 0.42) * (1.28 if raining else 1.0)
	for entry in signs:
		var mat: ShaderMaterial = entry.mat
		if mat:
			mat.set_shader_parameter("energy", float(entry.base) * boost)
	var lamp_level := (0.25 + smoothstep(0.2, 0.8, t) * 0.75) * (1.0 if raining else 0.55)
	for entry in lamps:
		var bulb_mat: StandardMaterial3D = entry.bulb_mat
		if bulb_mat:
			bulb_mat.emission_energy_multiplier = 0.4 + lamp_level * 2.4
		var light: OmniLight3D = entry.light
		entry.base_energy = float(entry.power) * lamp_level
		light.light_energy = float(entry.base_energy)


func set_night(value: bool) -> void:
	raining = value
	set_clean(clean_level)


func litter_puddle(pos: Vector3) -> void:
	for entry in electric_puddles:
		if Vector2(entry.pos.x - pos.x, entry.pos.z - pos.z).length() < 1.6:
			entry.hazard = false
			if entry.sparks != null and is_instance_valid(entry.sparks):
				entry.sparks.visible = false
			var lamp: MeshInstance3D = entry.lamp
			if lamp != null and is_instance_valid(lamp):
				var mat := lamp.material_override as StandardMaterial3D
				if mat:
					mat.emission = Color(0.32, 0.85, 0.78)
					mat.emission_energy_multiplier = 0.22
			var light: OmniLight3D = entry.sign_light
			if light != null and is_instance_valid(light):
				light.light_energy = 0.0


func litter_mix() -> Array:
	return [
		"paper", "cup", "can", "carton", "bag", "bottle", "can",
		"paper", "leaf", "cup", "bag", "can", "bottle_cap", "paper",
	]


func heavy_mix() -> Array:
	return ["crate", "barrel", "sack", "tyre", "planks", "sack"]


func pile_spots() -> Array:
	return [
		Vector3(-17.0, 0.0, -9.0),
		Vector3(7.0, 0.0, 11.0),
		Vector3(17.0, 0.0, 1.0),
	]


func crowd_points() -> Array:
	return [
		Vector3(-16.0, 0.0, 6.0), Vector3(-8.0, 0.0, 8.0), Vector3(2.0, 0.0, 4.0),
		Vector3(8.0, 0.0, 0.0), Vector3(-4.0, 0.0, -2.0), Vector3(16.0, 0.0, 4.0),
		Vector3(-18.0, 0.0, -2.0), Vector3(12.0, 0.0, 10.0), Vector3(-10.0, 0.0, -8.0),
		Vector3(6.0, 0.0, -10.0), Vector3(18.0, 0.0, 10.0), Vector3(-6.0, 0.0, 11.0),
	]


# ---------------------------------------------------------------- ground

func _build_ground() -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	add_child(ground)
	ground_mat = K.texture_material(_asphalt, Vector3(18, 14, 1), Color(0.62, 0.64, 0.74))
	K.plane(ground, Vector2(44, 34), Vector3(0, 0, 0), K.STONE, ground_mat)
	K.collider(ground, Vector3(44, 1, 34), Vector3(0, -0.5, 0))
	var apron_mat := K.material(Color(0.2, 0.2, 0.26))
	for piece in [
		{"size": Vector2(120, 24), "pos": Vector3(0, -0.06, -30.0)},
		{"size": Vector2(120, 24), "pos": Vector3(0, -0.06, 30.0)},
		{"size": Vector2(28, 80), "pos": Vector3(-36, -0.06, 0.0)},
		{"size": Vector2(28, 80), "pos": Vector3(36, -0.06, 0.0)},
	]:
		var apron := K.plane(ground, piece.size, piece.pos, K.STONE_DARK, apron_mat)
		apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var crossing := K.plane(ground, Vector2(10, 1.8), Vector3(0, 0.006, 5.4), K.STONE, K.texture_material(_stripe, Vector3(4, 1, 1)))
	crossing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------- buildings

func _build_north_row() -> void:
	# Arcade hall.
	_building(Vector3(-8.0, 0, -14.8), 14.0, 4.4, 6.5, Color(0.24, 0.22, 0.34), [-12.0, -4.0])
	# Ramen shop.
	_building(Vector3(4.5, 0, -14.9), 9.0, 4.2, 5.5, Color(0.3, 0.24, 0.3), [4.5])
	# Laundry tower.
	_building(Vector3(13.5, 0, -14.7), 8.0, 5.0, 7.0, Color(0.2, 0.28, 0.36), [13.5])
	# East block holding the plant gate.
	_building(Vector3(19.75, 0, -14.5), 4.5, 4.4, 4.5, Color(0.26, 0.26, 0.3), [19.75])
	_build_door(interiors[0], Color(0.85, 0.28, 0.62), "INSERT COIN")
	_build_door(interiors[1], Color(0.35, 0.75, 0.6), "STAFF ONLY")


func _building(center: Vector3, width: float, depth: float, height: float, color: Color, blockers: Array) -> void:
	var node := Node3D.new()
	node.position = center
	add_child(node)
	for bx in blockers:
		_block(Vector3(bx, 0, center.z), width / float(blockers.size()) * 0.52)
	K.box(node, Vector3(width, height, depth), Vector3(0, height / 2.0, 0), color)
	K.box(node, Vector3(width + 0.3, 0.3, depth + 0.3), Vector3(0, height + 0.12, 0), K.INK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.collider(node, Vector3(width, height, depth), Vector3(0, height / 2.0, 0))
	var cols := maxi(2, int(width / 3.0))
	for col in cols:
		var wx := -width * 0.36 + col * (width * 0.72 / maxi(1, cols - 1))
		for wy in [1.6, 3.4]:
			if wy > height - 1.2:
				continue
			var lit := (col + int(wy)) % 3 != 0
			var pane := K.quad(node, Vector2(0.9, 1.1), Vector3(wx, wy, depth / 2.0 + 0.02), Color(0.08, 0.1, 0.16) if not lit else Color(0.95, 0.7, 0.4))
			if lit:
				var mat := pane.material_override as StandardMaterial3D
				mat.emission_enabled = true
				mat.emission = Color(0.95, 0.62, 0.32) if wy < 3.0 else Color(0.45, 0.85, 0.95)
				mat.emission_energy_multiplier = 0.5
			pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_door(entry: Dictionary, accent: Color, sub: String) -> void:
	var pos: Vector3 = entry.pos
	var door := Node3D.new()
	door.position = pos
	add_child(door)
	_block(pos + Vector3(0, 0, 0.5), 1.1)
	K.box(door, Vector3(3.2, 2.7, 0.16), Vector3(0, 1.35, 0.02), K.INK)
	K.box(door, Vector3(2.4, 2.4, 0.2), Vector3(0, 1.2, 0.14), Color(0.14, 0.13, 0.2))
	for row in 2:
		for col in 2:
			K.box(door, Vector3(0.92, 0.78, 0.06), Vector3(-0.56 + col * 1.12, 0.72 + row * 1.0, 0.26), Color(0.2, 0.18, 0.28))
	var strip := K.box(door, Vector3(3.0, 0.14, 0.1), Vector3(0, 2.86, 0.12), Color.WHITE)
	strip.material_override = K.material(accent, 0.5, 0.0, accent, 1.6)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.label(door, str(entry.title), Vector3(0, 2.6, 0.2), 30, K.CREAM)
	K.label(door, sub, Vector3(0, 2.36, 0.2), 12, accent)
	var bulb := K.sphere(door, 0.09, Vector3(0, 3.06, 0.2), Color(1.0, 0.9, 0.7))
	var bulb_mat := K.material(Color(1.0, 0.9, 0.7), 0.6, 0.0, Color(1.0, 0.8, 0.5), 1.2)
	bulb.material_override = bulb_mat
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.9, 0.5)
	light.light_color = Color(1.0, 0.72, 0.5)
	light.light_energy = 0.8
	light.omni_range = 5.0
	door.add_child(light)
	K.collider(door, Vector3(3.1, 2.9, 0.4), Vector3(0, 1.45, 0.1))


func _build_cabinet_wall() -> void:
	var colors := [K.CORAL, K.TEAL, K.OCHRE, K.PLUM, Color(0.4, 0.8, 0.95), Color(0.9, 0.5, 0.8)]
	for i in 6:
		var x := -13.5 + i * 2.2
		_cabinet(Vector3(x, 0, -11.4), colors[i], i)
	var awning := K.box(self, Vector3(13.6, 0.1, 2.4), Vector3(-8.0, 2.9, -10.9), K.CREAM, Vector3(-0.16, 0, 0), K.texture_material(_stripe, Vector3(3.2, 1, 1)))
	awning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sx in [-14.2, -1.8]:
		K.cylinder(self, 0.07, 2.9, Vector3(sx, 1.45, -10.2), K.INK, Vector3.ZERO, 6)
		_block(Vector3(sx, 0, -10.2), 0.35)


func _cabinet(pos: Vector3, color: Color, index: int) -> void:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = PI
	add_child(node)
	_block(pos, 0.9)
	K.box(node, Vector3(1.0, 2.0, 0.8), Vector3(0, 1.0, 0), Color(0.14, 0.13, 0.2))
	K.box(node, Vector3(1.06, 0.2, 0.86), Vector3(0, 2.0, 0), color.darkened(0.3))
	K.box(node, Vector3(0.84, 0.6, 0.04), Vector3(0, 1.54, 0.42), K.INK)
	var screen := K.quad(node, Vector2(0.72, 0.48), Vector3(0, 1.54, 0.45), color)
	var screen_mat := K.material(color, 0.4, 0.0, color, 1.3)
	screen.material_override = screen_mat
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(node, Vector3(0.9, 0.24, 0.46), Vector3(0, 1.04, 0.44), Color(0.22, 0.2, 0.28))
	K.sphere(node, 0.05, Vector3(-0.16, 1.1, 0.5), K.CORAL).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.sphere(node, 0.05, Vector3(0.02, 1.1, 0.5), K.OCHRE).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.label(node, "GAME %d" % (index + 1), Vector3(0, 1.94, 0.45), 15, K.CREAM)
	K.collider(node, Vector3(1.0, 2.1, 0.9), Vector3(0, 1.05, 0))


func _build_south_row() -> void:
	# Noodle bar.
	var node := Node3D.new()
	node.position = Vector3(-12.0, 0, 15.0)
	add_child(node)
	_block(Vector3(-12.0, 0, 15.0), 5.4)
	K.box(node, Vector3(12.0, 4.8, 4.0), Vector3(0, 2.4, 0), Color(0.26, 0.3, 0.34))
	K.box(node, Vector3(12.4, 0.3, 4.4), Vector3(0, 4.9, 0), K.INK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.collider(node, Vector3(12.0, 4.8, 4.0), Vector3(0, 2.4, 0))
	var glow := K.quad(node, Vector2(8.0, 1.6), Vector3(0, 1.5, -2.03), Color(0.98, 0.8, 0.5))
	var glow_mat := glow.material_override as StandardMaterial3D
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.7, 0.38)
	glow_mat.emission_energy_multiplier = 0.55
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.label(node, "NOODLE BAR", Vector3(0, 3.6, -2.06), 44, K.CREAM, Vector3(0, PI, 0))
	# Pawn shop.
	node = Node3D.new()
	node.position = Vector3(-1.0, 0, 15.4)
	add_child(node)
	_block(Vector3(-1.0, 0, 15.4), 3.6)
	K.box(node, Vector3(8.0, 5.6, 3.2), Vector3(0, 2.8, 0), Color(0.32, 0.26, 0.24))
	K.box(node, Vector3(8.3, 0.3, 3.5), Vector3(0, 5.7, 0), K.INK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.collider(node, Vector3(8.0, 5.6, 3.2), Vector3(0, 2.8, 0))
	K.label(node, "PAWN", Vector3(0, 4.2, -1.64), 52, K.OCHRE, Vector3(0, PI, 0))


# ---------------------------------------------------------------- rooftop

func _build_rooftop() -> void:
	var node := Node3D.new()
	node.position = Vector3(14.0, 0, 12.5)
	add_child(node)
	_block(Vector3(14.0, 0, 12.5), 7.0)
	K.box(node, Vector3(12.0, 2.4, 7.0), Vector3(0, 1.2, 0), Color(0.28, 0.26, 0.36))
	K.box(node, Vector3(12.2, 0.18, 7.2), Vector3(0, 2.42, 0), Color(0.34, 0.32, 0.44))
	K.collider(node, Vector3(12.0, 2.4, 7.0), Vector3(0, 1.2, 0))
	# Railings with a gap at the west edge for the fire escape.
	for edge in [
		{"size": Vector3(0.12, 0.55, 7.0), "pos": Vector3(-5.95, 2.75, 0.0), "gap": true},
		{"size": Vector3(0.12, 0.55, 7.0), "pos": Vector3(5.95, 2.75, 0.0), "gap": false},
		{"size": Vector3(12.0, 0.55, 0.12), "pos": Vector3(0.0, 2.75, -3.45), "gap": false},
		{"size": Vector3(12.0, 0.55, 0.12), "pos": Vector3(0.0, 2.75, 3.45), "gap": false},
	]:
		if bool(edge.gap):
			for part in [-2.6, 2.6]:
				K.box(node, Vector3(0.12, 0.55, 1.8), Vector3(edge.pos.x, edge.pos.y, part), K.INK)
				K.collider(node, Vector3(0.12, 0.7, 1.8), Vector3(edge.pos.x, edge.pos.y, part))
			continue
		K.box(node, edge.size, edge.pos, K.INK)
		K.collider(node, edge.size + Vector3(0, 0.2, 0), edge.pos)
	# Roof clutter: AC unit, water tank, crates.
	K.box(node, Vector3(1.6, 0.9, 1.2), Vector3(-2.8, 2.9, -2.2), K.METAL)
	K.collider(node, Vector3(1.6, 0.9, 1.2), Vector3(-2.8, 2.9, -2.2))
	var tank := K.cylinder(node, 1.0, 1.6, Vector3(4.2, 3.2, -2.0), Color(0.36, 0.42, 0.5), Vector3.ZERO, 12)
	K.collider(node, Vector3(2.0, 1.6, 2.0), Vector3(4.2, 3.2, -2.0))
	tank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(node, Vector3(0.7, 0.5, 0.7), Vector3(-4.4, 2.7, 2.4), K.WOOD_DARK)
	K.box(node, Vector3(0.6, 0.4, 0.6), Vector3(-3.6, 2.65, 2.8), K.WOOD)
	# Pip's hideout.
	K.box(node, Vector3(2.6, 1.9, 2.0), Vector3(3.0, 3.35, 1.4), Color(0.32, 0.3, 0.44))
	K.box(node, Vector3(2.9, 0.22, 2.3), Vector3(3.0, 4.35, 1.4), K.INK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.collider(node, Vector3(2.6, 1.9, 2.0), Vector3(3.0, 3.35, 1.4))
	var window := K.quad(node, Vector2(0.9, 0.6), Vector3(3.0, 3.5, 0.38), Color(0.5, 0.9, 0.95))
	var window_mat := window.material_override as StandardMaterial3D
	window_mat.emission_enabled = true
	window_mat.emission = Color(0.45, 0.85, 0.95)
	window_mat.emission_energy_multiplier = 1.1
	window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rug := K.plane(node, Vector2(2.4, 1.6), Vector3(1.2, 2.53, 0.6), Color(0.5, 0.3, 0.5), K.clear_material(Color(0.6, 0.35, 0.6), 0.5))
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Antenna with a blinking beacon.
	K.cylinder(node, 0.04, 2.2, Vector3(5.2, 3.6, 2.7), K.INK, Vector3.ZERO, 5)
	_antenna_bulb = K.sphere(node, 0.09, Vector3(5.2, 4.75, 2.7), Color(1.0, 0.4, 0.5))
	_antenna_mat = K.material(Color(1.0, 0.4, 0.5), 0.5, 0.0, Color(1.0, 0.3, 0.4), 1.0)
	_antenna_bulb.material_override = _antenna_mat
	_antenna_bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# String lights along the north roof edge.
	for i in 9:
		var x := -5.0 + i * 1.25
		K.cylinder(node, 0.008, 0.3, Vector3(x, 3.2, -3.2), K.INK, Vector3.ZERO, 3).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bulb := K.sphere(node, 0.055, Vector3(x, 3.05, -3.2), [K.CORAL, K.TEAL, K.OCHRE][i % 3])
		bulb.material_override = K.material([K.CORAL, K.TEAL, K.OCHRE][i % 3], 0.5, 0.0, [K.CORAL, K.TEAL, K.OCHRE][i % 3], 1.4)
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Faint hotel sign on the west face.
	var hotel := K.quad(node, Vector2(1.0, 3.2), Vector3(-6.02, 1.5, 0.0), K.PLUM)
	var hotel_mat := hotel.material_override as StandardMaterial3D
	hotel_mat.emission_enabled = true
	hotel_mat.emission = K.PLUM
	hotel_mat.emission_energy_multiplier = 0.4
	hotel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hotel.rotation.y = -PI / 2.0


func _build_fire_escape() -> void:
	var steps := [
		{"top": 0.5, "pos": Vector3(6.9, 0.0, 14.6)},
		{"top": 0.95, "pos": Vector3(6.9, 0.0, 13.0)},
		{"top": 1.4, "pos": Vector3(6.9, 0.0, 14.6)},
		{"top": 1.85, "pos": Vector3(6.9, 0.0, 13.0)},
	]
	for step in steps:
		var top: float = step.top
		var pos: Vector3 = step.pos
		K.box(self, Vector3(1.7, 0.12, 1.7), Vector3(pos.x, top - 0.06, pos.z), K.METAL)
		K.collider(self, Vector3(1.7, 0.12, 1.7), Vector3(pos.x, top - 0.06, pos.z))
		for side in [-1.0, 1.0]:
			K.box(self, Vector3(0.06, 0.5, 1.7), Vector3(pos.x + side * 0.82, top + 0.22, pos.z), K.INK)
	# Ladder base post.
	K.cylinder(self, 0.06, 0.6, Vector3(6.9, 0.3, 15.6), K.METAL, Vector3.ZERO, 6)


# ---------------------------------------------------------------- street dressing

func _build_canopy() -> void:
	var roof := K.plane(self, Vector2(26.0, 11.0), Vector3(-4.0, 4.4, -1.0), Color(0.3, 0.5, 0.6), K.clear_material(Color(0.35, 0.55, 0.65), 0.16))
	roof.rotation.x = 0.02
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for px in [-16.0, 8.0]:
		for pz in [-6.0, 4.0]:
			K.cylinder(self, 0.09, 4.4, Vector3(px, 2.2, pz), K.INK, Vector3.ZERO, 6)
			_block(Vector3(px, 0, pz), 0.35)
	for px in [-16.0, 8.0]:
		K.box(self, Vector3(0.14, 0.14, 10.4), Vector3(px, 4.42, -1.0), K.INK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(self, Vector3(24.4, 0.14, 0.14), Vector3(-4.0, 4.42, -6.0), K.INK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(self, Vector3(24.4, 0.14, 0.14), Vector3(-4.0, 4.42, 4.0), K.INK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _neon_quad(parent: Node3D, size: Vector2, pos: Vector3, color: Color, energy: float, dropout := 0.0, rot := Vector3.ZERO) -> MeshInstance3D:
	var quad := K.quad(parent, size, pos, color, rot)
	var mat := ShaderMaterial.new()
	mat.shader = _neon_shader
	mat.set_shader_parameter("neon_colour", color)
	mat.set_shader_parameter("energy", energy)
	mat.set_shader_parameter("dropout", dropout)
	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	signs.append({"mat": mat, "base": energy})
	return quad


func _build_signs() -> void:
	# Arcade hall marquee.
	_neon_quad(self, Vector2(5.4, 1.15), Vector3(-8.0, 5.6, -12.52), Color(1.0, 0.32, 0.72), 1.8, 0.3)
	K.label(self, "NEON ARCADE", Vector3(-8.0, 5.6, -12.44), 46, K.CREAM)
	_neon_quad(self, Vector2(3.2, 0.7), Vector3(-8.0, 4.62, -12.52), Color(0.4, 0.85, 1.0), 1.5, 0.0)
	K.label(self, "OPEN ALL NIGHT", Vector3(-8.0, 4.62, -12.44), 22, K.CREAM)
	# Laundry tower.
	_neon_quad(self, Vector2(4.6, 1.0), Vector3(13.5, 5.6, -12.42), Color(0.5, 0.9, 1.0), 1.6, 0.15)
	K.label(self, "LAUNDRY", Vector3(13.5, 5.6, -12.34), 40, K.CREAM)
	# Ramen shop, warm and static.
	var ramen := K.quad(self, Vector2(3.6, 0.9), Vector3(4.5, 4.2, -12.72), Color(1.0, 0.62, 0.3))
	var ramen_mat := ramen.material_override as StandardMaterial3D
	ramen_mat.emission_enabled = true
	ramen_mat.emission = Color(1.0, 0.55, 0.25)
	ramen_mat.emission_energy_multiplier = 1.3
	ramen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.label(self, "RAMEN", Vector3(4.5, 4.2, -12.64), 38, K.CREAM)
	# Plant gate marker.
	var plant := K.quad(self, Vector2(2.6, 0.62), Vector3(19.5, 3.4, -12.22), Color(0.4, 0.9, 0.6))
	var plant_mat := plant.material_override as StandardMaterial3D
	plant_mat.emission_enabled = true
	plant_mat.emission = Color(0.35, 0.85, 0.55)
	plant_mat.emission_energy_multiplier = 1.0
	plant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.label(self, "PLANT GATE ->", Vector3(19.5, 3.4, -12.14), 24, K.CREAM)


func _build_cables() -> void:
	var spans := [
		{"a": Vector3(-13.0, 6.4, -12.6), "b": Vector3(-13.0, 4.9, 13.0)},
		{"a": Vector3(-6.0, 6.4, -12.6), "b": Vector3(-6.0, 5.6, 13.4)},
		{"a": Vector3(0.5, 5.4, -12.8), "b": Vector3(0.5, 5.7, 13.6)},
		{"a": Vector3(6.0, 5.4, -12.8), "b": Vector3(8.2, 2.9, 10.0)},
	]
	for span in spans:
		_cable(span.a, span.b)


func _cable(a: Vector3, b: Vector3) -> void:
	var segments := 9
	for i in segments:
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		var p0 := a.lerp(b, t0)
		var p1 := a.lerp(b, t1)
		p0.y -= sin(t0 * PI) * 0.8
		p1.y -= sin(t1 * PI) * 0.8
		var seg := K.cylinder(self, 0.016, p0.distance_to(p1), (p0 + p1) * 0.5, K.INK, Vector3.ZERO, 4)
		seg.look_at(p1, Vector3.UP)
		seg.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if a.x < 8.0 and absf(a.z - b.z) > 10.0:
		var mid := a.lerp(b, 0.5)
		mid.y -= sin(0.5 * PI) * 0.8
		var lantern := Node3D.new()
		lantern.position = mid
		add_child(lantern)
		K.cylinder(lantern, 0.008, 0.5, Vector3(0, -0.25, 0), K.INK, Vector3.ZERO, 3).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bulb := K.sphere(lantern, 0.12, Vector3(0, -0.55, 0), Color(1.0, 0.75, 0.4))
		bulb.material_override = K.material(Color(1.0, 0.75, 0.4), 0.5, 0.0, Color(1.0, 0.65, 0.3), 1.5)
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lanterns.append({"node": lantern, "phase": a.x})


func _build_pole_lamps() -> void:
	for spec in [
		{"pos": Vector3(-10.0, 0, 7.0), "flicker": true},
		{"pos": Vector3(6.0, 0, -8.0), "flicker": false},
	]:
		var pos: Vector3 = spec.pos
		var node := Node3D.new()
		node.position = pos
		add_child(node)
		_block(pos, 0.4)
		K.cylinder(node, 0.11, 3.8, Vector3(0, 1.9, 0), K.INK, Vector3.ZERO, 8)
		K.cylinder(node, 0.24, 0.18, Vector3(0, 0.12, 0), K.INK, Vector3.ZERO, 8)
		var head := K.box(node, Vector3(0.5, 0.24, 0.5), Vector3(0, 3.85, 0), K.INK)
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bulb := K.sphere(node, 0.14, Vector3(0, 3.72, 0), Color(0.75, 0.9, 1.0))
		var bulb_mat := K.material(Color(0.75, 0.9, 1.0), 0.4, 0.0, Color(0.6, 0.85, 1.0), 0.4)
		bulb.material_override = bulb_mat
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light := OmniLight3D.new()
		light.position = Vector3(0, 3.6, 0)
		light.light_color = Color(0.62, 0.85, 1.0)
		light.omni_range = 9.0
		light.light_energy = 0.0
		node.add_child(light)
		lamps.append({"bulb_mat": bulb_mat, "light": light, "base_energy": 0.0, "power": 1.5, "flicker": bool(spec.flicker)})


func _build_vents() -> void:
	for spec in [{"x": -12.0, "y": 6.5}, {"x": -8.5, "y": 6.5}, {"x": 13.5, "y": 7.0}]:
		var node := Node3D.new()
		node.position = Vector3(spec.x, spec.y, -15.4)
		add_child(node)
		K.box(node, Vector3(1.1, 0.7, 1.1), Vector3(0, 0.35, 0), K.METAL)
		var blades := Node3D.new()
		blades.position = Vector3(0, 0.72, 0)
		node.add_child(blades)
		for side in [-1.0, 1.0]:
			K.box(blades, Vector3(0.9, 0.04, 0.16), Vector3.ZERO, K.INK, Vector3(0, side * PI / 2.0, 0))
		K.cylinder(node, 0.5, 0.08, Vector3(0, 0.72, 0), K.INK, Vector3.ZERO, 12).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fans.append({"node": blades, "speed": 3.0 + float(int(spec.x) % 3)})


func _build_depot() -> void:
	var node := Node3D.new()
	node.position = Vector3(19.0, 0, 6.0)
	node.rotation.y = -PI / 2.0
	add_child(node)
	_block(Vector3(19.0, 0, 6.0), 2.6)
	K.box(node, Vector3(3.4, 1.0, 1.1), Vector3(0, 0.5, 0), K.WOOD_DARK)
	K.box(node, Vector3(3.6, 0.12, 1.3), Vector3(0, 1.04, 0), K.WOOD)
	K.collider(node, Vector3(3.6, 1.5, 1.4), Vector3(0, 0.75, 0))
	K.label(node, "NEON SORTING", Vector3(0, 1.9, 0), 30, K.CREAM, Vector3(0, PI / 2.0, 0), true)
	var names := ["GLASS", "METAL", "PAPER", "COMPOST"]
	var colors := [Color(0.32, 0.6, 0.55), K.METAL, Color(0.42, 0.55, 0.72), Color(0.45, 0.52, 0.29)]
	for i in 4:
		var z := -1.5 + i * 1.0
		K.box(node, Vector3(0.82, 1.25, 0.82), Vector3(0.4, 0.62, z), colors[i])
		K.box(node, Vector3(0.9, 0.16, 0.9), Vector3(0.4, 1.3, z), colors[i].darkened(0.2))
		K.label(node, names[i], Vector3(0.86, 1.8, z), 20, K.CREAM, Vector3(0, PI / 2.0, 0), true)
	stations = [{"pos": Vector3(19.0, 0, 6.0), "label": "NEON SORTING"}]


func _build_skip() -> void:
	var node := Node3D.new()
	node.position = skip_pos
	node.rotation.y = 0.4
	add_child(node)
	_block(skip_pos, 2.0)
	K.box(node, Vector3(3.0, 1.1, 1.6), Vector3(0, 0.55, 0), Color(0.5, 0.28, 0.2))
	K.box(node, Vector3(3.2, 0.16, 1.8), Vector3(0, 1.16, 0), Color(0.4, 0.22, 0.16))
	K.box(node, Vector3(2.6, 0.5, 1.2), Vector3(0, 0.9, 0), Color(0.16, 0.15, 0.14))
	K.collider(node, Vector3(3.0, 1.3, 1.6), Vector3(0, 0.65, 0))
	K.label(node, "SKIP", Vector3(0, 0.7, 0.95), 26, K.CREAM)


func _build_slip_puddles() -> void:
	for item in [
		{"pos": Vector3(-6.0, 0, 2.0), "r": 1.1},
		{"pos": Vector3(8.0, 0, 6.0), "r": 1.0},
		{"pos": Vector3(-18.0, 0, -8.0), "r": 1.2},
		{"pos": Vector3(12.0, 0, 0.0), "r": 0.9},
	]:
		var pos: Vector3 = item.pos
		var radius: float = item.r
		var node := Node3D.new()
		node.position = pos + Vector3(0, 0.02, 0)
		add_child(node)
		var disc := K.plane(node, Vector2(radius * 2.1, radius * 1.5), Vector3.ZERO, Color(0.3, 0.4, 0.52), K.clear_material(Color(0.36, 0.5, 0.66), 0.34))
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puddles.append({"pos": pos, "radius": radius, "node": node})


func _build_electric_puddles() -> void:
	for spec in [
		{"pos": Vector3(-14.0, 0, -4.0), "sign": Vector3(-15.3, 0, -5.4)},
		{"pos": Vector3(2.0, 0, 8.0), "sign": Vector3(3.3, 0, 9.4)},
		{"pos": Vector3(16.0, 0, -2.0), "sign": Vector3(17.3, 0, -3.4)},
	]:
		var pos: Vector3 = spec.pos
		var sign_pos: Vector3 = spec.sign
		var node := Node3D.new()
		node.position = pos + Vector3(0, 0.025, 0)
		add_child(node)
		var disc := K.plane(node, Vector2(2.6, 1.9), Vector3.ZERO, Color(0.3, 0.44, 0.6), K.clear_material(Color(0.36, 0.55, 0.75), 0.4))
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Crackle burst, hidden until the puddle goes live.
		var sparks := Node3D.new()
		sparks.position = pos + Vector3(0, 0.3, 0)
		add_child(sparks)
		for i in 3:
			var flash := K.quad(sparks, Vector2(0.7, 0.7), Vector3.ZERO, Color(0.6, 0.95, 1.0), Vector3(0, i * PI / 3.0, 0))
			flash.material_override = K.clear_material(Color(0.6, 0.95, 1.0), 0.7, true)
			flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sparks.visible = false
		electric_puddles.append({
			"pos": pos, "radius": 1.25, "sign": sign_pos, "sparks": sparks,
			"lamp": null, "sign_light": null, "hazard": true, "active": false,
			"was_live": false, "crackle": 0.4,
		})
		_build_shorting_sign(sign_pos, pos)


func _build_shorting_sign(sign_pos: Vector3, puddle_pos: Vector3) -> void:
	var node := Node3D.new()
	node.position = sign_pos
	add_child(node)
	var toward := (puddle_pos - sign_pos).normalized()
	node.rotation.y = atan2(toward.x, toward.z)
	_block(sign_pos, 0.5)
	K.cylinder(node, 0.07, 2.6, Vector3(0, 1.3, 0), K.METAL, Vector3(0.06, 0, -0.1), 6)
	var box := K.box(node, Vector3(0.6, 0.8, 0.3), Vector3(0, 2.2, 0.1), Color(0.24, 0.26, 0.3))
	box.rotation.z = 0.14
	K.collider(node, Vector3(0.7, 2.6, 0.5), Vector3(0, 1.3, 0))
	var lamp := K.sphere(node, 0.09, Vector3(0.0, 1.72, 0.16), Color(0.6, 0.95, 1.0))
	lamp.material_override = K.material(Color(0.6, 0.95, 1.0), 0.4, 0.0, Color(0.5, 0.9, 1.0), 0.9)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.8, 0.3)
	light.light_color = Color(0.55, 0.9, 1.0)
	light.omni_range = 5.0
	light.light_energy = 0.0
	node.add_child(light)
	# Remember the lamp and light on the matching puddle entry.
	for entry in electric_puddles:
		if Vector2(entry.pos.x - puddle_pos.x, entry.pos.z - puddle_pos.z).length() < 0.1:
			entry.lamp = lamp
			entry.sign_light = light
			break


func _build_bounds() -> void:
	var walls := [
		{"size": Vector3(1, 4, 34), "pos": Vector3(-22, 2, 0)},
		{"size": Vector3(1, 4, 34), "pos": Vector3(22, 2, 0)},
		{"size": Vector3(45, 4, 1), "pos": Vector3(0, 2, -17.6)},
		{"size": Vector3(45, 4, 1), "pos": Vector3(0, 2, 17.6)},
	]
	for wall in walls:
		K.collider(self, wall.size, wall.pos)
