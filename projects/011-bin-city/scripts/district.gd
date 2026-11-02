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


# Slow drifting motes across the district. Used for sunlit dust in the market
# and canal haze; cheap enough for the web build at these counts.
func add_dust(count := 36, color := Color(0.98, 0.93, 0.78), size := 1.0) -> GPUParticles3D:
	var r := bounds
	var center := Vector3(r.position.x + r.size.x * 0.5, 2.4, r.position.y + r.size.y * 0.5)
	return _motes("Dust", count, Vector3(r.size.x, 4.5, r.size.y), center, color, size, 0.16)


# Leaves that flutter down around trees and planters.
func add_leaves(count := 22) -> GPUParticles3D:
	var r := bounds
	var center := Vector3(r.position.x + r.size.x * 0.5, 4.2, r.position.y + r.size.y * 0.5)
	var leaves := _motes("Leaves", count, Vector3(r.size.x, 5.0, r.size.y), center, Color(0.62, 0.55, 0.28), 1.6, 0.1)
	var mat := leaves.process_material as ParticleProcessMaterial
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 0.35
	mat.initial_velocity_max = 0.7
	mat.gravity = Vector3(0.12, -0.55, 0.05)
	mat.angular_velocity_min = -160.0
	mat.angular_velocity_max = 160.0
	return leaves


# A puffing vent or machine stack. Puffs rise and fade.
func add_steam(pos: Vector3, count := 14) -> GPUParticles3D:
	var steam := _motes("Steam", count, Vector3(0.8, 0.5, 0.8), pos + Vector3(0, 0.3, 0), Color(0.92, 0.9, 0.86), 3.2, 0.85)
	var mat := steam.process_material as ParticleProcessMaterial
	mat.gravity = Vector3(0, 0.25, 0)
	mat.damping_min = 0.4
	mat.damping_max = 0.9
	steam.visibility_aabb = AABB(Vector3(-2.0, -0.6, -2.0), Vector3(4.0, 9.0, 4.0))
	return steam


func _motes(name: String, count: int, area: Vector3, center: Vector3, color: Color, size: float, rise: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = name
	particles.amount = count
	particles.lifetime = 7.0
	particles.position = center
	particles.visibility_aabb = AABB(-area * 0.6, area * 1.2)
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = area * 0.5
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = rise * 0.5
	mat.initial_velocity_max = rise
	mat.gravity = Vector3.ZERO
	mat.scale_min = size * 0.6
	mat.scale_max = size
	mat.color = color
	particles.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.02
	mesh.height = 0.04
	mesh.radial_segments = 4
	mesh.rings = 2
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = color
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = dm
	particles.draw_pass_1 = mesh
	add_child(particles)
	return particles


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
