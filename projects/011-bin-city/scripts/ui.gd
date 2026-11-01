extends CanvasLayer

signal play_pressed
signal restart_pressed
signal title_pressed
signal resume_pressed
signal mute_pressed
signal pause_pressed
signal sort_choice(kind: String)
signal sort_closed
signal interact_pressed

const K = preload("res://scripts/kit.gd")
const TouchStick = preload("res://scripts/touch_stick.gd")
const LookPad = preload("res://scripts/look_pad.gd")

const KIND_COLORS := {
	"glass": Color(0.3, 0.58, 0.54),
	"metal": Color(0.62, 0.66, 0.68),
	"paper": Color(0.4, 0.53, 0.72),
	"compost": Color(0.44, 0.51, 0.28),
}
const KIND_LABEL := {"glass": "GLASS", "metal": "METAL", "paper": "PAPER", "compost": "COMPOST"}
const RANK_NAMES := {1: "STREET SWEEPER", 2: "BAG BARON", 3: "SCRAP KNIGHT", 4: "RECYCLORD", 5: "COSMIC CUSTODIAN"}

var root: Control
var hud: Control
var title_layer: Control
var sort_layer: Control
var pause_layer: Control
var results_layer: Control
var rank_layer: Control
var prompt_panel: PanelContainer
var prompt_label: Label
var subtitle_panel: PanelContainer
var subtitle_label: Label
var score_label: Label
var rank_label: Label
var clean_label: Label
var clean_bar: ProgressBar
var bag_label: Label
var bag_pips: Array[ColorRect] = []
var charge_bar: ProgressBar
var flow_label: Label
var flow_bar: ProgressBar
var stack_label: Label
var timer_label: Label
var sound_button: Button
var sort_title: Label
var sort_progress: Label
var sort_item_name: Label
var sort_item_hint: Label
var sort_swatch: ColorRect
var sort_feedback: Label
var sort_panel: PanelContainer
var sort_buttons: Dictionary = {}
var results_title: Label
var results_grid: VBoxContainer
var rank_kicker: Label
var rank_name: Label
var rank_line: Label
var rank_panel: PanelContainer
var title_play: Button
var touch_root: Control
var stick: Control
var look_pad: Control
var touch_vacuum := false
var touch_sprint := false
var display_font: FontVariation
var _subtitle_tween: Tween
var _rank_tween: Tween
var _prompt_text := ""
var _phase := "title"
var _feedback_tween: Tween


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	display_font = FontVariation.new()
	display_font.base_font = ThemeDB.fallback_font
	display_font.variation_embolden = 1.5

	root = Control.new()
	root.name = "UI"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_hud()
	_build_prompt()
	_build_subtitle()
	_build_title()
	_build_sort()
	_build_pause()
	_build_results()
	_build_rank()
	_build_touch()
	set_phase("title")
	set_muted(Sound.muted)


# ---------------------------------------------------------------- helpers

func _flat(color: Color, radius := 14, border := 0, border_color := K.INK) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	if border > 0:
		box.set_border_width_all(border)
		box.border_color = border_color
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


func _label(text: String, size: int, color := K.INK, bold := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_override("font", display_font if bold else ThemeDB.fallback_font)
	return label


func _button(text: String, fill: Color, text_color: Color, size := 20, glow := false, width := 0.0, height := 0.0) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_font_override("font", display_font)
	if width > 0.0 or height > 0.0:
		button.custom_minimum_size = Vector2(width, height)
	var normal := _flat(fill, 14, 2, K.INK)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	normal.content_margin_top = 14
	normal.content_margin_bottom = 14
	if glow:
		normal.shadow_color = Color(fill.r, fill.g, fill.b, 0.5)
		normal.shadow_size = 18
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = fill.lightened(0.08)
	if glow:
		hover.shadow_color = Color(fill.r, fill.g, fill.b, 0.65)
		hover.shadow_size = 22
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = fill.darkened(0.1)
	pressed.shadow_size = 6
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", normal)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	button.add_theme_color_override("font_focus_color", text_color)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _text_button(text: String, color := K.INK, size := 14) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", K.CORAL)
	button.add_theme_color_override("font_pressed_color", K.CORAL)
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, empty)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


func _rule(color: Color, width: int, height := 5) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.custom_minimum_size = Vector2(width, height)
	rect.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return rect


func _spacer(height: float) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	return node


