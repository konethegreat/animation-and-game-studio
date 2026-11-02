extends Node

# Rooms are built at a far offset so the outdoor district can be parked in
# place with all of its litter, XP and colliders untouched.

const ROOM = preload("res://scripts/interior.gd")
const OFFSET := Vector3(0.0, 0.0, 300.0)

const TIPS := {
	"depot": "TIP  The front desk sorts a full hopper in one run. Nell is watching.",
	"bakery": "TIP  The baker pays in XP for flour sacks. Do not ask about the secret.",
	"boathouse": "TIP  Nets catch more than fish. Shake them out before you leave.",
	"arcade": "TIP  The high score is real. The cabinet is held together with tape.",
	"plant": "TIP  Mind the pipes. The city notices when you do not.",
}


static func build(id: String) -> Node3D:
	var room = ROOM.new()
	room.setup(id)
	room.name = "Room" + id.to_pascal_case()
	room.position = OFFSET
	return room


static func tip(id: String) -> String:
	return str(TIPS.get(id, TIPS["depot"]))
