extends Node2D

enum State { MENU, PLAY, OVER }

const W := 960.0
const H := 540.0

const INK_TOP := Color(0.075, 0.082, 0.11)
const INK_BOTTOM := Color(0.035, 0.039, 0.055)
const CREAM := Color(0.98, 0.965, 0.925)
const LIME := Color(0.788, 0.949, 0.306)
const CORAL := Color(1.0, 0.353, 0.235)
const MUTED := Color(0.98, 0.965, 0.925, 0.45)
const ROCK_DARK := Color(0.53, 0.16, 0.10)

var state: State = State.MENU
var score := 0
var best := 0
var lives := 3
var ship_x := W * 0.5
var drag_x := W * 0.5
var dragging := false
var elapsed := 0.0
var spawn_timer := 0.8
var invulnerable := 0.0
var shake := 0.0
var over_timer := 0.0

var items: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var backdrop: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var font: Font

var collect_player: AudioStreamPlayer
var hit_player: AudioStreamPlayer
var config := ConfigFile.new()


func _ready() -> void:
	rng.randomize()
	font = ThemeDB.fallback_font
	for i in 70:
		backdrop.append({
			"pos": Vector2(rng.randf_range(0, W), rng.randf_range(0, H)),
			"speed": rng.randf_range(6.0, 34.0),
			"size": rng.randf_range(0.8, 2.4),
			"alpha": rng.randf_range(0.18, 0.65),
		})
	collect_player = _make_player("res://audio/collect.wav", -7.0)
	hit_player = _make_player("res://audio/hit.wav", -4.0)
	_load_best()


func _make_player(path: String, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		player.stream = load(path)
	player.volume_db = volume
	add_child(player)
	return player


func _load_best() -> void:
	if config.load("user://orbit.cfg") == OK:
		best = int(config.get_value("score", "best", 0))


func _save_best() -> void:
	if score <= best:
		return
	best = score
	config.set_value("score", "best", best)
	config.save("user://orbit.cfg")


func _start() -> void:
	state = State.PLAY
	score = 0
	lives = 3
	invulnerable = 0.0
	shake = 0.0
	spawn_timer = 0.7
	elapsed = 0.0
	over_timer = 0.0
	items.clear()
	particles.clear()
	ship_x = W * 0.5
	drag_x = ship_x


func _confirm() -> void:
	if state == State.MENU:
		_start()
	elif state == State.OVER and over_timer > 0.35:
		_start()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_confirm()
	if event is InputEventScreenTouch:
		dragging = event.pressed
		drag_x = event.position.x
		if event.pressed:
			_confirm()
	elif event is InputEventScreenDrag:
		drag_x = event.position.x
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		drag_x = event.position.x
		if event.pressed:
			_confirm()
	elif event is InputEventMouseMotion and dragging:
		drag_x = event.position.x


func _process(delta: float) -> void:
	elapsed += delta
	over_timer += delta

	for star in backdrop:
		star["pos"] = (star["pos"] as Vector2) + Vector2(0, float(star["speed"]) * delta)
		if (star["pos"] as Vector2).y > H + 4:
			star["pos"] = Vector2(rng.randf_range(0, W), -4)

	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 3.4)
	if invulnerable > 0.0:
		invulnerable = maxf(0.0, invulnerable - delta)

	if state == State.PLAY:
		_move_ship(delta)
		_update_items(delta)
		_update_particles(delta)
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn()
			spawn_timer = maxf(0.32, 0.92 - score * 0.0035)
	elif state == State.OVER:
		_update_particles(delta)

	queue_redraw()


func _move_ship(delta: float) -> void:
	if dragging:
		ship_x = lerpf(ship_x, drag_x, 1.0 - exp(-12.0 * delta))
	else:
		var direction := 0.0
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
			direction -= 1.0
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
			direction += 1.0
		ship_x += direction * 440.0 * delta
	ship_x = clampf(ship_x, 46.0, W - 46.0)


