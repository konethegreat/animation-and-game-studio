extends Node2D

## Orbit Run: a radial orbit runner.
## A paper courier circles a small planet. Drag in or out to change orbit,
## thread debris, collect stars, graze rocks for surge and ride the milestones.

enum State { MENU, PLAY, OVER }

const W := 960.0
const H := 540.0
const CX := 480.0
const CY := 292.0
const PLANET_R := 82.0
const ORBIT_MIN := 116.0
const ORBIT_MAX := 216.0
const TAU := PI * 2.0

const CREAM := Color(0.98, 0.965, 0.925)
const LIME := Color(0.788, 0.949, 0.306)
const CORAL := Color(1.0, 0.353, 0.235)
const CORAL_DARK := Color(0.55, 0.17, 0.11)
const INK := Color(0.075, 0.082, 0.11)
const MUTED := Color(0.98, 0.965, 0.925, 0.52)
const FAINT := Color(0.98, 0.965, 0.925, 0.16)

var state: State = State.MENU
var calm := false
var elapsed := 0.0
var over_timer := 0.0

var angle := 0.15
var radius := 208.0
var target_radius := 172.0
var dragging := false

var score := 0
var best := 0
var best_range := 0
var lives := 3
var shields := 0
var stars_taken := 0
var distance := 0.0
var combo := 1
var combo_timer := 0.0
var surge := 0.0
var surge_time := 0.0
var stage := 0
var sky_stage := 0.0
var invulnerable := 0.0
var shake := 0.0
var flash := 0.0
var spawn_timer := 0.6

var banner := ""
var banner_sub := ""
var banner_timer := 0.0

var items: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var toasts: Array[Dictionary] = []
var trail: Array[Dictionary] = []

var rng := RandomNumberGenerator.new()
var font: Font
var nebula_material: ShaderMaterial
var planet_material: ShaderMaterial

var pad_player: AudioStreamPlayer
var hit_player: AudioStreamPlayer
var surge_player: AudioStreamPlayer
var milestone_player: AudioStreamPlayer
var collect_players: Array[AudioStreamPlayer] = []
var collect_cursor := 0

var config := ConfigFile.new()

const MILESTONES := [600.0, 1500.0, 2600.0]
const STAGE_NAMES := ["PAPER BELT", "COMET DRIFT", "DAWN LINE"]


func _ready() -> void:
	rng.randomize()
	font = ThemeDB.fallback_font
	_build_sky()
	_build_audio()
	_detect_calm()
	_load_best()


func _build_sky() -> void:
	var nebula := ColorRect.new()
	nebula.size = Vector2(W, H)
	nebula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nebula.z_index = -3
	nebula_material = ShaderMaterial.new()
	nebula_material.shader = load("res://nebula.gdshader")
	nebula.material = nebula_material
	add_child(nebula)

	var disc := PLANET_R * 2.0
	var planet := ColorRect.new()
	planet.size = Vector2(disc, disc)
	planet.position = Vector2(CX - PLANET_R, CY - PLANET_R)
	planet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	planet.z_index = -2
	planet_material = ShaderMaterial.new()
	planet_material.shader = load("res://planet.gdshader")
	planet.material = planet_material
	add_child(planet)


func _build_audio() -> void:
	pad_player = _audio_player(_make_pad(), -15.0)
	hit_player = _audio_player(_make_hit(), -4.0)
	surge_player = _audio_player(_make_surge(), -6.0)
	milestone_player = _audio_player(_make_milestone(), -5.0)
	for i in 3:
		collect_players.append(_audio_player(_make_collect(), -8.0))


