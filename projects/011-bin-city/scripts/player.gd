extends CharacterBody3D

signal stack_tumbled(item: Node3D)
signal slipped
signal jumped(double_jump: bool)
signal landed(hard: bool)
signal dash_started
signal pulse_requested(origin: Vector3, radius: float)

const K = preload("res://scripts/kit.gd")
const Data = preload("res://scripts/data.gd")

const BASE_SPEED := 5.3
const SPRINT_SPEED := 7.0
const ACCEL := 24.0
const TURN := 12.0
const JUMP_SPEED := 7.1
const GRAVITY := 22.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.14
const DASH_SPEED := 15.5
const DASH_TIME := 0.18
const DASH_COOLDOWN := 0.85
const GLIDE_FALL := -2.6
const PULSE_RADIUS := 4.2
const PULSE_COOLDOWN := 6.0

var locked := true
var traction := 1.0
var rank := 1
var max_stack := 1
var speed_bonus := 0.0
var vacuum_radius := 2.2
var slip_timer := 0.0
var vacuuming := false
var touch_input := Vector2.ZERO
var touch_sprint := false
var touch_jump := false
var touch_dash := false
var touch_pulse := false
var stack: Array[Node3D] = []
var lean := Vector2.ZERO
var wobble := 0.0
var is_moving := false
var can_magnet := false
var can_dash := false
var can_double_jump := false
var can_glide := false
var can_pulse := false
var is_gliding := false
var dash_ready := true
var pulse_ready := true
var _coyote := 0.0
var _jump_buffer := 0.0
var _jumps_used := 0
var _air_time := 0.0
var _was_on_floor := true
var _dash_timer := 0.0
var _dash_cooldown := 0.0
var _dash_dir := Vector3.ZERO
var _pulse_cooldown := 0.0
var _jump_held := false
var _dash_held := false
var _pulse_held := false

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
var plate_armour: Node3D
var magnet_gauntlet: Node3D
var wheel_rig: Node3D
var cap_crown: Node3D
var cape: Node3D
var turbine: Node3D
var orbit_bins: Node3D
var visor: Node3D
var comet_broom: Node3D
var halo: Node3D
var ground_aura: MeshInstance3D
var _shirt_mat: StandardMaterial3D
var _apron_mat: StandardMaterial3D
var _cap_mat: StandardMaterial3D
var _anim := 0.0
var _prev_velocity := Vector3.ZERO
var _prev_yaw := 0.0
var _cone_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var rank_parts: Dictionary = {}


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

	_build_rank_parts()
	set_rank(1)