func _bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.13, 0.12, 0.1, 0.14)
	back.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _margin(amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", amount)
	margin.add_theme_constant_override("margin_right", amount)
	margin.add_theme_constant_override("margin_top", amount)
	margin.add_theme_constant_override("margin_bottom", amount)
	return margin


func _center(panel: Control, width: float, height: float) -> void:
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_bottom = height * 0.5
	panel.custom_minimum_size = Vector2(width, height)


func _dimmer(alpha := 0.5) -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.07, 0.07, alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	return dim


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)

	var panel := PanelContainer.new()
	panel.position = Vector2(24, 22)
	panel.add_theme_stylebox_override("panel", _flat(Color(0.973, 0.945, 0.898, 0.94), 18, 2, K.INK))
	hud.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 6)
	var wrap := _margin(12)
	wrap.add_child(box)
	panel.add_child(wrap)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	rank_label = _label("RANK 1  STREET SWEEPER", 12, K.CORAL, true)
	rank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(rank_label)
	score_label = _label("00000", 22, K.INK, true)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(score_label)
	box.add_child(top)

	var clean_row := HBoxContainer.new()
	var clean_caption := _label("STREET CLEAN", 11, Color(0.13, 0.12, 0.1, 0.6), true)
	clean_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clean_row.add_child(clean_caption)
	clean_label = _label("0%", 14, K.TEAL_DARK, true)
	clean_row.add_child(clean_label)
	box.add_child(clean_row)
	clean_bar = _bar(K.TEAL)
	clean_bar.max_value = 100
	box.add_child(clean_bar)

	var bag_row := HBoxContainer.new()
	bag_row.add_theme_constant_override("separation", 3)
	bag_label = _label("HOPPER 0/12", 11, Color(0.13, 0.12, 0.1, 0.6), true)
	bag_row.add_child(bag_label)
	var pip_space := Control.new()
	pip_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_row.add_child(pip_space)
	for i in 20:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(9, 10)
		pip.color = Color(0.13, 0.12, 0.1, 0.15)
		bag_row.add_child(pip)
		bag_pips.append(pip)
	box.add_child(bag_row)

	var charge_row := HBoxContainer.new()
	var charge_caption := _label("SUCTION", 11, Color(0.13, 0.12, 0.1, 0.6), true)
	charge_row.add_child(charge_caption)
	charge_bar = _bar(Color(0.35, 0.6, 0.55))
	charge_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	charge_bar.custom_minimum_size = Vector2(0, 8)
	charge_row.add_child(charge_bar)
	box.add_child(charge_row)

	var flow_row := HBoxContainer.new()
	flow_row.add_theme_constant_override("separation", 8)
	flow_label = _label("FLOW x1.0", 12, K.CORAL, true)
	flow_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow_row.add_child(flow_label)
	stack_label = _label("", 11, Color(0.13, 0.12, 0.1, 0.7), true)
	stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	flow_row.add_child(stack_label)
	box.add_child(flow_row)
	flow_bar = _bar(K.CORAL)
	flow_bar.max_value = 1.0
	flow_bar.value = 0.0
	flow_bar.custom_minimum_size = Vector2(0, 5)
	box.add_child(flow_bar)

	var top_right := PanelContainer.new()
	top_right.anchor_left = 1.0
	top_right.anchor_right = 1.0
	top_right.offset_left = -248
	top_right.offset_right = -24
	top_right.offset_top = 22
	top_right.add_theme_stylebox_override("panel", _flat(Color(0.973, 0.945, 0.898, 0.94), 16, 2, K.INK))
	hud.add_child(top_right)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	top_right.add_child(row)
	timer_label = _label("00:00", 18, K.INK, true)
	timer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(timer_label)
	sound_button = _text_button("SOUND", K.INK, 12)
	sound_button.pressed.connect(func() -> void: mute_pressed.emit())
	row.add_child(sound_button)
	var pause_button := _text_button("PAUSE", K.INK, 12)
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	row.add_child(pause_button)

	hud.visible = false


func _build_prompt() -> void:
	prompt_panel = PanelContainer.new()
	prompt_panel.anchor_left = 0.5
	prompt_panel.anchor_right = 0.5
	prompt_panel.anchor_top = 1.0
	prompt_panel.anchor_bottom = 1.0
	prompt_panel.offset_left = -330
	prompt_panel.offset_right = 330
	prompt_panel.offset_top = -132
	prompt_panel.offset_bottom = -78
	prompt_panel.add_theme_stylebox_override("panel", _flat(Color(0.13, 0.12, 0.1, 0.88), 14, 0, K.INK))
	prompt_label = _label("", 16, K.CREAM, false)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_panel.add_child(prompt_label)
	root.add_child(prompt_panel)
	prompt_panel.visible = false


