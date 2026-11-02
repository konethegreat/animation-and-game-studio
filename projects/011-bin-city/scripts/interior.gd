extends "res://scripts/district.gd"

# Every interior is the same shell with a different life inside it. Rooms are
# built at a far offset so the outdoor district can be hidden without moving
# a single collider.

const ROOM := Rect2(-9.0, -7.0, 18.0, 14.0)
const WALL_HEIGHT := 4.4
const DOOR_GAP := 4.0

var kind := "depot"
var greeting := ""
var exit_pos := Vector3(0.0, 0.0, 5.7)
var save_pos := Vector3.ZERO
var has_save := false
var practicals: Array[Dictionary] = []
var _time := 0.0


func setup(id: String) -> void:
	kind = id
	mood = "interior"
	has_save = id == "depot"
	save_pos = Vector3(-7.0, 0.0, 2.9)
	match kind:
		"bakery":
			title = "THE BAKERY"
			greeting = "The night oven is still warm. The baker is not."
		"boathouse":
			title = "THE BOATHOUSE"
			greeting = "Rope, tar and river air. Somebody left a lamp on."
		"arcade":
			title = "NEON ARCADE"
			greeting = "Six cabinets, one working high score, and a carpet that hums."
		"plant":
			title = "THE PLANT"
			greeting = "Pipes tick overhead. The city drinks here and never says thanks."
		_:
			title = "BUREAU DEPOT"
			greeting = "Nell has the kettle on and the rank board freshly dusted."


func _ready() -> void:
	bounds = ROOM
	spawn = Vector3(0.0, 0.0, 2.6)
	exit_pos = Vector3(0.0, 0.0, 5.7)
	skip_pos = Vector3(0.0, 0.0, -400.0)
	music = "market"
	ambience = "interior"
	_build_shell()
	match kind:
		"bakery":
			_build_bakery()
		"boathouse":
			_build_boathouse()
		"arcade":
			_build_arcade()
		"plant":
			_build_plant()
		_:
			_build_depot()
	_build_door()


func _process(delta: float) -> void:
	_time += delta
	for item in practicals:
		var light: OmniLight3D = item.light
		if light != null:
			light.light_energy = float(item.base) * (0.95 + 0.05 * sin(_time * 2.1 + float(item.phase)))


func set_clean(value: float) -> void:
	clean_level = clampf(value, 0.0, 1.0)


func crowd_points() -> Array:
	match kind:
		"bakery":
			return [Vector3(-6.2, 0.0, 1.6), Vector3(5.8, 0.0, 2.2), Vector3(-2.4, 0.0, 4.2)]
		"boathouse":
			return [Vector3(-6.4, 0.0, 2.0), Vector3(6.0, 0.0, -1.4), Vector3(2.4, 0.0, 4.4)]
		"arcade":
			return [Vector3(-6.0, 0.0, 0.4), Vector3(-2.2, 0.0, 0.4), Vector3(5.8, 0.0, 2.6)]
		"plant":
			return [Vector3(-5.8, 0.0, 2.2), Vector3(5.6, 0.0, 3.0), Vector3(-1.2, 0.0, 4.4)]
	return [Vector3(-6.2, 0.0, 1.8), Vector3(6.2, 0.0, 1.4), Vector3(-2.8, 0.0, -2.4), Vector3(4.4, 0.0, 3.6)]


# ---------------------------------------------------------------- shell

func _wall_color() -> Color:
	match kind:
		"bakery":
			return Color(0.85, 0.72, 0.55)
		"boathouse":
			return Color(0.48, 0.55, 0.53)
		"arcade":
			return Color(0.26, 0.22, 0.34)
		"plant":
			return Color(0.6, 0.62, 0.56)
	return Color(0.78, 0.75, 0.65)


func _floor_color() -> Color:
	match kind:
		"arcade":
			return Color(0.18, 0.16, 0.22)
		"bakery":
			return Color(0.54, 0.41, 0.29)
		"boathouse":
			return Color(0.38, 0.36, 0.31)
		"plant":
			return Color(0.45, 0.46, 0.43)
	return Color(0.47, 0.38, 0.29)