func _build_rank_parts() -> void:
	# Rank three: sign plate armour, a magnet gauntlet and a cart rig.
	plate_armour = Node3D.new()
	rig.add_child(plate_armour)
	for side in [-1.0, 1.0]:
		K.box(plate_armour, Vector3(0.26, 0.13, 0.36), Vector3(side * 0.38, 1.63, 0.0), K.METAL)
		K.box(plate_armour, Vector3(0.19, 0.17, 0.06), Vector3(side * 0.165, 0.6, 0.06), K.METAL)
	K.box(plate_armour, Vector3(0.42, 0.34, 0.06), Vector3(0, 1.37, 0.215), K.METAL)
	K.box(plate_armour, Vector3(0.3, 0.07, 0.07), Vector3(0, 1.46, 0.22), K.CORAL)

	magnet_gauntlet = Node3D.new()
	magnet_gauntlet.position = Vector3(0, -0.58, 0)
	arm_right.add_child(magnet_gauntlet)
	var ring := K.torus(magnet_gauntlet, 0.09, 0.17, Vector3.ZERO, K.CORAL)
	ring.rotation.x = PI / 2.0
	for i in 3:
		var a := TAU * float(i) / 3.0
		K.sphere(magnet_gauntlet, 0.035, Vector3(cos(a) * 0.13, 0, sin(a) * 0.13), K.OCHRE).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	wheel_rig = Node3D.new()
	rig.add_child(wheel_rig)
	for side in [-1.0, 1.0]:
		var wheel := K.cylinder(wheel_rig, 0.22, 0.11, Vector3(side * 0.34, 0.36, -0.3), K.INK, Vector3(0, 0, PI / 2.0), 12)
		wheel.scale = Vector3(1, 1, 1)
		K.cylinder(wheel_rig, 0.08, 0.13, Vector3(side * 0.34, 0.36, -0.3), K.METAL, Vector3(0, 0, PI / 2.0), 8)
		K.box(wheel_rig, Vector3(0.05, 0.42, 0.05), Vector3(side * 0.28, 0.6, -0.32), K.WOOD_DARK, Vector3(0.3, 0, 0))

	# Rank four: a bottle cap crown, a tarpaulin cape and twin turbines.
	cap_crown = Node3D.new()
	cap_crown.position = Vector3(0, 0.2, 0)
	head.add_child(cap_crown)
	for i in 5:
		var a := TAU * float(i) / 5.0
		var cap := K.cylinder(cap_crown, 0.055, 0.035, Vector3(cos(a) * 0.19, 0, sin(a) * 0.19), K.OCHRE if i % 2 == 0 else K.METAL, Vector3(0.2 * cos(a), 0, 0.2 * sin(a)), 8)
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	cape = Node3D.new()
	cape.position = Vector3(0, 1.3, -0.25)
	cape.rotation.x = -0.16
	rig.add_child(cape)
	K.quad(cape, Vector2(1.02, 1.28), Vector3.ZERO, K.PLUM, Vector3.ZERO, true).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.quad(cape, Vector2(0.2, 1.26), Vector3(0, 0, -0.004), K.CORAL, Vector3.ZERO, true).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	turbine = Node3D.new()
	tank.add_child(turbine)
	for side in [-1.0, 1.0]:
		K.cylinder(turbine, 0.07, 0.1, Vector3(side * 0.11, 0.08, -0.3), K.METAL, Vector3(PI / 2.0, 0, 0), 8)
		K.cylinder(turbine, 0.03, 0.14, Vector3(side * 0.11, 0.08, -0.3), K.OCHRE, Vector3(PI / 2.0, 0, 0), 6)

	# Rank five: orbit bins, a cyan visor and a comet broom.
	orbit_bins = Node3D.new()
	orbit_bins.position = Vector3(0, 1.86, 0)
	rig.add_child(orbit_bins)
	var bin_colors := [K.CORAL, K.TEAL, K.OCHRE]
	for i in 3:
		var a := TAU * float(i) / 3.0
		var bin := K.box(orbit_bins, Vector3(0.17, 0.17, 0.17), Vector3(cos(a) * 0.62, 0, sin(a) * 0.62), bin_colors[i])
		bin.rotation = Vector3(0.3, a, 0.2)
		bin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = Color(0.42, 0.92, 0.9)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(0.35, 0.95, 0.95)
	_glow_mat.emission_energy_multiplier = 1.6

	visor = Node3D.new()
	visor.position = Vector3(0, 0.05, 0)
	head.add_child(visor)
	var lens := K.box(visor, Vector3(0.37, 0.1, 0.05), Vector3(0, 0, 0.2), Color.WHITE)
	lens.material_override = _glow_mat
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	halo = Node3D.new()
	halo.position = Vector3(0, 0.43, 0)
	head.add_child(halo)
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color(0.5, 0.9, 0.88)
	halo_mat.emission_enabled = true
	halo_mat.emission = Color(0.3, 0.82, 0.86)
	halo_mat.emission_energy_multiplier = 0.7
	var halo_ring := K.torus(halo, 0.15, 0.22, Vector3.ZERO, Color.WHITE, Vector3(PI / 2.0, 0, 0))
	halo_ring.material_override = halo_mat
	halo_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 4:
		var a := TAU * float(i) / 4.0
		var spark := K.sphere(halo, 0.022, Vector3(cos(a) * 0.22, 0, sin(a) * 0.22), Color.WHITE)
		spark.material_override = halo_mat
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var emblem := K.torus(plate_armour, 0.055, 0.1, Vector3(0, 1.37, 0.25), Color.WHITE, Vector3(PI / 2.0, 0, 0))
	emblem.material_override = halo_mat
	emblem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var aura_mesh := TorusMesh.new()
	aura_mesh.inner_radius = 0.52
	aura_mesh.outer_radius = 0.6
	aura_mesh.rings = 24
	aura_mesh.ring_segments = 4
	ground_aura = MeshInstance3D.new()
	ground_aura.mesh = aura_mesh
	ground_aura.material_override = K.clear_material(Color(0.36, 0.95, 0.9), 0.34)
	ground_aura.position = Vector3(0, 0.04, 0)
	ground_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground_aura)

	comet_broom = Node3D.new()
	comet_broom.position = Vector3(0.24, 1.15, -0.3)
	comet_broom.rotation = Vector3(0.15, 0, -0.42)
	rig.add_child(comet_broom)
	K.cylinder(comet_broom, 0.025, 1.5, Vector3(0, 0, 0), K.WOOD, Vector3.ZERO, 5)
	K.box(comet_broom, Vector3(0.3, 0.26, 0.1), Vector3(0, -0.82, 0), Color.WHITE).material_override = _glow_mat
	K.torus(comet_broom, 0.1, 0.16, Vector3(0, -0.98, 0), Color.WHITE, Vector3(PI / 2.0, 0, 0)).material_override = _glow_mat

	rank_parts = {
		"plates": plate_armour, "gauntlet": magnet_gauntlet, "wheels": wheel_rig,
		"crown": cap_crown, "cape": cape, "turbine": turbine,
		"bins": orbit_bins, "visor": visor, "comet": comet_broom, "halo": halo,
	}