func _audio_player(stream: AudioStream, volume: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume
	add_child(player)
	return player


func _wav(samples: PackedFloat32Array, rate: int = 22050, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


func _make_pad() -> AudioStreamWAV:
	var rate := 22050
	var n := rate * 8
	var out := PackedFloat32Array()
	out.resize(n)
	var notes := [110.0, 165.0, 220.0, 262.0, 330.0]
	var amps := [0.42, 0.30, 0.24, 0.16, 0.10]
	for i in n:
		var t := float(i) / float(rate)
		var s := 0.0
		for k in notes.size():
			s += sin(TAU * float(notes[k]) * t + float(k) * 0.7) * float(amps[k])
		var lfo := 0.66 + 0.34 * sin(TAU * 0.25 * t)
		out[i] = s * lfo * 0.125
	return _wav(out, rate, true)


func _make_collect() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.16
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * 26.0)
		var s := sin(TAU * 880.0 * t) * 0.6 + sin(TAU * 1320.0 * t) * 0.4
		out[i] = s * env * 0.5
	return _wav(out, rate)


func _make_hit() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.34
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var nrng := RandomNumberGenerator.new()
	nrng.seed = 19
	var last := 0.0
	for i in n:
		var t := float(i) / float(rate)
		var env := exp(-t * 9.0)
		last = last * 0.72 + nrng.randf_range(-1.0, 1.0) * 0.28
		var tone := sin(TAU * (120.0 - 40.0 * t) * t)
		out[i] = (tone * 0.6 + last * 0.5) * env * 0.5
	return _wav(out, rate)


func _make_surge() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.62
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(rate)
		var f := 180.0 + 780.0 * pow(t / dur, 1.25)
		phase += TAU * f / float(rate)
		var env := minf(1.0, t * 12.0) * exp(-t * 3.2)
		out[i] = (sin(phase) * 0.7 + sin(phase * 2.01) * 0.2) * env * 0.5
	return _wav(out, rate)


func _make_milestone() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.7
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var step := 0.11
	for i in n:
		var t := float(i) / float(rate)
		var index := clampi(int(t / step), 0, notes.size() - 1)
		var local := t - float(index) * step
		var env := exp(-local * 9.0)
		out[i] = sin(TAU * float(notes[index]) * t) * env * 0.4
	return _wav(out, rate)


func _detect_calm() -> void:
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var js := Engine.get_singleton("JavaScriptBridge")
		var prefers = js.call("eval", "window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches")
		calm = bool(prefers)


func _load_best() -> void:
	if config.load("user://orbit.cfg") == OK:
		best = int(config.get_value("score", "best", 0))
		best_range = int(config.get_value("score", "range", 0))


func _save_best() -> void:
	if score <= best and int(distance) <= best_range:
		return
	best = maxi(best, score)
	best_range = maxi(best_range, int(distance))
	config.set_value("score", "best", best)
	config.set_value("score", "range", best_range)
	config.save("user://orbit.cfg")


func _start() -> void:
	state = State.PLAY
	score = 0
	lives = 3
	shields = 1
	stars_taken = 0
	distance = 0.0
	combo = 1
	combo_timer = 0.0
	surge = 0.0
	surge_time = 0.0
	stage = 0
	sky_stage = 0.0
	invulnerable = 0.0
	shake = 0.0
	flash = 0.0
	spawn_timer = 1.1
	angle = -PI * 0.5
	radius = 172.0
	target_radius = 172.0
	invulnerable = 1.2
	items.clear()
	particles.clear()
	toasts.clear()
	trail.clear()
	banner = "ORBIT LOCKED"
	banner_sub = "Drag in or out to steer"
	banner_timer = 2.6
	if pad_player:
		pad_player.play()


func _confirm() -> void:
	if state == State.MENU:
		_start()
	elif state == State.OVER and over_timer > 0.35:
		_start()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_confirm()
		elif event.keycode == KEY_C:
			_toggle_calm()
	if event is InputEventScreenTouch:
		if event.pressed:
			if state != State.PLAY and _calm_rect().has_point(event.position):
				_toggle_calm()
				return
			_confirm()
			if state == State.PLAY:
				_point_radius(event.position)
		dragging = event.pressed
	elif event is InputEventScreenDrag:
		if state == State.PLAY:
			_point_radius(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if state != State.PLAY and _calm_rect().has_point(event.position):
				_toggle_calm()
				return
			_confirm()
			if state == State.PLAY:
				_point_radius(event.position)
		dragging = event.pressed
	elif event is InputEventMouseMotion:
		if state == State.PLAY:
			_point_radius(event.position)


func _point_radius(screen_pos: Vector2) -> void:
	var d := Vector2(screen_pos.x - CX, screen_pos.y - CY).length()
	target_radius = clampf(d, ORBIT_MIN, ORBIT_MAX)


func _toggle_calm() -> void:
	calm = not calm


func _process(delta: float) -> void:
	elapsed += delta
	over_timer += delta
	over_timer = minf(over_timer, 10.0)

	shake = maxf(0.0, shake - delta * 3.2)
	flash = maxf(0.0, flash - delta * 3.6)
	invulnerable = maxf(0.0, invulnerable - delta)
	banner_timer = maxf(0.0, banner_timer - delta)

	if state == State.MENU:
		angle += 0.1 * delta
		radius = 208.0 + sin(elapsed * 0.5) * 4.0
		target_radius = radius
		_update_particles(delta)
	elif state == State.PLAY:
		_play(delta)
	else:
		_update_particles(delta)
		for i in range(items.size() - 1, -1, -1):
			var item: Dictionary = items[i]
			item["rot"] = float(item["rot"]) + float(item["spin"]) * delta * 0.3

	for i in range(trail.size() - 1, -1, -1):
		trail[i]["life"] = float(trail[i]["life"]) - delta * 2.4
		if float(trail[i]["life"]) <= 0.0:
			trail.remove_at(i)
	_update_toasts(delta)

	var sky_target := float(stage) * 0.5
	sky_stage = lerpf(sky_stage, sky_target, 1.0 - exp(-2.2 * delta))
	if nebula_material:
		nebula_material.set_shader_parameter("stage", sky_stage)
		nebula_material.set_shader_parameter("calm", 1.0 if calm else 0.0)
	if planet_material:
		var glow := 1.0 if calm else 0.72 + 0.28 * sin(elapsed * 1.3)
		planet_material.set_shader_parameter("stage", minf(1.0, sky_stage))
		planet_material.set_shader_parameter("glow", glow)

	queue_redraw()


func _play(delta: float) -> void:
	var boost := surge_time > 0.0
	surge_time = maxf(0.0, surge_time - delta)

	var rate := 1.0
	if boost:
		rate *= 1.55
	if calm:
		rate *= 0.74
	angle += 0.95 * rate * delta

	var guide := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		guide += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		guide -= 1.0
	if guide != 0.0:
		target_radius = clampf(target_radius + guide * 250.0 * delta, ORBIT_MIN, ORBIT_MAX)

	radius = lerpf(radius, target_radius, 1.0 - exp(-9.0 * delta))
	var travelled := 0.95 * rate * radius * delta * 0.16
	distance += travelled
	score += int(round(travelled * (2.0 if boost else 1.0)))

	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 1

	if surge_time <= 0.0 and surge >= 1.0:
		surge = 0.0
		surge_time = 2.6
		banner = "SURGE"
		banner_sub = "Hold the line"
		banner_timer = 1.8
		if surge_player:
			surge_player.play()

	if state == State.PLAY:
		while stage < MILESTONES.size() and distance >= float(MILESTONES[stage]):
			_milestone(stage)

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_item()
		var gap := maxf(0.42, 1.0 - minf(0.42, distance * 0.00022))
		spawn_timer = gap * rng.randf_range(0.86, 1.14) * (1.3 if calm else 1.0)

	_update_items(delta)
	_update_particles(delta)

	var pos := _ship_pos()
	trail.append({"pos": pos, "life": 1.0})
	if trail.size() > 26:
		trail.pop_front()


func _milestone(index: int) -> void:
	stage = index + 1
	shields = mini(2, shields + 1)
	score += 150
	banner = STAGE_NAMES[index]
	banner_sub = "Shield restored"
	banner_timer = 2.8
	_burst(_ship_pos(), LIME, 26, 1.2)
	if milestone_player:
		milestone_player.play()


func _spawn_item() -> void:
	var roll := rng.randf()
	var kind := "star"
	if distance > 200.0 and roll < 0.06:
		kind = "comet"
	elif roll < 0.34:
		kind = "rock"

	var item_angle := angle + rng.randf_range(1.5, 2.35)
	var item_radius := rng.randf_range(ORBIT_MIN + 8.0, ORBIT_MAX - 8.0)
	for attempt in 4:
		var clear := true
		for other in items:
			var rel: float = absf(wrapf(float(other["a"]) - item_angle, -PI, PI))
			if rel < 0.34 and absf(float(other["r"]) - item_radius) < 34.0:
				clear = false
				break
		if clear:
			break
		item_angle = angle + rng.randf_range(1.5, 2.35)
		item_radius = rng.randf_range(ORBIT_MIN + 8.0, ORBIT_MAX - 8.0)

	var size := rng.randf_range(9.0, 13.0)
	if kind == "comet":
		size = 11.0
	var radii: Array[float] = []
	for i in 7:
		radii.append(rng.randf_range(0.72, 1.18))
	items.append({
		"kind": kind,
		"a": item_angle,
		"r": item_radius,
		"rot": rng.randf_range(0.0, TAU),
		"spin": rng.randf_range(-1.8, 1.8),
		"radii": radii,
		"size": size,
		"va": -rng.randf_range(0.42, 0.62) if kind == "comet" else 0.0,
		"grazed": false,
	})


func _update_items(delta: float) -> void:
	for i in range(items.size() - 1, -1, -1):
		var item: Dictionary = items[i]
		var drift := 0.7 if calm else 1.0
		item["a"] = float(item["a"]) + float(item["va"]) * delta * drift
		item["rot"] = float(item["rot"]) + float(item["spin"]) * delta

		var rel := wrapf(float(item["a"]) - angle, -PI, PI)
		if rel < -2.75:
			items.remove_at(i)
			continue

		var gap := absf(rel) * radius
		var radial := absf(float(item["r"]) - radius)
		var size := float(item["size"])
		var reach := (18.0 if item["kind"] == "star" else 15.0) + size
		var item_pos := _polar(float(item["a"]), float(item["r"]))

		if gap < reach and radial < reach:
			if item["kind"] == "star":
				_collect(item_pos)
			else:
				_take_hit(item_pos)
			items.remove_at(i)
			continue

		if item["kind"] == "rock" and not bool(item["grazed"]):
			if gap < reach + 17.0 and radial < reach + 17.0:
				item["grazed"] = true
				_graze(item_pos)


func _collect(at: Vector2) -> void:
	combo = mini(8, combo + 1)
	combo_timer = 2.6
	stars_taken += 1
	score += 10 * combo
	surge = minf(1.0, surge + 0.05)
	_burst(at, LIME, 12, 1.0)
	_toast("+%d" % (10 * combo), at, LIME)
	var player: AudioStreamPlayer = collect_players[collect_cursor]
	collect_cursor = (collect_cursor + 1) % collect_players.size()
	player.pitch_scale = 1.0 + 0.06 * float(combo)
	player.play()


func _graze(at: Vector2) -> void:
	score += 2
	surge = minf(1.0, surge + 0.11)
	_burst(at, CREAM, 5, 0.55)
	_toast("GRAZE +2", at, CREAM)


func _take_hit(at: Vector2) -> void:
	if invulnerable > 0.0:
		return
	invulnerable = 1.5
	combo = 1
	combo_timer = 0.0
	surge = maxf(0.0, surge - 0.25)
	if not calm:
		shake = 1.0
		flash = 1.0

	if shields > 0:
		shields -= 1
		_burst(at, LIME, 18, 1.1)
		banner = "SHIELD LOST"
		banner_sub = "Graze debris to rebuild surge"
		banner_timer = 1.6
		if hit_player:
			hit_player.pitch_scale = 1.25
			hit_player.play()
		return

	lives -= 1
	_burst(at, CORAL, 24, 1.2)
	if hit_player:
		hit_player.pitch_scale = 1.0
		hit_player.play()

	if lives <= 0:
		_end_run()
	else:
		banner = "HULL HIT"
		banner_sub = "1 life left" if lives == 1 else "%d lives left" % lives
		banner_timer = 1.4


func _end_run() -> void:
	state = State.OVER
	over_timer = 0.0
	banner = ""
	banner_sub = ""
	banner_timer = 0.0
	_save_best()
	if pad_player:
		pad_player.stop()


func _burst(at: Vector2, color: Color, amount: int, power: float) -> void:
	var count := amount
	if calm:
		count = int(amount * 0.45)
	for i in count:
		var a := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(35.0, 210.0) * power
		particles.append({
			"pos": at,
			"vel": Vector2(cos(a), sin(a)) * speed,
			"life": rng.randf_range(0.24, 0.7),
			"max": 0.7,
			"size": rng.randf_range(1.4, 3.8),
			"color": color,
		})


func _update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p["life"] = float(p["life"]) - delta
		if float(p["life"]) <= 0.0:
			particles.remove_at(i)
			continue
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		p["vel"] = (p["vel"] as Vector2) * (1.0 - 1.9 * delta)


func _toast(text: String, at: Vector2, color: Color) -> void:
	toasts.append({"text": text, "pos": at, "life": 0.9, "max": 0.9, "color": color})


func _update_toasts(delta: float) -> void:
	for i in range(toasts.size() - 1, -1, -1):
		var t: Dictionary = toasts[i]
		t["life"] = float(t["life"]) - delta
		if float(t["life"]) <= 0.0:
			toasts.remove_at(i)
			continue
		t["pos"] = (t["pos"] as Vector2) - Vector2(0, 26.0 * delta)


func _ship_pos() -> Vector2:
	return _polar(angle, radius)


func _polar(a: float, r: float) -> Vector2:
	return Vector2(CX + cos(a) * r, CY + sin(a) * r)


func _calm_rect() -> Rect2:
	return Rect2(W - 160.0, 22.0, 138.0, 34.0)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	_draw_orbit_guides()

	var jitter := Vector2.ZERO
	if shake > 0.0:
		jitter = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake * 10.0
	draw_set_transform(jitter, 0.0, Vector2.ONE)

	_draw_planet_rings()
	_draw_items()
	_draw_trail()
	_draw_ship(_ship_pos())
	_draw_particles()
	_draw_toasts()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(CORAL, 0.15 * flash))

	if state == State.PLAY:
		_draw_hud()
	elif state == State.MENU:
		_draw_menu()
	else:
		_draw_over()


func _draw_orbit_guides() -> void:
	var rings := [ORBIT_MIN, (ORBIT_MIN + ORBIT_MAX) * 0.5, ORBIT_MAX]
	for ring in rings:
		var dashes := 34
		for i in dashes:
			if i % 2 == 1:
				continue
			var a0 := TAU * float(i) / float(dashes)
			draw_arc(
				Vector2(CX, CY), float(ring), a0, a0 + TAU / float(dashes) * 0.5,
				3, Color(CREAM, 0.045), 1.0, true
			)
	if state != State.MENU:
		draw_arc(Vector2(CX, CY), radius, 0.0, TAU, 96, Color(LIME, 0.10), 1.4, true)


func _draw_planet_rings() -> void:
	draw_arc(Vector2(CX, CY), PLANET_R + 9.0, 0.0, TAU, 96, Color(CREAM, 0.10), 1.2, true)
	draw_arc(Vector2(CX, CY), PLANET_R + 21.0, 0.2, TAU * 0.92, 72, Color(CREAM, 0.06), 1.0, true)


func _draw_items() -> void:
	for item in items:
		var pos := _polar(float(item["a"]), float(item["r"]))
		var rot := float(item["rot"])
		match item["kind"]:
			"star":
				var pulse := 1.0
				if not calm:
					pulse = 1.0 + sin(elapsed * 4.2 + rot) * 0.07
				draw_circle(pos, 21.0 * pulse, Color(LIME, 0.09))
				draw_circle(pos, 13.0 * pulse, Color(LIME, 0.14))
				draw_colored_polygon(_star_points(pos, 10.5 * pulse, 4.6 * pulse, rot), LIME)
				draw_circle(pos, 2.1, CREAM)
			"rock":
				var radii: Array = item["radii"]
				var size := float(item["size"])
				var points := PackedVector2Array()
				for i in radii.size():
					var a := TAU * float(i) / float(radii.size()) + rot
					points.append(pos + Vector2(cos(a), sin(a)) * float(radii[i]) * size)
				draw_circle(pos, size * 1.35, Color(CORAL, 0.08))
				draw_colored_polygon(points, CORAL)
				var closed := points.duplicate()
				closed.append(points[0])
				draw_polyline(closed, CORAL_DARK, 2.4, true)
				draw_circle(pos + Vector2(-2.4, -2.0), size * 0.22, CORAL_DARK)
			"comet":
				var a := float(item["a"])
				var flow := -signf(float(item["va"]))
				var tail := Vector2(-sin(a), cos(a)) * flow
				for i in range(7, 0, -1):
					var t := float(i) / 7.0
					draw_circle(pos + tail * (12.0 + t * 46.0), 11.0 * (1.0 - t) + 2.0, Color(CORAL, 0.10 + 0.16 * (1.0 - t)))
				draw_circle(pos, 15.0, Color(CORAL, 0.16))
				draw_circle(pos, 9.0, CREAM)
				draw_circle(pos, 6.0, CORAL)
				draw_circle(pos + Vector2(-2, -2), 2.4, CREAM)


func _star_points(center: Vector2, outer: float, inner: float, rot: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var r := outer if i % 2 == 0 else inner
		var a := -PI * 0.5 + rot + float(i) * PI / 5.0
		points.append(center + Vector2(cos(a), sin(a)) * r)
	return points


func _draw_trail() -> void:
	for i in trail.size():
		var t: Dictionary = trail[i]
		var life := clampf(float(t["life"]), 0.0, 1.0)
		var pos: Vector2 = t["pos"]
		draw_circle(pos, 5.5 * life, Color(LIME, 0.14 * life))


func _draw_ship(pos: Vector2) -> void:
	if invulnerable > 0.0 and int(elapsed * 14.0) % 2 == 0:
		return

	var stretch := 1.0
	if surge_time > 0.0:
		stretch = 1.10
	draw_set_transform(pos, angle + PI, Vector2(1.0 / stretch, stretch))

	var sway := 0.0 if calm else sin(elapsed * 3.6) * 4.0
	draw_polyline(PackedVector2Array([
		Vector2(2.0, 9.0),
		Vector2(8.0 + sway * 0.5, 20.0),
		Vector2(3.0 + sway, 32.0),
	]), LIME, 5.4, true)
	draw_polyline(PackedVector2Array([
		Vector2(2.0, 9.0),
		Vector2(8.0 + sway * 0.5, 20.0),
		Vector2(3.0 + sway, 32.0),
	]), Color(CREAM, 0.55), 1.4, true)

	draw_circle(Vector2.ZERO, 15.0, CREAM)
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 32, INK, 2.4, true)
	draw_circle(Vector2(9.0, 4.0), 4.6, CORAL)
	draw_arc(Vector2(9.0, 4.0), 4.6, 0.0, TAU, 16, CORAL_DARK, 1.6, true)

	draw_rect(Rect2(-8.6, -8.6, 17.2, 7.0), INK)
	draw_circle(Vector2(-8.6, -5.1), 3.5, INK)
	draw_circle(Vector2(8.6, -5.1), 3.5, INK)
	draw_circle(Vector2(-3.4, -6.6), 1.6, Color(CREAM, 0.7))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if shields > 0:
		for s in shields:
			draw_arc(pos, 23.0 + float(s) * 5.5, 0.0, TAU, 40, Color(LIME, 0.46 - float(s) * 0.1), 2.0, true)
	if surge_time > 0.0:
		var pulse := 0.5 + 0.5 * sin(elapsed * 14.0)
		draw_arc(pos, 31.0 + pulse * 4.0, 0.0, TAU, 44, Color(LIME, 0.25 + 0.25 * pulse), 2.2, true)


func _draw_particles() -> void:
	for p in particles:
		var life := clampf(float(p["life"]) / float(p["max"]), 0.0, 1.0)
		var color: Color = p["color"]
		color.a = life
		draw_circle(p["pos"], float(p["size"]) * (0.35 + life), color)


func _draw_toasts() -> void:
	for t in toasts:
		var life := clampf(float(t["life"]) / float(t["max"]), 0.0, 1.0)
		var color: Color = t["color"]
		color.a = life
		var pos: Vector2 = t["pos"]
		_centered_at(str(t["text"]), pos + Vector2(0, -18), 13, color)


func _draw_hud() -> void:
	draw_string(font, Vector2(28, 34), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	draw_string(font, Vector2(28, 62), "%05d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, CREAM)
	draw_string(font, Vector2(28, 88), "RANGE %04d M" % int(distance), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
	if best > 0:
		draw_string(font, Vector2(28, 110), "BEST %05d" % maxi(best, score), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(CREAM, 0.3))

	for i in 3:
		var x := W - 34.0 - float(i) * 26.0
		var color := CREAM if i < lives else FAINT
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 28), Vector2(x - 8, 44), Vector2(x, 39), Vector2(x + 8, 44),
		]), color)
	if shields > 0:
		for i in shields:
			draw_arc(Vector2(W - 118.0 - float(i) * 20.0, 36.0), 7.0, 0.0, TAU, 20, Color(LIME, 0.8), 2.0, true)

	if combo > 1:
		var alpha := clampf(combo_timer / 2.6, 0.0, 1.0)
		draw_string(font, Vector2(28, H - 44), "COMBO x%d" % combo, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(LIME, 0.5 + 0.5 * alpha))
		draw_rect(Rect2(28, H - 34, 120.0 * alpha, 3.0), Color(LIME, 0.7))

	var bar := Rect2(W * 0.5 - 110.0, H - 38.0, 220.0, 8.0)
	draw_rect(bar, Color(CREAM, 0.1))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(surge, 0.0, 1.0), bar.size.y)), Color(LIME, 0.85))
	draw_rect(bar, Color(CREAM, 0.22), false, 1.0)
	if surge_time > 0.0:
		_centered_at("SURGING", Vector2(W * 0.5, H - 50.0), 12, Color(LIME, 0.9))
	else:
		_centered_at("SURGE", Vector2(W * 0.5, H - 50.0), 11, MUTED)

	if banner_timer > 0.0:
		var a := clampf(banner_timer, 0.0, 1.0)
		var lift := (1.0 - clampf(banner_timer / 0.6, 0.0, 1.0)) * 6.0
		_centered_at(banner, Vector2(W * 0.5, 132.0 - lift), 30, Color(CREAM, a))
		_centered_at(banner_sub, Vector2(W * 0.5, 158.0 - lift), 13, Color(CREAM, 0.6 * a))


