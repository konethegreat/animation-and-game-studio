extends Node3D

# The Gulper, a municipal waste engine that Sullage overclocked. Three
# phases: HUNGRY, OVERCLOCKED, CALMING. Chute hits drain its health; phase
# three opens the core for a full-hopper calm-down feed.

signal damaged(health: float)
signal phase_changed(phase: int)
signal defeated
signal stomp
signal suction(on: bool)
signal volley(origin: Vector3)

const K = preload("res://scripts/kit.gd")

const MAX_HEALTH := 300.0
const HIT_DAMAGE := 8.0
const CALM_GOAL := 12.0
const RAIL_MIN := -4.4
const RAIL_MAX := 4.4
const LOCAL_MOUTH := Vector3(0.0, 1.5, -4.4)
const CHUTE_KINDS := ["paper", "metal", "glass"]
const CHUTE_LOCAL := [Vector3(-3.4, 0.0, -3.0), Vector3(0.0, 0.0, -3.0), Vector3(3.4, 0.0, -3.0)]

var health := MAX_HEALTH
var phase := 1
var active := false
var core_open := false
var grime_blocked := false
var calm := 0.0
var suction_on := false

var chutes: Array = []
var _arena: Node3D = null
var _machine: Node3D = null
var _core_node: Node3D = null
var _chute_nodes := {}
var _hits := 0
var _window := 0.0
var _closed_for := 1.5
var _suction_timer := 6.0
var _volley_timer := 6.0
var _patrol := 0.0
var _patrol_dir := 1.0


func setup(arena: Node3D) -> void:
	_arena = arena
	for i in CHUTE_KINDS.size():
		chutes.append({
			"kind": CHUTE_KINDS[i],
			"local": CHUTE_LOCAL[i],
			"open": false,
			"timer": 0.0,
		})
	if _arena != null:
		_build_machine()


func begin() -> void:
	active = true
	_window = 2.0
	_closed_for = 0.0


func force_open(kind: String) -> void:
	for entry in chutes:
		if str(entry.kind) == kind:
			entry.open = true
			entry.timer = 999.0
			_update_chute_look(entry)


func is_open(kind: String) -> bool:
	for entry in chutes:
		if str(entry.kind) == kind:
			return bool(entry.open)
	return false


func open_kinds() -> Array:
	var kinds := []
	for entry in chutes:
		if bool(entry.open):
			kinds.append(str(entry.kind))
	return kinds


func chute_points() -> Array:
	var points := []
	for entry in chutes:
		var pos: Vector3 = entry.local
		if _arena != null:
			pos = _arena.to_global(pos)
		points.append({"kind": str(entry.kind), "pos": pos, "open": bool(entry.open)})
	return points


func mouth_position() -> Vector3:
	if _machine != null:
		return _machine.to_global(Vector3(0.0, 1.5, 1.2))
	if _arena != null:
		return _arena.to_global(LOCAL_MOUTH)
	return LOCAL_MOUTH


func feed(kind: String, items: Array) -> Dictionary:
	var result := {"damage": 0.0, "accepted": 0, "stomp": false}
	if phase == 3 or not active:
		return result
	if grime_blocked:
		return result
	if not is_open(kind):
		return result
	var accepted := 0
	for item in items:
		if str(item.get("kind", "")) == kind:
			accepted += 1
	if accepted <= 0:
		return result
	result.accepted = accepted
	var damage := HIT_DAMAGE * float(accepted)
	health = maxf(0.0, health - damage)
	result.damage = damage
	_hits += accepted
	if _hits % 3 == 0:
		result.stomp = true
	_check_phase()
	damaged.emit(health)
	return result


func feed_core(items: Array) -> int:
	if not core_open or not active:
		return 0
	var fed := items.size()
	calm += float(fed)
	if _core_node != null:
		_core_node.rotation.x = minf(1.1, calm / CALM_GOAL * 1.1)
	if calm >= CALM_GOAL:
		defeated.emit()
	return fed


func _check_phase() -> void:
	var new_phase := phase
	if health <= 100.0:
		new_phase = 3
	elif health <= 200.0:
		new_phase = 2
	if new_phase == phase:
		return
	phase = new_phase
	for entry in chutes:
		entry.open = false
		entry.timer = 0.0
		_update_chute_look(entry)
	_set_suction(false)
	if phase == 3:
		core_open = true
		if _core_node != null:
			_core_node.visible = true
	phase_changed.emit(phase)