func _limb(parent: Node3D, pivot: Vector3, color: Color) -> Node3D:
	var node := Node3D.new()
	node.position = pivot
	parent.add_child(node)
	K.box(node, Vector3(0.15, 0.62, 0.16), Vector3(0, -0.3, 0), color)
	K.sphere(node, 0.1, Vector3(0, -0.66, 0), Color(0.68, 0.48, 0.34))
	return node


func set_rank(value: int) -> void:
	rank = clampi(value, 1, Data.RANKS.size())
	var entry: Dictionary = Data.rank_entry(rank)
	max_stack = int(entry.carry)
	speed_bonus = float(entry.speed) - BASE_SPEED
	vacuum_radius = float(entry.vacuum)
	can_magnet = rank >= 3
	can_dash = rank >= 3
	can_double_jump = rank >= 4
	can_glide = rank >= 5
	can_pulse = rank >= 5
	_apply_rank_visibility()


func _apply_rank_visibility() -> void:
	var shirt := Color(0.78, 0.72, 0.55)
	var apron := Color(0.88, 0.83, 0.7)
	match rank:
		2:
			shirt = K.TEAL
			apron = K.TEAL_DARK
		3:
			shirt = K.TEAL_DARK
			apron = K.TEAL
		4:
			shirt = K.PLUM
			apron = K.TEAL_DARK
		5:
			shirt = Color(0.16, 0.21, 0.28)
			apron = Color(0.22, 0.44, 0.46)
	_shirt_mat.albedo_color = shirt
	_apron_mat.albedo_color = apron
	straw_cap.visible = rank == 1
	flat_cap.visible = rank >= 2
	broom.visible = rank == 1
	coat_tails.visible = rank >= 2
	buttons.visible = rank >= 2
	scarf.visible = rank >= 2
	satchel.scale = Vector3.ONE if rank == 1 else Vector3(1.25, 1.2, 1.2)
	if rank >= 5:
		satchel.scale = Vector3(1.4, 1.35, 1.35)
	tank.scale = Vector3.ONE if rank == 1 else Vector3(1.15, 1.15, 1.15)
	if rank >= 4:
		tank.scale = Vector3(1.3, 1.3, 1.3)
	plate_armour.visible = rank >= 3
	magnet_gauntlet.visible = rank >= 3
	wheel_rig.visible = rank >= 3
	cap_crown.visible = rank >= 4
	cape.visible = rank >= 4
	turbine.visible = rank >= 4
	orbit_bins.visible = rank >= 5
	visor.visible = rank >= 5
	comet_broom.visible = rank >= 5
	halo.visible = rank >= 5
	ground_aura.visible = rank >= 5