func _build_subtitle() -> void:
	subtitle_panel = PanelContainer.new()
	subtitle_panel.anchor_left = 0.5
	subtitle_panel.anchor_right = 0.5
	subtitle_panel.anchor_top = 1.0
	subtitle_panel.anchor_bottom = 1.0
	subtitle_panel.offset_left = -390
	subtitle_panel.offset_right = 390
	subtitle_panel.offset_top = -212
	subtitle_panel.offset_bottom = -146
	subtitle_panel.add_theme_stylebox_override("panel", _flat(Color(0.973, 0.945, 0.898, 0.95), 16, 2, K.INK))
	subtitle_label = _label("", 17, K.INK, false)
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_panel.add_child(subtitle_label)
	root.add_child(subtitle_panel)
	subtitle_panel.visible = false


# ---------------------------------------------------------------- title

func _build_title() -> void:
	title_layer = Control.new()
	title_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_layer)

	var card := PanelContainer.new()
	card.position = Vector2(54, 54)
	card.custom_minimum_size = Vector2(660, 612)
	card.add_theme_stylebox_override("panel", _flat(Color(0.973, 0.945, 0.898, 0.96), 28, 3, K.INK))
	title_layer.add_child(card)
	var wrap := _margin(32)
	card.add_child(wrap)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	wrap.add_child(box)

	var eyebrow := _label("A KONE STUDIO GAME", 13, K.CORAL, true)
	box.add_child(eyebrow)
	var title := _label("BIN CITY", 84, K.INK, true)
	title.add_theme_constant_override("outline_size", 0)
	box.add_child(title)
	box.add_child(_rule(K.CORAL, 72, 6))
	var place := _label("DAWN MARKET  /  06:12", 15, Color(0.13, 0.12, 0.1, 0.62), true)
	box.add_child(place)
	var hook := _label("One collector. One cart. One very messy morning.", 19, K.INK, false)
	hook.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hook.custom_minimum_size = Vector2(560, 0)
	box.add_child(hook)
	var goal := _label("TODAY'S JOB  /  GET THE STREET 90% CLEAN BEFORE OPENING", 11, K.TEAL_DARK, true)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(goal)
	box.add_child(_spacer(6))

	title_play = _button("START THE SHIFT", K.CORAL, K.CREAM, 24, true, 330, 66)
	title_play.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_play.pressed.connect(func() -> void: play_pressed.emit())
	box.add_child(title_play)

	box.add_child(_spacer(2))
	var controls := GridContainer.new()
	controls.columns = 2
	controls.add_theme_constant_override("h_separation", 18)
	controls.add_theme_constant_override("v_separation", 4)
	var rows := [
		["WASD / left stick", "Move"],
		["Hold left mouse / RT", "Vacuum"],
		["E / X", "Interact and sort"],
		["Shift / L3", "Run"],
		["Right drag / right stick", "Look"],
	]
	for row in rows:
		var key := _label(row[0], 12, Color(0.13, 0.12, 0.1, 0.62), true)
		key.custom_minimum_size = Vector2(205, 0)
		controls.add_child(key)
		controls.add_child(_label(row[1], 13, K.INK, false))
	box.add_child(controls)
	box.add_child(_spacer(2))
	var ranks := _label("RANKS IN THIS BUILD   1 STREET SWEEPER   /   2 BAG BARON", 10, Color(0.13, 0.12, 0.1, 0.55), true)
	ranks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(ranks)
	var footer := _label("Original score and effects, synthesised in the game. About ten minutes for a clean street.", 11, Color(0.13, 0.12, 0.1, 0.55), false)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.custom_minimum_size = Vector2(560, 0)
	box.add_child(footer)
	var mute := _text_button("SOUND ON", Color(0.13, 0.12, 0.1, 0.6), 11)
	mute.pressed.connect(func() -> void: mute_pressed.emit())
	mute.name = "TitleSound"
	box.add_child(mute)


# ---------------------------------------------------------------- sort

