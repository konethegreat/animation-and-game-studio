extends Control

signal changed(vector: Vector2)

var knob: Control
var base_ring: Control
var stick := Vector2.ZERO
var _active := false
var _index := -1
var _start := Vector2.ZERO
var _touch := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(190, 190)
	base_ring = ColorRect.new()
	base_ring.color = Color(0.97, 0.95, 0.9, 0.16)
	base_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	base_ring.offset_left = 14
	base_ring.offset_top = 14
	base_ring.offset_right = -14
	base_ring.offset_bottom = -14
	add_child(base_ring)
	knob = ColorRect.new()
	knob.color = Color(0.97, 0.95, 0.9, 0.62)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.size = Vector2(64, 64)
	add_child(knob)
	_reset_knob()


func _reset_knob() -> void:
	var center := size * 0.5
	knob.position = center - knob.size * 0.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not _active:
			_active = true
			_touch = true
			_index = touch.index
			_start = touch.position
			_update(touch.position)
			accept_event()
		elif not touch.pressed and _active and touch.index == _index:
			_release()
			accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _active and drag.index == _index:
			_update(drag.position)
			accept_event()
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if mouse.pressed:
				_active = true
				_touch = false
				_start = mouse.position
				_update(mouse.position)
			else:
				_release()
			accept_event()
	elif event is InputEventMouseMotion and _active and not _touch:
		_update((event as InputEventMouseMotion).position)
		accept_event()


func _update(position: Vector2) -> void:
	var center := size * 0.5
	var offset := position - center
	var limit: float = minf(size.x, size.y) * 0.32
	if offset.length() > limit:
		offset = offset.normalized() * limit
	stick = offset / limit
	knob.position = center + offset - knob.size * 0.5
	changed.emit(stick)


func _release() -> void:
	_active = false
	_index = -1
	stick = Vector2.ZERO
	_reset_knob()
	changed.emit(stick)