func _physics_process(delta: float) -> void:
	slip_timer = maxf(0.0, slip_timer - delta)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	_pulse_cooldown = maxf(0.0, _pulse_cooldown - delta)
	dash_ready = _dash_cooldown <= 0.0
	pulse_ready = _pulse_cooldown <= 0.0

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

	var jump_pressed := Input.is_action_just_pressed("jump") or (touch_jump and not _jump_held)
	var jump_down := Input.is_action_pressed("jump") or touch_jump
	var dash_pressed := Input.is_action_just_pressed("dash") or (touch_dash and not _dash_held)
	var pulse_pressed := Input.is_action_just_pressed("pulse") or (touch_pulse and not _pulse_held)
	_jump_held = touch_jump
	_dash_held = touch_dash
	_pulse_held = touch_pulse

	var on_floor := is_on_floor()
	if on_floor:
		_coyote = COYOTE_TIME
		_jumps_used = 0
		if not _was_on_floor and _air_time > 0.18:
			emit_signal("landed", _air_time > 0.55)
			Sound.play("land", 1.0, -6.0)
		_air_time = 0.0
	else:
		_coyote = maxf(0.0, _coyote - delta)
		_air_time += delta
	_was_on_floor = on_floor

	if not locked:
		if jump_pressed:
			_jump_buffer = JUMP_BUFFER
		else:
			_jump_buffer = maxf(0.0, _jump_buffer - delta)
		var max_jumps := 2 if can_double_jump else 1
		if _jump_buffer > 0.0 and (_coyote > 0.0 or _jumps_used < max_jumps):
			var double := _jumps_used > 0 and _coyote <= 0.0
			velocity.y = JUMP_SPEED * (0.94 if double else 1.0)
			_jumps_used += 1
			_coyote = 0.0
			_jump_buffer = 0.0
			emit_signal("jumped", double)
			Sound.play("jump", 1.18 if double else 1.0, -4.0)
		if not jump_down and velocity.y > 1.5:
			velocity.y *= 0.6
		if can_dash and dash_pressed and _dash_cooldown <= 0.0 and _dash_timer <= 0.0:
			var dash_dir := wish if wish.length() > 0.05 else -global_transform.basis.z
			dash_dir.y = 0.0
			_dash_dir = dash_dir.normalized()
			_dash_timer = DASH_TIME
			_dash_cooldown = DASH_COOLDOWN
			rotation.y = atan2(_dash_dir.x, _dash_dir.z)
			emit_signal("dash_started")
			Sound.play("dash", 1.0, -3.0)
		if can_pulse and pulse_pressed and _pulse_cooldown <= 0.0:
			_pulse_cooldown = PULSE_COOLDOWN
			emit_signal("pulse_requested", global_position, PULSE_RADIUS)
			Sound.play("pulse", 1.0, -2.0)

	var sprinting := (Input.is_action_pressed("sprint") or touch_sprint) and is_moving and slip_timer < 0.1
	var target_speed := (SPRINT_SPEED if sprinting else BASE_SPEED) + speed_bonus
	target_speed *= 1.0 - minf(0.18, stack.size() * 0.055)
	target_speed *= traction
	if slip_timer > 0.0:
		target_speed *= 0.32
		wish *= 0.35
	if locked:
		target_speed = 0.0
		wish = Vector3.ZERO

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity.x = _dash_dir.x * DASH_SPEED
		velocity.z = _dash_dir.z * DASH_SPEED
		velocity.y = 0.0
	else:
		var control := 1.0 if on_floor else 0.62
		if wish.length() > 0.05:
			velocity.x = move_toward(velocity.x, wish.x * target_speed, ACCEL * control * delta)
			velocity.z = move_toward(velocity.z, wish.z * target_speed, ACCEL * control * delta)
			if slip_timer < 0.1:
				var target_yaw := atan2(wish.x, wish.z)
				rotation.y = lerp_angle(rotation.y, target_yaw, TURN * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, ACCEL * 0.75 * control * delta)
			velocity.z = move_toward(velocity.z, 0.0, ACCEL * 0.75 * control * delta)

		is_gliding = can_glide and jump_down and not on_floor and velocity.y < -1.0
		if on_floor:
			velocity.y = -0.5
		elif is_gliding:
			velocity.y = maxf(velocity.y - GRAVITY * 0.3 * delta, GLIDE_FALL)
		else:
			velocity.y -= GRAVITY * delta
	move_and_slide()

	_update_wobble(delta)
	_update_animation(delta, sprinting)