func _build_shell() -> void:
	var wall := _wall_color()
	var floor_color := _floor_color()
	var boards := K.make_stripes(floor_color.lightened(0.05), floor_color.darkened(0.07), 10)
	var floor_mat := K.texture_material(boards, Vector3(5, 1, 1), Color(1.0, 0.98, 0.94))
	var floor_mesh := K.plane(self, Vector2(ROOM.size.x, ROOM.size.y), Vector3.ZERO, floor_color, floor_mat)
	floor_mesh.name = "Floor"
	K.collider(self, Vector3(ROOM.size.x, 1.0, ROOM.size.y), Vector3(0, -0.5, 0))

	var walls := Node3D.new()
	walls.name = "Walls"
	add_child(walls)
	K.box(walls, Vector3(ROOM.size.x + 0.4, WALL_HEIGHT, 0.4), Vector3(0, WALL_HEIGHT / 2.0, -7.0), wall)
	K.box(walls, Vector3(0.4, WALL_HEIGHT, ROOM.size.y + 0.4), Vector3(-9.0, WALL_HEIGHT / 2.0, 0), wall)
	K.box(walls, Vector3(0.4, WALL_HEIGHT, ROOM.size.y + 0.4), Vector3(9.0, WALL_HEIGHT / 2.0, 0), wall)
	var side_width := (ROOM.size.x - DOOR_GAP + 0.4) / 2.0
	K.box(walls, Vector3(side_width, WALL_HEIGHT, 0.4), Vector3(-(DOOR_GAP + side_width) / 2.0, WALL_HEIGHT / 2.0, 7.0), wall)
	K.box(walls, Vector3(side_width, WALL_HEIGHT, 0.4), Vector3((DOOR_GAP + side_width) / 2.0, WALL_HEIGHT / 2.0, 7.0), wall)
	K.box(walls, Vector3(DOOR_GAP, WALL_HEIGHT - 3.2, 0.4), Vector3(0, 3.2 + (WALL_HEIGHT - 3.2) / 2.0, 7.0), wall.darkened(0.05))

	var ceiling := K.box(walls, Vector3(ROOM.size.x + 0.4, 0.3, ROOM.size.y + 0.4), Vector3(0, WALL_HEIGHT + 0.15, 0), wall.darkened(0.52))
	ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	K.collider(walls, Vector3(ROOM.size.x + 0.4, WALL_HEIGHT, 0.5), Vector3(0, WALL_HEIGHT / 2.0, -7.0))
	K.collider(walls, Vector3(0.5, WALL_HEIGHT, ROOM.size.y + 0.4), Vector3(-9.0, WALL_HEIGHT / 2.0, 0))
	K.collider(walls, Vector3(0.5, WALL_HEIGHT, ROOM.size.y + 0.4), Vector3(9.0, WALL_HEIGHT / 2.0, 0))
	K.collider(walls, Vector3(side_width, WALL_HEIGHT, 0.5), Vector3(-(DOOR_GAP + side_width) / 2.0, WALL_HEIGHT / 2.0, 7.0))
	K.collider(walls, Vector3(side_width, WALL_HEIGHT, 0.5), Vector3((DOOR_GAP + side_width) / 2.0, WALL_HEIGHT / 2.0, 7.0))
	K.collider(walls, Vector3(ROOM.size.x + 0.4, 0.3, ROOM.size.y + 0.4), Vector3(0, WALL_HEIGHT + 0.15, 0))

	# Skirting keeps the room from reading as five flat planes.
	var trim := wall.lightened(0.18)
	for strip in [
		{"size": Vector3(17.8, 0.22, 0.1), "pos": Vector3(0, 0.11, -6.78)},
		{"size": Vector3(0.1, 0.22, 13.8), "pos": Vector3(-8.78, 0.11, 0)},
		{"size": Vector3(0.1, 0.22, 13.8), "pos": Vector3(8.78, 0.11, 0)},
	]:
		var box := K.box(walls, strip.size, strip.pos, trim)
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Two high windows per side wall, lit from nowhere in particular.
	for side in [-1.0, 1.0]:
		for z in [-3.4, 2.6]:
			var x: float = side * 8.77
			var frame := K.box(walls, Vector3(0.1, 1.5, 1.7), Vector3(x, 3.0, z), K.INK)
			frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var pane := K.quad(walls, Vector2(1.42, 1.22), Vector3(x - side * 0.07, 3.0, z), Color(0.94, 0.82, 0.6), Vector3(0, -side * PI / 2.0, 0))
			pane.material_override = _glow_mat(Color(0.92, 0.78, 0.56), 0.6)
			pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			K.box(walls, Vector3(0.08, 0.06, 1.5), Vector3(x - side * 0.09, 3.0, z), K.INK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_door() -> void:
	var door := Node3D.new()
	door.name = "ExitDoor"
	door.position = Vector3(0, 0, 7.02)
	add_child(door)
	K.box(door, Vector3(4.7, 0.34, 0.44), Vector3(0, 3.5, 0), K.WOOD_DARK)
	for side in [-1.0, 1.0]:
		K.box(door, Vector3(0.3, 3.3, 0.4), Vector3(side * 2.15, 1.65, 0), K.WOOD_DARK)
		K.box(door, Vector3(0.7, 0.18, 0.9), Vector3(side * 2.15, 0.09, 0.2), K.STONE)
	K.box(door, Vector3(3.9, 3.2, 0.22), Vector3(0, 1.6, 0.06), K.WOOD)
	for row in 2:
		for col in 2:
			K.box(door, Vector3(1.35, 1.0, 0.06), Vector3(-0.85 + col * 1.7, 0.95 + row * 1.3, -0.08), K.WOOD_DARK)
	K.cylinder(door, 0.06, 0.1, Vector3(1.45, 1.45, -0.16), K.OCHRE, Vector3(PI / 2, 0, 0), 10)
	K.box(door, Vector3(2.6, 0.44, 0.1), Vector3(0, 3.72, -0.16), K.INK)
	K.label(door, "EXIT", Vector3(0, 3.72, -0.24), 32, K.CREAM, Vector3(0, PI, 0))
	K.collider(door, Vector3(4.2, 3.3, 0.5), Vector3(0, 1.6, 0.06))
	_practical(Vector3(0, 3.28, 6.55), Color(1.0, 0.78, 0.48), 1.7, 6.0, "shade")


# ---------------------------------------------------------------- depot

func _build_depot() -> void:
	_counter(Vector3(-0.8, 0, -4.6), Vector2(7.6, 1.2), K.WOOD_DARK)
	K.box(self, Vector3(7.4, 0.1, 1.25), Vector3(-0.8, 1.16, -4.6), K.WOOD)
	K.box(self, Vector3(0.5, 0.34, 0.4), Vector3(-3.6, 1.38, -4.7), Color(0.34, 0.35, 0.32))
	K.box(self, Vector3(0.42, 0.08, 0.36), Vector3(-3.6, 1.59, -4.7), K.CREAM)
	K.cylinder(self, 0.06, 0.34, Vector3(-1.0, 1.38, -4.5), K.METAL, Vector3.ZERO, 8)
	K.sphere(self, 0.16, Vector3(-1.0, 1.6, -4.5), K.TEAL, Vector3(1, 0.6, 1))
	K.box(self, Vector3(0.6, 0.3, 0.5), Vector3(1.4, 1.36, -4.6), K.INK)
	K.quad(self, Vector2(0.42, 0.2), Vector3(1.4, 1.38, -4.29), Color(0.7, 0.92, 0.7)).material_override = _glow_mat(Color(0.5, 0.95, 0.6), 0.9)
	K.label(self, "FRONT DESK", Vector3(-0.8, 0.66, -3.98), 24, K.CREAM)
	_block(Vector3(-0.8, 0, -4.6), 4.0)

	_rank_board(Vector3(0, 0, -6.74))
	_shelf_unit(Vector3(-8.25, 0, -2.6), PI / 2.0, 3.2, 2.7)
	_shelf_unit(Vector3(-8.25, 0, 1.4), PI / 2.0, 3.2, 2.7)
	_bins(Vector3(6.7, 0, -3.9))
	_save_table(Vector3(-7.0, 0, 3.7))
	_crate(Vector3(-6.6, 0, 0.2), Vector3(1.1, 0.9, 1.0), 0.2)
	_crate(Vector3(-5.6, 0, 0.9), Vector3(0.8, 0.6, 0.8), -0.3)
	_crate(Vector3(4.4, 0, 3.9), Vector3(1.2, 1.0, 1.1), 0.5)
	_poster(Vector3(8.76, 2.4, 1.6), -PI / 2.0, "BAG IT\nSORT IT\nLOG IT", K.TEAL)
	_poster(Vector3(-4.9, 2.4, -6.72), 0.0, "NO\nSKIPPING", K.CORAL)
	_plant(Vector3(-7.9, 0, 5.6))
	_practical(Vector3(-4.2, 3.75, -1.6), Color(1.0, 0.82, 0.56), 1.9, 8.0)
	_practical(Vector3(3.8, 3.75, -1.6), Color(1.0, 0.82, 0.56), 1.9, 8.0)
	_practical(Vector3(0, 3.75, 4.4), Color(1.0, 0.86, 0.62), 1.6, 7.0)

	stations = [{"pos": Vector3(-0.8, 0, -3.1), "label": "THE FRONT DESK"}]


func _rank_board(pos: Vector3) -> void:
	var board := Node3D.new()
	board.position = pos
	add_child(board)
	K.box(board, Vector3(5.4, 3.0, 0.16), Vector3(0, 2.7, 0), K.WOOD_DARK)
	K.box(board, Vector3(5.0, 2.64, 0.08), Vector3(0, 2.7, 0.1), K.CREAM)
	K.label(board, "THE RANK BOARD", Vector3(0, 3.82, 0.18), 30, K.INK)
	var rows := [
		"1   STREET SWEEPER",
		"2   BAG BARON",
		"3   SCRAP KNIGHT",
		"4   RECYCLORD",
		"5   COSMIC CUSTODIAN",
	]
	for i in rows.size():
		K.label(board, rows[i], Vector3(0, 3.36 - i * 0.4, 0.18), 22, K.INK)
	for i in 4:
		var marker: Color = [K.CORAL, K.OCHRE, K.TEAL, K.PLUM][i]
		K.box(board, Vector3(0.24, 0.24, 0.06), Vector3(2.16, 3.36 - i * 0.4, 0.18), marker)
		K.box(board, Vector3(4.4, 0.03, 0.03), Vector3(0, 3.16 - i * 0.4, 0.16), K.STONE_DARK)


func _counter(pos: Vector3, size: Vector2, color: Color) -> void:
	K.box(self, Vector3(size.x, 1.05, size.y), pos + Vector3(0, 0.52, 0), color)
	K.box(self, Vector3(size.x + 0.2, 0.12, size.y + 0.2), pos + Vector3(0, 1.1, 0), color.lightened(0.18))
	for i in int(size.x / 1.4):
		K.box(self, Vector3(1.0, 0.5, 0.05), pos + Vector3(-size.x / 2.0 + 0.75 + i * 1.4, 0.52, size.y / 2.0 + 0.02), color.darkened(0.18))
	K.collider(self, Vector3(size.x, 1.1, size.y), pos + Vector3(0, 0.55, 0))


func _shelf_unit(pos: Vector3, rot: float, width: float, height: float) -> void:
	var unit := Node3D.new()
	unit.position = pos
	unit.rotation.y = rot
	add_child(unit)
	_block(pos, width * 0.45)
	var deck := K.WOOD_DARK
	for side in [-1.0, 1.0]:
		K.box(unit, Vector3(0.1, height, 0.5), Vector3(side * width / 2.0, height / 2.0, 0), deck)
	for i in 4:
		K.box(unit, Vector3(width, 0.08, 0.55), Vector3(0, 0.4 + i * (height - 0.6) / 3.0, 0), K.WOOD)
	K.collider(unit, Vector3(width, height, 0.6), Vector3(0, height / 2.0, 0))
	var palette := [K.CORAL, K.TEAL, K.OCHRE, K.PLUM, K.OLIVE]
	for row in 3:
		for col in 4:
			if (row + col) % 3 == 0:
				continue
			var y := 0.58 + row * (height - 0.6) / 3.0
			var x := -width / 2.0 + 0.45 + col * (width - 0.9) / 3.0
			var color: Color = palette[(row * 2 + col) % palette.size()]
			if (row + col) % 2 == 0:
				K.box(unit, Vector3(0.42, 0.36, 0.4), Vector3(x, y + 0.18, 0), color)
			else:
				K.cylinder(unit, 0.14, 0.36, Vector3(x, y + 0.18, 0), color, Vector3.ZERO, 8)


func _bins(pos: Vector3) -> void:
	var node := Node3D.new()
	node.position = pos
	add_child(node)
	_block(pos, 2.4)
	K.box(node, Vector3(4.6, 0.08, 1.1), Vector3(0, 1.36, 0), K.WOOD_DARK)
	for side in [-1.0, 1.0]:
		K.box(node, Vector3(0.12, 1.4, 0.12), Vector3(side * 2.2, 0.7, 0.42), K.WOOD_DARK)
	var names := ["GLASS", "METAL", "PAPER", "COMPOST"]
	var colors := [K.GLASS, K.METAL, K.PAPER, K.COMPOST]
	for i in 4:
		var x := -1.5 + i * 1.0
		var color: Color = colors[i]
		K.box(node, Vector3(0.78, 1.1, 0.78), Vector3(x, 0.55, 0), color)
		K.box(node, Vector3(0.86, 0.14, 0.86), Vector3(x, 1.16, 0), color.darkened(0.2))
		K.box(node, Vector3(0.56, 0.07, 0.18), Vector3(x, 1.05, 0.4), K.INK)
		K.label(node, names[i], Vector3(x, 1.68, 0.46), 22, K.CREAM)
	K.collider(node, Vector3(4.6, 1.2, 1.0), Vector3(0, 0.6, 0))


func _save_table(pos: Vector3) -> void:
	var node := Node3D.new()
	node.position = pos
	add_child(node)
	_block(pos, 1.4)
	K.box(node, Vector3(1.8, 0.8, 0.9), Vector3(0, 0.4, 0), K.WOOD_DARK)
	K.box(node, Vector3(1.9, 0.08, 1.0), Vector3(0, 0.84, 0), K.WOOD)
	K.box(node, Vector3(0.54, 0.3, 0.26), Vector3(-0.3, 1.05, 0.0), Color(0.36, 0.3, 0.24))
	K.box(node, Vector3(0.42, 0.18, 0.04), Vector3(-0.3, 1.06, 0.14), Color(0.55, 0.48, 0.36))
	var dial := K.cylinder(node, 0.09, 0.03, Vector3(0.02, 1.05, 0.14), Color(0.9, 0.78, 0.5), Vector3(PI / 2, 0, 0), 10)
	dial.material_override = _glow_mat(Color(1.0, 0.78, 0.4), 1.2)
	K.box(node, Vector3(0.62, 0.4, 0.08), Vector3(0.55, 1.1, 0.18), K.INK)
	K.label(node, "SAVE\nSHIFT", Vector3(0.55, 1.14, 0.23), 18, K.CREAM)
	K.cylinder(node, 0.015, 0.5, Vector3(0.14, 1.34, 0), K.OCHRE, Vector3.ZERO, 4)
	K.box(node, Vector3(1.1, 0.06, 0.5), Vector3(0, 0.86, 0.72), K.CREAM)
	K.collider(node, Vector3(1.9, 0.9, 1.0), Vector3(0, 0.45, 0))


func _crate(pos: Vector3, size: Vector3, rot: float) -> void:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = rot
	add_child(node)
	_block(pos, size.x * 0.6)
	K.box(node, size, Vector3(0, size.y / 2.0, 0), K.WOOD)
	K.box(node, Vector3(size.x + 0.04, 0.09, size.z + 0.04), Vector3(0, size.y * 0.72, 0), K.WOOD_DARK)
	K.box(node, Vector3(size.x + 0.04, 0.09, size.z + 0.04), Vector3(0, size.y * 0.26, 0), K.WOOD_DARK)
	K.collider(node, size, Vector3(0, size.y / 2.0, 0))


func _poster(pos: Vector3, rot: float, text: String, color: Color) -> void:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = rot
	add_child(node)
	K.box(node, Vector3(1.5, 1.9, 0.06), Vector3.ZERO, K.CREAM)
	K.box(node, Vector3(1.36, 0.14, 0.04), Vector3(0, 0.78, 0.05), color)
	K.label(node, text, Vector3(0, 0.1, 0.05), 26, K.INK, Vector3.ZERO, false)
	for i in 3:
		K.box(node, Vector3(1.2, 0.04, 0.04), Vector3(0, -0.55 - i * 0.12, 0.05), K.STONE_DARK)


func _plant(pos: Vector3) -> void:
	var node := Node3D.new()
	node.position = pos
	add_child(node)
	_block(pos, 0.9)
	K.cylinder(node, 0.42, 0.55, Vector3(0, 0.27, 0), K.BRICK, Vector3.ZERO, 10)
	K.cylinder(node, 0.46, 0.1, Vector3(0, 0.55, 0), K.BRICK.darkened(0.15), Vector3.ZERO, 10)
	for i in 5:
		var angle := i * TAU / 5.0
		K.sphere(node, 0.34, Vector3(cos(angle) * 0.24, 0.95 + sin(i * 2.0) * 0.18, sin(angle) * 0.24), Color(0.34, 0.5, 0.3), Vector3(0.8, 1.3, 0.8))
	K.collider(node, Vector3(0.9, 1.0, 0.9), Vector3(0, 0.5, 0))


# ---------------------------------------------------------------- bakery

func _build_bakery() -> void:
	_counter(Vector3(-1.0, 0, -2.0), Vector2(7.0, 1.2), K.WOOD_DARK)
	K.box(self, Vector3(6.8, 0.1, 1.25), Vector3(-1.0, 1.16, -2.0), K.WOOD)
	var tray := K.box(self, Vector3(4.8, 0.06, 0.7), Vector3(-1.4, 1.24, -2.0), K.METAL)
	tray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 7:
		_loaf(Vector3(-3.6 + i * 0.7, 1.35, -2.0 + (i % 2) * 0.18))
	K.box(self, Vector3(0.5, 0.34, 0.42), Vector3(1.6, 1.38, -2.05), K.OCHRE.darkened(0.35))
	K.box(self, Vector3(0.44, 0.06, 0.34), Vector3(1.6, 1.6, -2.05), K.CREAM)
	K.label(self, "BREAD & CO", Vector3(-1.0, 2.5, -2.72), 34, K.CREAM)
	_block(Vector3(-1.0, 0, -2.0), 3.8)

	_oven(Vector3(5.6, 0, -6.1))
	_shelf_unit(Vector3(8.25, 0, 2.2), -PI / 2.0, 3.2, 2.7)
	_shelf_unit(Vector3(-8.25, 0, 2.0), PI / 2.0, 3.2, 2.7)
	_sack(Vector3(-6.4, 0, -4.8), 0.0)
	_sack(Vector3(-5.5, 0, -4.4), 0.4)
	_sack(Vector3(-6.1, 0, -3.7), -0.3)
	_crate(Vector3(6.6, 0, -1.2), Vector3(1.2, 0.9, 1.1), 0.3)
	_table(Vector3(-6.4, 0, 5.0), "TODAY'S LOAF", K.OCHRE)
	for i in 3:
		_loaf(Vector3(-7.0 + i * 0.55, 1.0, 5.0))
	_poster(Vector3(-8.76, 2.4, -1.0), PI / 2.0, "FLOUR\nWATER\nPATIENCE", K.OCHRE)
	_practical(Vector3(-4.4, 3.75, 1.6), Color(1.0, 0.8, 0.52), 1.8, 7.5)
	_practical(Vector3(2.8, 3.75, 1.6), Color(1.0, 0.8, 0.52), 1.8, 7.5)
	_practical(Vector3(5.6, 3.4, -5.2), Color(1.0, 0.68, 0.36), 1.6, 6.0)
	_practical(Vector3(0, 3.75, 4.8), Color(1.0, 0.86, 0.62), 1.4, 6.5)

	stations = []


func _loaf(pos: Vector3) -> void:
	var loaf := K.sphere(self, 0.2, pos, Color(0.72, 0.5, 0.26), Vector3(1.5, 0.75, 0.95))
	loaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var slash := K.box(self, Vector3(0.28, 0.02, 0.08), pos + Vector3(0, 0.09, 0), Color(0.55, 0.36, 0.18), Vector3(0, 0.3, 0))
	slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _oven(pos: Vector3) -> void:
	var node := Node3D.new()
	node.position = pos
	add_child(node)
	_block(pos, 2.4)
	K.box(node, Vector3(3.4, 2.9, 1.6), Vector3(0, 1.45, -0.4), K.BRICK)
	K.box(node, Vector3(3.7, 0.2, 1.7), Vector3(0, 2.94, -0.35), K.STONE_DARK)
	K.box(node, Vector3(2.4, 1.5, 0.4), Vector3(0, 1.05, 0.38), K.INK)
	var mouth := K.quad(node, Vector2(2.0, 1.2), Vector3(0, 0.95, 0.61), Color(1.0, 0.55, 0.2))
	mouth.material_override = _glow_mat(Color(1.0, 0.46, 0.14), 2.2)
	K.box(node, Vector3(2.6, 0.14, 0.2), Vector3(0, 1.78, 0.46), K.METAL)
	K.cylinder(node, 0.05, 0.34, Vector3(0, 1.78, 0.6), K.INK, Vector3.ZERO, 6)
	for i in 4:
		K.box(node, Vector3(0.34, 0.1, 0.5), Vector3(-0.9 + i * 0.6, 0.34, 0.5), K.WOOD_DARK)
	K.label(node, "NIGHT OVEN", Vector3(0, 2.2, 0.66), 22, K.INK)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.0, 1.0)
	light.light_color = Color(1.0, 0.56, 0.22)
	light.light_energy = 2.0
	light.omni_range = 6.5
	light.shadow_enabled = false
	node.add_child(light)
	practicals.append({"light": light, "base": 2.0, "phase": 4.0})
	K.collider(node, Vector3(3.5, 3.0, 2.0), Vector3(0, 1.5, -0.25))


