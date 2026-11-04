extends CanvasLayer

signal play_pressed
signal shift_pressed(index: int)
signal restart_pressed
signal title_pressed
signal resume_pressed
signal mute_pressed
signal pause_pressed
signal sort_choice(kind: String)
signal sort_closed
signal interact_pressed
signal dialogue_next
signal dialogue_choice(index: int)
signal skip_pressed

const K = preload("res://scripts/kit.gd")
const TouchStick = preload("res://scripts/touch_stick.gd")
const LookPad = preload("res://scripts/look_pad.gd")
const TouchButton = preload("res://scripts/touch_button.gd")
const TouchPad = preload("res://scripts/touch_pad.gd")

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
var title_shifts: VBoxContainer
var title_note: Label
var objective_label: Label
var results_next: Button
var results_line: Label
var boss_panel: PanelContainer
var boss_name: Label
var boss_bar: ProgressBar
var boss_phase_pips: Array[ColorRect] = []
var boss_strip: Label
var boss_flash: ColorRect
var _boss_flash_tween: Tween
var skip_button: Button
var touch_root: Control
var stick: TouchStick
var look_pad: LookPad
var pad_vacuum: TouchPad
var pad_jump: TouchPad
var pad_use: TouchPad
var pad_dash: TouchPad
var pad_pulse: TouchPad
var touch_mode := false
var touch_rank := 1
var display_font: FontVariation
var dialogue_layer: Control
var dialogue_panel: PanelContainer
var dialogue_speaker: Label
var dialogue_text: Label
var dialogue_choices_box: VBoxContainer
var dialogue_hint: Label
var _typing_tween: Tween
var _dialogue_typing := false
var _dialogue_full := ""
var _pending_choices: Array = []
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
	_build_dialogue()
	_build_title()
	_build_sort()
	_build_pause()
	_build_results()
	_build_rank()
	_build_touch()
	set_touch_mode(wants_touch(
		OS.has_feature("mobile"),
		OS.has_feature("web_android"),
		OS.has_feature("web_ios"),
		DisplayServer.is_touchscreen_available()
	))
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
	var button := TouchButton.new()
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
	var button := TouchButton.new()
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

	objective_label = _label("", 11, K.TEAL_DARK, true)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size = Vector2(336, 0)
	box.add_child(objective_label)

	var top_right := PanelContainer.new()
	top_right.name = "TopRight"
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

	boss_panel = PanelContainer.new()
	boss_panel.anchor_left = 0.5
	boss_panel.anchor_right = 0.5
	boss_panel.offset_left = -170
	boss_panel.offset_right = 290
	boss_panel.offset_top = 22
	boss_panel.offset_bottom = 104
	boss_panel.add_theme_stylebox_override("panel", _flat(Color(0.973, 0.945, 0.898, 0.94), 18, 2, K.INK))
	boss_panel.visible = false
	hud.add_child(boss_panel)
	boss_flash = ColorRect.new()
	boss_flash.color = Color(0.85, 0.35, 0.3, 0.0)
	boss_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	boss_panel.add_child(boss_flash)
	var boss_wrap := _margin(12)
	boss_panel.add_child(boss_wrap)
	var boss_box := VBoxContainer.new()
	boss_box.add_theme_constant_override("separation", 5)
	boss_wrap.add_child(boss_box)
	var boss_top := HBoxContainer.new()
	boss_top.add_theme_constant_override("separation", 10)
	boss_box.add_child(boss_top)
	boss_name = _label("THE GULPER", 13, K.CORAL, true)
	boss_top.add_child(boss_name)
	for i in 3:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(22, 10)
		pip.color = Color(0.13, 0.12, 0.1, 0.15)
		boss_top.add_child(pip)
		boss_phase_pips.append(pip)
	boss_bar = _bar(K.CORAL)
	boss_bar.max_value = 300.0
	boss_bar.custom_minimum_size = Vector2(0, 10)
	boss_box.add_child(boss_bar)
	boss_strip = _label("", 11, K.TEAL_DARK, true)
	boss_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_strip)

	skip_button = _text_button("SKIP  >>", K.CORAL, 13)
	skip_button.anchor_left = 1.0
	skip_button.anchor_right = 1.0
	skip_button.offset_left = -120
	skip_button.offset_right = -24
	skip_button.offset_top = 64
	skip_button.visible = false
	skip_button.pressed.connect(func() -> void: skip_pressed.emit())
	hud.add_child(skip_button)