func _draw_menu() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.035, 0.039, 0.055, 0.42))
	_draw_calm_chip()

	draw_arc(Vector2(CX, CY - 118.0), 30.0, PI * 0.15, PI * 0.85, 24, Color(LIME, 0.45), 2.0, true)
	draw_circle(Vector2(CX - 26.0, CY - 129.0), 4.0, LIME)
	draw_circle(Vector2(CX + 26.0, CY - 129.0), 4.0, Color(CREAM, 0.5))

	_centered_at("ORBIT RUN", Vector2(CX, 190), 74, CREAM)
	_centered_at("A courier circles a paper planet.", Vector2(CX, 232), 18, Color(CREAM, 0.62))

	if best > 0:
		_centered_at("BEST %05d  /  %04d M" % [best, best_range], Vector2(CX, 284), 13, Color(LIME, 0.7))

	draw_rect(Rect2(CX - 176.0, 330.0, 352.0, 74.0), Color(0.035, 0.039, 0.055, 0.78))
	draw_rect(Rect2(CX - 176.0, 330.0, 352.0, 74.0), Color(CREAM, 0.2), false, 1.0)
	_centered_at("DRAG IN AND OUT TO STEER YOUR ORBIT", Vector2(CX, 356), 13, CREAM)
	_centered_at("Collect stars, graze debris, ride the surge", Vector2(CX, 380), 12, MUTED)

	var pulse := 0.55 + 0.4 * sin(elapsed * 3.2) if not calm else 0.8
	_centered_at("SPACE OR TAP TO START", Vector2(CX, 448), 16, Color(CREAM, pulse))
	_centered_at("W / S or arrow keys also work", Vector2(CX, 474), 11, Color(CREAM, 0.32))