func _build_sort() -> void:
	sort_layer = Control.new()
	sort_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	sort_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(sort_layer)
	sort_layer.add_child(_dimmer(0.42))

	sort_panel = PanelContainer.new()
	_center(sort_panel, 820, 470)
	sort_panel.add_theme_stylebox_override("panel", _flat(Color(0.973, 0.945, 0.898, 0.99), 26, 3, K.INK))
	sort_layer.add_child(sort_panel)
	var wrap := _margin(26)
	sort_panel.add_child(wrap)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	wrap.add_child(box)

	var head := HBoxContainer.new()
	sort_title = _label("SORT IT RIGHT", 30, K.INK, true)
	sort_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sort_title)
	sort_progress = _label("1 / 8", 14, Color(0.13, 0.12, 0.1, 0.6), true)
	head.add_child(sort_progress)
	box.add_child(head)
	box.add_child(_label("Pick the bin for each item. A wrong drop breaks the flow chain.", 13, Color(0.13, 0.12, 0.1, 0.68), false))
	box.add_child(_spacer(4))

	var item_card := PanelContainer.new()
	item_card.add_theme_stylebox_override("panel", _flat(Color(0.906, 0.867, 0.792), 16, 2, K.INK))
	box.add_child(item_card)
	var item_row := HBoxContainer.new()
	item_row.add_theme_constant_override("separation", 16)
	var item_wrap := _margin(10)
	item_wrap.add_child(item_row)
	item_card.add_child(item_wrap)
	sort_swatch = ColorRect.new()
	sort_swatch.custom_minimum_size = Vector2(72, 72)
	sort_swatch.color = K.CREAM
	item_row.add_child(sort_swatch)
	var item_text := VBoxContainer.new()
	item_text.add_theme_constant_override("separation", 0)
	item_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_row.add_child(item_text)
	sort_item_name = _label("Wax paper", 26, K.INK, true)
	item_text.add_child(sort_item_name)
	sort_item_hint = _label("This one is paper. Probably.", 12, Color(0.13, 0.12, 0.1, 0.62), false)
	item_text.add_child(sort_item_hint)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	var order := ["glass", "metal", "paper", "compost"]
	var keys := ["1", "2", "3", "4"]
	for i in order.size():
		var kind: String = order[i]
		var fill: Color = KIND_COLORS[kind]
		var text_color := K.CREAM if kind == "glass" or kind == "compost" else K.INK
		var button := _button("%s   %s" % [keys[i], KIND_LABEL[kind]], fill, text_color, 19, false, 380, 74)
		button.pressed.connect(func() -> void: sort_choice.emit(kind))
		grid.add_child(button)
		sort_buttons[kind] = button
	sort_feedback = _label("", 14, K.CORAL, true)
	sort_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sort_feedback)
	var close := _text_button("CLOSE AND KEEP THE HOPPER", Color(0.13, 0.12, 0.1, 0.55), 11)
	close.pressed.connect(func() -> void: sort_closed.emit())
	box.add_child(close)
	sort_layer.visible = false


# ---------------------------------------------------------------- pause

func _build_pause() -> void:
	pause_layer = Control.new()
	pause_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(pause_layer)
	pause_layer.add_child(_dimmer(0.48))

	var panel := PanelContainer.new()
	_center(panel, 460, 400)
	panel.add_theme_stylebox_override("panel", _flat(Color(0.973, 0.945, 0.898, 0.99), 24, 3, K.INK))
	pause_layer.add_child(panel)
	var wrap := _margin(28)
	panel.add_child(wrap)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	wrap.add_child(box)
	box.add_child(_label("PAUSED", 42, K.INK, true))
	box.add_child(_label("The market can wait a minute.", 14, Color(0.13, 0.12, 0.1, 0.62), false))
	box.add_child(_spacer(8))
	var resume := _button("BACK TO WORK", K.TEAL, K.CREAM, 20, false, 0, 58)
	resume.pressed.connect(func() -> void: resume_pressed.emit())
	box.add_child(resume)
	var restart := _button("RESTART THE SHIFT", K.CREAM, K.INK, 18, false, 0, 52)
	restart.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(restart)
	var quit := _button("BACK TO TITLE", K.CREAM, K.INK, 18, false, 0, 52)
	quit.pressed.connect(func() -> void: title_pressed.emit())
	box.add_child(quit)
	var mute := _text_button("SOUND ON", Color(0.13, 0.12, 0.1, 0.62), 12)
	mute.pressed.connect(func() -> void: mute_pressed.emit())
	mute.name = "PauseSound"
	box.add_child(mute)
	pause_layer.visible = false


