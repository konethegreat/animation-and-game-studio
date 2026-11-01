extends Control

signal looked(relative: Vector2)

var _active := false
var _index := -1
var _touch := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not _active:
			_active = true
			_touch = true
			_index = touch.index
			accept_event()
		elif not touch.pressed and _active and touch.index == _index:
			_active = false
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _active and drag.index == _index:
			looked.emit(drag.relative)
			accept_event()
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			_active = mouse.pressed
			_touch = false
			accept_event()
	elif event is InputEventMouseMotion and _active and not _touch:
		looked.emit((event as InputEventMouseMotion).relative)
		accept_event()