func _process(delta: float) -> void:
	if not active:
		return
	_patrol_machine(delta)
	if phase == 3:
		return
	_run_chute_windows(delta)
	_run_suction(delta)
	_volley_timer -= delta
	if _volley_timer <= 0.0:
		_volley_timer = 7.0 if phase == 1 else 4.6
		volley.emit(mouth_position())


func _set_suction(on: bool) -> void:
	if suction_on == on:
		return
	suction_on = on
	suction.emit(on)


func _run_chute_windows(delta: float) -> void:
	for entry in chutes:
		if bool(entry.open):
			entry.timer = float(entry.timer) - delta
			if float(entry.timer) <= 0.0:
				entry.open = false
				_closed_for = 2.2 if phase == 1 else 1.4
				_update_chute_look(entry)
	if _closed_for > 0.0:
		_closed_for -= delta
		return
	if _any_open():
		return
	_window -= delta
	if _window > 0.0:
		return
	var count := 1 if phase == 1 else 2
	var order := CHUTE_KINDS.duplicate()
	order.shuffle()
	for i in count:
		for entry in chutes:
			if str(entry.kind) == order[i]:
				entry.open = true
				entry.timer = 6.5 if phase == 1 else 4.6
				_update_chute_look(entry)
	_window = 1.0


func _any_open() -> bool:
	for entry in chutes:
		if bool(entry.open):
			return true
	return false


func _run_suction(delta: float) -> void:
	_suction_timer -= delta
	if suction_on:
		if _suction_timer <= 0.0:
			_set_suction(false)
			_suction_timer = 8.0 if phase == 1 else 5.5
	else:
		if _suction_timer <= 0.0:
			_set_suction(true)
			_suction_timer = 2.4 if phase == 1 else 2.8


func _patrol_machine(delta: float) -> void:
	if _machine == null:
		return
	var speed := 1.1 if phase == 1 else 2.3
	if phase == 3:
		speed = 0.25
	_patrol += delta * speed * _patrol_dir
	if _patrol > RAIL_MAX:
		_patrol = RAIL_MAX
		_patrol_dir = -1.0
	elif _patrol < RAIL_MIN:
		_patrol = RAIL_MIN
		_patrol_dir = 1.0
	_machine.position.x = _patrol


func _update_chute_look(entry: Dictionary) -> void:
	var node = _chute_nodes.get(str(entry.kind))
	if node == null or not is_instance_valid(node):
		return
	var door: Node3D = node.get_node_or_null("Door")
	if door:
		door.position.y = 0.9 if bool(entry.open) else 0.34


# ---------------------------------------------------------------- visuals

