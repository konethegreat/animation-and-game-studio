extends Node3D

const K = preload("res://scripts/kit.gd")

const SKIN := [
	Color(0.68, 0.48, 0.34), Color(0.78, 0.6, 0.45), Color(0.55, 0.37, 0.26),
	Color(0.86, 0.69, 0.54), Color(0.45, 0.3, 0.22), Color(0.72, 0.53, 0.4),
]
const SHIRTS := [K.CORAL, K.TEAL, K.OCHRE, K.PLUM, K.OLIVE, K.BRICK, K.GLASS]
const TROUSERS := [K.WOOD_DARK, K.INK, Color(0.24, 0.28, 0.34), K.STONE_DARK, K.OLIVE]

var role := "shopper"
var palette := 0
var rng: RandomNumberGenerator
var lines: Array = []
var dialogue_id := ""
var display_name := ""

var home := Vector3.ZERO
var _rig: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _tail: Node3D
var _hat: Node3D
var _body: Node3D

var _height := 1.0
var _speed := 1.3
var _radius := 4.0
var _wander := 0.0
var _target := Vector3.ZERO
var _wait := 0.6
var _anim := 0.0
var _just_talked := 0.0
var _cheer := 0.0
var _sidestep := Vector3.ZERO
var _sidestep_time := 0.0
var _scatter := 0.0
var _facing := 0.0
var _flying := false
var _physics_tick := 0.0


func setup(role_name: String, palette_index: int, generator: RandomNumberGenerator) -> void:
	role = role_name
	palette = palette_index % SKIN.size()
	rng = generator
	home = global_position
	dialogue_id = role_name
	display_name = _role_name(role_name)
	_height = _role_height(role_name)
	_speed = rng.randf_range(0.9, 1.5)
	match role:
		"keeper":
			_speed = 0.0
			dialogue_id = "keeper_%d" % (palette_index % 3)
		"baker", "nell":
			_speed = 0.0
		"child":
			_speed = 2.2
			dialogue_id = "child_%d" % (palette_index % 2)
		"shopper":
			dialogue_id = "shopper_%d" % (palette_index % 3)
		"pigeon":
			_flying = true
		"ferryman":
			_speed = 0.0
		"arcade_kid":
			_speed = 0.4
		"dog":
			_speed = 1.6
	_build()
	_face(rng.randf_range(-PI, PI))


func talk() -> Dictionary:
	_just_talked = 2.0
	return {"id": dialogue_id, "name": display_name}


func react(kind: String) -> void:
	match kind:
		"vacuum":
			if role != "keeper" and role != "ferryman":
				var away := global_position - _player_hint
				away.y = 0.0
				if away.length() > 0.05:
					_sidestep = away.normalized() * 1.6
					_sidestep_time = 0.7
			_cheer = 0.0
		"cheer":
			if global_position.distance_to(_player_hint) < 22.0:
				_cheer = 1.6
		"scare":
			_scatter = 2.0


var _player_hint := Vector3.ZERO


func tick(delta: float, player_pos: Vector3, vacuuming: bool, distance: float) -> void:
	_player_hint = player_pos
	_just_talked = maxf(0.0, _just_talked - delta)
	_cheer = maxf(0.0, _cheer - delta)
	_sidestep_time = maxf(0.0, _sidestep_time - delta)
	_scatter = maxf(0.0, _scatter - delta)
	_physics_tick -= delta

	if distance > 18.0 and _physics_tick > 0.0:
		return
	_physics_tick = 0.12 if distance > 18.0 else 0.0

	if vacuuming and distance < 3.2 and role != "keeper":
		react("vacuum")
	if distance < 2.6:
		face_point(player_pos, delta * 5.0)

	match role:
		"shopper", "arcade_kid":
			_walk(delta)
		"child":
			_child(delta, player_pos, distance)
		"pigeon":
			_pigeon(delta, player_pos, distance, vacuuming)
		"cat":
			_cat(delta, player_pos)
		"dog":
			_dog(delta, player_pos, distance)
		"keeper", "ferryman":
			_settle(delta)
		_:
			_settle(delta)

	if _sidestep_time > 0.0:
		position += _sidestep * delta
		_sidestep = _sidestep.move_toward(Vector3.ZERO, delta * 2.0)
	if _scatter > 0.0:
		var away := global_position - player_pos
		away.y = 0.0
		if away.length() < 5.0 and away.length() > 0.01:
			position += away.normalized() * delta * 3.2
			if _flying:
				position.y = 0.5 + sin(_anim * 3.0) * 0.24

	_animate(delta, distance)