func show_skip(on: bool) -> void:
	skip_button.visible = on
	_refresh_touch()


func show_boss(name_text: String) -> void:
	boss_panel.visible = true
	boss_name.text = name_text
	boss_bar.value = boss_bar.max_value
	for i in boss_phase_pips.size():
		boss_phase_pips[i].color = K.TEAL if i == 0 else Color(0.13, 0.12, 0.1, 0.15)
	boss_strip.text = ""


func update_boss(health: float, max_health: float, phase: int, strip: String) -> void:
	boss_bar.max_value = max_health
	boss_bar.value = health
	for i in boss_phase_pips.size():
		boss_phase_pips[i].color = K.TEAL if i < phase else Color(0.13, 0.12, 0.1, 0.15)
	boss_strip.text = strip


func boss_warn() -> void:
	if _boss_flash_tween != null and _boss_flash_tween.is_valid():
		_boss_flash_tween.kill()
	boss_flash.color = Color(0.85, 0.35, 0.3, 0.5)
	_boss_flash_tween = boss_panel.create_tween()
	_boss_flash_tween.tween_property(boss_flash, "color", Color(0.85, 0.35, 0.3, 0.0), 0.5)


func hide_boss() -> void:
	boss_panel.visible = false


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


func _build_dialogue() -> void:
	dialogue_layer = Control.new()
	dialogue_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialogue_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dialogue_layer)

	dialogue_panel = PanelContainer.new()
	dialogue_panel.anchor_left = 0.5
	dialogue_panel.anchor_right = 0.5
	dialogue_panel.anchor_top = 1.0
	dialogue_panel.anchor_bottom = 1.0
	dialogue_panel.offset_left = -440
	dialogue_panel.offset_right = 440
	dialogue_panel.offset_top = -304
	dialogue_panel.offset_bottom = -36
	dialogue_panel.add_theme_stylebox_override("panel", _flat(Color(0.973, 0.945, 0.898, 0.97), 18, 2, K.INK))
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_panel.gui_input.connect(_on_dialogue_input)
	dialogue_layer.add_child(dialogue_panel)

	var wrap := _margin(16)
	dialogue_panel.add_child(wrap)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	wrap.add_child(box)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	dialogue_speaker = _label("NELL QUILL", 13, K.CORAL, true)
	dialogue_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(dialogue_speaker)
	dialogue_hint = _label("E  NEXT", 11, Color(0.13, 0.12, 0.1, 0.5), true)
	top.add_child(dialogue_hint)
	box.add_child(top)
	box.add_child(_rule(K.CORAL, 42, 3))

	dialogue_text = _label("", 18, K.INK, false)
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.custom_minimum_size = Vector2(0, 56)
	dialogue_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	box.add_child(dialogue_text)

	dialogue_choices_box = VBoxContainer.new()
	dialogue_choices_box.add_theme_constant_override("separation", 5)
	box.add_child(dialogue_choices_box)

	dialogue_panel.visible = false


func open_dialogue(speaker: String, text: String, choices: Array) -> void:
	dialogue_panel.visible = true
	subtitle_panel.visible = false
	_pending_choices = choices.duplicate()
	_refresh_touch()
	var extra := 0.0 if choices.is_empty() else choices.size() * 52.0
	dialogue_panel.offset_top = -40.0 - 132.0 - extra
	dialogue_speaker.text = speaker
	_dialogue_full = text
	dialogue_text.text = text
	dialogue_text.visible_characters = 0
	for child in dialogue_choices_box.get_children():
		child.queue_free()
	_dialogue_typing = true
	if _typing_tween:
		_typing_tween.kill()
	_typing_tween = create_tween()
	var duration := clampf(float(text.length()) / 52.0, 0.35, 2.2)
	_typing_tween.tween_property(dialogue_text, "visible_characters", text.length(), duration).from(0)
	_typing_tween.tween_callback(func() -> void:
		_dialogue_typing = false
		_reveal_choices(choices)
	)
	dialogue_hint.text = _hint_copy(not choices.is_empty())


