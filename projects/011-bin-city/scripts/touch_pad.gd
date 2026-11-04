extends Control

# A round hold pad for the phone controls. Circles look like buttons and are
# easier to hit with a thumb than a square that silently covers its neighbour.

signal held_started
signal held_stopped

var held := false
var label_text := ""
var fill := Color.WHITE
var ink := Color.BLACK
var radius := 60.0

var _index := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= radius + 8.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _index != -1:
				return
			_index = touch.index
			_set_held(true)
			accept_event()
		elif touch.index == _index:
			_index = -1
			_set_held(false)
			accept_event()


func release() -> void:
	_index = -1
	_set_held(false)


func _set_held(value: bool) -> void:
	if held == value:
		return
	held = value
	self_modulate = Color(0.86, 0.86, 0.86, 1.0) if held else Color.WHITE
	queue_redraw()
	if held:
		held_started.emit()
	else:
		held_stopped.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		release()


func _draw() -> void:
	var center := size * 0.5
	var outer := radius - 2.0
	draw_circle(center, outer, fill.darkened(0.08) if held else fill)
	draw_arc(center, outer, 0.0, TAU, 48, ink, 3.0, true)
	if label_text == "":
		return
	var font := get_theme_default_font()
	var font_size := int(radius * 0.34)
	var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.34)
	draw_string(font, baseline, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
