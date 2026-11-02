extends Node

# Every sound in BIN CITY is synthesised from oscillators and noise at load
# time. No samples, no library music, no network requests.

const RATE := 22050
const TAU := 6.283185307179586

var muted := false
var library: Dictionary = {}
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var vacuum: AudioStreamPlayer
var pool: Array[AudioStreamPlayer] = []
var pool_index := 0
var vacuum_level := 0.0
var vacuum_on := false
var current_music := "music_market"
var current_ambience := ""
var boss_layer := 1
var _blip_at := 0
var _music_fade_rate := 14.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.name = "Music"
	music.volume_db = -8.0
	add_child(music)

	ambience = AudioStreamPlayer.new()
	ambience.name = "Ambience"
	ambience.volume_db = -14.0
	add_child(ambience)

	vacuum = AudioStreamPlayer.new()
	vacuum.name = "Vacuum"
	vacuum.volume_db = -40.0
	add_child(vacuum)

	for i in 10:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		player.volume_db = -4.0
		add_child(player)
		pool.append(player)

	_load_settings()
	_build_library()
	music.stream = library["music_market"]
	vacuum.stream = library["vacuum"]
	if not muted:
		music.play()


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://bincity.cfg") == OK:
		muted = bool(config.get_value("audio", "muted", false))
	AudioServer.set_bus_mute(0, muted)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load("user://bincity.cfg")
	config.set_value("audio", "muted", muted)
	config.save("user://bincity.cfg")


func toggle_mute() -> bool:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	_save_settings()
	return muted


func _process(delta: float) -> void:
	if vacuum != null:
		var target := 0.0
		if vacuum_on and not muted:
			target = 0.16 + vacuum_level * 0.24
			if not vacuum.playing:
				vacuum.play()
		vacuum.volume_db = lerpf(vacuum.volume_db, linear_to_db(maxf(target, 0.001)), minf(1.0, delta * 12.0))
	if music != null and music.playing:
		music.volume_db = move_toward(music.volume_db, _music_target_db(), delta * _music_fade_rate)
	if ambience != null and ambience.playing:
		ambience.volume_db = move_toward(ambience.volume_db, _ambience_target_db(), delta * 10.0)


func _music_target_db() -> float:
	return -8.0


func _ambience_target_db() -> float:
	return -22.0 if current_music == "music_boss" else -14.0


func play_music(track: String, fade := 1.0) -> void:
	var key := "music_" + track
	_ensure(key)
	if not library.has(key):
		return
	if current_music == key and music.playing:
		return
	current_music = key
	music.stream = library[key]
	if not muted:
		music.volume_db = _music_target_db() - 22.0
		music.play()
	_music_fade_rate = 24.0 / maxf(fade, 0.1)


func play_ambience(bed: String) -> void:
	var key := "amb_" + bed
	if current_ambience == key:
		return
	current_ambience = key
	_ensure(key)
	if not library.has(key):
		ambience.stop()
		return
	ambience.stream = library[key]
	ambience.volume_db = _ambience_target_db() - 16.0
	if not muted:
		ambience.play()


func set_boss_layer(layer: int) -> void:
	boss_layer = clampi(layer, 1, 3)
	var key := "music_boss_%d" % boss_layer
	_ensure(key)
	if not library.has(key):
		return
	current_music = "music_boss"
	if music.stream != library[key]:
		music.stream = library[key]
	if not muted and not music.playing:
		music.play()


