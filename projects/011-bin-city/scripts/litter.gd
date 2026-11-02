extends Node3D

const K = preload("res://scripts/kit.gd")

var display := "Litter"
var kind := ""
var sort_kind := "paper"
var tint := Color(0.9, 0.88, 0.8)
var weight := 1.0
var heavy := false
var floating := false
var collected := false
var spin_speed := 2.0
var _pull_target := Vector3.ZERO
var _pulling := false
var _pull_time := 0.0
var _vx := 0.0
var _bob := 0.0
var _base_y := 0.0


func build(kind: String, rng: RandomNumberGenerator) -> void:
	self.kind = kind
	rotation.y = rng.randf_range(0.0, TAU)
	_bob = rng.randf_range(0.0, TAU)
	match kind:
		"paper":
			display = ["Wax paper", "Market flyer", "Receipt"][rng.randi_range(0, 2)]
			sort_kind = "paper"
			tint = Color(0.94, 0.92, 0.84)
			_paper(rng)
		"cup":
			display = "Paper cup"
			sort_kind = "paper"
			tint = Color(0.96, 0.93, 0.86)
			_cup(rng)
		"carton":
			display = "Juice carton"
			sort_kind = "paper"
			tint = Color(0.86, 0.79, 0.62)
			_carton(rng)
		"can":
			display = "Tin can"
			sort_kind = "metal"
			tint = Color(0.62, 0.66, 0.68)
			_can(rng)
		"bottle":
			display = "Glass bottle"
			sort_kind = "glass"
			tint = Color(0.33, 0.55, 0.4)
			_bottle(rng)
		"leaf":
			display = ["Cabbage leaf", "Orange peel"][rng.randi_range(0, 1)]
			sort_kind = "compost"
			tint = Color(0.55, 0.58, 0.28)
			_leaf(rng)
		"bag":
			display = "Crumpled bag"
			sort_kind = "paper"
			tint = Color(0.9, 0.88, 0.8)
			_bag(rng)
		"crate":
			display = "Produce crate"
			heavy = true
			weight = 5.0
			_crate(rng)
		"barrel":
			display = "Rain barrel"
			heavy = true
			weight = 6.0
			_barrel(rng)
		"sack":
			display = "Grain sack"
			heavy = true
			weight = 5.0
			_sack(rng)
		"tyre":
			display = "Old tyre"
			heavy = true
			weight = 6.0
			_tyre(rng)
		"planks":
			display = "Plank stack"
			heavy = true
			weight = 5.0
			_planks(rng)
		"float_bottle":
			display = "Canal bottle"
			sort_kind = "glass"
			tint = Color(0.4, 0.62, 0.48)
			floating = true
			weight = 1.2
			_float_bottle(rng)
		"float_bag":
			display = "Waterlogged bag"
			sort_kind = "paper"
			tint = Color(0.84, 0.84, 0.78)
			floating = true
			_float_bag(rng)
		"bottle_cap":
			display = "Bottle cap"
			sort_kind = "metal"
			tint = Color(0.66, 0.3, 0.24)
			floating = true
			weight = 0.6
			_cap(rng)
		"grime":
			display = "Drain grime"
			sort_kind = "compost"
			tint = Color(0.3, 0.28, 0.22)
			weight = 1.5
			_grime(rng)
		"token":
			display = "Arcade token"
			sort_kind = "metal"
			tint = Color(0.95, 0.78, 0.25)
			weight = 0.5
			_token(rng)
		_:
			display = "Litter"
			_paper(rng)
	scale = Vector3.ONE * rng.randf_range(0.92, 1.1)
	if heavy:
		# Heavy items are the props the player handles most, so they get the
		# ink outline that marks key objects in the toon look.
		K.apply_toon(self, 0.05)
	if floating:
		set_process(true)


