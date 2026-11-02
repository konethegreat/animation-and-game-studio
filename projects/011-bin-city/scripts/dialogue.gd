extends Node

signal started(id: String)
signal line(speaker: String, text: String, choices: Array)
signal finished(id: String)

var TREES: Dictionary = {}
var _id := ""
var _node := "start"
var _index := -1
var _active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if TREES.is_empty():
		TREES = _build_trees()


func is_active() -> bool:
	return _active


func start(id: String) -> bool:
	if not TREES.has(id):
		return false
	_id = id
	_node = "start"
	_index = -1
	_active = true
	emit_signal("started", id)
	_next()
	return true


func advance() -> void:
	if not _active:
		return
	var current := _line_data()
	if not current.is_empty() and not current.get("choices", []).is_empty():
		return
	_next()


func choose(index: int) -> void:
	if not _active:
		return
	var current := _line_data()
	var choices: Array = current.get("choices", [])
	if index < 0 or index >= choices.size():
		return
	var choice: Dictionary = choices[index]
	_apply(choice)
	var next := str(choice.get("next", ""))
	if next == "":
		_finish()
		return
	_node = next
	_index = -1
	_next()


func _line_data() -> Dictionary:
	var data := _node_data()
	var lines: Array = data.get("lines", [])
	if _index < 0 or _index >= lines.size():
		return {}
	return lines[_index]


func _node_data() -> Dictionary:
	if not TREES.has(_id):
		return {}
	var tree: Dictionary = TREES[_id]
	if _node == "start" and tree.has("lines"):
		return tree
	if tree.has(_node):
		return tree[_node]
	return {}


func _next() -> void:
	var data := _node_data()
	var lines: Array = data.get("lines", [])
	while true:
		_index += 1
		if _index >= lines.size():
			_finish()
			return
		var entry: Dictionary = lines[_index]
		_apply(entry)
		var choices: Array = entry.get("choices", [])
		emit_signal("line", str(entry.get("speaker", "")), str(entry.get("text", "")), choices)
		return


func _finish() -> void:
	_active = false
	emit_signal("finished", _id)


func _apply(effects: Dictionary) -> void:
	var state = get_node_or_null("/root/GameState")
	if state == null:
		return
	var flag := str(effects.get("flag", ""))
	if flag != "":
		state.set_flag(flag)
	var quest := str(effects.get("quest", ""))
	if quest != "":
		var mode := str(effects.get("mode", "start"))
		if mode == "step":
			if state.quest_status(quest) == "active":
				state.advance_quest(quest, int(effects.get("amount", 1)))
		elif state.quest_status(quest) != "done":
			state.start_quest(quest)
	var xp := int(effects.get("xp", 0))
	if xp > 0:
		state.add_xp(xp)