func _draw_over() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.035, 0.039, 0.055, 0.84))
	_draw_calm_chip()

	_centered_at("RUN OVER", Vector2(CX, 190), 58, CREAM)
	_centered_at("%05d" % score, Vector2(CX, 252), 34, LIME)
	_centered_at("SCORE", Vector2(CX, 274), 11, MUTED)

	draw_string(font, Vector2(CX - 172.0, 330), "RANGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	draw_string(font, Vector2(CX + 60.0, 330), "STARS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
	draw_string(font, Vector2(CX - 172.0, 358), "%04d M" % int(distance), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, CREAM)
	draw_string(font, Vector2(CX + 60.0, 358), "%03d" % stars_taken, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, CREAM)
	_centered_at("BEST %05d  /  %04d M" % [best, best_range], Vector2(CX, 400), 13, Color(CREAM, 0.5))

	if over_timer > 0.35:
		var pulse := 0.55 + 0.4 * sin(elapsed * 3.2) if not calm else 0.8
		_centered_at("SPACE OR TAP TO RETRY", Vector2(CX, 458), 15, Color(CREAM, pulse))


func _draw_calm_chip() -> void:
	var r := _calm_rect()
	draw_rect(r, Color(0.035, 0.039, 0.055, 0.6))
	draw_rect(r, Color(CREAM, 0.22), false, 1.0)
	var label := "CALM ON" if calm else "CALM OFF"
	draw_string(font, r.position + Vector2(18, 22), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(CREAM, 0.8))
	draw_circle(r.position + Vector2(r.size.x - 20.0, 17.0), 4.0, LIME if calm else Color(CREAM, 0.25))


func _centered_at(text: String, center: Vector2, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(center.x - width * 0.5, center.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