func _build_machine() -> void:
	var root := Node3D.new()
	root.name = "Gulper"
	root.position = Vector3(0.0, 0.0, -4.4)
	_arena.add_child(root)
	_machine = root

	var body := K.cylinder(root, 1.9, 2.6, Vector3(0, 1.9, 0), Color(0.32, 0.36, 0.4), Vector3(PI / 2, 0, 0), 18)
	body.material_override = K.material(Color(0.32, 0.36, 0.4), 0.55, 0.6)
	var band := K.cylinder(root, 1.96, 0.5, Vector3(0, 1.9, 0.0), K.CORAL, Vector3(PI / 2, 0, 0), 18)
	band.material_override = K.material(K.CORAL, 0.4, 0.5, K.CORAL, 0.25)
	var mouth := K.box(root, Vector3(2.2, 1.2, 0.5), Vector3(0, 1.5, 1.85), Color(0.13, 0.12, 0.1))
	for i in 5:
		var tx := -0.88 + i * 0.44
		K.box(root, Vector3(0.18, 0.34, 0.22), Vector3(tx, 2.22, 1.95), K.CREAM, Vector3(0.5, 0, 0))
		K.box(root, Vector3(0.18, 0.34, 0.22), Vector3(tx, 0.82, 1.95), K.CREAM, Vector3(-0.5, 0, 0))
	var eye := K.sphere(root, 0.3, Vector3(0, 2.9, 1.55), Color(1.0, 0.75, 0.35))
	eye.material_override = K.material(Color(1.0, 0.75, 0.35), 0.3, 0.0, Color(1.0, 0.6, 0.25), 1.4)
	for side in [-1.0, 1.0]:
		K.cylinder(root, 0.22, 1.6, Vector3(side * 1.1, 3.9, -0.4), K.METAL, Vector3.ZERO, 8)
		K.box(root, Vector3(1.0, 0.5, 2.6), Vector3(side * 1.7, 0.25, 0), Color(0.2, 0.2, 0.24))
	K.collider(root, Vector3(4.2, 3.4, 3.4), Vector3(0, 1.7, 0.2))

	var core := Node3D.new()
	core.name = "Core"
	core.position = Vector3(0, 0.9, 2.05)
	core.visible = false
	root.add_child(core)
	_core_node = core
	var hatch := K.box(core, Vector3(1.1, 0.9, 0.12), Vector3(0, 0, 0), Color(0.85, 0.62, 0.2))
	hatch.material_override = K.material(Color(0.85, 0.62, 0.2), 0.35, 0.7, Color(1.0, 0.72, 0.25), 0.5)
	K.label(core, "CORE", Vector3(0, 0.62, 0.1), 18, K.INK)

	for i in CHUTE_KINDS.size():
		var kind: String = CHUTE_KINDS[i]
		var pad := Node3D.new()
		pad.name = "Chute" + kind.to_pascal_case()
		pad.position = CHUTE_LOCAL[i]
		_arena.add_child(pad)
		var base := K.box(pad, Vector3(1.5, 0.24, 1.1), Vector3(0, 0.12, 0), Color(0.24, 0.26, 0.3))
		base.material_override = K.material(Color(0.24, 0.26, 0.3), 0.6, 0.5)
		var door := K.box(pad, Vector3(1.3, 0.56, 0.16), Vector3(0, 0.34, -0.42), K.CREAM)
		door.name = "Door"
		var lamp := K.sphere(pad, 0.09, Vector3(0, 0.62, 0.3), Color(0.2, 0.2, 0.24))
		lamp.name = "Lamp"
		lamp.material_override = K.material(Color(0.2, 0.2, 0.24), 0.4, 0.0, Color(0.2, 0.2, 0.24), 0.0)
		K.label(pad, kind.to_upper(), Vector3(0, 0.5, 0.58), 16, K.CREAM)
		_chute_nodes[kind] = pad

	for side in [-1.0, 1.0]:
		var lamp_light := OmniLight3D.new()
		lamp_light.position = Vector3(side * 5.4, 3.4, -3.4)
		lamp_light.light_color = Color(1.0, 0.35, 0.25)
		lamp_light.omni_range = 6.0
		lamp_light.light_energy = 0.9
		_arena.add_child(lamp_light)
		K.box(_arena, Vector3(0.5, 0.3, 0.5), Vector3(side * 5.4, 3.6, -3.4), Color(0.3, 0.24, 0.22))

	var gantry := K.box(_arena, Vector3(3.4, 0.18, 1.6), Vector3(6.9, 2.3, -4.6), K.METAL)
	gantry.material_override = K.material(K.METAL, 0.5, 0.7)
	for gx in [-1.4, 0.0, 1.4]:
		K.box(_arena, Vector3(0.12, 2.3, 0.12), Vector3(6.9 + gx, 1.15, -4.6), K.METAL)
	K.label(_arena, "GANTRY", Vector3(6.9, 2.75, -4.6), 14, K.CREAM)
	K.apply_toon(root, 0.03)


func set_chute_lights(open_kinds_list: Array) -> void:
	for kind in _chute_nodes:
		var pad = _chute_nodes[kind]
		if pad == null or not is_instance_valid(pad):
			continue
		var lamp: Node3D = pad.get_node_or_null("Lamp")
		if lamp == null:
			continue
		var is_lit := open_kinds_list.has(kind)
		lamp.material_override = K.material(
			Color(0.2, 0.2, 0.24) if not is_lit else Color(0.5, 1.0, 0.6),
			0.4, 0.0,
			Color(0.2, 0.2, 0.24) if not is_lit else Color(0.4, 1.0, 0.55),
			0.0 if not is_lit else 1.6)