func _paper(rng: RandomNumberGenerator) -> void:
	var tint := Color(0.94, 0.92, 0.84).lerp(Color(0.86, 0.8, 0.65), rng.randf())
	var sheet := K.box(self, Vector3(0.34, 0.015, 0.27), Vector3(0, 0.02, 0), tint, Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.3, 0.3)))
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(self, Vector3(0.2, 0.006, 0.02), Vector3(0, 0.031, 0.02), K.INK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _cup(rng: RandomNumberGenerator) -> void:
	rotation.z = rng.randf_range(-1.3, 1.3)
	var cup := K.cone(self, 0.075, 0.055, 0.14, Vector3(0, 0.07, 0), Color(0.96, 0.93, 0.86), Vector3.ZERO, 9)
	cup.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var band := K.cylinder(self, 0.072, 0.05, Vector3(0, 0.07, 0), K.CORAL, Vector3.ZERO, 9)
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _carton(rng: RandomNumberGenerator) -> void:
	K.box(self, Vector3(0.12, 0.2, 0.09), Vector3(0, 0.1, 0), Color(0.86, 0.79, 0.62), Vector3(0, 0, rng.randf_range(-0.4, 0.4)))
	K.box(self, Vector3(0.13, 0.06, 0.1), Vector3(0, 0.21, 0), Color(0.6, 0.32, 0.26)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _can(rng: RandomNumberGenerator) -> void:
	var color: Color = [Color(0.72, 0.24, 0.2), Color(0.27, 0.44, 0.6), Color(0.42, 0.55, 0.3)][rng.randi_range(0, 2)]
	var body := K.cylinder(self, 0.055, 0.15, Vector3(0, 0.075, 0), color, Vector3(0, 0, 1.57), 9)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.cylinder(self, 0.05, 0.012, Vector3(0.077, 0.075, 0), K.METAL, Vector3(0, 0, 1.57), 9).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _bottle(rng: RandomNumberGenerator) -> void:
	rotation.z = rng.randf_range(0.7, 1.4)
	K.cylinder(self, 0.055, 0.24, Vector3(0, 0.12, 0), Color(0.33, 0.55, 0.4), Vector3.ZERO, 9)
	K.cylinder(self, 0.024, 0.08, Vector3(0, 0.28, 0), Color(0.33, 0.55, 0.4), Vector3.ZERO, 7)
	K.cylinder(self, 0.028, 0.025, Vector3(0, 0.325, 0), K.OCHRE, Vector3.ZERO, 7)


func _leaf(rng: RandomNumberGenerator) -> void:
	var color := Color(0.5, 0.58, 0.28) if rng.randf() > 0.5 else Color(0.72, 0.44, 0.2)
	K.box(self, Vector3(0.26, 0.012, 0.18), Vector3(0, 0.02, 0), color, Vector3(0, 0, rng.randf_range(0, TAU))).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _bag(rng: RandomNumberGenerator) -> void:
	var bag := K.sphere(self, 0.16, Vector3(0, 0.14, 0), Color(0.92, 0.9, 0.82), Vector3(1.1, 0.8, 0.9))
	bag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.cone(self, 0.02, 0.05, 0.09, Vector3(0, 0.29, 0), Color(0.85, 0.83, 0.76), Vector3.ZERO, 6)


func _crate(rng: RandomNumberGenerator) -> void:
	K.box(self, Vector3(0.84, 0.6, 0.66), Vector3(0, 0.3, 0), K.WOOD)
	K.box(self, Vector3(0.88, 0.08, 0.7), Vector3(0, 0.62, 0), K.WOOD_DARK)
	for x in [-0.36, 0.36]:
		K.box(self, Vector3(0.06, 0.56, 0.7), Vector3(x, 0.3, 0), K.WOOD_DARK).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 4:
		K.sphere(self, 0.11, Vector3(-0.25 + (i % 2) * 0.5, 0.7, -0.16 + (i / 2.0) * 0.32), [K.CORAL, K.OCHRE, K.OLIVE][rng.randi_range(0, 2)]).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _barrel(rng: RandomNumberGenerator) -> void:
	K.cylinder(self, 0.32, 0.86, Vector3(0, 0.43, 0), Color(0.56, 0.38, 0.25), Vector3.ZERO, 12)
	K.cylinder(self, 0.335, 0.06, Vector3(0, 0.22, 0), K.INK, Vector3.ZERO, 12).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.cylinder(self, 0.335, 0.06, Vector3(0, 0.66, 0), K.INK, Vector3.ZERO, 12).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.cylinder(self, 0.275, 0.02, Vector3(0, 0.87, 0), K.INK, Vector3.ZERO, 12)


func _sack(rng: RandomNumberGenerator) -> void:
	K.sphere(self, 0.34, Vector3(0, 0.32, 0), Color(0.76, 0.66, 0.48), Vector3(1, 1.15, 0.9))
	K.cone(self, 0.03, 0.12, 0.22, Vector3(0, 0.73, 0), Color(0.7, 0.6, 0.43), Vector3.ZERO, 6)
	K.box(self, Vector3(0.2, 0.05, 0.05), Vector3(0, 0.68, 0), K.WOOD_DARK)


func _tyre(rng: RandomNumberGenerator) -> void:
	var t := K.torus(self, 0.26, 0.46, Vector3(0, 0.12, 0), Color(0.16, 0.16, 0.16), Vector3.ZERO)
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.cylinder(self, 0.24, 0.1, Vector3(0, 0.12, 0), Color(0.45, 0.45, 0.43), Vector3.ZERO, 12)


func _planks(rng: RandomNumberGenerator) -> void:
	for i in 4:
		K.box(self, Vector3(1.0, 0.06, 0.22), Vector3(0.02 * i, 0.05 + i * 0.065, 0.0), K.WOOD if i % 2 == 0 else Color(0.64, 0.46, 0.3), Vector3(0, rng.randf_range(-0.08, 0.08), 0))


func _float_bottle(rng: RandomNumberGenerator) -> void:
	_base_y = -0.52
	position.y = _base_y
	var body := K.cylinder(self, 0.055, 0.26, Vector3(0, 0.03, 0), Color(0.4, 0.62, 0.48), Vector3(PI / 2.0 + rng.randf_range(-0.2, 0.2), 0, 0), 9)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.cylinder(self, 0.026, 0.07, Vector3(0.15, 0.05, 0), Color(0.4, 0.62, 0.48), Vector3(PI / 2.0, 0, 0), 7).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.cylinder(self, 0.03, 0.025, Vector3(0.19, 0.05, 0), K.OCHRE, Vector3(PI / 2.0, 0, 0), 7).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _float_bag(rng: RandomNumberGenerator) -> void:
	_base_y = -0.5
	position.y = _base_y
	var bag := K.sphere(self, 0.18, Vector3(0, -0.02, 0), Color(0.84, 0.84, 0.78), Vector3(1.2, 0.55, 0.9))
	bag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.cone(self, 0.02, 0.05, 0.1, Vector3(0.05, 0.1, 0), Color(0.8, 0.8, 0.74), Vector3(rng.randf_range(-0.4, 0.4), 0, 0), 6).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _cap(rng: RandomNumberGenerator) -> void:
	_base_y = -0.54
	position.y = _base_y
	var cap := K.cylinder(self, 0.07, 0.02, Vector3(0, 0.0, 0), Color(0.66, 0.3, 0.24), Vector3(PI / 2.0, 0, rng.randf()), 10)
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.cylinder(self, 0.055, 0.012, Vector3(0.02, 0.01, 0), Color(0.72, 0.36, 0.28), Vector3(PI / 2.0, 0, 0), 10).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _grime(rng: RandomNumberGenerator) -> void:
	var mound := K.sphere(self, 0.3, Vector3(0, 0.08, 0), Color(0.3, 0.28, 0.22), Vector3(1.4, 0.4, 1.1))
	mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 6:
		var angle := rng.randf_range(0.0, TAU)
		var speck := K.sphere(self, 0.05, Vector3(cos(angle) * 0.28, 0.1, sin(angle) * 0.22), [Color(0.42, 0.36, 0.2), Color(0.24, 0.24, 0.2), Color(0.5, 0.44, 0.28)][i % 3], Vector3(1, 0.6, 1))
		speck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.box(self, Vector3(0.34, 0.01, 0.24), Vector3(0, 0.16, 0), Color(0.22, 0.21, 0.17)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _token(rng: RandomNumberGenerator) -> void:
	var coin := K.cylinder(self, 0.14, 0.035, Vector3(0, 0.06, 0), Color(0.95, 0.78, 0.25), Vector3(PI / 2.0, 0, rng.randf() * TAU), 14)
	coin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var face_mat := K.material(Color(0.95, 0.78, 0.25), 0.35, 0.75, Color(1.0, 0.82, 0.3), 0.55)
	coin.material_override = face_mat
	K.box(self, Vector3(0.16, 0.012, 0.045), Vector3(0, 0.06, 0.0), Color(1.0, 0.9, 0.5), Vector3(0, 0, 0.0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spin_speed = 3.2


func pull(toward: Vector3, delta: float) -> void:
	if not _pulling:
		_pulling = true
		set_process(true)
	_pull_target = toward
	_pull_time += delta
	var flat := Vector3(_pull_target.x, 0.0, _pull_target.z)
	var distance := Vector2(position.x - flat.x, position.z - flat.z).length()
	var dir := Vector3(_pull_target.x - position.x, 0.0, _pull_target.z - position.z).normalized()
	var speed := 8.0 + minf(_pull_time, 1.2) * 6.0
	position += dir * speed * delta
	position.y = 0.35 + absf(sin(_pull_time * 9.0)) * 0.22 + minf(0.7, _pull_time * 0.5)
	rotation.y += spin_speed * delta * 2.5
	rotation.x = sin(_pull_time * 8.0) * 0.35
	scale = Vector3.ONE * maxf(0.35, 1.0 - _pull_time * 0.25)


func _process(delta: float) -> void:
	if _pulling:
		return
	if floating and not collected:
		_bob += delta
		position.y = _base_y + sin(_bob * 1.4) * 0.04
		rotation.y += 0.12 * delta
		return
	set_process(false)