func _spawn() -> void:
	var kind := "star" if rng.randf() < 0.72 else "rock"
	var radii: Array[float] = []
	for i in 7:
		radii.append(rng.randf_range(12.0, 19.0))
	items.append({
		"kind": kind,
		"pos": Vector2(rng.randf_range(48.0, W - 48.0), -28.0),
		"rot": rng.randf_range(0.0, TAU),
		"spin": rng.randf_range(-2.4, 2.4),
		"radii": radii,
		"size": rng.randf_range(14.0, 19.0),
	})


func _update_items(delta: float) -> void:
	var fall := 118.0 + minf(190.0, score * 1.3)
	var ship_pos := Vector2(ship_x, 462.0)
	for i in range(items.size() - 1, -1, -1):
		var item := items[i]
		var pos: Vector2 = item["pos"] + Vector2(0, fall * delta)
		item["pos"] = pos
		item["rot"] = float(item["rot"]) + float(item["spin"]) * delta

		if pos.y > H + 40:
			items.remove_at(i)
			continue

		if pos.distance_to(ship_pos) < 34.0:
			if item["kind"] == "star":
				score += 10
				_burst(pos, LIME, 14)
				if collect_player.stream:
					collect_player.play()
				items.remove_at(i)
			elif invulnerable <= 0.0:
				lives -= 1
				invulnerable = 1.3
				shake = 1.0
				_burst(pos, CORAL, 20)
				if hit_player.stream:
					hit_player.play()
				items.remove_at(i)
				if lives <= 0:
					state = State.OVER
					over_timer = 0.0
					_save_best()


func _burst(at: Vector2, color: Color, amount: int) -> void:
	for i in amount:
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(40.0, 220.0)
		particles.append({
			"pos": at,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"life": rng.randf_range(0.25, 0.65),
			"max_life": 0.65,
			"size": rng.randf_range(2.0, 5.0),
			"color": color,
		})


func _update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var particle := particles[i]
		particle["life"] = float(particle["life"]) - delta
		if float(particle["life"]) <= 0.0:
			particles.remove_at(i)
			continue
		particle["pos"] = particle["pos"] + (particle["vel"] as Vector2) * delta
		particle["vel"] = (particle["vel"] as Vector2) * (1.0 - 1.8 * delta)


func _draw() -> void:
	_draw_background()

	draw_set_transform(Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake * 11.0, 0.0, Vector2.ONE)
	_draw_stars()
	for item in items:
		_draw_item(item)
	if state != State.MENU and state != State.OVER:
		if invulnerable <= 0.0 or int(elapsed * 12.0) % 2 == 0:
			_draw_ship(Vector2(ship_x, 462.0))
	elif state == State.MENU:
		_draw_ship(Vector2(W * 0.5, 430.0 + sin(elapsed * 2.2) * 7.0))
	_draw_particles()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if state == State.PLAY:
		_draw_hud()
	elif state == State.MENU:
		_draw_menu()
	else:
		_draw_over()


func _draw_background() -> void:
	for i in 26:
		var f := i / 25.0
		draw_rect(Rect2(0, i * H / 26.0, W, H / 26.0 + 1), INK_TOP.lerp(INK_BOTTOM, f))
	draw_circle(Vector2(760, 130), 150, Color(1.0, 0.353, 0.235, 0.045))
	draw_circle(Vector2(180, 430), 220, Color(0.788, 0.949, 0.306, 0.035))
	draw_arc(Vector2(W * 0.5, H * 0.52), 250, 0.0, TAU, 96, Color(0.98, 0.965, 0.925, 0.05), 1.0, true)
	draw_arc(Vector2(W * 0.5, H * 0.52), 330, 0.0, TAU, 96, Color(0.98, 0.965, 0.925, 0.03), 1.0, true)