func _process(delta: float) -> void:
	if orbit_bins and orbit_bins.visible:
		orbit_bins.rotation.y += delta * 1.6
	if cape and cape.visible:
		var planar := Vector2(velocity.x, velocity.z).length()
		var target := -0.16 - clampf(planar / 8.0, 0.0, 1.0) * 0.42
		if _dash_timer > 0.0:
			target = -0.75
		cape.rotation.x = lerpf(cape.rotation.x, target, minf(1.0, delta * 6.0))
		cape.rotation.z = sin(_anim * 0.8) * 0.05
	if halo and halo.visible:
		halo.rotation.y += delta * 0.9
		halo.position.y = 0.43 + sin(_anim * 1.4) * 0.03
	if ground_aura and ground_aura.visible:
		ground_aura.rotation.y += delta * 0.5
		var planar_a := Vector2(velocity.x, velocity.z).length()
		ground_aura.scale = Vector3.ONE * (1.0 + clampf(planar_a / 10.0, 0.0, 0.7))
	ground_aura.visible = rank >= 5 and is_on_floor()
	if _glow_mat and visor and visor.visible:
		_glow_mat.emission_energy_multiplier = 1.4 + sin(_anim * 2.2) * 0.3


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

	arm_left.rotation.z = 0.0
	arm_right.rotation.z = 0.0
	if slip_timer > 0.0:
		rig.rotation.z = sin(slip_timer * 28.0) * 0.24
		arm_left.rotation.x = -2.2 + sin(slip_timer * 22.0) * 0.6
		arm_right.rotation.x = -2.0 - sin(slip_timer * 22.0) * 0.5
	elif _dash_timer > 0.0:
		rig.rotation.x = 0.34
		arm_left.rotation.x = -1.9
		arm_right.rotation.x = -1.5
		leg_left.rotation.x = 0.85
		leg_right.rotation.x = -0.45
	elif vacuuming:
		rig.rotation.x = 0.1
		arm_right.rotation.x = -1.25
		arm_left.rotation.x = -0.3
	elif not is_on_floor():
		rig.rotation.x = -0.05
		leg_left.rotation.x = 0.55
		leg_right.rotation.x = -0.28
		arm_left.rotation.x = -0.72
		arm_right.rotation.x = -0.9
		if is_gliding:
			arm_left.rotation.z = -1.3
			arm_right.rotation.z = 1.3
			rig.rotation.x = -0.18
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


func apply_shock() -> void:
	if slip_timer > 0.2:
		return
	slip_timer = 0.7
	lean += Vector2(0.42, 0.5)
	if stack.size() > 0:
		var item: Node3D = stack.pop_back()
		if item:
			emit_signal("stack_tumbled", item)
			_refresh_stack()
	emit_signal("slipped")


func ability(name: String) -> bool:
	match name:
		"sprint":
			return rank >= 2
		"magnet":
			return can_magnet
		"sort_aura":
			return can_double_jump
		"double_jump":
			return can_double_jump
		"glide":
			return can_glide
		"cleanse_pulse":
			return can_pulse
	return false


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
	traction = 1.0
	slip_timer = 0.0
	vacuuming = false
	_coyote = 0.0
	_jump_buffer = 0.0
	_jumps_used = 0
	_air_time = 0.0
	_dash_timer = 0.0
	_dash_cooldown = 0.0
	_pulse_cooldown = 0.0
	_dash_dir = Vector3.ZERO
	is_gliding = false
	dash_ready = true
	pulse_ready = true
	for item in stack:
		item.queue_free()
	stack.clear()
	_refresh_stack()