func _sack(pos: Vector3, rot: float) -> void:
	var node := Node3D.new()
	node.position = pos
	node.rotation.y = rot
	add_child(node)
	_block(pos, 0.55)
	var body := K.sphere(node, 0.42, Vector3(0, 0.42, 0), Color(0.76, 0.68, 0.52), Vector3(0.85, 1.1, 0.85))
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.cylinder(node, 0.16, 0.18, Vector3(0, 0.86, 0), Color(0.68, 0.6, 0.44), Vector3.ZERO, 7)
	K.box(node, Vector3(0.2, 0.3, 0.02), Vector3(0, 0.55, 0.36), K.INK)


func _table(pos: Vector3, label: String, accent: Color) -> void:
	var node := Node3D.new()
	node.position = pos
	add_child(node)
	_block(pos, 1.0)
	K.box(node, Vector3(2.0, 0.1, 1.1), Vector3(0, 0.92, 0), K.WOOD)
	for side in [-1.0, 1.0]:
		for z in [-0.4, 0.4]:
			K.box(node, Vector3(0.1, 0.9, 0.1), Vector3(side * 0.85, 0.45, z), K.WOOD_DARK)
	K.box(node, Vector3(1.4, 0.28, 0.06), Vector3(0, 1.24, 0), K.INK)
	K.label(node, label, Vector3(0, 1.24, 0.06), 16, accent)
	K.collider(node, Vector3(2.0, 1.0, 1.1), Vector3(0, 0.5, 0))


