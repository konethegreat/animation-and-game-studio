extends Node2D

const W := 960.0
const H := 540.0

const INK := Color(0.055, 0.06, 0.075)
const CREAM := Color(0.98, 0.965, 0.925)
const LIME := Color(0.788, 0.949, 0.306)
const CORAL := Color(1.0, 0.353, 0.235)
const MUTED := Color(0.98, 0.965, 0.925, 0.45)

var player_x := W * 0.5
var target_x := player_x
var score := 0
var best := 0
var star := Vector2.ZERO
var speed := 170.0
var rng := RandomNumberGenerator.new()
var config := ConfigFile.new()


func _ready() -> void:
	rng.randomize()
	_load_best()
	_spawn_star()


func _load_best() -> void:
	if config.load("user://sample.cfg") == OK:
		best = int(config.get_value("score", "best", 0))


func _save_best() -> void:
	if score <= best:
		return
	best = score
	config.set_value("score", "best", best)
	config.save("user://sample.cfg")


func _spawn_star() -> void:
	star = Vector2(rng.randf_range(70.0, W - 70.0), rng.randf_range(-40.0, 40.0))
	speed = 160.0 + score * 8.0


func _process(delta: float) -> void:
	var direction := 0.0
	if Input.is_action_pressed("ui_left"):
		direction -= 1.0
	if Input.is_action_pressed("ui_right"):
		direction += 1.0
	target_x += direction * 620.0 * delta

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		target_x = get_viewport().get_mouse_position().x
	target_x = clampf(target_x, 48.0, W - 48.0)
	player_x = lerpf(player_x, target_x, 1.0 - exp(-14.0 * delta))

	star.y += speed * delta
	if star.y > H + 40.0:
		_spawn_star()

	var player := Vector2(player_x, H - 84.0)
	if player.distance_to(star) < 44.0:
		score += 1
		_save_best()
		_spawn_star()

	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), INK)
	for i in 40:
		var x := fmod(float(i) * 227.0, W)
		var y := fmod(float(i) * 131.0 + float(score) * 9.0, H)
		draw_circle(Vector2(x, y), 1.6, MUTED)
	draw_circle(star, 18.0, CORAL)
	draw_circle(star, 10.0, INK)
	draw_circle(Vector2(player_x, H - 84.0), 20.0, LIME)
	draw_string(ThemeDB.fallback_font, Vector2(40, 64), str(score), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, CREAM)
	draw_string(ThemeDB.fallback_font, Vector2(40, 94), "best %d" % best, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)
