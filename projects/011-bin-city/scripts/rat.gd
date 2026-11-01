extends Node3D

const K = preload("res://scripts/kit.gd")

var loot: Node3D
var body: Node3D
var _t := 0.0
var _step := 0.0
var carrying := false


func _ready() -> void:
	_t = randf() * 10.0
	body = Node3D.new()
	add_child(body)
	K.sphere(body, 0.22, Vector3(0, 0.26, 0), Color(0.42, 0.41, 0.4), Vector3(0.8, 0.9, 1.25))
	K.sphere(body, 0.16, Vector3(0, 0.38, 0.24), Color(0.46, 0.44, 0.42))
	K.cone(body, 0.0, 0.12, 0.14, Vector3(0, 0.5, 0.28), Color(0.42, 0.4, 0.38), Vector3(0.2, 0, 0), 6)
	for side in [-1.0, 1.0]:
		K.sphere(body, 0.055, Vector3(side * 0.1, 0.49, 0.2), Color(0.48, 0.46, 0.44), Vector3(1, 0.8, 0.6)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		K.box(body, Vector3(0.03, 0.03, 0.02), Vector3(side * 0.09, 0.4, 0.36), K.CORAL).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.cylinder(body, 0.02, 0.5, Vector3(0, 0.24, -0.38), Color(0.5, 0.43, 0.4), Vector3(PI / 2.3, 0, 0), 5)
	for i in 4:
		var foot := K.sphere(body, 0.045, Vector3(-0.12 + (i % 2) * 0.24, 0.05, -0.1 + (i / 2) * 0.2), Color(0.48, 0.44, 0.41), Vector3(1, 0.5, 1))
		foot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	loot = Node3D.new()
	loot.visible = false
	loot.position = Vector3(0, 0.56, 0.24)
	body.add_child(loot)
	K.box(loot, Vector3(0.22, 0.14, 0.16), Vector3.ZERO, Color(0.9, 0.86, 0.75))
	K.box(loot, Vector3(0.16, 0.02, 0.14), Vector3(0, 0.08, 0), K.CORAL)


func _process(delta: float) -> void:
	_t += delta
	body.position.y = absf(sin(_step * 8.0)) * 0.06
	body.rotation.z = sin(_step * 8.0) * 0.05


func set_loot(on: bool) -> void:
	carrying = on
	loot.visible = on


func walk_to(target: Vector3, delta: float, speed := 1.6) -> float:
	var flat := Vector3(target.x, 0, target.z)
	var delta_v := flat - position
	delta_v.y = 0
	var distance := delta_v.length()
	if distance > 0.05:
		var dir := delta_v.normalized()
		position += dir * minf(speed * delta, distance)
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 7.0))
		_step += delta * maxf(0.4, speed)
	return distance


func flee_from(threat: Vector3, delta: float, speed := 4.2) -> void:
	var away := position - threat
	away.y = 0
	if away.length() < 0.01:
		away = Vector3(1, 0, 0)
	away = away.normalized()
	position += away * speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(away.x, away.z), minf(1.0, delta * 10.0))
	_step += delta * speed


func spin_loot() -> void:
	loot.rotation.y += 0.2