# ---------------------------------------------------------------- boathouse

func _build_boathouse() -> void:
	var hull := Node3D.new()
	hull.position = Vector3(0, 0, -3.4)
	add_child(hull)
	_block(Vector3(0, 0, -3.4), 3.2)
	K.box(hull, Vector3(7.2, 0.9, 2.6), Vector3(0, 0.45, 0), K.TEAL_DARK)
	K.box(hull, Vector3(6.4, 0.36, 2.1), Vector3(0, 1.0, 0), K.WOOD)
	K.box(hull, Vector3(5.4, 0.5, 1.7), Vector3(0, 1.42, 0), K.TEAL)
	K.box(hull, Vector3(1.8, 0.7, 1.4), Vector3(-1.2, 1.9, 0), K.CREAM)
	for i in 5:
		K.box(hull, Vector3(0.9, 0.24, 0.05), Vector3(-2.2 + i * 1.1, 1.55, 1.0), K.INK)
	K.cylinder(hull, 0.14, 2.4, Vector3(1.4, 1.6, 0.2), K.INK)
	K.box(hull, Vector3(7.4, 0.14, 0.16), Vector3(0, 1.08, 1.28), K.WOOD_DARK)
	K.collider(hull, Vector3(7.2, 2.2, 2.6), Vector3(0, 1.1, 0))

	for side in [-1.0, 1.0]:
		for z in [-1.6, 1.0]:
			var post := K.cylinder(self, 0.13, 3.9, Vector3(side * 7.4, 1.95, z), K.WOOD_DARK, Vector3.ZERO, 8)
			post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			K.box(self, Vector3(0.34, 0.14, 0.34), Vector3(side * 7.4, 3.82, z), K.INK)
	_block(Vector3(-7.4, 0, 0), 1.0)
	_block(Vector3(7.4, 0, 0), 1.0)

	var net := K.torus(self, 1.1, 1.35, Vector3(6.2, 0.12, 4.3), Color(0.78, 0.72, 0.56), Vector3(PI / 2, 0, 0))
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 6:
		var angle := i * TAU / 6.0
		K.cylinder(self, 0.02, 2.3, Vector3(6.2 + cos(angle) * 0.8, 0.16, 4.3 + sin(angle) * 0.8), Color(0.72, 0.66, 0.5), Vector3(PI / 2, angle, 0), 4).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 4:
		var color: Color = [K.CORAL, K.OCHRE, K.TEAL, K.CREAM][i]
		K.sphere(self, 0.22, Vector3(-6.6 + (i % 2) * 0.6, 0.24, 3.4 + (i / 2) * 0.6), color, Vector3(1, 1.2, 1))
	K.cylinder(self, 0.36, 0.9, Vector3(6.4, 0.45, -1.0), K.WOOD, Vector3.ZERO, 10)
	K.cylinder(self, 0.4, 0.08, Vector3(6.4, 0.92, -1.0), K.WOOD_DARK, Vector3.ZERO, 10)
	K.cylinder(self, 0.36, 0.9, Vector3(5.6, 0.45, -1.5), K.WOOD, Vector3.ZERO, 10)
	_crate(Vector3(-6.4, 0, -1.2), Vector3(1.2, 1.0, 1.0), 0.2)
	_crate(Vector3(-5.4, 0, -0.6), Vector3(0.9, 0.7, 0.9), -0.4)
	_table(Vector3(-5.8, 0, 4.6), "TIDE TABLE", K.TEAL)
	_poster(Vector3(0, 2.6, -6.72), 0.0, "THE RIVER\nTAKES\nEVERYTHING", K.TEAL)
	_practical(Vector3(-5.6, 3.4, 4.8), Color(1.0, 0.76, 0.44), 1.4, 6.5, "lantern")
	_practical(Vector3(3.4, 3.4, 3.8), Color(1.0, 0.76, 0.44), 1.4, 6.5, "lantern")
	_practical(Vector3(0, 3.75, -2.0), Color(0.72, 0.86, 0.92), 1.3, 7.0)

	stations = []


