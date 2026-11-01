extends Node3D

const K = preload("res://scripts/kit.gd")

var base_weight := 12.0
var held_weight := 0.0
var _visual: Node3D
var _flies: Array[Dictionary] = []
var _t := 0.0


func _ready() -> void:
	_t = randf() * 5.0
	_visual = Node3D.new()
	add_child(_visual)
	K.cone(_visual, 0.15, 1.25, 0.9, Vector3(0, 0.45, 0), Color(0.27, 0.25, 0.22), Vector3.ZERO, 9)
	K.cone(_visual, 0.1, 0.85, 0.7, Vector3(0.3, 0.6, 0.15), Color(0.34, 0.3, 0.25), Vector3(0, 0.4, 0.15), 8)
	for i in 5:
		var angle := i * 1.3
		K.box(_visual, Vector3(0.32, 0.16, 0.26), Vector3(cos(angle) * 0.55, 0.18 + (i % 2) * 0.22, sin(angle) * 0.5), [Color(0.4, 0.34, 0.26), Color(0.48, 0.3, 0.24), Color(0.32, 0.38, 0.28)][i % 3], Vector3(0, angle, 0.2)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 3:
		var fly := K.sphere(_visual, 0.025, Vector3(0, 1.2, 0), K.INK)
		fly.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flies.append({"node": fly, "phase": i * 2.1, "radius": 0.3 + i * 0.12})


func _process(delta: float) -> void:
	_t += delta
	for fly in _flies:
		var node: MeshInstance3D = fly.node
		var phase := float(fly.phase)
		var radius := float(fly.radius)
		node.position = Vector3(cos(_t * 2.3 + phase) * radius, 1.05 + sin(_t * 3.0 + phase) * 0.2, sin(_t * 1.9 + phase) * radius)


func add_held(weight: float) -> void:
	held_weight += weight
	var grow := minf(0.5, held_weight * 0.03)
	_visual.scale = Vector3(1.0 + grow, 1.0 + grow * 0.5, 1.0 + grow)


func total_weight() -> float:
	return base_weight + held_weight
