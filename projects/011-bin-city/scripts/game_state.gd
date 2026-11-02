extends Node

signal rank_changed(rank: int)
signal xp_changed(xp: int, rank: int)
signal quest_changed(id: String)
signal story_changed(flag: String)
signal shift_unlocked(index: int)

const Data = preload("res://scripts/data.gd")
const SAVE_PATH := "user://bincity_save.cfg"

var save_path := SAVE_PATH
var rank := 1
var xp := 0
var shift_index := 1
var unlocked_shift := 1
var flags: Dictionary = {}
var quests: Dictionary = {}
var best_scores: Dictionary = {}
var settings := {"muted": false, "reduced_motion": false, "quality": "standard"}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if has_save():
		load_save()


func reset_new_game() -> void:
	rank = 1
	xp = 0
	shift_index = 1
	unlocked_shift = 1
	flags = {"met_nell": true}
	quests = {}
	best_scores = {}
	rank_changed.emit(rank)
	xp_changed.emit(xp, rank)


func xp_floor(value: int) -> int:
	return int(Data.rank_entry(value).xp)


func rank_for_xp(value: int) -> int:
	var result := 1
	for entry in Data.RANKS:
		if value >= int(entry.xp):
			result = int(entry.rank)
	return result


func xp_to_next_rank() -> int:
	if rank >= Data.RANKS.size():
		return 0
	return xp_floor(rank + 1)


func rank_progress() -> float:
	if rank >= Data.RANKS.size():
		return 1.0
	var floor_value := xp_floor(rank)
	var ceiling := xp_floor(rank + 1)
	return clampf(float(xp - floor_value) / float(maxi(1, ceiling - floor_value)), 0.0, 1.0)


func add_xp(amount: int) -> bool:
	xp += maxi(0, amount)
	var new_rank := rank_for_xp(xp)
	var ranked := new_rank > rank
	rank = new_rank
	xp_changed.emit(xp, rank)
	if ranked:
		rank_changed.emit(rank)
		save()
	return ranked


func set_flag(name: String) -> void:
	if has_flag(name):
		return
	flags[name] = true
	story_changed.emit(name)
	save()


func has_flag(name: String) -> bool:
	return bool(flags.get(name, false))


func unlock_shift(index: int) -> void:
	if index <= unlocked_shift:
		return
	unlocked_shift = mini(index, Data.SHIFTS.size())
	shift_unlocked.emit(unlocked_shift)
	save()


func start_quest(id: String) -> void:
	if quests.has(id) or not Data.QUESTS.has(id):
		return
	quests[id] = {"status": "active", "progress": 0, "goal": int(Data.QUESTS[id].goal), "rewarded": false}
	quest_changed.emit(id)
	save()


func advance_quest(id: String, amount := 1) -> void:
	if quest_status(id) != "active":
		return
	var entry: Dictionary = quests[id]
	entry.progress = mini(int(entry.goal), int(entry.progress) + amount)
	if int(entry.progress) >= int(entry.goal):
		_finish_quest(id, entry)
	quest_changed.emit(id)
	save()


func complete_quest(id: String) -> void:
	if quest_status(id) == "done":
		return
	if not quests.has(id):
		start_quest(id)
	if not quests.has(id):
		return
	var entry: Dictionary = quests[id]
	entry.progress = int(entry.goal)
	_finish_quest(id, entry)
	quest_changed.emit(id)
	save()


func _finish_quest(id: String, entry: Dictionary) -> void:
	entry.status = "done"
	if not bool(entry.get("rewarded", false)):
		entry.rewarded = true
		add_xp(int(Data.QUESTS[id].xp))


func quest_status(id: String) -> String:
	return str(quests.get(id, {}).get("status", "inactive"))


func reset_quest(id: String) -> void:
	quests.erase(id)
	quest_changed.emit(id)
	save()


func save() -> void:
	var config := ConfigFile.new()
	config.load(save_path)
	config.set_value("progress", "rank", rank)
	config.set_value("progress", "xp", xp)
	config.set_value("progress", "shift_index", shift_index)
	config.set_value("progress", "unlocked_shift", unlocked_shift)
	config.set_value("progress", "flags", flags)
	config.set_value("progress", "quests", quests)
	config.set_value("progress", "best_scores", best_scores)
	config.set_value("settings", "muted", bool(settings.get("muted", false)))
	config.set_value("settings", "reduced_motion", bool(settings.get("reduced_motion", false)))
	config.set_value("settings", "quality", str(settings.get("quality", "standard")))
	config.save(save_path)


func load_save() -> bool:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return false
	rank = int(config.get_value("progress", "rank", 1))
	xp = int(config.get_value("progress", "xp", 0))
	shift_index = int(config.get_value("progress", "shift_index", 1))
	unlocked_shift = int(config.get_value("progress", "unlocked_shift", 1))
	flags = config.get_value("progress", "flags", {})
	quests = config.get_value("progress", "quests", {})
	best_scores = config.get_value("progress", "best_scores", {})
	settings.muted = bool(config.get_value("settings", "muted", false))
	settings.reduced_motion = bool(config.get_value("settings", "reduced_motion", false))
	settings.quality = str(config.get_value("settings", "quality", "standard"))
	rank_changed.emit(rank)
	xp_changed.emit(xp, rank)
	return true


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
