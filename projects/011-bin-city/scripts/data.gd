extends RefCounted

const RANKS := [
	{"rank": 1, "title": "STREET SWEEPER", "xp": 0, "carry": 1, "speed": 5.3, "vacuum": 2.2, "ability": "none"},
	{"rank": 2, "title": "BAG BARON", "xp": 600, "carry": 3, "speed": 5.65, "vacuum": 2.7, "ability": "sprint"},
	{"rank": 3, "title": "SCRAP KNIGHT", "xp": 1800, "carry": 5, "speed": 5.9, "vacuum": 3.1, "ability": "magnet"},
	{"rank": 4, "title": "RECYCLORD", "xp": 3600, "carry": 8, "speed": 6.2, "vacuum": 3.5, "ability": "sort_aura"},
	{"rank": 5, "title": "COSMIC CUSTODIAN", "xp": 6000, "carry": 12, "speed": 6.5, "vacuum": 4.0, "ability": "cleanse_pulse"},
]

const QUESTS := {
	"bakery": {
		"title": "Bread and Circuses", "goal": 3, "xp": 300, "giver": "baker",
		"desc": "Carry three flour sacks to the bakery and clear the rat nest.",
	},
	"bottles": {
		"title": "Message in a Bottle", "goal": 5, "xp": 320, "giver": "odo",
		"desc": "Return five glass bottles to Odo at the boathouse.",
	},
	"cat": {
		"title": "Miso Soup", "goal": 1, "xp": 250, "giver": "child",
		"desc": "Find Miso the cat and coax her out.",
	},
	"high_score": {
		"title": "High Score", "goal": 4, "xp": 350, "giver": "pip",
		"desc": "Find three arcade tokens in the litter, then beat the taped-up cabinet.",
	},
}

const DISTRICTS := {
	"dawn_market": {
		"title": "DAWN MARKET", "accent": Color(0.86, 0.42, 0.29), "music": "market",
		"spawn": Vector3(2, 0, 2), "interiors": ["depot", "bakery"], "crowd": 14,
	},
	"canal_quarter": {
		"title": "CANAL QUARTER", "accent": Color(0.22, 0.55, 0.5), "music": "canal",
		"spawn": Vector3(0, 0, 14), "interiors": ["boathouse"], "crowd": 10,
	},
	"neon_arcade": {
		"title": "NEON ARCADE", "accent": Color(0.85, 0.28, 0.62), "music": "neon",
		"spawn": Vector3(0, 0, 10), "interiors": ["arcade", "plant"], "crowd": 12,
	},
}

const SHIFTS := [
	{
		"id": "shift_1", "district": "dawn_market", "rank": 2, "goal": 0.9,
		"title": "THE MORNING RUSH", "brief": "Clean the market before the nine o'clock bell.",
	},
	{
		"id": "shift_2", "district": "canal_quarter", "rank": 3, "goal": 0.82,
		"title": "LOW TIDE", "brief": "The canal is choked. Clear the banks and the drains.",
	},
	{
		"id": "shift_3", "district": "canal_quarter", "rank": 4, "goal": 0.88,
		"title": "NIGHT TIDE", "brief": "Follow the manifest to the lock gates.", "night": true,
	},
	{
		"id": "shift_4", "district": "neon_arcade", "rank": 5, "goal": 0.9,
		"title": "NEON RAIN", "brief": "The arcade is buried and something big is awake.", "night": true,
	},
	{
		"id": "shift_5", "district": "neon_arcade", "rank": 5, "goal": 1.0,
		"title": "THE GULPER", "brief": "Calm the machine under the sorting plant.",
	},
]

static func rank_title(value: int) -> String:
	for entry in RANKS:
		if int(entry.rank) == value:
			return str(entry.title)
	return "STREET SWEEPER"

static func rank_entry(value: int) -> Dictionary:
	for entry in RANKS:
		if int(entry.rank) == value:
			return entry
	return RANKS[0]

static func quest(id: String) -> Dictionary:
	return QUESTS.get(id, {})

static func shift(index: int) -> Dictionary:
	if index >= 1 and index <= SHIFTS.size():
		return SHIFTS[index - 1]
	return SHIFTS[0]
