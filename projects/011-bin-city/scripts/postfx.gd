extends CanvasLayer

const POST = preload("res://shaders/post.gdshader")

var rect: ColorRect
var material: ShaderMaterial
var _time := 0.0
var _quality := "standard"
var _mood := "dawn"


func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.name = "Grade"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	material = ShaderMaterial.new()
	material.shader = POST
	rect.material = material
	add_child(rect)
	set_quality(_quality)
	set_mood(_mood)


func set_quality(name: String) -> void:
	_quality = name
	rect.visible = name != "low" and _mood != "plain"
	if not rect.visible:
		return
	match name:
		"high":
			material.set_shader_parameter("strength", 0.62)
			material.set_shader_parameter("grain", 0.03)
			material.set_shader_parameter("vignette", 0.32)
		_:
			material.set_shader_parameter("strength", 0.5)
			material.set_shader_parameter("grain", 0.022)
			material.set_shader_parameter("vignette", 0.28)


func set_accents(warm_color: Color, cool_color: Color, amount := 0.5) -> void:
	material.set_shader_parameter("warm", warm_color)
	material.set_shader_parameter("cool", cool_color)
	material.set_shader_parameter("strength", amount)


func set_mood(mood: String) -> void:
	_mood = mood
	rect.visible = _quality != "low"
	match mood:
		"canal":
			set_accents(Color(0.9, 0.98, 0.93), Color(0.66, 0.83, 0.86), 0.44)
		"night":
			set_accents(Color(0.95, 0.84, 0.68), Color(0.55, 0.72, 0.95), 0.58)
		"neon":
			set_accents(Color(1.0, 0.72, 0.88), Color(0.55, 0.85, 1.0), 0.5)
		"boss":
			set_accents(Color(1.0, 0.72, 0.5), Color(0.7, 0.62, 0.68), 0.6)
		"plain":
			rect.visible = false
		_:
			set_accents(Color(1.0, 0.94, 0.83), Color(0.59, 0.74, 0.95), 0.44)


func _process(delta: float) -> void:
	if not rect.visible:
		return
	var settings = get_node_or_null("/root/GameState")
	if settings != null and bool(settings.settings.get("reduced_motion", false)):
		return
	_time += delta
	material.set_shader_parameter("time", _time)
