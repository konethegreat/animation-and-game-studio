extends Node

# Every sound in BIN CITY is synthesised from oscillators and noise at load
# time. No samples, no library music, no network requests.

const RATE := 22050
const TAU := 6.283185307179586

var muted := false
var library: Dictionary = {}
var music: AudioStreamPlayer
var vacuum: AudioStreamPlayer
var pool: Array[AudioStreamPlayer] = []
var pool_index := 0
var vacuum_level := 0.0
var vacuum_on := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.name = "Music"
	music.volume_db = -8.0
	add_child(music)

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
	music.stream = library["music"]
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
	if vacuum == null:
		return
	var target := 0.0
	if vacuum_on and not muted:
		target = 0.16 + vacuum_level * 0.24
		if not vacuum.playing:
			vacuum.play()
	vacuum.volume_db = lerpf(vacuum.volume_db, linear_to_db(maxf(target, 0.001)), minf(1.0, delta * 12.0))


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
	library["vacuum"] = _wav(_vacuum_loop(), true)
	library["music"] = _wav(_music(), true)


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


func _music() -> PackedFloat32Array:
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

	# Normalise to a comfortable peak.
	var peak := 0.01
	for sample in out:
		peak = maxf(peak, absf(sample))
	var gain := 0.82 / peak
	for i in out.size():
		out[i] = out[i] * gain
	return out
