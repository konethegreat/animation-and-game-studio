extends Button

# BaseButton only listens to the mouse, so a phone could only ever press one
# button with the finger that feeds mouse emulation. Reading the touches here
# lets every finger press its own button.

var _index := -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if disabled or _index != -1:
				return
			_index = touch.index
			self_modulate = Color(0.86, 0.86, 0.86, 1.0)
			accept_event()
		elif touch.index == _index:
			var inside := Rect2(Vector2.ZERO, size).has_point(touch.position)
			_reset()
			if inside and not disabled:
				pressed.emit()
			accept_event()


func release() -> void:
	_reset()


func _reset() -> void:
	_index = -1
	self_modulate = Color.WHITE


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_reset()
