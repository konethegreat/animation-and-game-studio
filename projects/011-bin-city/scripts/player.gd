extends CharacterBody3D

signal stack_tumbled(item: Node3D)
signal slipped

const K = preload("res://scripts/kit.gd")

const BASE_SPEED := 5.3
const SPRINT_SPEED := 7.0
const ACCEL := 24.0
const TURN := 12.0

var locked := true
var rank := 1
var max_stack := 1
var speed_bonus := 0.0
var slip_timer := 0.0
var vacuuming := false
var touch_input := Vector2.ZERO
var touch_sprint := false
var stack: Array[Node3D] = []
var lean := Vector2.ZERO
var wobble := 0.0
var is_moving := false

var rig: Node3D
var stack_anchor: Node3D
var vacuum_cone: MeshInstance3D
var vacuum_ring: MeshInstance3D
var leg_left: Node3D
var leg_right: Node3D
var arm_left: Node3D
var arm_right: Node3D
var head: Node3D
var straw_cap: Node3D
var flat_cap: Node3D
var broom: Node3D
var coat_tails: Node3D
var buttons: Node3D
var scarf: Node3D
var satchel: Node3D
var tank: Node3D
var _shirt_mat: StandardMaterial3D
var _apron_mat: StandardMaterial3D
var _cap_mat: StandardMaterial3D
var _anim := 0.0
var _prev_velocity := Vector3.ZERO
var _prev_yaw := 0.0
var _cone_mat: StandardMaterial3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.85, 0)
	add_child(shape)
	_build_body()
	rotation.y = PI
	_prev_yaw = rotation.y
	set_rank(1)


