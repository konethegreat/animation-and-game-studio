extends Control

# A floating stick: the base appears where the thumb lands, so the thumb never
# has to find a fixed ring mid-run. The whole left zone is the stick.

signal changed(vector: Vector2)

const RADIUS := 72.0

var stick := Vector2.ZERO

var _index := -1
var _base := Vector2.ZERO
var _knob := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func wants_sprint() -> bool:
	return stick.length() >= 0.9


func release() -> void:
	_index = -1
	if stick == Vector2.ZERO:
		return
	stick = Vector2.ZERO
	queue_redraw()
	changed.emit(stick)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _index != -1:
				return
			_index = touch.index
			_base = touch.position
			_knob = _base
			stick = Vector2.ZERO
			queue_redraw()
			accept_event()
		elif touch.index == _index:
			release()
			accept_event()
	elif event is InputEventScreenDrag and event.index == _index:
		var drag := event as InputEventScreenDrag
		var offset := drag.position - _base
		if offset.length() > RADIUS:
			offset = offset.normalized() * RADIUS
		stick = Vector2(offset.x, -offset.y) / RADIUS
		_knob = _base + offset
		queue_redraw()
		changed.emit(stick)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		release()


func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point)


func _draw() -> void:
	var font := get_theme_default_font()
	if _index >= 0:
		draw_circle(_base, RADIUS, Color(0.973, 0.945, 0.898, 0.22))
		draw_arc(_base, RADIUS, 0.0, TAU, 48, Color(0.13, 0.12, 0.1, 0.45), 3.0, true)
		draw_circle(_knob, 26.0, Color(0.973, 0.945, 0.898, 0.95))
		draw_arc(_knob, 26.0, 0.0, TAU, 32, Color(0.13, 0.12, 0.1, 0.6), 3.0, true)
		return
	var rest := Vector2(size.x * 0.5, size.y * 0.62)
	draw_circle(rest, RADIUS, Color(0.973, 0.945, 0.898, 0.16))
	draw_arc(rest, RADIUS, 0.0, TAU, 48, Color(0.13, 0.12, 0.1, 0.28), 3.0, true)
	var text := "MOVE"
	var font_size := 18
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, rest + Vector2(-text_size.x * 0.5, text_size.y * 0.34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.13, 0.12, 0.1, 0.35))
