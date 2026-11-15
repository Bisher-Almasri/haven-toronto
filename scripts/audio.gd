class_name GameAudio
extends Node

const SFX_RATE := 22050
const MUSIC_RATE := 11025
const POOL := 10

var _sfx := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.volume_db = -3.0
		add_child(p)
		_pool.append(p)
	_build_sfx()
	_music = AudioStreamPlayer.new()
	_music.volume_db = -15.0
	add_child(_music)
	_music.stream = _build_music()
	_music.play()


func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _sfx.has(name):
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL
	p.stream = _sfx[name]
	p.pitch_scale = pitch * randf_range(0.97, 1.03)
	p.volume_db = -3.0 + volume_db
	p.play()


func set_music_ducked(ducked: bool) -> void:
	create_tween().tween_property(_music, "volume_db", -24.0 if ducked else -15.0, 0.4)


func _build_sfx() -> void:
	_sfx["jump"] = _render([_n(0.0, 0.16, 300.0, 620.0, 0, 0.5, 0.0, 2.5)], 0.16)
	_sfx["land"] = _render([_n(0.0, 0.1, 130.0, 60.0, 0, 0.7, 0.15, 3.0)], 0.1)
	_sfx["bounce"] = _render([
		_n(0.0, 0.32, 200.0, 760.0, 0, 0.5, 0.0, 2.0),
		_n(0.0, 0.32, 400.0, 1520.0, 2, 0.2, 0.0, 2.5),
	], 0.32)
	_sfx["rebound"] = _render([
		_n(0.0, 0.4, 520.0, 180.0, 1, 0.35, 0.0, 2.0),
		_n(0.0, 0.4, 530.0, 190.0, 0, 0.35, 0.0, 2.0),
		_n(0.0, 0.08, 900.0, 300.0, 0, 0.3, 0.6, 4.0),
	], 0.4)
	_sfx["hurt"] = _render([
		_n(0.0, 0.35, 420.0, 90.0, 1, 0.5, 0.25, 1.8),
		_n(0.0, 0.1, 200.0, 100.0, 0, 0.35, 1.0, 3.0),
	], 0.35)
	_sfx["die"] = _render([
		_n(0.0, 0.2, 520.0, 380.0, 2, 0.45, 0.0, 1.5),
		_n(0.18, 0.2, 400.0, 290.0, 2, 0.45, 0.0, 1.5),
		_n(0.36, 0.5, 300.0, 70.0, 2, 0.5, 0.0, 1.5),
	], 0.9)
	_sfx["squish"] = _render([
		_n(0.0, 0.18, 360.0, 90.0, 0, 0.6, 0.0, 2.0),
		_n(0.0, 0.1, 0.0, 0.0, 0, 0.35, 1.0, 5.0),
	], 0.18)
	_sfx["curl"] = _render([_n(0.0, 0.09, 500.0, 900.0, 2, 0.3, 0.1, 3.0)], 0.09)
	_sfx["uncurl"] = _render([_n(0.0, 0.09, 800.0, 450.0, 2, 0.25, 0.1, 3.0)], 0.09)
	_sfx["checkpoint"] = _render([
		_n(0.0, 0.3, 659.25, 659.25, 2, 0.4, 0.0, 2.0),
		_n(0.09, 0.3, 880.0, 880.0, 2, 0.4, 0.0, 2.0),
		_n(0.18, 0.5, 1318.5, 1318.5, 2, 0.4, 0.0, 2.0),
	], 0.7)
	_sfx["launch"] = _render([
		_n(0.0, 1.2, 150.0, 1400.0, 0, 0.5, 0.0, 1.2),
		_n(0.0, 1.2, 160.0, 1500.0, 2, 0.3, 0.0, 1.4),
		_n(0.0, 0.5, 0.0, 0.0, 0, 0.18, 1.0, 2.5),
	], 1.2)
	var jingle := []
	var notes := [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5, 1318.5]
	for i in notes.size():
		jingle.append(_n(i * 0.13, 0.55, notes[i], notes[i], 2, 0.4, 0.0, 2.0))
		jingle.append(_n(i * 0.13, 0.55, notes[i] * 0.5, notes[i] * 0.5, 0, 0.2, 0.0, 2.0))
	_sfx["win"] = _render(jingle, 1.6)
	_sfx["pause"] = _render([_n(0.0, 0.1, 440.0, 330.0, 2, 0.3, 0.0, 3.0)], 0.1)
	_sfx["start"] = _render([
		_n(0.0, 0.25, 392.0, 392.0, 2, 0.4, 0.0, 2.0),
		_n(0.1, 0.4, 587.33, 587.33, 2, 0.4, 0.0, 2.0),
	], 0.5)


