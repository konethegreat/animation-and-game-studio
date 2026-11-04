extends Control

# Touch look. Web drag events carry a relative motion per changed finger, not
# per tracked pointer, so the delta is measured from this pad's own positions.

signal looked(relative: Vector2)

var _index := -1
var _last := Vector2.ZERO
var _mouse := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func release() -> void:
	_index = -1
	_mouse = false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _index != -1:
				return
			_index = touch.index
			_last = touch.position
			accept_event()
		elif touch.index == _index:
			_index = -1
			accept_event()
	elif event is InputEventScreenDrag and event.index == _index:
		var drag := event as InputEventScreenDrag
		var delta := drag.position - _last
		_last = drag.position
		if delta != Vector2.ZERO:
			looked.emit(delta)
		accept_event()
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_mouse = mouse.pressed
			accept_event()
	elif event is InputEventMouseMotion and _mouse:
		var motion := event as InputEventMouseMotion
		looked.emit(motion.relative)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		release()
