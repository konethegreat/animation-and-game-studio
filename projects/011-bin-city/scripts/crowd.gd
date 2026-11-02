extends Node3D

const NPC = preload("res://scripts/npc.gd")

var members: Array = []
var player_pos := Vector3.ZERO
var vacuuming := false
var _cheered_clean := false


func build(points: Array, budget: int, rng: RandomNumberGenerator, roster: Array = []) -> void:
	var roles: Array = roster
	if roles.is_empty():
		roles = ["keeper", "shopper", "shopper", "child", "pigeon", "shopper", "child", "cat", "keeper", "shopper", "pigeon", "child", "cat", "shopper"]
	for i in mini(budget, points.size()):
		var npc = NPC.new()
		npc.position = points[i]
		add_child(npc)
		npc.setup(roles[i % roles.size()], rng.randi() % 6, rng)
		members.append(npc)


func spawn(role_id: String, point: Vector3, dialogue_id: String, shown_name: String, rng: RandomNumberGenerator) -> Node3D:
	var npc = NPC.new()
	npc.position = point
	add_child(npc)
	npc.setup(role_id, rng.randi() % 6, rng)
	npc.dialogue_id = dialogue_id
	npc.display_name = shown_name
	members.append(npc)
	return npc


func update_player(pos: Vector3, is_vacuuming: bool) -> void:
	player_pos = pos
	vacuuming = is_vacuuming


func _process(delta: float) -> void:
	for npc in members:
		if not is_instance_valid(npc):
			continue
		var distance: float = npc.global_position.distance_to(player_pos)
		if distance > 48.0:
			continue
		npc.tick(delta, player_pos, vacuuming, distance)


func cheer() -> void:
	for npc in members:
		if is_instance_valid(npc):
			npc.react("cheer")


func scatter() -> void:
	for npc in members:
		if is_instance_valid(npc):
			npc.react("scare")


func watch_clean(value: float) -> void:
	if value < 0.2:
		_cheered_clean = false
		return
	if _cheered_clean or value < 0.8:
		return
	_cheered_clean = true
	cheer()


func nearest(point: Vector3, radius := 2.6):
	var best = null
	var best_distance := radius
	for npc in members:
		if not is_instance_valid(npc):
			continue
		var distance: float = npc.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = npc
	return best


func clear() -> void:
	for npc in members:
		if is_instance_valid(npc):
			npc.queue_free()
	members.clear()