# ---------------------------------------------------------------- results

func _build_results() -> void:
	results_layer = Control.new()
	results_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	results_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(results_layer)
	results_layer.add_child(_dimmer(0.5))

	var panel := PanelContainer.new()
	_center(panel, 640, 540)
	panel.add_theme_stylebox_override("panel", _flat(Color(0.973, 0.945, 0.898, 0.99), 26, 3, K.INK))
	results_layer.add_child(panel)
	var wrap := _margin(32)
	panel.add_child(wrap)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	wrap.add_child(box)
	box.add_child(_label("SHIFT COMPLETE", 12, K.CORAL, true))
	results_title = _label("STREET RESTORED", 46, K.INK, true)
	box.add_child(results_title)
	box.add_child(_rule(K.TEAL, 90, 6))
	box.add_child(_label("Dawn Market is clean before the shutters go up.", 14, Color(0.13, 0.12, 0.1, 0.66), false))
	box.add_child(_spacer(6))
	results_grid = VBoxContainer.new()
	results_grid.add_theme_constant_override("separation", 6)
	box.add_child(results_grid)
	box.add_child(_spacer(8))
	var replay := _button("PLAY IT AGAIN", K.CORAL, K.CREAM, 21, true, 0, 60)
	replay.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(replay)
	var title := _button("BACK TO TITLE", K.CREAM, K.INK, 17, false, 0, 50)
	title.pressed.connect(func() -> void: title_pressed.emit())
	box.add_child(title)
	box.add_child(_label("Next stop: Neon Arcade, in a future shift.", 11, Color(0.13, 0.12, 0.1, 0.5), false))
	results_layer.visible = false


# ---------------------------------------------------------------- rank banner

func _build_rank() -> void:
	rank_layer = Control.new()
	rank_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	rank_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rank_layer)
	rank_panel = PanelContainer.new()
	_center(rank_panel, 460, 150)
	rank_panel.anchor_top = 0.0
	rank_panel.anchor_bottom = 0.0
	rank_panel.offset_top = 170
	rank_panel.offset_bottom = 320
	rank_panel.add_theme_stylebox_override("panel", _flat(Color(0.13, 0.12, 0.1, 0.94), 20, 2, K.OCHRE))
	rank_layer.add_child(rank_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var wrap := _margin(16)
	wrap.add_child(box)
	rank_panel.add_child(wrap)
	rank_kicker = _label("RANK 2", 13, K.OCHRE, true)
	rank_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rank_kicker)
	rank_name = _label("BAG BARON", 32, K.CREAM, true)
	rank_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rank_name)
	rank_line = _label("", 12, Color(0.973, 0.945, 0.898, 0.72), false)
	rank_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(rank_line)
	rank_layer.visible = false


# ---------------------------------------------------------------- touch

func _build_touch() -> void:
	touch_root = Control.new()
	touch_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch_root)

	look_pad = LookPad.new()
	look_pad.anchor_left = 1.0
	look_pad.anchor_right = 1.0
	look_pad.anchor_top = 0.2
	look_pad.anchor_bottom = 1.0
	look_pad.offset_left = -560
	look_pad.offset_top = 0
	look_pad.offset_right = 0
	look_pad.offset_bottom = -200
	touch_root.add_child(look_pad)

	stick = TouchStick.new()
	stick.anchor_top = 1.0
	stick.anchor_bottom = 1.0
	stick.offset_left = 20
	stick.offset_right = 210
	stick.offset_top = -220
	stick.offset_bottom = -30
	touch_root.add_child(stick)

	var vacuum := _button("VAC", K.CORAL, K.CREAM, 20, true, 132, 132)
	vacuum.anchor_left = 1.0
	vacuum.anchor_right = 1.0
	vacuum.anchor_top = 1.0
	vacuum.anchor_bottom = 1.0
	vacuum.offset_left = -164
	vacuum.offset_right = -32
	vacuum.offset_top = -164
	vacuum.offset_bottom = -32
	vacuum.button_down.connect(func() -> void: touch_vacuum = true)
	vacuum.button_up.connect(func() -> void: touch_vacuum = false)
	touch_root.add_child(vacuum)

	var use := _button("USE", K.INK, K.CREAM, 16, false, 96, 96)
	use.anchor_left = 1.0
	use.anchor_right = 1.0
	use.anchor_top = 1.0
	use.anchor_bottom = 1.0
	use.offset_left = -282
	use.offset_right = -186
	use.offset_top = -138
	use.offset_bottom = -42
	use.pressed.connect(func() -> void: interact_pressed.emit())
	touch_root.add_child(use)

	var run := _button("RUN", K.INK, K.CREAM, 14, false, 86, 70)
	run.anchor_left = 1.0
	run.anchor_right = 1.0
	run.anchor_top = 1.0
	run.anchor_bottom = 1.0
	run.offset_left = -184
	run.offset_right = -98
	run.offset_top = -248
	run.offset_bottom = -178
	run.button_down.connect(func() -> void: touch_sprint = true)
	run.button_up.connect(func() -> void: touch_sprint = false)
	touch_root.add_child(run)

	# Touch hardware is common on laptops, so the pads stay hidden until the
	# browser actually reports a touch. Phones show them straight away.
	touch_root.visible = OS.has_feature("mobile")


