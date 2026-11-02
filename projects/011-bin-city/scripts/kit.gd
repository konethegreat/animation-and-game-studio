extends RefCounted

# Shared palette and geometry helpers. Everything in BIN CITY is built from
# primitives at load time, so the web package stays small and every shape is
# readable in source.

const CREAM := Color(0.973, 0.945, 0.898)
const PAPER := Color(0.906, 0.867, 0.792)
const INK := Color(0.129, 0.118, 0.106)
const CORAL := Color(0.886, 0.333, 0.196)
const TEAL := Color(0.227, 0.522, 0.482)
const TEAL_DARK := Color(0.145, 0.353, 0.341)
const OCHRE := Color(0.878, 0.639, 0.239)
const OLIVE := Color(0.416, 0.475, 0.282)
const PLUM := Color(0.443, 0.318, 0.459)
const BRICK := Color(0.702, 0.333, 0.259)
const WOOD := Color(0.596, 0.412, 0.267)
const WOOD_DARK := Color(0.373, 0.243, 0.157)
const STONE := Color(0.757, 0.706, 0.616)
const STONE_DARK := Color(0.588, 0.541, 0.463)
const WATER := Color(0.204, 0.435, 0.435)
const GLASS := Color(0.373, 0.647, 0.573)
const METAL := Color(0.706, 0.722, 0.714)
const COMPOST := Color(0.463, 0.525, 0.294)

static var _materials: Dictionary = {}
static var _toon_shader: Shader = null
static var _outline_shader: Shader = null
static var _toon_materials: Dictionary = {}
static var _outline_materials: Dictionary = {}


static func toon_material(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if _toon_materials.has(key):
		return _toon_materials[key]
	if _toon_shader == null:
		_toon_shader = load("res://shaders/toon.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = _toon_shader
	mat.set_shader_parameter("albedo", color)
	_toon_materials[key] = mat
	return mat


static func outline_material(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if _outline_materials.has(key):
		return _outline_materials[key]
	if _outline_shader == null:
		_outline_shader = load("res://shaders/outline.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = _outline_shader
	mat.set_shader_parameter("ink", color)
	_outline_materials[key] = mat
	return mat


static func outline_mesh(mesh_instance: MeshInstance3D, thickness := 0.02, color := Color(0.16, 0.13, 0.11)) -> MeshInstance3D:
	var hull := MeshInstance3D.new()
	hull.name = "Outline"
	hull.mesh = mesh_instance.mesh
	hull.material_override = outline_material(color)
	hull.scale = Vector3.ONE * (1.0 + thickness)
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.add_child(hull)
	return hull


# Convert a built character or prop to the toon look. Only plain opaque
# standard materials are swapped; textured, additive and glowing materials
# keep their own look. With thickness above zero every swapped mesh also
# grows an inverted hull outline.
static func apply_toon(node: Node3D, thickness := 0.0, skip: Array = []) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mat: Material = child.material_override
			if mat is StandardMaterial3D:
				var std := mat as StandardMaterial3D
				var convertible := std.albedo_texture == null and std.albedo_color.a >= 0.99
				convertible = convertible and std.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
				convertible = convertible and std.emission_energy_multiplier < 0.25
				convertible = convertible and not skip.has(std)
				if convertible:
					child.material_override = toon_material(std.albedo_color)
					if thickness > 0.0:
						outline_mesh(child, thickness)
		if child is Node3D:
			apply_toon(child, thickness, skip)


static func material(color: Color, roughness := 0.92, metallic := 0.0, emission := Color(0, 0, 0), energy := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s|%.2f" % [color.to_html(), roughness, metallic, emission.to_html(), energy]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	if emission != Color(0, 0, 0) or energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	_materials[key] = mat
	return mat


static func clear_material(color: Color, alpha := 0.28, additive := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return mat


static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO, mat: Material = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat if mat else material(color)
	node.position = pos
	node.rotation = rot
	parent.add_child(node)
	return node


static func cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, rot := Vector3.ZERO, sides := 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	node.rotation = rot
	parent.add_child(node)
	return node


static func cone(parent: Node3D, top_radius: float, bottom_radius: float, height: float, pos: Vector3, color: Color, rot := Vector3.ZERO, sides := 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	node.rotation = rot
	parent.add_child(node)
	return node


static func sphere(parent: Node3D, radius: float, pos: Vector3, color: Color, scale := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	node.scale = scale
	parent.add_child(node)
	return node


static func plane(parent: Node3D, size: Vector2, pos: Vector3, color: Color, mat: Material = null) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat if mat else material(color)
	node.position = pos
	parent.add_child(node)
	return node


static func quad(parent: Node3D, size: Vector2, pos: Vector3, color: Color, rot := Vector3.ZERO, double_sided := true) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat := material(color).duplicate() as StandardMaterial3D
	if double_sided:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	node.position = pos
	node.rotation = rot
	parent.add_child(node)
	return node


static func torus(parent: Node3D, inner: float, outer: float, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 16
	mesh.ring_segments = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	node.rotation = rot
	parent.add_child(node)
	return node


static func label(parent: Node3D, text: String, pos: Vector3, size := 64, color := CREAM, rot := Vector3.ZERO, billboard := false) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.font_size = size
	node.pixel_size = 0.005
	node.modulate = color
	node.outline_size = 14
	node.outline_modulate = INK
	node.position = pos
	node.rotation = rot
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard else BaseMaterial3D.BILLBOARD_DISABLED
	node.double_sided = true
	node.no_depth_test = false
	node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	parent.add_child(node)
	return node


static func collider(parent: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)
	return body


static func keep_on_ground(parent: Node3D, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)
	parent.add_child(body)


static func make_cobble() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	img.fill(Color(0.27, 0.26, 0.24))
	var cells := 8
	var cell := 256 / cells
	for cy in cells:
		for cx in cells:
			var base := 0.4 + rng.randf() * 0.13
			var warm := rng.randf() * 0.06
			var tilt := rng.randf_range(-0.02, 0.02)
			var x0 := cx * cell + rng.randi_range(2, 4)
			var y0 := cy * cell + rng.randi_range(2, 4)
			var w := cell - rng.randi_range(4, 7)
			var h := cell - rng.randi_range(4, 7)
			# Two soft pits per tile keep the slab from reading as flat paint.
			var pits := []
			for i in 2:
				pits.append(Vector3(rng.randf_range(x0, x0 + w), rng.randf_range(y0, y0 + h), rng.randf_range(0.025, 0.05)))
			for y in range(y0, min(y0 + h, 256)):
				for x in range(x0, min(x0 + w, 256)):
					var n := rng.randf_range(-0.02, 0.02)
					var shade := 0.0
					for p in pits:
						var d := Vector2(x - p.x, y - p.y).length()
						shade += p.z * (1.0 - clampf(d / 9.0, 0.0, 1.0))
					var v := base + n + warm - shade + tilt * (float(y - y0) / float(h))
					img.set_pixel(x, y, Color(v + 0.01, v * 0.96, v * 0.9))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func make_stripes(a: Color, b: Color, count := 8) -> ImageTexture:
	var img := Image.create(128, 64, false, Image.FORMAT_RGB8)
	var width := 128 / count
	for y in 64:
		for x in 128:
			img.set_pixel(x, y, a if (x / width) % 2 == 0 else b)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func texture_material(texture: Texture2D, scale := Vector3(1, 1, 1), color := Color.WHITE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.texture_repeat = true
	mat.uv1_scale = scale
	return mat


static func color_lerp(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0.0, 1.0))