func blip(speaker: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _blip_at < 50:
		return
	_blip_at = now
	var pitch := 0.86 + float(abs(speaker.hash()) % 60) / 100.0
	play("blip", pitch, -7.0)


func set_vacuum(on: bool, level := 1.0) -> void:
	vacuum_on = on
	vacuum_level = clampf(level, 0.0, 1.0)


func play(name: String, pitch := 1.0, db := 0.0) -> void:
	if muted or not library.has(name):
		return
	var player := pool[pool_index]
	pool_index = (pool_index + 1) % pool.size()
	player.stream = library[name]
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.volume_db = -4.0 + db
	player.play()


func _build_library() -> void:
	library["pickup"] = _wav(_pickup())
	library["correct"] = _wav(_correct())
	library["wrong"] = _wav(_wrong())
	library["rustle"] = _wav(_rustle())
	library["lift"] = _wav(_lift())
	library["throw"] = _wav(_throw())
	library["burst"] = _wav(_burst())
	library["rat"] = _wav(_squeak())
	library["rank"] = _wav(_rank())
	library["finish"] = _wav(_finish())
	library["click"] = _wav(_click())
	library["slip"] = _wav(_slip())
	library["pile"] = _wav(_pile())
	library["jump"] = _wav(_jump())
	library["land"] = _wav(_land())
	library["dash"] = _wav(_dash())
	library["pulse"] = _wav(_pulse())
	library["door"] = _wav(_door())
	library["zap"] = _wav(_zap())
	library["roar"] = _wav(_roar())
	library["stomp"] = _wav(_stomp())
	library["bell"] = _wav(_bell())
	library["token"] = _wav(_token())
	library["cat"] = _wav(_cat())
	library["pigeon"] = _wav(_pigeon())
	library["unlock"] = _wav(_unlock())
	library["reveal"] = _wav(_reveal())
	library["blip"] = _wav(_blip_tone())
	library["vacuum"] = _wav(_vacuum_loop(), true)
	var market := _wav(_market_music(), true)
	library["music_market"] = market
	library["music"] = market
	library["amb_market"] = _wav(_amb_market(), true)


const AREA_BEDS := {
	"dawn_market": "market",
	"canal_quarter": "canal",
	"neon_arcade": "neon",
}


func prepare_area(id: String) -> void:
	var bed := str(AREA_BEDS.get(id, "market"))
	_ensure("music_" + bed)
	_ensure("amb_" + bed)


func prepare_room(id: String) -> void:
	if id == "plant":
		_ensure("music_boss_1")
		_ensure("music_boss_2")
		_ensure("music_boss_3")
		_ensure("music_ending")
		_ensure("amb_plant")
	else:
		_ensure("amb_interior")


func _ensure(key: String) -> void:
	if library.has(key):
		return
	match key:
		"music_canal":
			library[key] = _wav(_canal_music(), true)
		"music_neon":
			library[key] = _wav(_neon_music(), true)
		"music_boss_1":
			library[key] = _wav(_boss_music(1), true)
		"music_boss_2":
			library[key] = _wav(_boss_music(2), true)
		"music_boss_3":
			library[key] = _wav(_boss_music(3), true)
		"music_ending":
			library[key] = _wav(_ending_music(), true)
		"amb_canal":
			library[key] = _wav(_amb_canal(), true)
		"amb_neon":
			library[key] = _wav(_amb_neon(), true)
		"amb_interior":
			library[key] = _wav(_amb_interior(), true)
		"amb_plant":
			library[key] = _wav(_amb_plant(), true)


func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


func _buffer(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * RATE))
	return samples


func _normalise(out: PackedFloat32Array, peak_target := 0.82) -> PackedFloat32Array:
	var peak := 0.01
	for sample in out:
		peak = maxf(peak, absf(sample))
	var gain := peak_target / peak
	for i in out.size():
		out[i] = out[i] * gain
	return out


func _loopify(out: PackedFloat32Array, fade := 0.04) -> PackedFloat32Array:
	var fade_n := int(fade * RATE)
	for i in mini(fade_n, out.size()):
		var mix := float(i) / float(maxi(fade_n, 1))
		out[i] = out[i] * mix + out[out.size() - fade_n + i] * (1.0 - mix)
	return out


func _pickup() -> PackedFloat32Array:
	var out := _buffer(0.16)
	for i in out.size():
		var t := float(i) / RATE
		var f := 640.0 + 900.0 * t
		var env := exp(-t * 26.0) * (1.0 - exp(-t * 900.0))
		out[i] = sin(TAU * f * t) * env * 0.5 + sin(TAU * f * 2.0 * t) * env * 0.12
	return out


func _correct() -> PackedFloat32Array:
	var out := _buffer(0.5)
	var notes := [523.25, 783.99, 1046.5]
	for i in out.size():
		var t := float(i) / RATE
		var value := 0.0
		for n in notes.size():
			var start := n * 0.075
			if t >= start:
				var local := t - start
				var env := exp(-local * 7.0) * (1.0 - exp(-local * 400.0))
				value += sin(TAU * notes[n] * local) * env * 0.26
		out[i] = value
	return out


func _wrong() -> PackedFloat32Array:
	var out := _buffer(0.34)
	for i in out.size():
		var t := float(i) / RATE
		var env := exp(-t * 11.0)
		var sq := signf(sin(TAU * 118.0 * t))
		var buzz := sin(TAU * 93.0 * t)
		out[i] = (sq * 0.18 + buzz * 0.3) * env
	return out


func _rustle() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var out := _buffer(0.28)
	var held := 0.0
	for i in out.size():
		var t := float(i) / RATE
		held = lerpf(held, rng.randf_range(-1.0, 1.0), 0.22)
		var env := sin(PI * minf(1.0, t / 0.28))
		out[i] = held * env * 0.22
	return out


func _lift() -> PackedFloat32Array:
	var out := _buffer(0.28)
	for i in out.size():
		var t := float(i) / RATE
		var env := exp(-t * 9.0) * (1.0 - exp(-t * 120.0))
		var saw := fmod(92.0 * t, 1.0) * 2.0 - 1.0
		out[i] = (saw * 0.16 + sin(TAU * 70.0 * t) * 0.24) * env
	return out


func _throw() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	var out := _buffer(0.42)
	var held := 0.0
	for i in out.size():
		var t := float(i) / RATE
		held = lerpf(held, rng.randf_range(-1.0, 1.0), 0.4)
		var env := sin(PI * minf(1.0, t / 0.42))
		out[i] = held * env * 0.3 * (1.0 - t * 1.6)
	return out


