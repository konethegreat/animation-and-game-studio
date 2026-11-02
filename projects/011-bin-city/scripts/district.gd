extends Node3D

const K = preload("res://scripts/kit.gd")

var spawn := Vector3(0.0, 0.0, 6.0)
var title := "DAWN MARKET"
var mood := "dawn"
var stations: Array[Dictionary] = []
var interiors: Array = []
var skip_pos := Vector3.ZERO
var bounds := Rect2(-20.0, -13.0, 40.0, 27.0)
var music := "market"
var ambience := "market"
var blocked: Array[Dictionary] = []
var puddles: Array[Dictionary] = []
var clean_level := 0.0
var light_count := 96
var heavy_count := 12
var pile_count := 4
var grime_count := 0


func build() -> void:
	pass


func set_clean(_value: float) -> void:
	pass


func litter_mix() -> Array:
	return [
		"paper", "paper", "cup", "carton", "can", "can", "bottle",
		"leaf", "bag", "paper", "can", "bottle", "cup", "leaf",
	]


func heavy_mix() -> Array:
	return ["crate", "barrel", "sack", "tyre", "planks"]


func pile_spots() -> Array:
	return []


func crowd_points() -> Array:
	return []


func is_free(point: Vector3) -> bool:
	if point.x < bounds.position.x + 1.0 or point.x > bounds.end.x - 1.0:
		return false
	if point.z < bounds.position.y + 1.0 or point.z > bounds.end.y - 1.0:
		return false
	for item in blocked:
		var p: Vector3 = item.pos
		if Vector2(point.x - p.x, point.z - p.z).length() < float(item.r):
			return false
	return true


func random_walkable(rng: RandomNumberGenerator) -> Vector3:
	for attempt in 80:
		var point := Vector3(
			rng.randf_range(bounds.position.x + 1.2, bounds.end.x - 1.2),
			0.0,
			rng.randf_range(bounds.position.y + 1.2, bounds.end.y - 1.2)
		)
		if is_free(point):
			return point
	return spawn


func near_puddle(point: Vector3, margin := 0.4) -> bool:
	for item in puddles:
		var center: Vector3 = item.pos
		var radius := float(item.radius) + margin
		if Vector2(point.x - center.x, point.z - center.z).length() < radius:
			return true
	return false


func add_blocker(pos: Vector3, radius: float) -> void:
	blocked.append({"pos": pos, "r": radius})


func _block(pos: Vector3, radius: float) -> void:
	add_blocker(pos, radius)