func _reveal_choices(choices: Array) -> void:
	for child in dialogue_choices_box.get_children():
		child.queue_free()
	if choices.is_empty():
		dialogue_hint.text = _hint_copy(false)
		return
	dialogue_hint.text = _hint_copy(true)
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var button := _button(str(choice.get("label", "...")).to_upper(), K.PAPER, K.INK, 15, false)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var index := i
		button.pressed.connect(func() -> void: dialogue_choice.emit(index))
		dialogue_choices_box.add_child(button)


func dialogue_typing() -> bool:
	return _dialogue_typing


func finish_typing() -> void:
	if not _dialogue_typing:
		return
	if _typing_tween:
		_typing_tween.kill()
	dialogue_text.visible_characters = -1
	_dialogue_typing = false
	_reveal_choices(_pending_choices)


func close_dialogue() -> void:
	if _typing_tween:
		_typing_tween.kill()
	_dialogue_typing = false
	_pending_choices = []
	for child in dialogue_choices_box.get_children():
		child.queue_free()
	dialogue_panel.visible = false
	_refresh_touch()


func dialogue_open() -> bool:
	return dialogue_panel != null and dialogue_panel.visible


func _on_dialogue_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		dialogue_next.emit()


# ---------------------------------------------------------------- title

func _build_title() -> void:
	title_layer = Control.new()
	title_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title_layer)

	var card := PanelContainer.new()
	card.position = Vector2(54, 44)
	card.custom_minimum_size = Vector2(660, 656)
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
	title_note = _label("", 13, K.TEAL_DARK, true)
	title_note.visible = false
	box.add_child(title_note)
	box.add_child(_spacer(6))

	title_shifts = VBoxContainer.new()
	title_shifts.add_theme_constant_override("separation", 6)
	box.add_child(title_shifts)

	box.add_child(_spacer(2))
	var controls := GridContainer.new()
	controls.columns = 2
	controls.add_theme_constant_override("h_separation", 18)
	controls.add_theme_constant_override("v_separation", 4)
	var rows := [
		["WASD / left stick", "Move"],
		["Hold left mouse / RT", "Vacuum"],
		["E / X", "Talk, lift, sort"],
		["Space / A", "Jump, then double jump"],
		["Ctrl / B", "Dash"],
		["Q / Y", "Cleanse pulse"],
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
	var ranks := _label("FIVE RANKS   /   SWEEPER TO COSMIC CUSTODIAN. XP COMES FROM A CLEAN STREET.", 10, Color(0.13, 0.12, 0.1, 0.55), true)
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

	var credit := PanelContainer.new()
	credit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credit.add_theme_stylebox_override("panel", _flat(Color(0.973, 0.945, 0.898, 0.92), 10, 1, Color(0.13, 0.12, 0.1, 0.24)))
	var credit_wrap := _margin(10)
	credit.add_child(credit_wrap)
	var credit_text := _label("© 2026 KONE TSHIVHINDA   /   ALL RIGHTS RESERVED", 9, Color(0.13, 0.12, 0.1, 0.68), true)
	credit_wrap.add_child(credit_text)
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	title_layer.add_child(credit)


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
	results_line = _label("Dawn Market is clean before the shutters go up.", 14, Color(0.13, 0.12, 0.1, 0.66), false)
	results_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(results_line)
	box.add_child(_spacer(6))
	results_grid = VBoxContainer.new()
	results_grid.add_theme_constant_override("separation", 6)
	box.add_child(results_grid)
	box.add_child(_spacer(8))
	var replay := _button("PLAY IT AGAIN", K.CORAL, K.CREAM, 21, true, 0, 60)
	replay.pressed.connect(func() -> void: restart_pressed.emit())
	box.add_child(replay)
	results_next = _button("NEXT SHIFT", K.TEAL, K.CREAM, 19, true, 0, 56)
	results_next.visible = false
	box.add_child(results_next)
	var title := _button("BACK TO TITLE", K.CREAM, K.INK, 17, false, 0, 50)
	title.pressed.connect(func() -> void: title_pressed.emit())
	box.add_child(title)
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
	touch_root.visible = false
	root.add_child(touch_root)

	stick = TouchStick.new()
	stick.name = "Stick"
	stick.anchor_left = 0.0
	stick.anchor_right = 0.42
	stick.anchor_top = 0.0
	stick.anchor_bottom = 1.0
	stick.offset_left = 0
	stick.offset_right = 0
	stick.offset_top = 260
	stick.offset_bottom = 0
	touch_root.add_child(stick)

	look_pad = LookPad.new()
	look_pad.name = "LookPad"
	look_pad.anchor_left = 0.42
	look_pad.anchor_right = 1.0
	look_pad.anchor_top = 0.0
	look_pad.anchor_bottom = 1.0
	look_pad.offset_left = 0
	look_pad.offset_right = 0
	look_pad.offset_top = 130
	look_pad.offset_bottom = 0
	touch_root.add_child(look_pad)

	pad_vacuum = _touch_pad("Vacuum", "VAC", Vector2(-116, -116), 88, K.CORAL, K.CREAM)
	pad_jump = _touch_pad("Jump", "JUMP", Vector2(-318, -94), 66, K.TEAL_DARK, K.CREAM)
	pad_dash = _touch_pad("Dash", "DASH", Vector2(-292, -292), 56, K.INK, K.CREAM)
	pad_pulse = _touch_pad("Pulse", "PULSE", Vector2(-94, -490), 56, K.TEAL, K.CREAM)
	pad_use = _touch_pad("Use", "USE", Vector2(-94, -318), 66, K.INK, K.CREAM)
	pad_use.held_started.connect(func() -> void: interact_pressed.emit())
	set_touch_rank(touch_rank)


func _touch_pad(pad_name: String, text: String, center: Vector2, radius: float, fill: Color, ink: Color) -> TouchPad:
	var pad := TouchPad.new()
	pad.name = pad_name
	pad.label_text = text
	pad.fill = fill
	pad.ink = ink
	pad.radius = radius
	pad.anchor_left = 1.0
	pad.anchor_right = 1.0
	pad.anchor_top = 1.0
	pad.anchor_bottom = 1.0
	pad.offset_left = center.x - radius
	pad.offset_right = center.x + radius
	pad.offset_top = center.y - radius
	pad.offset_bottom = center.y + radius
	touch_root.add_child(pad)
	return pad


func set_touch_mode(on: bool) -> void:
	if touch_mode == on:
		return
	touch_mode = on
	if not on:
		_reset_touch()
	_apply_copy_width()
	if prompt_label:
		prompt_label.text = _prompt_copy(_prompt_text)
	if dialogue_panel and dialogue_panel.visible:
		dialogue_hint.text = _hint_copy(not _pending_choices.is_empty())
	_refresh_touch()


static func wants_touch(mobile: bool, web_android: bool, web_ios: bool, touchscreen: bool) -> bool:
	return mobile or web_android or web_ios or touchscreen


func _prompt_copy(text: String) -> String:
	if touch_mode and text.begins_with("E  "):
		return "USE  " + text.substr(3)
	return text


func _hint_copy(choosing: bool) -> String:
	if touch_mode:
		return "TAP A CHOICE" if choosing else "TAP TO CONTINUE"
	return "CHOOSE" if choosing else "E  NEXT"


func set_touch_rank(value: int) -> void:
	touch_rank = value
	if pad_dash:
		pad_dash.visible = value >= 3
	if pad_pulse:
		pad_pulse.visible = value >= 5


func _refresh_touch() -> void:
	if touch_root == null:
		return
	var show := touch_mode and _phase == "play" and not dialogue_open() and (skip_button == null or not skip_button.visible)
	if touch_root.visible and not show:
		_reset_touch()
	touch_root.visible = show


func _reset_touch() -> void:
	for node in touch_root.get_children():
		if node.has_method("release"):
			node.release()


func _apply_copy_width() -> void:
	if prompt_panel:
		prompt_panel.offset_left = -240.0 if touch_mode else -330.0
		prompt_panel.offset_right = 240.0 if touch_mode else 330.0
	if subtitle_panel:
		subtitle_panel.offset_left = -240.0 if touch_mode else -390.0
		subtitle_panel.offset_right = 240.0 if touch_mode else 390.0


func _input(event: InputEvent) -> void:
	if not touch_mode:
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			set_touch_mode(true)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		set_touch_mode(false)
	elif event is InputEventJoypadButton and event.pressed:
		set_touch_mode(false)
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		set_touch_mode(false)


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
	_refresh_touch()


func prompt(text: String) -> void:
	if text == _prompt_text:
		return
	_prompt_text = text
	prompt_label.text = _prompt_copy(text)
	prompt_panel.visible = text != "" and (_phase == "play")


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
	var objective := str(data.get("objective", ""))
	objective_label.text = objective
	objective_label.visible = objective != ""


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


func show_shifts(entries: Array, note := "") -> void:
	title_note.visible = note != ""
	title_note.text = note
	for child in title_shifts.get_children():
		child.queue_free()
	for entry in entries:
		var index := int(entry.get("index", 1))
		if not bool(entry.get("unlocked", false)):
			var locked := _label("SHIFT %d   LOCKED" % index, 13, Color(0.13, 0.12, 0.1, 0.32), true)
			title_shifts.add_child(locked)
			continue
		var label := "SHIFT %d   %s" % [index, str(entry.get("title", "SHIFT"))]
		var button := _button(label, K.CORAL if index == int(entry.get("latest", 1)) else K.TEAL, K.CREAM, 17, index == int(entry.get("latest", 1)), 430, 48)
		button.pressed.connect(func() -> void: shift_pressed.emit(index))
		title_shifts.add_child(button)
		if bool(entry.get("done", false)):
			var stamp := _label("DONE", 11, Color(0.13, 0.12, 0.1, 0.5), true)
			title_shifts.add_child(stamp)


func show_results(stats: Dictionary) -> void:
	for child in results_grid.get_children():
		child.queue_free()
	results_title.text = str(stats.get("title", "STREET RESTORED"))
	results_line.text = str(stats.get("line", "The street is clean and the bell is still ringing."))
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
	var next_index := int(stats.get("next", 0))
	if next_index > 0:
		if not results_next.visible:
			results_next.visible = true
		if not results_next.pressed.is_connected(_emit_shift):
			results_next.pressed.connect(_emit_shift.bind(next_index))
		else:
			for connection in results_next.pressed.get_connections():
				results_next.pressed.disconnect(connection["callable"])
			results_next.pressed.connect(_emit_shift.bind(next_index))
		results_next.text = "NEXT SHIFT   %s" % str(stats.get("next_title", "ONWARDS"))
	else:
		results_next.visible = false
	results_layer.visible = true


func _emit_shift(index: int) -> void:
	shift_pressed.emit(index)


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
	return touch_root.visible and stick != null and stick.wants_sprint()


func touch_wants_vacuum() -> bool:
	return touch_root.visible and pad_vacuum != null and pad_vacuum.held


func touch_wants_jump() -> bool:
	return touch_root.visible and pad_jump != null and pad_jump.held


func touch_wants_dash() -> bool:
	return touch_root.visible and pad_dash != null and pad_dash.held


func touch_wants_pulse() -> bool:
	return touch_root.visible and pad_pulse != null and pad_pulse.held


func touch_available() -> bool:
	return touch_mode