func _input(event: InputEvent) -> void:
	if touch_root.visible:
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch_root.visible = true


# ---------------------------------------------------------------- public API

func capture_mode() -> void:
	root.visible = false


func set_phase(phase: String) -> void:
	_phase = phase
	hud.visible = phase == "play" or phase == "sort" or phase == "pause"
	title_layer.visible = phase == "title"
	sort_layer.visible = phase == "sort"
	pause_layer.visible = phase == "pause"
	results_layer.visible = phase == "results"
	rank_layer.visible = false
	prompt_panel.visible = false
	if phase != "sort":
		sort_layer.visible = false
	if phase == "play":
		pass


func prompt(text: String) -> void:
	if text == _prompt_text:
		return
	_prompt_text = text
	prompt_label.text = text
	prompt_panel.visible = text != "" and (_phase == "play")
	if touch_root.visible and text != "":
		prompt_label.text = text + "   (or use USE)"


func subtitle(text: String, seconds := 5.0) -> void:
	subtitle_label.text = text
	subtitle_panel.visible = true
	subtitle_panel.modulate.a = 1.0
	if _subtitle_tween:
		_subtitle_tween.kill()
	_subtitle_tween = create_tween()
	_subtitle_tween.tween_interval(seconds)
	_subtitle_tween.tween_property(subtitle_panel, "modulate:a", 0.0, 0.6)
	_subtitle_tween.tween_callback(func() -> void: subtitle_panel.visible = false)


func update_hud(data: Dictionary) -> void:
	if not hud.visible:
		return
	score_label.text = "%05d" % int(data.get("score", 0))
	rank_label.text = "RANK %d  %s" % [int(data.get("rank", 1)), RANK_NAMES.get(int(data.get("rank", 1)), "")]
	clean_label.text = "%d%%" % int(round(float(data.get("clean", 0.0)) * 100.0))
	clean_bar.value = float(data.get("clean", 0.0)) * 100.0
	var bag := int(data.get("bag", 0))
	var bag_max := int(data.get("bag_max", 12))
	bag_label.text = "HOPPER %d/%d" % [bag, bag_max]
	for i in bag_pips.size():
		bag_pips[i].visible = i < bag_max
		bag_pips[i].color = K.CORAL if i < bag else Color(0.13, 0.12, 0.1, 0.15)
	charge_bar.value = float(data.get("charge", 0.0))
	flow_label.text = "FLOW x%.1f" % float(data.get("multiplier", 1.0))
	flow_bar.value = clampf(float(data.get("flow_time", 0.0)) / 14.0, 0.0, 1.0)
	var stack := int(data.get("stack", 0))
	var max_stack := int(data.get("max_stack", 1))
	if stack > 0:
		stack_label.text = "STACK %d/%d" % [stack, max_stack]
		if float(data.get("lean", 0.0)) > 0.4:
			stack_label.text = "WOBBLE  %d/%d" % [stack, max_stack]
			stack_label.add_theme_color_override("font_color", K.CORAL)
		else:
			stack_label.add_theme_color_override("font_color", Color(0.13, 0.12, 0.1, 0.7))
	else:
		stack_label.text = ""
	timer_label.text = _format_time(float(data.get("time", 0.0)))


func _format_time(seconds: float) -> String:
	var total := int(seconds)
	return "%02d:%02d" % [total / 60, total % 60]