func _draw_stars() -> void:
	for star in backdrop:
		var color := Color(CREAM, float(star["alpha"]))
		draw_circle(star["pos"], float(star["size"]), color)


func _draw_item(item: Dictionary) -> void:
	var pos: Vector2 = item["pos"]
	var rot: float = item["rot"]
	if item["kind"] == "star":
		draw_circle(pos, 30.0, Color(0.788, 0.949, 0.306, 0.12))
		draw_colored_polygon(_star_points(pos, 17.0, 7.5, rot), LIME)
	else:
		var radii: Array[float] = item["radii"]
		var points := PackedVector2Array()
		for i in radii.size():
			var angle := TAU * i / radii.size() + rot
			points.append(pos + Vector2(cos(angle), sin(angle)) * radii[i])
		draw_colored_polygon(points, CORAL)
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, ROCK_DARK, 3.0, true)
		draw_circle(pos + Vector2(-4, -3), 4.0, ROCK_DARK)


func _star_points(center: Vector2, outer: float, inner: float, rot: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var radius := outer if i % 2 == 0 else inner
		var angle := -PI * 0.5 + rot + i * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _draw_ship(pos: Vector2) -> void:
	var flame := 7.0 + sin(elapsed * 34.0) * 3.5
	draw_line(pos + Vector2(0, 22), pos + Vector2(0, 48), Color(0.788, 0.949, 0.306, 0.22), 3.0, true)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-8, 14), pos + Vector2(0, 20 + flame), pos + Vector2(8, 14),
	]), CORAL)
	var body := PackedVector2Array([
		pos + Vector2(0, -23), pos + Vector2(-19, 17), pos + Vector2(0, 9), pos + Vector2(19, 17),
	])
	draw_colored_polygon(body, LIME)
	var closed := body.duplicate()
	closed.append(body[0])
	draw_polyline(closed, CREAM, 2.0, true)
	draw_circle(pos + Vector2(0, -2), 5.0, CREAM)


func _draw_particles() -> void:
	for particle in particles:
		var life := float(particle["life"]) / float(particle["max_life"])
		var color: Color = particle["color"]
		color.a = clampf(life, 0.0, 1.0)
		draw_circle(particle["pos"], float(particle["size"]) * (0.4 + life), color)


func _draw_hud() -> void:
	draw_string(font, Vector2(28, 44), "SCORE  %04d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, CREAM)
	draw_string(font, Vector2(28, 70), "BEST  %04d" % maxi(best, score), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)
	for i in 3:
		var x := W - 40.0 - i * 30.0
		var color := LIME if i < lives else Color(0.98, 0.965, 0.925, 0.16)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 26), Vector2(x - 9, 44), Vector2(x, 38), Vector2(x + 9, 44),
		]), color)


func _draw_menu() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.035, 0.039, 0.055, 0.45))
	var title := "ORBIT RUN"
	var title_size := 72
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	draw_string(font, Vector2((W - title_width) * 0.5, 210), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, CREAM)
	draw_circle(Vector2((W + title_width) * 0.5 + 14, 188), 8, LIME)
	_centered("Collect stars. Dodge rocks.", 258, 22, MUTED)
	_centered("PRESS SPACE OR TAP TO START", 352, 16, Color(CREAM, 0.55 + 0.35 * sin(elapsed * 3.4)))
	_centered("A / D or drag to move", 492, 14, Color(CREAM, 0.32))


func _draw_over() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.035, 0.039, 0.055, 0.74))
	_centered("RUN OVER", 214, 64, CREAM)
	_centered("SCORE  %04d" % score, 274, 28, LIME)
	_centered("BEST  %04d" % best, 310, 18, MUTED)
	if over_timer > 0.35:
		_centered("PRESS SPACE OR TAP TO RETRY", 380, 16, Color(CREAM, 0.55 + 0.35 * sin(elapsed * 3.4)))


func _centered(text: String, y: float, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2((W - width) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