func _burst() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var out := _buffer(0.6)
	var held := 0.0
	for i in out.size():
		var t := float(i) / RATE
		held = lerpf(held, rng.randf_range(-1.0, 1.0), 0.65)
		var env := exp(-t * 5.0) * (1.0 - exp(-t * 90.0))
		var tone := sin(TAU * (200.0 - 120.0 * t) * t)
		out[i] = (held * 0.36 + tone * 0.2) * env
	return out


func _squeak() -> PackedFloat32Array:
	var out := _buffer(0.2)
	for i in out.size():
		var t := float(i) / RATE
		var f := 1350.0 + 700.0 * sin(PI * t / 0.2) + 120.0 * sin(TAU * 40.0 * t)
		var env := sin(PI * minf(1.0, t / 0.2))
		out[i] = sin(TAU * f * t) * env * 0.26
	return out


func _rank() -> PackedFloat32Array:
	var out := _buffer(1.6)
	var notes := [261.63, 329.63, 392.0, 523.25, 659.25]
	for i in out.size():
		var t := float(i) / RATE
		var value := 0.0
		for n in notes.size():
			var start := n * 0.11
			if t >= start:
				var local := t - start
				var env := exp(-local * 2.6) * (1.0 - exp(-local * 220.0))
				value += sin(TAU * notes[n] * local) * env * 0.22
		# warm bed under the fanfare
		value += (sin(TAU * 130.81 * t) + sin(TAU * 196.0 * t)) * 0.035 * minf(1.0, t / 0.5) * exp(-t * 1.2)
		out[i] = value
	return out


func _finish() -> PackedFloat32Array:
	var out := _buffer(2.4)
	var notes := [174.61, 220.0, 261.63, 349.23, 392.0]
	for i in out.size():
		var t := float(i) / RATE
		var value := 0.0
		for n in notes.size():
			var f: float = notes[n]
			var env := minf(1.0, t / 0.4) * exp(-t * 1.1)
			value += sin(TAU * f * t) * env * 0.12
			value += sin(TAU * f * 2.0 * t) * env * 0.03
		out[i] = value
	return out


func _click() -> PackedFloat32Array:
	var out := _buffer(0.06)
	for i in out.size():
		var t := float(i) / RATE
		out[i] = sin(TAU * 1200.0 * t) * exp(-t * 90.0) * 0.3
	return out


func _slip() -> PackedFloat32Array:
	var out := _buffer(0.55)
	for i in out.size():
		var t := float(i) / RATE
		var f := 900.0 - 620.0 * (t / 0.55)
		var env := sin(PI * minf(1.0, t / 0.55))
		out[i] = sin(TAU * f * t) * env * 0.22
	return out


func _pile() -> PackedFloat32Array:
	var out := _buffer(0.5)
	for i in out.size():
		var t := float(i) / RATE
		var env := exp(-t * 8.0)
		var thump := sin(TAU * 58.0 * t) * 0.4
		var rattle := sin(TAU * 320.0 * t) * 0.1 * sin(TAU * 17.0 * t)
		out[i] = (thump + rattle) * env
	return out


func _jump() -> PackedFloat32Array:
	var out := _buffer(0.22)
	for i in out.size():
		var t := float(i) / RATE
		var f := 300.0 + 640.0 * t / 0.22
		var env := sin(PI * minf(1.0, t / 0.22)) * (1.0 - exp(-t * 300.0))
		out[i] = (sin(TAU * f * t) * 0.26 + sin(TAU * f * 2.0 * t) * 0.06) * env
	return out


func _land() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 515
	var out := _buffer(0.18)
	var held := 0.0
	for i in out.size():
		var t := float(i) / RATE
		held = lerpf(held, rng.randf_range(-1.0, 1.0), 0.4)
		var f := 120.0 - 45.0 * t / 0.18
		var env := exp(-t * 22.0) * (1.0 - exp(-t * 600.0))
		out[i] = (sin(TAU * f * t) * 0.4 + held * 0.14) * env
	return out


func _dash() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 616
	var out := _buffer(0.3)
	var held := 0.0
	for i in out.size():
		var t := float(i) / RATE
		held = lerpf(held, rng.randf_range(-1.0, 1.0), 0.7)
		var env := sin(PI * minf(1.0, t / 0.3))
		var whistle := sin(TAU * (760.0 - 480.0 * t / 0.3) * t)
		out[i] = (held * 0.3 + whistle * 0.08) * env
	return out


func _door() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 707
	var out := _buffer(0.62)
	var held := 0.0
	for i in out.size():
		var t := float(i) / RATE
		held = lerpf(held, rng.randf_range(-1.0, 1.0), 0.25)
		var wood := sin(TAU * (96.0 - 18.0 * minf(1.0, t / 0.4)) * t) * exp(-t * 9.0)
		var frame := sin(TAU * 240.0 * t) * exp(-t * 30.0) * 0.18
		var latch_at := 0.3
		var latch := 0.0
		if t >= latch_at:
			var local := t - latch_at
			latch = sin(TAU * 1750.0 * local) * exp(-local * 55.0) * 0.22
		out[i] = (wood * 0.4 + held * 0.09 + frame + latch)
	return out