func face_point(point: Vector3, amount: float) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length() < 0.05:
		return
	var want := atan2(to.x, to.z)
	_facing = lerp_angle(_facing, want, clampf(amount, 0.0, 1.0))
	rotation.y = _facing


func _face(angle: float) -> void:
	_facing = angle
	rotation.y = _facing


func _walk(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		return
	if _target == Vector3.ZERO:
		var angle := rng.randf_range(-PI, PI)
		var reach := rng.randf_range(1.2, _radius)
		_target = home + Vector3(cos(angle) * reach, 0, sin(angle) * reach)
	var to := _target - global_position
	to.y = 0.0
	if to.length() < 0.25:
		_target = Vector3.ZERO
		_wait = rng.randf_range(1.0, 3.5)
		return
	position += to.normalized() * _speed * delta
	face_point(_target, delta * 4.0)


func _child(delta: float, player_pos: Vector3, distance: float) -> void:
	if distance < 6.0 and distance > 2.2:
		var to := player_pos - global_position
		to.y = 0.0
		position += to.normalized() * _speed * 0.55 * delta
		face_point(player_pos, delta * 5.0)
	else:
		_wander += delta
		var side := Vector3(cos(_wander * 1.7), 0, sin(_wander * 1.3)) * 1.6
		var want := home + side
		var to := want - global_position
		to.y = 0.0
		if to.length() > 0.3:
			position += to.normalized() * _speed * 0.4 * delta
			face_point(want, delta * 4.0)


func _pigeon(delta: float, player_pos: Vector3, distance: float, vacuuming: bool) -> void:
	_wander += delta
	if distance < 2.4 or (vacuuming and distance < 4.5):
		_scatter = maxf(_scatter, 0.9)
	position.y = 0.16 + sin(_wander * 2.4) * 0.05
	rotation.y = sin(_wander * 1.1) * 0.4


func _cat(delta: float, player_pos: Vector3) -> void:
	_wander += delta
	if _tail:
		_tail.rotation.z = sin(_wander * 1.6) * 0.24
	if global_position.distance_to(player_pos) < 3.0:
		face_point(player_pos, delta * 2.0)


func _dog(delta: float, player_pos: Vector3, distance: float) -> void:
	var state = get_node_or_null("/root/GameState")
	var friendly: bool = state != null and int(state.rank) >= 4
	if friendly and distance < 7.0:
		var to := player_pos - global_position
		to.y = 0.0
		if to.length() > 2.0:
			position += to.normalized() * _speed * 0.5 * delta
			face_point(player_pos, delta * 3.0)
	else:
		_wander += delta


func _settle(delta: float) -> void:
	_wander += delta
	if _wait > 0.0:
		_wait -= delta


func _animate(delta: float, distance: float) -> void:
	if _rig == null:
		return
	var moving := _speed > 0.2
	_anim += delta * (5.0 if moving else 1.6)
	var swing := sin(_anim) * (0.42 if moving else 0.03)
	if _leg_l:
		_leg_l.rotation.x = swing
	if _leg_r:
		_leg_r.rotation.x = -swing
	var arm_swing := -swing * 0.6
	if _cheer > 0.0:
		arm_swing = -2.6 + sin(_anim * 8.0) * 0.25
	if _sidestep_time > 0.0 and _arm_r:
		_arm_r.rotation.x = -2.4
	elif _arm_r:
		_arm_r.rotation.x = arm_swing
	if _arm_l:
		_arm_l.rotation.x = arm_swing
	if _head:
		_head.rotation.y = sin(_anim * 0.7) * 0.12
	if _rig:
		_rig.position.y = absf(sin(_anim * 2.0)) * 0.03
		if _cheer > 0.0:
			_rig.position.y = absf(sin(_anim * 9.0)) * 0.14


func _build() -> void:
	_rig = Node3D.new()
	add_child(_rig)
	var skin: Color = SKIN[palette]
	var shirt: Color = SHIRTS[(palette + 2) % SHIRTS.size()]
	var trousers: Color = TROUSERS[palette % TROUSERS.size()]
	match role:
		"child":
			shirt = K.OCHRE if palette % 2 == 0 else K.GLASS
			_build_person(skin, shirt, trousers, Vector3(0.72, 0.72, 0.72))
		"keeper", "baker":
			_build_person(skin, shirt, trousers, Vector3.ONE)
			_build_apron()
		"ferryman":
			_build_person(skin, K.TEAL_DARK, K.WOOD_DARK, Vector3(1.06, 1.08, 1.06))
			_build_cap(K.TEAL_DARK)
		"arcade_kid":
			_build_person(skin, K.PLUM, Color(0.2, 0.22, 0.3), Vector3(0.9, 0.92, 0.9))
			_build_hood()
		"cat":
			_build_cat()
		"pigeon":
			_build_pigeon()
		"dog":
			_build_dog()
		"rat":
			_build_rat()
		_:
			_build_person(skin, shirt, trousers, Vector3.ONE)
	var shadow := K.plane(self, Vector2(0.95, 0.95), Vector3(0, 0.02, 0), Color(0, 0, 0, 0.2), K.clear_material(Color(0.08, 0.07, 0.06), 0.22))
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.scale = Vector3(_height, 1.0, _height)
	for node in _rig.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh != null:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_person(skin: Color, shirt: Color, trousers: Color, size: Vector3) -> void:
	_rig.scale = size
	_leg_l = _limb(Vector3(-0.13, 0.72, 0), trousers)
	_leg_r = _limb(Vector3(0.13, 0.72, 0), trousers)
	_body = K.box(_rig, Vector3(0.46, 0.62, 0.3), Vector3(0, 1.03, 0), shirt)
	K.box(_rig, Vector3(0.5, 0.08, 0.34), Vector3(0, 0.76, 0), K.INK)
	_arm_l = _limb(Vector3(-0.29, 1.28, 0), shirt)
	_arm_r = _limb(Vector3(0.29, 1.28, 0), shirt)
	_head = Node3D.new()
	_head.position = Vector3(0, 1.48, 0)
	_rig.add_child(_head)
	K.sphere(_head, 0.18, Vector3.ZERO, skin)
	K.box(_head, Vector3(0.06, 0.08, 0.09), Vector3(0, -0.02, 0.17), skin.darkened(0.08))
	for side in [-1.0, 1.0]:
		K.box(_head, Vector3(0.032, 0.035, 0.02), Vector3(side * 0.062, 0.04, 0.17), K.INK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_hat(palette)


func _build_hat(index: int) -> void:
	_hat = Node3D.new()
	_hat.position = Vector3(0, 0.16, 0)
	_head.add_child(_hat)
	match index % 4:
		0:
			K.cylinder(_hat, 0.19, 0.06, Vector3.ZERO, K.STONE, Vector3.ZERO, 10)
			K.box(_hat, Vector3(0.34, 0.03, 0.22), Vector3(0, -0.01, 0.1), K.STONE).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		1:
			K.sphere(_hat, 0.17, Vector3(0, 0, 0), K.PLUM).scale = Vector3(1, 0.6, 1)
		2:
			K.cylinder(_hat, 0.16, 0.18, Vector3(0, 0.04, 0), K.OCHRE, Vector3.ZERO, 8)
			K.torus(_hat, 0.15, 0.19, Vector3(0, -0.03, 0), K.CORAL, Vector3(PI / 2.0, 0, 0))
		3:
			K.cylinder(_hat, 0.14, 0.1, Vector3(0, 0.02, 0), K.TEAL_DARK, Vector3.ZERO, 8)
			K.box(_hat, Vector3(0.3, 0.02, 0.2), Vector3(0, -0.03, 0.08), K.TEAL_DARK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_apron() -> void:
	K.box(_rig, Vector3(0.34, 0.5, 0.04), Vector3(0, 1.0, 0.18), K.PAPER)
	K.box(_rig, Vector3(0.08, 0.18, 0.02), Vector3(0, 1.18, 0.21), K.CORAL)


func _build_cap(color: Color) -> void:
	if _hat:
		_hat.queue_free()
	_hat = Node3D.new()
	_hat.position = Vector3(0, 0.18, 0)
	_head.add_child(_hat)
	K.cylinder(_hat, 0.19, 0.08, Vector3.ZERO, color, Vector3.ZERO, 10)
	K.box(_hat, Vector3(0.34, 0.025, 0.2), Vector3(0, -0.02, 0.1), color).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_hood() -> void:
	K.sphere(_head, 0.21, Vector3(0, 0.03, -0.03), K.PLUM).scale = Vector3(1, 1, 1.05)
	K.box(_head, Vector3(0.3, 0.16, 0.06), Vector3(0, 0.03, 0.16), K.PLUM).material_override = K.material(K.PLUM, 0.9)


func _build_cat() -> void:
	_rig.scale = Vector3(0.9, 0.9, 0.9)
	_body = K.sphere(_rig, 0.24, Vector3(0, 0.28, 0), Color(0.56, 0.54, 0.5), Vector3(1.5, 0.9, 1.0))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.42, 0.3)
	_rig.add_child(_head)
	K.sphere(_head, 0.15, Vector3.ZERO, Color(0.6, 0.58, 0.54))
	for side in [-1.0, 1.0]:
		K.cone(_head, 0.01, 0.09, 0.12, Vector3(side * 0.09, 0.13, 0), Color(0.6, 0.58, 0.54), Vector3(0, 0, side * -0.2), 4)
		K.box(_head, Vector3(0.025, 0.03, 0.02), Vector3(side * 0.055, 0.02, 0.14), K.OCHRE).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tail = K.cylinder(_rig, 0.03, 0.5, Vector3(0, 0.32, -0.36), Color(0.58, 0.56, 0.52), Vector3(1.0, 0, 0), 5)
	for side in [-1.0, 1.0]:
		K.box(_rig, Vector3(0.07, 0.16, 0.07), Vector3(side * 0.14, 0.1, 0.18), Color(0.52, 0.5, 0.47))


func _build_pigeon() -> void:
	_rig.scale = Vector3(0.75, 0.75, 0.75)
	_body = K.sphere(_rig, 0.16, Vector3.ZERO, Color(0.48, 0.5, 0.53), Vector3(1.2, 1.0, 1.5))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.16, 0.17)
	_rig.add_child(_head)
	K.sphere(_head, 0.09, Vector3.ZERO, Color(0.4, 0.44, 0.48))
	K.cone(_head, 0.005, 0.03, 0.08, Vector3(0, 0, 0.1), K.OCHRE, Vector3(PI / 2.0, 0, 0), 4)
	for side in [-1.0, 1.0]:
		K.box(_head, Vector3(0.022, 0.022, 0.01), Vector3(side * 0.035, 0.02, 0.075), K.CORAL).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_dog() -> void:
	_rig.scale = Vector3(1.0, 1.0, 1.0)
	_body = K.box(_rig, Vector3(0.42, 0.32, 0.8), Vector3(0, 0.48, 0), K.WOOD)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.62, 0.44)
	_rig.add_child(_head)
	K.box(_head, Vector3(0.3, 0.28, 0.3), Vector3.ZERO, K.WOOD)
	K.box(_head, Vector3(0.16, 0.1, 0.12), Vector3(0, -0.06, 0.16), K.WOOD_DARK)
	for side in [-1.0, 1.0]:
		K.box(_head, Vector3(0.06, 0.14, 0.06), Vector3(side * 0.14, 0.16, -0.02), K.WOOD_DARK)
		K.box(_head, Vector3(0.035, 0.035, 0.02), Vector3(side * 0.08, 0.04, 0.15), K.INK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for side in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			K.box(_rig, Vector3(0.1, 0.4, 0.1), Vector3(side * 0.14, 0.2, z * 0.25), K.WOOD_DARK)
	_tail = K.box(_rig, Vector3(0.08, 0.08, 0.32), Vector3(0, 0.58, -0.48), K.WOOD)


func _build_rat() -> void:
	_rig.scale = Vector3(0.55, 0.55, 0.55)
	_body = K.sphere(_rig, 0.16, Vector3.ZERO, Color(0.4, 0.38, 0.36), Vector3(1.3, 0.9, 1.7))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.03, 0.24)
	_rig.add_child(_head)
	K.cone(_head, 0.01, 0.09, 0.2, Vector3(0, 0, 0.08), Color(0.44, 0.42, 0.4), Vector3(PI / 2.0, 0, 0), 6)
	for side in [-1.0, 1.0]:
		K.sphere(_head, 0.04, Vector3(side * 0.07, 0.1, -0.04), Color(0.5, 0.38, 0.36))
	_tail = K.cylinder(_rig, 0.012, 0.4, Vector3(0, 0, -0.32), Color(0.52, 0.44, 0.42), Vector3(1.2, 0, 0), 4)


func _limb(pivot: Vector3, color: Color) -> Node3D:
	var node := Node3D.new()
	node.position = pivot
	_rig.add_child(node)
	K.box(node, Vector3(0.12, 0.5, 0.13), Vector3(0, -0.24, 0), color)
	K.sphere(node, 0.08, Vector3(0, -0.52, 0), SKIN[palette])
	return node


func _role_height(role_name: String) -> float:
	match role_name:
		"child":
			return 0.72
		"cat":
			return 0.4
		"pigeon":
			return 1.35
		_:
			return 1.0


func _role_name(role_name: String) -> String:
	match role_name:
		"keeper":
			return "STALL KEEPER"
		"shopper":
			return "SHOPPER"
		"child":
			return "CHILD"
		"ferryman":
			return "ODO"
		"arcade_kid":
			return "PIP"
		"cat":
			return "MISO"
		"pigeon":
			return "PIGEON"
		"dog":
			return "DOG"
		"rat":
			return "RAT"
		"nell":
			return "NELL QUILL"
		"rook":
			return "ROOK"
		"baker":
			return "BAKER"
		_:
			return role_name.to_upper()
