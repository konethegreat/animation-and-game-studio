extends CanvasLayer

const K = preload("res://scripts/kit.gd")

signal gate_opened
signal revealed

var root: Control
var title_label: Label
var line_label: Label
var tip_label: Label
var status_label: Label
var bar_fill: ColorRect
var display_font: FontVariation

var _gate_open := true
var _gate_time := 0.0
var _bar_tween: Tween


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	display_font = FontVariation.new()
	display_font.base_font = ThemeDB.fallback_font
	display_font.variation_embolden = 2.0

	root = Control.new()
	root.name = "LoadingCard"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.visible = false
	add_child(root)

	var ink := ColorRect.new()
	ink.color = Color(0.11, 0.1, 0.09)
	ink.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ink)

	var top_band := ColorRect.new()
	top_band.color = K.CREAM
	top_band.anchor_right = 1.0
	top_band.offset_bottom = 8.0
	root.add_child(top_band)

	var bottom_band := ColorRect.new()
	bottom_band.color = K.CORAL
	bottom_band.anchor_top = 1.0
	bottom_band.anchor_right = 1.0
	bottom_band.anchor_bottom = 1.0
	bottom_band.offset_top = -6.0
	root.add_child(bottom_band)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(620, 0)
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)

	var kicker := _label("BIN CITY  /  NIGHT SHIFT", 13, Color(0.86, 0.82, 0.74, 0.72))
	column.add_child(kicker)

	title_label = _label("BUREAU DEPOT", 58, K.CREAM, true)
	column.add_child(title_label)

	var rule := ColorRect.new()
	rule.color = K.CORAL
	rule.custom_minimum_size = Vector2(72, 6)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(rule)

	line_label = _label("", 19, Color(0.93, 0.89, 0.8, 0.9))
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.custom_minimum_size = Vector2(600, 0)
	column.add_child(line_label)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	column.add_child(gap)

	var track := Control.new()
	track.custom_minimum_size = Vector2(420, 8)
	track.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(track)

	var trough := ColorRect.new()
	trough.color = Color(0.96, 0.93, 0.86, 0.16)
	trough.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.add_child(trough)

	bar_fill = ColorRect.new()
	bar_fill.color = K.CORAL
	bar_fill.position = Vector2.ZERO
	bar_fill.size = Vector2(420, 8)
	bar_fill.pivot_offset = Vector2(0, 4)
	bar_fill.scale = Vector2(0.001, 1.0)
	track.add_child(bar_fill)

	status_label = _label("OPENING THE DOOR", 12, Color(0.86, 0.82, 0.74, 0.6))
	column.add_child(status_label)

	var tip_anchor := Control.new()
	tip_anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	tip_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tip_anchor)
	tip_label = _label("", 14, Color(0.86, 0.82, 0.74, 0.66))
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tip_label.offset_left = -420
	tip_label.offset_right = 420
	tip_label.offset_top = -58
	tip_label.offset_bottom = -24
	root.add_child(tip_label)


func _label(text: String, size: int, color: Color, display := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if display:
		label.add_theme_font_override("font", display_font)
	return label


func _process(delta: float) -> void:
	if _gate_open or not root.visible:
		return
	_gate_time -= delta
	if _gate_time <= 0.0:
		_open_gate()
	elif Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		_open_gate()


func cover(title: String, line: String, tip: String) -> void:
	title_label.text = title
	line_label.text = line
	tip_label.text = tip
	status_label.text = "OPENING THE DOOR"
	root.visible = true
	root.modulate.a = 0.0
	bar_fill.scale = Vector2(0.001, 1.0)
	var fade := create_tween()
	fade.tween_property(root, "modulate:a", 1.0, 0.18)
	if _bar_tween != null:
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.tween_property(bar_fill, "scale:x", 1.0, 0.82).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_gate_open = false
	_gate_time = 0.92
	await gate_opened


func _open_gate() -> void:
	if _gate_open:
		return
	_gate_open = true
	if _bar_tween != null:
		_bar_tween.kill()
	bar_fill.scale = Vector2(1.0, 1.0)
	status_label.text = "STRAIGHTENING THE CAP"
	gate_opened.emit()


func reveal() -> void:
	_gate_open = true
	status_label.text = ""
	var fade := create_tween()
	fade.tween_property(root, "modulate:a", 0.0, 0.3)
	await fade.finished
	root.visible = false
	revealed.emit()


func is_covering() -> bool:
	return root != null and root.visible