func _pulse() -> PackedFloat32Array:
	var out := _buffer(0.7)
	for i in out.size():
		var t := float(i) / RATE
		var env := exp(-t * 6.0) * (1.0 - exp(-t * 160.0))
		var low := sin(TAU * 110.0 * t) * 0.3
		var high := sin(TAU * 440.0 * t + sin(TAU * 3.0 * t)) * 0.12
		out[i] = (low + high) * env
	return out


func _zap() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 818
	var out := _buffer(0.42)
	var held := 0.0
	for i in out.size():
		var t := float(i) / RATE
		held = lerpf(held, rng.randf_range(-1.0, 1.0), 0.6)
		var gate := 1.0 if fmod(t, 0.06) < 0.032 else 0.0
		var env := exp(-t * 7.0)
		var blip := signf(sin(TAU * (1600.0 - 900.0 * t) * t)) * 0.12
		out[i] = (held * 0.3 * gate + blip * gate) * env
	return out


func _vacuum_loop() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var seconds := 1.2
	var fade := int(0.03 * RATE)
	var out := _buffer(seconds)
	var held := 0.0
	for i in out.size():
		var t := float(i) / RATE
		held = lerpf(held, rng.randf_range(-1.0, 1.0), 0.5)
		var hum := sin(TAU * 72.0 * t) * 0.1 + sin(TAU * 144.0 * t) * 0.04
		out[i] = held * 0.22 + hum
	for i in fade:
		var mix := float(i) / fade
		out[i] = out[i] * mix + out[out.size() - fade + i] * (1.0 - mix)
	return out


func _market_music() -> PackedFloat32Array:
	# 8 bars at 80 bpm, 3 seconds a bar. A warm dawn loop in F major with a
	# soft market shuffle. Generated deterministically, so it is the same cue
	# on every machine.
	var bpm := 80.0
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var bars := 8
	var seconds := bar * bars
	var out := _buffer(seconds)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261102

	var chords := [
		[174.61, 220.0, 261.63, 329.63],   # Fmaj7
		[146.83, 174.61, 220.0, 261.63],   # Dm7
		[116.54, 146.83, 174.61, 220.0],   # Bbmaj7
		[130.81, 164.81, 196.0, 246.94],   # C
		[174.61, 220.0, 261.63, 329.63],   # Fmaj7
		[110.0, 130.81, 164.81, 196.0],    # Am7
		[116.54, 146.83, 174.61, 220.0],   # Bbmaj7
		[130.81, 164.81, 196.0, 246.94],   # C
	]
	var melody_scale := [349.23, 392.0, 440.0, 523.25, 587.33, 698.46]
	var melody := [2, 4, 3, 5, 4, 2, 0, 3, 5, 4, 2, 1, 3, 0, 2, 4]

	var noise := PackedFloat32Array()
	noise.resize(RATE)
	for i in noise.size():
		noise[i] = rng.randf_range(-1.0, 1.0)
	var noise_held := 0.0

	for i in out.size():
		var t := float(i) / RATE
		var bar_index := int(t / bar) % bars
		var bar_t := fmod(t, bar)
		var chord: Array = chords[bar_index]
		var value := 0.0

		# Pad, with a slow bloom and a gentle fall at the end of the bar.
		var pad_env := minf(1.0, bar_t / 0.7) * minf(1.0, (bar - bar_t) / 0.5)
		for freq in chord:
			var f: float = freq
			value += sin(TAU * f * t) * 0.038 * pad_env
			value += sin(TAU * f * 1.003 * t + 0.7) * 0.02 * pad_env
		value += sin(TAU * (chord[0] / 2.0) * t) * 0.06 * pad_env

		# Bass on the first and third beat.
		for beat_index in [0, 2]:
			var local: float = bar_t - float(beat_index) * beat
			if local >= 0.0 and local < beat * 0.9:
				var env := exp(-local * 2.2) * (1.0 - exp(-local * 80.0))
				value += sin(TAU * (chord[0] / 2.0) * t) * env * 0.14

		# Plucked melody, one note per beat with rests on the off bars.
		var step := int(bar_t / beat)
		if step < 4:
			var local := bar_t - step * beat
			var note_index: int = melody[(bar_index * 4 + step) % melody.size()]
			if not (bar_index % 4 == 3 and step == 3):
				var freq: float = melody_scale[note_index]
				var env := exp(-local * 3.4) * (1.0 - exp(-local * 120.0))
				value += sin(TAU * freq * local) * env * 0.055
				value += sin(TAU * freq * 2.0 * local) * env * 0.018

		# Shaker on every eighth note, very soft.
		var eighth := beat / 2.0
		var shaker_t := fmod(bar_t, eighth)
		var noise_index := i % noise.size()
		noise_held = lerpf(noise_held, noise[noise_index], 0.6)
		var shaker_env := exp(-shaker_t * 38.0) * 0.05
		value += noise_held * shaker_env

		# A distant gull now and then.
		var gull_start := fmod(t, 6.0)
		if gull_start < 0.32 and bar_index % 2 == 1:
			var f := 1250.0 + 260.0 * sin(PI * gull_start / 0.32)
			value += sin(TAU * f * gull_start) * 0.018 * sin(PI * gull_start / 0.32)

		out[i] = value

	return _normalise(out, 0.82)