func _build_trees() -> Dictionary:
	return {
		"nell": {
			"lines": [
				{"speaker": "NELL QUILL", "text": "Market's a mess, rookie. The bins were emptied last night and the rubbish came back for a visit."},
				{"speaker": "NELL QUILL", "text": "Get the street to 90 percent clean before the nine o'clock bell. Sort what you collect. The bins pay you, not me."},
				{"speaker": "NELL QUILL", "text": "Any questions before the shutters go up?", "choices": [
					{"label": "WHAT DO I DO FIRST?", "next": "ask"},
					{"label": "I'M ON IT", "next": "", "flag": "met_nell"},
				]},
			],
			"ask": {"lines": [
				{"speaker": "NELL QUILL", "text": "Vacuum the loose litter. Lift the heavy stuff with E and drop it in the skip. Empty the hopper at a depot before it jams."},
				{"speaker": "NELL QUILL", "text": "And if a rat gives you a look, it is bluffing. Mostly."},
			]},
		},
		"nell_intro": {"lines": [
			{"speaker": "NELL QUILL", "text": "First shift, rookie. Vacuum the loose litter, lift the heavy stuff, and sort it right at the depot. The bins pay better than I do."},
			{"speaker": "NELL QUILL", "text": "Get the market to 90 percent before the nine o'clock bell. The stall keepers have sharp elbows and long memories.", "choices": [
				{"label": "WHY IS IT SO MESSY?", "next": "why"},
				{"label": "ON IT", "next": "", "flag": "met_nell"},
			]},
		],
		"why": {"lines": [
			{"speaker": "NELL QUILL", "text": "Good question. The bins were emptied last night. Rubbish should not come back for a visit. Just clean it and keep your eyes open.", "flag": "met_nell"},
		]},
		},
		"nell_shift_2": {"lines": [
			{"speaker": "NELL QUILL", "text": "The canal quarter is choked and the barge leaves at noon. Odo the ferryman counts every bottle that floats past."},
			{"speaker": "NELL QUILL", "text": "Clear the banks, clear the drains, and if you see Rook, he is stuck on the north bridge with a bent axle. Again.", "flag": "met_nell"},
		]},
		"rook_meet": {"lines": [
			{"speaker": "ROOK", "text": "Before you say anything, the cart slipped. The bridge jumped out at me."},
			{"speaker": "ROOK", "text": "You want to know what choked the canal? Sullage Haulage. I lifted a manifest off their foreman. Take it, I memorised it. Mostly.", "choices": [
				{"label": "TAKE THE MANIFEST", "next": "", "flag": "rook_rival"},
				{"label": "FIX YOUR CART FIRST", "next": "cart"},
			]},
		],
		"cart": {"lines": [
			{"speaker": "ROOK", "text": "The axle just needs a kick and an audience. There. Repaired by embarrassment."},
			{"speaker": "ROOK", "text": "Manifest. Sullage's crews dump before dawn so the Bureau looks useless. I am done being fast for that man.", "flag": "rook_rival"},
		]},
		},
		"odo_bottles": {"lines": [
			{"speaker": "ODO", "text": "The tide brought the whole city's glass to my doorstep. Every bottle a letter, and every letter addressed to me."},
			{"speaker": "ODO", "text": "Vacuum five bottles out of the water and bring them here. I will tell you what the barges unload at night.", "quest": "bottles"},
		]},
		"pip_high_score": {"lines": [
			{"speaker": "PIP", "text": "You made it up. The fire escape only bites twice. From here you can see the whole strip and the plant gate under it."},
			{"speaker": "PIP", "text": "The machine under the plant ate the street again last night. I count its snores. Find my three tokens, beat the taped-up cabinet, and I will call you when the gate opens.", "quest": "high_score", "flag": "met_pip"},
		]},
		"sullage_taunt": {"lines": [
			{"speaker": "DIRECTOR SULLAGE", "text": "Filth is a service. I provide it reliably. Your little broom is a rounding error, sweeper."},
			{"speaker": "DIRECTOR SULLAGE", "text": "Gulper, dinner shift. Eat the street. Expense it.", "flag": "sullage_overclock"},
		]},
		"nell_ending": {"lines": [
			{"speaker": "NELL QUILL", "text": "The plant is quiet, the canal is glass, and the market rang its bell on time. The Bureau owes you a promotion and a very large brush."},
			{"speaker": "NELL QUILL", "text": "Marrow Bay is yours to keep clean, COSMIC CUSTODIAN. Clock out whenever. The bins will miss you.", "flag": "promoted"},
		]},
		"rook": {
			"lines": [
				{"speaker": "ROOK", "text": "Nice cart. Does it come with a pension?"},
				{"speaker": "ROOK", "text": "Keep up, rookie. The scoreboard does not care how tired you are."},
				{"speaker": "ROOK", "text": "For the record, I am not helping. I am observing. From very close.", "choices": [
					{"label": "OBSERVE THIS", "next": "bet", "flag": "rook_rival"},
					{"label": "SEE YOU AT THE BELL", "next": ""},
				]},
			],
			"bet": {"lines": [
				{"speaker": "ROOK", "text": "Big words for someone carrying one crate at a time. Level up and maybe I will lend you a wheel."},
			]},
		},
		"keeper_0": {"lines": [
			{"speaker": "STALL KEEPER", "text": "Mind the strawberries. They roll better than they sell."},
			{"speaker": "STALL KEEPER", "text": "If you spot a crate with a red stamp, that one is mine. The rest is rubbish, officially."},
		]},
		"keeper_1": {"lines": [
			{"speaker": "STALL KEEPER", "text": "Bread at dawn, dust by eight. City life."},
			{"speaker": "STALL KEEPER", "text": "A clean street sells more buns. That is economics."},
		]},
		"keeper_2": {"lines": [
			{"speaker": "STALL KEEPER", "text": "Flowers are just plants with better hats."},
			{"speaker": "STALL KEEPER", "text": "You look like you could use a tulip. Come back when the street shines."},
		]},
		"shopper_0": {"lines": [
			{"speaker": "SHOPPER", "text": "I dropped a coin somewhere around here. It is round and shiny and mine."},
		]},
		"shopper_1": {"lines": [
			{"speaker": "SHOPPER", "text": "The market opens in an hour and I have been waiting for two."},
			{"speaker": "SHOPPER", "text": "No rush. The potatoes are not going anywhere."},
		]},
		"shopper_2": {"lines": [
			{"speaker": "SHOPPER", "text": "I heard the big machine under the plant eats the street. I assumed it was a metaphor."},
		]},
		"child_0": {"lines": [
			{"speaker": "CHILD", "text": "Are you the bin wizard? My brother says the bins pay you."},
			{"speaker": "CHILD", "text": "Can I try the vacuum? I would be very careful. Mostly."},
		]},
		"child_1": {"lines": [
			{"speaker": "CHILD", "text": "I saw a cat. Grey. Very round. Extremely fast."},
			{"speaker": "CHILD", "text": "If you find her, tell her I said hi. Her name is Miso.", "flag": "miso_hint", "quest": "cat"},
		]},
		"ferryman": {"lines": [
			{"speaker": "ODO", "text": "That bottle has been down the canal twice. It knows the way home."},
			{"speaker": "ODO", "text": "Bring me five glass bottles and I will tell you what the barges unload at night.", "quest": "bottles"},
		]},
		"arcade_kid": {"lines": [
			{"speaker": "PIP", "text": "The big machine eats the street. I named it. You're welcome."},
			{"speaker": "PIP", "text": "The roof route is faster. Find three tokens and I will show you the cabinet.", "quest": "high_score"},
		]},
		"pip": {"lines": [
			{"speaker": "PIP", "text": "You climbed the fire escape. Most people give up at the second platform."},
			{"speaker": "PIP", "text": "I watch the strip from up here. The neon, the rain, the machine under the plant waking up. Best seat in Bin City.", "choices": [
				{"label": "WHAT MACHINE?", "next": "machine"},
				{"label": "ANY TOKENS UP HERE?", "next": "tokens"},
				{"label": "NICE VIEW", "next": "", "flag": "met_pip"},
			]},
		],
		"machine": {"lines": [
			{"speaker": "PIP", "text": "The compactor under the sorting plant. It ate the old street sweeper. Not the person. The machine. Probably."},
			{"speaker": "PIP", "text": "When the plant gate opens at night, you will hear it. Bring earplugs and a very big broom.", "flag": "plant_hint"},
		]},
		"tokens": {"lines": [
			{"speaker": "PIP", "text": "One is up here somewhere, I dropped it behind the tank. The rest are glinting down in the litter. Gold, shiny, very findable."},
			{"speaker": "PIP", "text": "Feed three to the taped-up cabinet inside the arcade and it will remember what a high score is.", "quest": "high_score"},
		]},
		},
		"miso": {"lines": [
			{"speaker": "MISO", "text": "Mrrp."},
			{"speaker": "MISO", "text": "Miso blinks slowly, which is cat for 'you may stay'. She follows you at a distance, officially not following you.", "quest": "cat", "mode": "step"},
		]},
		"pigeon": {"lines": [
			{"speaker": "PIGEON", "text": "The pigeon regards you with the confidence of a landlord."},
		]},
		"dog": {"lines": [
			{"speaker": "DOG", "text": "The dog wakes up, looks at the street, and goes back to sleep."},
		]},
		"baker": {"lines": [
			{"speaker": "BAKER", "text": "Three flour sacks, if you can lift them. The rats moved into the storeroom and they did not sign a lease.", "quest": "bakery"},
		]},
	}