# ---------------------------------------------------------------- arcade

func _build_arcade() -> void:
	var screen_colors := [K.CORAL, K.TEAL, K.OCHRE, K.PLUM, K.CORAL, K.TEAL]
	for i in 6:
		var x := -6.5 + i * 2.6
		_cabinet(Vector3(x, 0, -5.9), screen_colors[i], i)
	var rug := K.plane(self, Vector2(10.0, 6.0), Vector3(0, 0.015, 1.6), Color(0.24, 0.2, 0.3), K.clear_material(Color(0.34, 0.24, 0.4), 0.5))
	rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1.0, 1.0]:
		K.box(self, Vector3(0.12, 0.12, 10.0), Vector3(side * 8.6, 3.9, 0.6), Color(0.2, 0.2, 0.26)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var strip := K.box(self, Vector3(0.14, 0.08, 9.6), Vector3(side * 8.52, 3.9, 0.6), Color(0.9, 0.4, 0.7) if side < 0 else Color(0.4, 0.8, 0.95))
		strip.material_override = _glow_mat(Color(1.0, 0.42, 0.7) if side < 0 else Color(0.42, 0.85, 1.0), 1.8)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(self, Vector3(6.0, 0.08, 1.6), Vector3(-3.0, 1.0, 3.2), K.WOOD_DARK)
	K.box(self, Vector3(5.8, 0.1, 1.4), Vector3(-3.0, 1.06, 3.2), Color(0.5, 0.3, 0.5))
	for i in 5:
		K.sphere(self, 0.24, Vector3(-5.2 + i * 1.1, 1.38, 3.2), [K.CORAL, K.OCHRE, K.TEAL, K.PLUM, K.CREAM][i], Vector3(1, 1.1, 1))
	_block(Vector3(-3.0, 0, 3.2), 2.6)
	_crate(Vector3(6.8, 0, 4.4), Vector3(1.1, 0.9, 1.0), 0.4)
	_poster(Vector3(8.76, 2.5, 2.4), -PI / 2.0, "HIGH\nSCORE\nHALL", K.CORAL)
	_practical(Vector3(-5.0, 3.8, 0.0), Color(1.0, 0.46, 0.72), 2.0, 8.0)
	_practical(Vector3(4.6, 3.8, 0.0), Color(0.44, 0.84, 1.0), 2.0, 8.0)
	_practical(Vector3(0, 3.75, 4.6), Color(1.0, 0.78, 0.56), 1.3, 6.0)

	stations = []


func _cabinet(pos: Vector3, color: Color, index: int) -> void:
	var node := Node3D.new()
	node.position = pos
	add_child(node)
	_block(pos, 1.1)
	K.box(node, Vector3(1.0, 2.0, 0.8), Vector3(0, 1.0, 0), Color(0.16, 0.14, 0.2))
	K.box(node, Vector3(1.06, 0.2, 0.86), Vector3(0, 2.0, 0), color.darkened(0.25))
	K.box(node, Vector3(0.84, 0.62, 0.03), Vector3(0, 1.56, 0.42), K.INK)
	var screen := K.quad(node, Vector2(0.72, 0.5), Vector3(0, 1.56, 0.44), color)
	screen.material_override = _glow_mat(color, 1.6)
	K.box(node, Vector3(0.9, 0.26, 0.5), Vector3(0, 1.06, 0.44), Color(0.22, 0.2, 0.26))
	K.sphere(node, 0.06, Vector3(-0.16, 1.12, 0.52), K.CORAL)
	K.sphere(node, 0.06, Vector3(0.02, 1.12, 0.52), K.OCHRE)
	K.box(node, Vector3(0.16, 0.04, 0.12), Vector3(0.22, 1.12, 0.52), K.CREAM)
	K.box(node, Vector3(0.9, 0.3, 0.03), Vector3(0, 1.96, 0.44), color.darkened(0.4))
	K.label(node, "GAME %d" % (index + 1), Vector3(0, 1.96, 0.46), 16, K.CREAM)
	K.collider(node, Vector3(1.0, 2.1, 0.9), Vector3(0, 1.05, 0))


# ---------------------------------------------------------------- plant

func _build_plant() -> void:
	for side in [-1.0, 1.0]:
		var tank := K.cylinder(self, 1.25, 3.0, Vector3(side * 6.4, 1.5, -5.2), Color(0.44, 0.5, 0.47), Vector3.ZERO, 14)
		tank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		K.cylinder(self, 1.32, 0.16, Vector3(side * 6.4, 3.02, -5.2), K.METAL, Vector3.ZERO, 14)
		K.cylinder(self, 1.32, 0.16, Vector3(side * 6.4, 0.08, -5.2), K.METAL, Vector3.ZERO, 14)
		K.cylinder(self, 0.09, 2.4, Vector3(side * 6.4, 4.0, -5.2), K.METAL, Vector3.ZERO, 8)
		_block(Vector3(side * 6.4, 0, -5.2), 1.6)
		K.collider(self, Vector3(2.6, 3.0, 2.6), Vector3(side * 6.4, 1.5, -5.2))
	for i in 3:
		var pipe_color: Color = K.TEAL if i == 1 else K.METAL
		var pipe := K.cylinder(self, 0.16, 17.0, Vector3(0, 4.0 - i * 0.22, -6.2 + i * 0.3), pipe_color, Vector3(0, 0, PI / 2), 8)
		pipe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1.0, 1.0]:
		var upright := K.cylinder(self, 0.14, 3.6, Vector3(side * 8.2, 1.8, 1.4), K.METAL, Vector3.ZERO, 8)
		upright.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		K.torus(self, 0.18, 0.3, Vector3(side * 8.2, 1.8, 1.4), K.CORAL, Vector3(PI / 2, 0, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_block(Vector3(-8.2, 0, 1.4), 0.7)
	_block(Vector3(8.2, 0, 1.4), 0.7)
	K.box(self, Vector3(6.0, 0.14, 2.4), Vector3(0, 0.9, -4.2), Color(0.36, 0.4, 0.38))
	for side in [-1.0, 1.0]:
		for z in [-5.2, -3.2]:
			K.box(self, Vector3(0.14, 0.9, 0.14), Vector3(side * 2.8, 0.45, z), K.METAL)
	K.collider(self, Vector3(6.0, 1.0, 2.4), Vector3(0, 0.5, -4.2))
	_block(Vector3(0, 0, -4.2), 3.4)
	_crate(Vector3(-6.2, 0, 2.6), Vector3(1.2, 1.0, 1.0), 0.2)
	_crate(Vector3(6.0, 0, 2.2), Vector3(0.9, 0.8, 0.9), -0.3)
	_poster(Vector3(0, 2.6, -6.72), 0.0, "MIND\nTHE\nPIPES", K.OCHRE)
	_practical(Vector3(-4.4, 3.75, -1.0), Color(0.76, 0.88, 0.86), 1.6, 7.0)
	_practical(Vector3(3.8, 3.75, -1.0), Color(0.76, 0.88, 0.86), 1.6, 7.0)
	_practical(Vector3(0, 3.4, 4.2), Color(1.0, 0.72, 0.4), 1.2, 5.5, "lantern")
	add_steam(Vector3(-6.4, 5.1, -5.2), 12)
	add_steam(Vector3(6.4, 5.1, -5.2), 12)

	stations = []


# ---------------------------------------------------------------- shared props

func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _practical(pos: Vector3, color: Color, energy := 1.6, range_m := 7.5, style := "shade") -> void:
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	var bulb: MeshInstance3D
	if style == "lantern":
		K.cylinder(holder, 0.14, 0.24, Vector3(0, 0.22, 0), K.INK, Vector3.ZERO, 8)
		K.cylinder(holder, 0.02, 0.35, Vector3(0, 0.5, 0), K.INK, Vector3.ZERO, 4)
		bulb = K.sphere(holder, 0.12, Vector3(0, 0, 0), color, Vector3(1, 1.3, 1))
	else:
		K.cylinder(holder, 0.02, 0.6, Vector3(0, 0.36, 0), K.INK, Vector3.ZERO, 5)
		K.cone(holder, 0.1, 0.42, 0.28, Vector3(0, 0, 0), K.INK, Vector3.ZERO, 10)
		bulb = K.sphere(holder, 0.1, Vector3(0, -0.14, 0), color)
	bulb.material_override = _glow_mat(color, 2.4)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.position = Vector3(0, -0.18, 0)
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_m
	light.omni_attenuation = 1.05
	light.shadow_enabled = false
	holder.add_child(light)
	practicals.append({"light": light, "base": energy, "phase": float(practicals.size()) * 1.7})