func _canal_music() -> PackedFloat32Array:
	# 8 bars of 3/4 at 84 bpm in D minor. A patient waltz with a water-like
	# broken chord and a lonely lead that drifts over the banks.
	var bpm := 84.0
	var beat := 60.0 / bpm
	var bar := beat * 3.0
	var bars := 8
	var seconds := bar * bars
	var out := _buffer(seconds)
	var chords := [
		[146.83, 174.61, 220.0],   # Dm
		[116.54, 146.83, 174.61],  # Bb
		[174.61, 220.0, 261.63],   # F
		[130.81, 164.81, 196.0],   # C
		[146.83, 174.61, 220.0],   # Dm
		[138.59, 174.61, 207.65],  # colour
		[116.54, 146.83, 174.61],  # Bb
		[164.81, 196.0, 246.94],   # A
	]
	var melody := [440.0, 523.25, 587.33, 523.25, 440.0, 392.0, 349.23, 440.0]
	for i in out.size():
		var t := float(i) / RATE
		var bar_index := int(t / bar) % bars
		var bar_t := fmod(t, bar)
		var chord: Array = chords[bar_index]
		var value := 0.0
		# Waltz bass on beat one.
		if bar_t < beat * 0.9:
			var bass_env := exp(-bar_t * 2.0) * (1.0 - exp(-bar_t * 90.0))
			value += sin(TAU * (chord[0] / 2.0) * t) * bass_env * 0.16
		# Water arpeggio in flowing eighths.
		var eighth := beat / 2.0
		var step := int(bar_t / eighth)
		var local := bar_t - step * eighth
		var note: float = chord[step % 3] * (2.0 if step >= 3 else 1.0)
		var arp_env := exp(-local * 4.5) * (1.0 - exp(-local * 150.0))
		value += sin(TAU * note * local) * arp_env * 0.05
		value += sin(TAU * note * 2.0 * local) * arp_env * 0.012
		# Melody, one long note per bar with a slow wander.
		var f: float = melody[bar_index]
		var mel_env := minf(1.0, bar_t / 0.3) * minf(1.0, (bar - bar_t) / 0.4)
		var slow_vib := 4.0 * sin(TAU * 5.0 * t)
		value += (sin(TAU * (f + slow_vib) * t) * 0.05 + sin(TAU * f * 2.0 * t) * 0.014) * mel_env
		# Soft pad swell.
		var pad_env := minf(1.0, bar_t / 0.8) * minf(1.0, (bar - bar_t) / 0.6)
		for freq in chord:
			var pf: float = freq
			value += sin(TAU * pf * t) * 0.022 * pad_env
		out[i] = value
	return _normalise(out, 0.8)