func open_sort(item: Dictionary, index: int, total: int, multiplier: float) -> void:
	sort_layer.visible = true
	sort_title.text = "SORT IT RIGHT"
	sort_progress.text = "%d / %d     FLOW x%.1f" % [mini(index + 1, total), total, multiplier]
	sort_item_name.text = str(item.get("name", "Litter"))
	sort_item_hint.text = "Pick the bin. The market is not judging you. Much."
	sort_swatch.color = item.get("swatch", K.PAPER)
	sort_feedback.text = ""
	for kind in sort_buttons:
		sort_buttons[kind].disabled = false


func sort_result(ok: bool, chain: int) -> void:
	if _feedback_tween:
		_feedback_tween.kill()
	if ok:
		sort_feedback.text = "NICE.  CHAIN %d" % chain
		sort_feedback.add_theme_color_override("font_color", K.TEAL_DARK)
	else:
		sort_feedback.text = "WRONG BIN.  CHAIN BROKEN."
		sort_feedback.add_theme_color_override("font_color", K.CORAL)
		var base := sort_panel.position
		_feedback_tween = create_tween()
		_feedback_tween.tween_property(sort_panel, "position", base + Vector2(10, 0), 0.04)
		_feedback_tween.tween_property(sort_panel, "position", base - Vector2(10, 0), 0.05)
		_feedback_tween.tween_property(sort_panel, "position", base, 0.05)


func sort_done(sorted_count: int, perfect: bool) -> void:
	sort_layer.visible = false
	if perfect:
		subtitle("Sorted %d, no mistakes. The bins approve." % sorted_count, 4.0)
	else:
		subtitle("Sorted %d. Keep the flow alive." % sorted_count, 4.0)


func close_sort() -> void:
	sort_layer.visible = false


func show_rank(rank: int, line: String) -> void:
	rank_kicker.text = "RANK %d" % rank
	rank_name.text = str(RANK_NAMES.get(rank, "COLLECTOR"))
	rank_line.text = line
	rank_layer.visible = true
	rank_panel.modulate.a = 0.0
	rank_panel.scale = Vector2(0.94, 0.94)
	rank_panel.pivot_offset = rank_panel.size * 0.5
	if _rank_tween:
		_rank_tween.kill()
	_rank_tween = create_tween()
	_rank_tween.set_parallel(true)
	_rank_tween.tween_property(rank_panel, "modulate:a", 1.0, 0.25)
	_rank_tween.tween_property(rank_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_rank_tween.set_parallel(false)
	_rank_tween.tween_interval(2.4)
	_rank_tween.tween_property(rank_panel, "modulate:a", 0.0, 0.5)
	_rank_tween.tween_callback(func() -> void: rank_layer.visible = false)


func hide_rank() -> void:
	rank_layer.visible = false


func show_results(stats: Dictionary) -> void:
	for child in results_grid.get_children():
		child.queue_free()
	var rows := [
		["Time", _format_time(float(stats.get("time", 0.0)))],
		["Score", "%d" % int(stats.get("score", 0))],
		["Best", "%d" % int(stats.get("best", 0))],
		["Sorted", "%d items" % int(stats.get("sorted", 0))],
		["Rank", str(RANK_NAMES.get(int(stats.get("rank", 1)), ""))],
		["Street", "%d%% clean" % int(round(float(stats.get("clean", 0.0)) * 100.0))],
	]
	for row in rows:
		var line := HBoxContainer.new()
		var key := _label(row[0], 12, Color(0.13, 0.12, 0.1, 0.6), true)
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(key)
		line.add_child(_label(row[1], 20, K.INK, true))
		results_grid.add_child(line)
	results_layer.visible = true


func set_muted(muted: bool) -> void:
	var text := "SOUND OFF" if muted else "SOUND ON"
	if sound_button:
		sound_button.text = text
	var title_sound := title_layer.find_child("TitleSound", true, false) as Button
	if title_sound:
		title_sound.text = "SOUND OFF" if muted else "SOUND ON"
	var pause_sound := pause_layer.find_child("PauseSound", true, false) as Button
	if pause_sound:
		pause_sound.text = "SOUND OFF" if muted else "SOUND ON"


func touch_move() -> Vector2:
	if not touch_root.visible:
		return Vector2.ZERO
	return stick.stick if stick else Vector2.ZERO


func touch_wants_sprint() -> bool:
	return touch_root.visible and touch_sprint


func touch_wants_vacuum() -> bool:
	return touch_root.visible and touch_vacuum


func touch_available() -> bool:
	return touch_root.visible