func _build_music() -> AudioStreamWAV:
	var beat := 60.0 / 92.0
	var bars := 8
	var length := beat * 4.0 * bars
	var events := []
	var chords := [
		[130.81, 196.0, 261.63, 329.63],
		[110.0, 164.81, 220.0, 261.63],
		[87.31, 130.81, 174.61, 220.0],
		[98.0, 146.83, 196.0, 246.94],
	]
	var melody := [
		[0, 4, 7, 9, 7, 4, 2, 4],
		[4, 7, 9, 12, 9, 7, 4, 2],
		[2, 4, 7, 9, 7, 4, 0, 2],
		[4, 2, 0, 2, 4, 7, 4, 2],
	]
	for bar in bars:
		var chord: Array = chords[bar % 4]
		var t0 := bar * beat * 4.0
		events.append(_n(t0, beat * 1.9, chord[0], chord[0], 0, 0.35, 0.0, 1.5))
		events.append(_n(t0 + beat * 2.0, beat * 1.9, chord[1] * 0.5, chord[1] * 0.5, 0, 0.3, 0.0, 1.5))
		for i in 4:
			events.append(_n(t0 + i * beat, beat * 1.5, chord[i], chord[i], 2, 0.1, 0.0, 1.8))
		var line: Array = melody[(bar / 2) % 4] if bar % 2 == 0 else melody[(bar / 2 + 1) % 4]
		for i in 8:
			if (bar + i) % 5 == 4:
				continue
			var note: int = line[i]
			var f := 261.63 * pow(2.0, (note + 12) / 12.0)
			events.append(_n(t0 + i * beat * 0.5, beat * 0.9, f, f, 2, 0.15, 0.0, 2.6))
	var wav := _render(events, length, MUSIC_RATE)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(length * MUSIC_RATE)
	return wav


# Note event: [start, duration, freq_start, freq_end, shape (0 sine, 1 square, 2 triangle), volume, noise mix, decay curve]
func _n(start: float, dur: float, f0: float, f1: float, shape: int, vol: float, noise: float, curve: float) -> Array:
	return [start, dur, f0, f1, shape, vol, noise, curve]


func _render(events: Array, length: float, rate := SFX_RATE) -> AudioStreamWAV:
	var total := int(length * rate)
	var buf := PackedFloat32Array()
	buf.resize(total)
	for e: Array in events:
		var first := int(e[0] * rate)
		var count := mini(int(e[1] * rate), total - first)
		var phase := 0.0
		var attack := maxf(0.004 * rate, 1.0)
		for i in count:
			var t := float(i) / float(maxi(count, 1))
			phase += lerpf(e[2], e[3], t) / rate
			var wave: float
			match int(e[4]):
				1:
					wave = 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0
				2:
					wave = absf(fposmod(phase, 1.0) * 4.0 - 2.0) - 1.0
				_:
					wave = sin(TAU * phase)
			var mix: float = e[6]
			var vol: float = e[5]
			var curve: float = e[7]
			var s: float = (wave * (1.0 - mix) + randf_range(-1.0, 1.0) * mix) * vol
			s *= pow(1.0 - t, curve) * minf(float(i) / attack, 1.0)
			buf[first + i] += s
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