func _build_body() -> void:
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)

	leg_left = _limb(rig, Vector3(-0.165, 0.86, 0), Color(0.24, 0.28, 0.22))
	leg_right = _limb(rig, Vector3(0.165, 0.86, 0), Color(0.24, 0.28, 0.22))
	for leg in [leg_left, leg_right]:
		K.box(leg, Vector3(0.2, 0.12, 0.32), Vector3(0, -0.76, 0.07), K.INK)

	_shirt_mat = StandardMaterial3D.new()
	_shirt_mat.albedo_color = Color(0.78, 0.72, 0.55)
	_shirt_mat.roughness = 0.95
	var torso := K.box(rig, Vector3(0.58, 0.72, 0.38), Vector3(0, 1.3, 0), Color.WHITE)
	torso.material_override = _shirt_mat
	K.box(rig, Vector3(0.62, 0.1, 0.42), Vector3(0, 0.95, 0), K.WOOD_DARK)

	_apron_mat = StandardMaterial3D.new()
	_apron_mat.albedo_color = Color(0.88, 0.83, 0.7)
	_apron_mat.roughness = 0.95
	K.box(rig, Vector3(0.46, 0.72, 0.05), Vector3(0, 1.06, 0.21), Color.WHITE, Vector3.ZERO, _apron_mat)

	head = Node3D.new()
	head.position = Vector3(0, 1.75, 0)
	rig.add_child(head)
	K.sphere(head, 0.225, Vector3.ZERO, Color(0.66, 0.46, 0.33))
	K.box(head, Vector3(0.09, 0.1, 0.12), Vector3(0, -0.01, 0.21), Color(0.6, 0.4, 0.29))
	for side in [-1.0, 1.0]:
		K.box(head, Vector3(0.045, 0.045, 0.02), Vector3(side * 0.08, 0.06, 0.21), K.INK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(head, Vector3(0.17, 0.035, 0.02), Vector3(0, -0.1, 0.21), Color(0.38, 0.22, 0.17)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	arm_left = _limb(rig, Vector3(-0.37, 1.5, 0), Color(0.74, 0.62, 0.46))
	arm_right = _limb(rig, Vector3(0.37, 1.5, 0), Color(0.74, 0.62, 0.46))

	# Rank one: straw cap, broom, small satchel.
	straw_cap = Node3D.new()
	straw_cap.position = Vector3(0, 1.93, 0)
	head.add_child(straw_cap)
	_cap_mat = StandardMaterial3D.new()
	_cap_mat.albedo_color = Color(0.86, 0.68, 0.32)
	_cap_mat.roughness = 1.0
	K.cylinder(straw_cap, 0.23, 0.11, Vector3.ZERO, Color.WHITE, Vector3.ZERO, 12).material_override = _cap_mat
	K.box(straw_cap, Vector3(0.5, 0.04, 0.38), Vector3(0, -0.02, 0.1), Color.WHITE, Vector3.ZERO, _cap_mat).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	broom = Node3D.new()
	broom.position = Vector3(0.22, 1.15, -0.28)
	broom.rotation = Vector3(0.15, 0, -0.42)
	rig.add_child(broom)
	K.cylinder(broom, 0.025, 1.5, Vector3(0, 0, 0), K.WOOD, Vector3.ZERO, 5)
	K.box(broom, Vector3(0.3, 0.26, 0.1), Vector3(0, -0.82, 0), K.OCHRE)
	for i in 4:
		K.box(broom, Vector3(0.06, 0.16, 0.02), Vector3(-0.12 + i * 0.08, -0.96, 0), K.OCHRE).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	satchel = Node3D.new()
	satchel.position = Vector3(0.36, 1.0, -0.16)
	rig.add_child(satchel)
	K.box(satchel, Vector3(0.3, 0.32, 0.18), Vector3.ZERO, Color(0.47, 0.36, 0.24))
	K.box(satchel, Vector3(0.34, 0.09, 0.21), Vector3(0, 0.18, 0), K.WOOD_DARK)
	K.box(rig, Vector3(0.05, 0.72, 0.04), Vector3(0.32, 1.32, 0.14), K.WOOD_DARK, Vector3(0, 0, -0.28))

	# Rank two: teal baron coat, flat cap, brass buttons, bigger grip.
	flat_cap = Node3D.new()
	flat_cap.position = Vector3(0, 1.91, 0)
	head.add_child(flat_cap)
	K.cylinder(flat_cap, 0.235, 0.09, Vector3(0, 0.01, 0), K.TEAL_DARK, Vector3.ZERO, 12)
	K.box(flat_cap, Vector3(0.47, 0.03, 0.32), Vector3(0, -0.03, 0.12), K.TEAL_DARK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	coat_tails = Node3D.new()
	rig.add_child(coat_tails)
	K.box(coat_tails, Vector3(0.28, 0.58, 0.06), Vector3(-0.16, 0.68, -0.2), K.TEAL_DARK, Vector3(0.12, 0, 0))
	K.box(coat_tails, Vector3(0.28, 0.58, 0.06), Vector3(0.16, 0.68, -0.2), K.TEAL_DARK, Vector3(0.12, 0, 0))

	buttons = Node3D.new()
	rig.add_child(buttons)
	for i in 3:
		K.sphere(buttons, 0.032, Vector3(0.16, 1.18 + i * 0.18, 0.2), K.OCHRE).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	scarf = Node3D.new()
	rig.add_child(scarf)
	K.box(scarf, Vector3(0.5, 0.14, 0.4), Vector3(0, 1.58, 0), K.CORAL)
	K.box(scarf, Vector3(0.16, 0.42, 0.05), Vector3(0.18, 1.34, 0.2), K.CORAL, Vector3(0, 0, 0.1))

	# Vacuum rig and hose.
	tank = Node3D.new()
	tank.position = Vector3(0, 1.25, -0.32)
	rig.add_child(tank)
	K.box(tank, Vector3(0.4, 0.52, 0.22), Vector3.ZERO, Color(0.55, 0.6, 0.57))
	K.cylinder(tank, 0.13, 0.42, Vector3(0, 0.05, -0.17), K.CORAL, Vector3.ZERO, 8)
	K.cylinder(tank, 0.15, 0.04, Vector3(0, 0.3, -0.17), K.INK, Vector3.ZERO, 8)
	var hose_a := K.cylinder(rig, 0.035, 0.55, Vector3(0.34, 1.35, -0.12), K.INK, Vector3.ZERO, 5)
	hose_a.rotation = Vector3(0.5, 0, -0.4)
	for i in 3:
		var t := float(i) / 2.0
		K.cylinder(rig, 0.03, 0.26, Vector3(0.4 - t * 0.02, 1.05 - t * 0.1, 0.1 + t * 0.16), K.INK, Vector3(1.1, 0, 0.1), 5).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var nozzle := K.cone(rig, 0.06, 0.12, 0.24, Vector3(0.42, 0.88, 0.44), K.CORAL, Vector3(1.35, 0, 0), 8)
	nozzle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	stack_anchor = Node3D.new()
	stack_anchor.position = Vector3(0, 1.22, 0.2)
	rig.add_child(stack_anchor)

	# The soft suction cone is only visible while the rig is running.
	_cone_mat = StandardMaterial3D.new()
	_cone_mat.albedo_color = Color(0.55, 0.86, 0.8, 0.16)
	_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_mat.no_depth_test = false
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 1.35
	cone_mesh.bottom_radius = 0.06
	cone_mesh.height = 3.0
	cone_mesh.radial_segments = 16
	cone_mesh.rings = 1
	vacuum_cone = MeshInstance3D.new()
	vacuum_cone.mesh = cone_mesh
	vacuum_cone.material_override = _cone_mat
	vacuum_cone.position = Vector3(0, 1.0, 1.65)
	vacuum_cone.rotation.x = PI / 2.0
	vacuum_cone.visible = false
	vacuum_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(vacuum_cone)

	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.18
	ring_mesh.outer_radius = 1.36
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 6
	vacuum_ring = MeshInstance3D.new()
	vacuum_ring.mesh = ring_mesh
	vacuum_ring.material_override = K.clear_material(Color(0.6, 0.95, 0.86), 0.5)
	vacuum_ring.position = Vector3(0, 1.0, 3.1)
	vacuum_ring.rotation.x = PI / 2.0
	vacuum_ring.visible = false
	vacuum_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(vacuum_ring)

	set_rank(1)


func _limb(parent: Node3D, pivot: Vector3, color: Color) -> Node3D:
	var node := Node3D.new()
	node.position = pivot
	parent.add_child(node)
	K.box(node, Vector3(0.15, 0.62, 0.16), Vector3(0, -0.3, 0), color)
	K.sphere(node, 0.1, Vector3(0, -0.66, 0), Color(0.68, 0.48, 0.34))
	return node


func set_rank(value: int) -> void:
	rank = value
	max_stack = 1 if rank == 1 else 3
	if rank == 1:
		_shirt_mat.albedo_color = Color(0.78, 0.72, 0.55)
		_apron_mat.albedo_color = Color(0.88, 0.83, 0.7)
		if straw_cap:
			straw_cap.visible = true
		if flat_cap:
			flat_cap.visible = false
		if broom:
			broom.visible = true
		if coat_tails:
			coat_tails.visible = false
		if buttons:
			buttons.visible = false
		if scarf:
			scarf.visible = false
		if satchel:
			satchel.scale = Vector3.ONE
		if tank:
			tank.scale = Vector3.ONE
	else:
		_shirt_mat.albedo_color = K.TEAL
		_apron_mat.albedo_color = K.TEAL_DARK
		if straw_cap:
			straw_cap.visible = false
		if flat_cap:
			flat_cap.visible = true
		if broom:
			broom.visible = false
		if coat_tails:
			coat_tails.visible = true
		if buttons:
			buttons.visible = true
		if scarf:
			scarf.visible = true
		if satchel:
			satchel.scale = Vector3(1.25, 1.2, 1.2)
		if tank:
			tank.scale = Vector3(1.15, 1.15, 1.15)


func _physics_process(delta: float) -> void:
	slip_timer = maxf(0.0, slip_timer - delta)
	var input := Vector2.ZERO
	if not locked:
		input = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		if touch_input.length() > 0.05:
			input = touch_input
	var wish := Vector3.ZERO
	if input.length() > 0.04:
		var camera := get_viewport().get_camera_3d()
		if camera:
			var forward := -camera.global_transform.basis.z
			forward.y = 0.0
			forward = forward.normalized()
			var right := camera.global_transform.basis.x
			right.y = 0.0
			right = right.normalized()
			wish = (right * input.x + forward * input.y).normalized()
	is_moving = wish.length() > 0.05 and not locked

	var sprinting := (Input.is_action_pressed("sprint") or touch_sprint) and is_moving and slip_timer < 0.1
	var target_speed := (SPRINT_SPEED if sprinting else BASE_SPEED) + speed_bonus
	target_speed *= 1.0 - minf(0.18, stack.size() * 0.055)
	if slip_timer > 0.0:
		target_speed *= 0.32
		wish *= 0.35
	if locked:
		target_speed = 0.0
		wish = Vector3.ZERO

	if wish.length() > 0.05:
		velocity.x = move_toward(velocity.x, wish.x * target_speed, ACCEL * delta)
		velocity.z = move_toward(velocity.z, wish.z * target_speed, ACCEL * delta)
		if slip_timer < 0.1:
			var target_yaw := atan2(wish.x, wish.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, TURN * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ACCEL * 0.75 * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCEL * 0.75 * delta)

	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= 22.0 * delta
	move_and_slide()

	_update_wobble(delta)
	_update_animation(delta, sprinting)


func _update_wobble(delta: float) -> void:
	var accel := (velocity - _prev_velocity) / maxf(delta, 0.001)
	_prev_velocity = velocity
	var local := global_transform.basis.inverse() * accel
	var turn := angle_difference(_prev_yaw, rotation.y) / maxf(delta, 0.001)
	_prev_yaw = rotation.y
	var target := Vector2.ZERO
	if stack.size() > 0:
		target.x = clampf(-local.z * 0.011, -0.65, 0.65)
		target.y = clampf(-turn * 0.055, -0.65, 0.65)
		if slip_timer > 0.0:
			target += Vector2(0.35, 0.45)
	lean = lean.lerp(target, minf(1.0, delta * 7.0))
	stack_anchor.rotation = Vector3(lean.x, 0, lean.y)
	if stack.size() > 0 and lean.length() > 0.5 and velocity.length() > 2.0:
		wobble += delta
	else:
		wobble = maxf(0.0, wobble - delta * 1.6)
	if wobble > 0.55:
		wobble = 0.0
		var item: Node3D = stack.pop_back()
		if item:
			emit_signal("stack_tumbled", item)
			_refresh_stack()


func _update_animation(delta: float, sprinting: bool) -> void:
	var planar := Vector2(velocity.x, velocity.z).length()
	var rate := 5.0 + planar * 1.15
	_anim += delta * rate
	var swing := sin(_anim) * clampf(planar / 5.0, 0.0, 1.0) * (0.62 if sprinting else 0.5)
	leg_left.rotation.x = swing
	leg_right.rotation.x = -swing
	arm_left.rotation.x = -swing * 0.8
	arm_right.rotation.x = swing * 0.8
	rig.position.y = absf(sin(_anim * 2.0)) * 0.035 * clampf(planar / 5.0, 0.0, 1.0)
	rig.rotation.z = sin(_anim) * 0.012 * clampf(planar / 5.0, 0.0, 1.0)
	head.rotation.y = 0.0

	if slip_timer > 0.0:
		rig.rotation.z = sin(slip_timer * 28.0) * 0.24
		arm_left.rotation.x = -2.2 + sin(slip_timer * 22.0) * 0.6
		arm_right.rotation.x = -2.0 - sin(slip_timer * 22.0) * 0.5
	elif vacuuming:
		rig.rotation.x = 0.1
		arm_right.rotation.x = -1.25
		arm_left.rotation.x = -0.3
	elif stack.size() > 0:
		rig.rotation.x = -0.06 - stack.size() * 0.03
		arm_left.rotation.x = -2.35
		arm_right.rotation.x = -2.35
	else:
		rig.rotation.x = lerpf(rig.rotation.x, 0.0, 8.0 * delta)

	if vacuuming:
		rig.rotation.x = 0.1
		arm_right.rotation.x = -1.25
		vacuum_cone.visible = true
		vacuum_ring.visible = true
		_cone_mat.albedo_color = Color(0.55, 0.86, 0.8, 0.12 + sin(_anim * 6.0) * 0.035)
		vacuum_ring.rotation.z += delta * 2.0
	else:
		vacuum_cone.visible = false
		vacuum_ring.visible = false


func add_to_stack(item: Node3D) -> void:
	item.reparent(stack_anchor, false)
	stack.append(item)
	item.rotation = Vector3.ZERO
	item.position = Vector3(0.0, 0.02 + (stack.size() - 1) * 0.62, 0.0)
	item.scale = Vector3(0.92, 0.92, 0.92)
	item.set_process(false)
	_refresh_stack()


func take_stack() -> Array[Node3D]:
	var items: Array[Node3D] = []
	while stack.size() > 0:
		items.append(stack.pop_back())
	_refresh_stack()
	return items


func _refresh_stack() -> void:
	for i in stack.size():
		stack[i].position = Vector3(0.0, 0.02 + i * 0.62, 0.0)


func face_direction(direction: Vector3, delta: float) -> void:
	if direction.length() < 0.05:
		return
	var flat := Vector3(direction.x, 0, direction.z).normalized()
	rotation.y = lerp_angle(rotation.y, atan2(flat.x, flat.z), minf(1.0, delta * 14.0))


func apply_slip() -> void:
	if slip_timer > 0.2:
		return
	slip_timer = 1.15
	lean += Vector2(0.3, 0.4)
	emit_signal("slipped")


func stack_count() -> int:
	return stack.size()


func stack_names() -> Array[String]:
	var names: Array[String] = []
	for item in stack:
		names.append(str(item.get("display")))
	return names


func reset_player(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	rotation.y = PI
	lean = Vector2.ZERO
	wobble = 0.0
	slip_timer = 0.0
	vacuuming = false
	for item in stack:
		item.queue_free()
	stack.clear()
	_refresh_stack()