func _neon_music() -> PackedFloat32Array:
	# 8 bars of 4/4 at 100 bpm in A minor. A square lead, a soft
	# four-on-the-floor kick and a muted saw bass, heard like arcade music
	# through a door.
	var bpm := 100.0
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var bars := 8
	var seconds := bar * bars
	var out := _buffer(seconds)
	var chords := [
		[110.0, 130.81, 164.81],   # Am
		[87.31, 110.0, 130.81],    # F
		[130.81, 164.81, 196.0],   # C
		[98.0, 123.47, 146.83],    # G
		[110.0, 130.81, 164.81],   # Am
		[87.31, 110.0, 130.81],    # F
		[130.81, 164.81, 196.0],   # C
		[98.0, 123.47, 146.83],    # G
	]
	var lead := [440.0, 523.25, 659.25, 523.25, 440.0, 349.23, 392.0, 440.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	var noise := PackedFloat32Array()
	noise.resize(RATE)
	for i in noise.size():
		noise[i] = rng.randf_range(-1.0, 1.0)
	var held := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var bar_index := int(t / bar) % bars
		var bar_t := fmod(t, bar)
		var chord: Array = chords[bar_index]
		var value := 0.0
		# Four on the floor kick.
		var kick_t := fmod(bar_t, beat)
		value += sin(TAU * (120.0 - 70.0 * minf(1.0, kick_t / 0.12)) * kick_t) * exp(-kick_t * 16.0) * (1.0 - exp(-kick_t * 300.0)) * 0.3
		# Hats on the offbeats.
		var hat_t := fmod(bar_t - beat / 2.0, beat)
		if hat_t >= 0.0:
			held = lerpf(held, noise[i % noise.size()], 0.7)
			value += held * exp(-hat_t * 60.0) * 0.05
		# Muted saw bass in eighths.
		var eighth := beat / 2.0
		var step := int(bar_t / eighth)
		var local := bar_t - step * eighth
		var bf: float = chord[0]
		var bass_env := exp(-local * 8.0) * (1.0 - exp(-local * 200.0))
		var saw := fmod(bf * t, 1.0) * 2.0 - 1.0
		value += saw * bass_env * 0.1
		# Square lead, one note every two beats.
		var lead_step := int(bar_t / (beat * 2.0))
		var lead_local := bar_t - lead_step * beat * 2.0
		var lf: float = lead[(bar_index * 2 + lead_step) % lead.size()]
		var lead_env := exp(-lead_local * 2.6) * (1.0 - exp(-lead_local * 120.0))
		var sq := signf(sin(TAU * lf * lead_local))
		value += (sq * 0.05 + sin(TAU * lf * lead_local) * 0.02) * lead_env
		# Soft pad.
		var pad_env := minf(1.0, bar_t / 0.4) * minf(1.0, (bar - bar_t) / 0.4)
		for freq in chord:
			var pf: float = freq
			value += sin(TAU * pf * 2.0 * t) * 0.014 * pad_env
		out[i] = value
	return _normalise(out, 0.8)


func _boss_music(layer: int) -> PackedFloat32Array:
	# 8 bars of 4/4 at 108 bpm in E minor. Three mixes of one groove: the
	# low pulse, then drums, then a brassy saw on top. The fight swaps the
	# stream as phases advance.
	var bpm := 108.0
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var bars := 8
	var seconds := bar * bars
	var out := _buffer(seconds)
	var chords := [
		[82.41, 123.47, 164.81],   # Em
		[82.41, 123.47, 164.81],   # Em
		[65.41, 98.0, 130.81],     # C
		[73.42, 110.0, 146.83],    # D
		[82.41, 123.47, 164.81],   # Em
		[61.74, 92.5, 123.47],     # colour
		[65.41, 98.0, 130.81],     # C
		[73.42, 110.0, 146.83],    # D
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 505 + layer
	var noise := PackedFloat32Array()
	noise.resize(RATE)
	for i in noise.size():
		noise[i] = rng.randf_range(-1.0, 1.0)
	var held := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var bar_index := int(t / bar) % bars
		var bar_t := fmod(t, bar)
		var chord: Array = chords[bar_index]
		var value := 0.0
		# The pulse, always present: a low drone and a heartbeat fifth.
		var pulse := 0.5 + 0.5 * sin(TAU * (1.0 / beat) * bar_t)
		value += sin(TAU * (chord[0] / 2.0) * t) * 0.09
		value += sin(TAU * chord[0] * t) * (0.03 + 0.03 * pulse)
		value += sin(TAU * chord[2] * t) * 0.018 * pulse
		if layer >= 2:
			# Drums: kick on the downbeats, snare noise in the backbeat.
			var kick_t := fmod(bar_t, beat)
			if int(bar_t / beat) % 2 == 0:
				value += sin(TAU * (110.0 - 60.0 * minf(1.0, kick_t / 0.1)) * kick_t) * exp(-kick_t * 18.0) * (1.0 - exp(-kick_t * 350.0)) * 0.32
			var snare_t := fmod(bar_t - beat, beat * 2.0)
			if snare_t >= 0.0 and int(bar_t / beat) % 2 == 1:
				held = lerpf(held, noise[i % noise.size()], 0.65)
				value += held * exp(-snare_t * 26.0) * 0.16
			var hat_t := fmod(bar_t, beat / 2.0)
			held = lerpf(held, noise[i % noise.size()], 0.7)
			value += held * exp(-hat_t * 70.0) * 0.045
			# Bass eighth drive.
			var eighth := beat / 2.0
			var local := bar_t - int(bar_t / eighth) * eighth
			var bf: float = chord[0]
			var saw_bass := fmod(bf * t, 1.0) * 2.0 - 1.0
			value += saw_bass * exp(-local * 9.0) * (1.0 - exp(-local * 250.0)) * 0.1
		if layer >= 3:
			# Brassy saw stabs on the offbeats of the second half of the bar.
			var stab_step := int(bar_t / (beat / 2.0))
			var stab_local := bar_t - stab_step * (beat / 2.0)
			if stab_step >= 4:
				var env := exp(-stab_local * 7.0) * (1.0 - exp(-stab_local * 160.0))
				for freq in chord:
					var sf: float = freq
					var detuned := sin(TAU * sf * t) + sin(TAU * sf * 1.006 * t)
					value += signf(detuned) * env * 0.035
		out[i] = value
	return _normalise(out, 0.8)


func _ending_music() -> PackedFloat32Array:
	# A warm F major reprise of the market theme at 72 bpm. Slower and
	# fuller, with a bell-like doubling of the melody an octave up.
	var bpm := 72.0
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	var bars := 8
	var seconds := bar * bars
	var out := _buffer(seconds)
	var chords := [
		[174.61, 220.0, 261.63, 329.63],   # Fmaj7
		[146.83, 174.61, 220.0, 261.63],   # Dm7
		[116.54, 146.83, 174.61, 220.0],   # Bbmaj7
		[130.81, 164.81, 196.0, 246.94],   # C
		[174.61, 220.0, 261.63, 329.63],   # Fmaj7
		[110.0, 130.81, 164.81, 196.0],    # Am7
		[116.54, 146.83, 174.61, 220.0],   # Bbmaj7
		[130.81, 164.81, 196.0, 246.94],   # C
	]
	var melody_scale := [349.23, 392.0, 440.0, 523.25, 587.33, 698.46]
	var melody := [4, 5, 4, 3, 2, 3, 4, 2, 0, 2, 3, 4, 5, 4, 2, 1]
	for i in out.size():
		var t := float(i) / RATE
		var bar_index := int(t / bar) % bars
		var bar_t := fmod(t, bar)
		var chord: Array = chords[bar_index]
		var value := 0.0
		var pad_env := minf(1.0, bar_t / 0.9) * minf(1.0, (bar - bar_t) / 0.7)
		for freq in chord:
			var f: float = freq
			value += sin(TAU * f * t) * 0.045 * pad_env
			value += sin(TAU * f * 0.5 * t) * 0.03 * pad_env
		for beat_index in [0, 2]:
			var local: float = bar_t - float(beat_index) * beat
			if local >= 0.0 and local < beat:
				var env := exp(-local * 1.8) * (1.0 - exp(-local * 70.0))
				value += sin(TAU * (chord[0] / 2.0) * t) * env * 0.12
		var step := int(bar_t / beat)
		if step < 4:
			var local := bar_t - step * beat
			var note_index: int = melody[(bar_index * 4 + step) % melody.size()]
			var freq: float = melody_scale[note_index]
			var env := exp(-local * 2.6) * (1.0 - exp(-local * 100.0))
			value += sin(TAU * freq * local) * env * 0.06
			value += sin(TAU * freq * 2.0 * local) * env * 0.025
		out[i] = value
	return _normalise(out, 0.8)


func _amb_market() -> PackedFloat32Array:
	# Crowd murmur with a far-off gull. Loops every six seconds.
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var out := _buffer(6.0)
	var murmur := 0.0
	for i in out.size():
		var t := float(i) / RATE
		murmur = lerpf(murmur, rng.randf_range(-1.0, 1.0), 0.06)
		var value := murmur * 0.05
		value += sin(TAU * (220.0 + 30.0 * sin(TAU * 0.13 * t)) * t) * 0.006
		var local := t - 1.2
		if local >= 0.0 and local < 0.3:
			var f := 1200.0 + 300.0 * sin(PI * local / 0.3)
			value += sin(TAU * f * local) * 0.02 * sin(PI * local / 0.3)
		out[i] = value
	return _loopify(out)


func _amb_canal() -> PackedFloat32Array:
	# Water lapping against stone with a chain clink now and then.
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	var out := _buffer(6.0)
	var lap := 0.0
	var water := 0.0
	for i in out.size():
		var t := float(i) / RATE
		water = lerpf(water, rng.randf_range(-1.0, 1.0), 0.25)
		lap = lerpf(lap, water, 0.08)
		var swell := 0.5 + 0.5 * sin(TAU * 0.35 * t)
		var value := lap * 0.06 * (0.4 + 0.6 * swell) + water * 0.015
		for start: float in [1.6, 4.1]:
			var local := t - start
			if local >= 0.0 and local < 0.18:
				value += sin(TAU * 2400.0 * local) * exp(-local * 40.0) * 0.05
				value += sin(TAU * 3600.0 * local) * exp(-local * 60.0) * 0.02
		out[i] = value
	return _loopify(out)


func _amb_neon() -> PackedFloat32Array:
	# Night rain, mains hum from the signs, a ghost of arcade music.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3030
	var out := _buffer(6.0)
	var rain := 0.0
	for i in out.size():
		var t := float(i) / RATE
		rain = lerpf(rain, rng.randf_range(-1.0, 1.0), 0.5)
		var value := rain * 0.05
		value += sin(TAU * 50.0 * t) * 0.012 + sin(TAU * 100.0 * t) * 0.006
		value += sin(TAU * 220.0 * t) * (0.004 + 0.003 * sin(TAU * 0.5 * t))
		out[i] = value
	return _loopify(out)


func _amb_interior() -> PackedFloat32Array:
	# Quiet room tone with one settling creak in the middle of the loop.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040
	var out := _buffer(6.0)
	var tone := 0.0
	for i in out.size():
		var t := float(i) / RATE
		tone = lerpf(tone, rng.randf_range(-1.0, 1.0), 0.08)
		var value := tone * 0.018
		value += sin(TAU * 60.0 * t) * 0.004
		var local := t - 3.0
		if local >= 0.0 and local < 0.12:
			value += sin(TAU * 900.0 * local) * exp(-local * 50.0) * 0.015
		out[i] = value
	return _loopify(out)


func _amb_plant() -> PackedFloat32Array:
	# Machinery: a slow breath of steam hiss, low rumble, one distant clang.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5050
	var out := _buffer(6.0)
	var hiss := 0.0
	for i in out.size():
		var t := float(i) / RATE
		hiss = lerpf(hiss, rng.randf_range(-1.0, 1.0), 0.4)
		var breath := 0.5 + 0.5 * sin(TAU * 0.25 * t)
		var value := hiss * (0.02 + 0.03 * breath)
		value += sin(TAU * 55.0 * t) * 0.03 + sin(TAU * 110.0 * t) * 0.012
		var local := t - 2.4
		if local >= 0.0 and local < 0.4:
			value += (sin(TAU * 340.0 * local) * 0.06 + sin(TAU * 517.0 * local) * 0.03) * exp(-local * 12.0)
		out[i] = value
	return _loopify(out)


func _roar() -> PackedFloat32Array:
	var out := _buffer(1.4)
	for i in out.size():
		var t := float(i) / RATE
		var env := sin(PI * minf(1.0, t / 1.4)) * (1.0 - exp(-t * 60.0))
		var bend := 1.0 - 0.35 * (t / 1.4)
		var f := 82.0 * bend
		var saw := fmod(f * t, 1.0) * 2.0 - 1.0
		var grit := sin(TAU * (f * 1.5) * t)
		out[i] = (saw * 0.3 + grit * 0.18) * env
	return out


func _stomp() -> PackedFloat32Array:
	var out := _buffer(0.5)
	for i in out.size():
		var t := float(i) / RATE
		var env := exp(-t * 10.0) * (1.0 - exp(-t * 400.0))
		out[i] = (sin(TAU * (64.0 - 30.0 * minf(1.0, t / 0.4)) * t) * 0.5 + sin(TAU * 130.0 * t) * 0.12) * env
	return out


func _bell() -> PackedFloat32Array:
	var out := _buffer(2.2)
	var partials := [[660.0, 0.34, 2.2], [1320.0, 0.18, 3.2], [1980.0, 0.08, 4.5], [554.0, 0.12, 1.8]]
	for i in out.size():
		var t := float(i) / RATE
		var value := 0.0
		for p in partials:
			var f: float = p[0]
			value += sin(TAU * f * t) * exp(-t * float(p[2])) * float(p[1])
		out[i] = value * (1.0 - exp(-t * 200.0))
	return out


func _token() -> PackedFloat32Array:
	var out := _buffer(0.5)
	var notes := [1568.0, 2093.0]
	for i in out.size():
		var t := float(i) / RATE
		var value := 0.0
		for n in notes.size():
			var local := t - n * 0.07
			if local >= 0.0:
				value += sin(TAU * notes[n] * local) * exp(-local * 9.0) * (1.0 - exp(-local * 500.0)) * 0.2
		out[i] = value
	return out


func _cat() -> PackedFloat32Array:
	var out := _buffer(0.6)
	for i in out.size():
		var t := float(i) / RATE
		var shape := sin(PI * minf(1.0, t / 0.6))
		var f := 520.0 + 320.0 * sin(PI * t / 0.6) + 25.0 * sin(TAU * 7.0 * t)
		var vib := sin(TAU * f * t)
		out[i] = signf(vib) * pow(absf(vib), 0.6) * shape * 0.22
	return out


func _pigeon() -> PackedFloat32Array:
	var out := _buffer(0.8)
	for i in out.size():
		var t := float(i) / RATE
		var value := 0.0
		for start: float in [0.0, 0.32]:
			var local := t - start
			if local >= 0.0 and local < 0.26:
				var env := sin(PI * local / 0.26)
				var f := 310.0 - 60.0 * (local / 0.26)
				value += (sin(TAU * f * local) + sin(TAU * f * 2.0 * local) * 0.3) * env * 0.2
		out[i] = value
	return out


func _unlock() -> PackedFloat32Array:
	var out := _buffer(0.8)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in out.size():
		var t := float(i) / RATE
		var value := 0.0
		for n in notes.size():
			var local := t - n * 0.08
			if local >= 0.0:
				value += sin(TAU * notes[n] * local) * exp(-local * 6.0) * (1.0 - exp(-local * 300.0)) * 0.18
		out[i] = value
	return out


func _reveal() -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 242
	var out := _buffer(1.1)
	var held := 0.0
	for i in out.size():
		var t := float(i) / RATE
		held = lerpf(held, rng.randf_range(-1.0, 1.0), 0.35)
		var swell := minf(1.0, t / 0.4) * exp(-maxf(0.0, t - 0.5) * 3.0)
		var chime := sin(TAU * 1318.5 * t) * 0.06 + sin(TAU * 1975.5 * t) * 0.03
		out[i] = (held * 0.1 + chime) * swell
	return out


func _blip_tone() -> PackedFloat32Array:
	var out := _buffer(0.07)
	for i in out.size():
		var t := float(i) / RATE
		out[i] = sin(TAU * 880.0 * t) * exp(-t * 60.0) * 0.3
	return out
