extends Node
## Procedurally synthesized sound effects (no external audio files).

const RATE := 22050

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _ambient: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_streams["pulse"] = _make(1.3, _pulse_sample)
	_streams["reveal"] = _make(0.7, _reveal_sample)
	_streams["relay"] = _make(1.4, _relay_sample)
	_streams["gate"] = _make(1.8, _gate_sample)
	_streams["win"] = _make(3.5, _win_sample)
	_streams["tick"] = _make(0.09, _tick_sample)
	_streams["ui"] = _make(0.07, _ui_sample)
	_streams["checkpoint"] = _make(0.8, _checkpoint_sample)
	_streams["respawn"] = _make(0.6, _respawn_sample)
	_streams["bolt"] = _make(0.25, _bolt_sample)
	_streams["hit"] = _make(0.18, _hit_sample)
	_streams["drone_charge"] = _make(0.6, _drone_charge_sample)
	_streams["drone_shot"] = _make(0.35, _drone_shot_sample)
	_streams["drone_down"] = _make(0.9, _drone_down_sample)
	_streams["hurt"] = _make(0.3, _hurt_sample)
	_streams["surf_start"] = _make(1.2, _surf_sample)
	_streams["ring"] = _make(0.35, _ring_sample)
	_streams["clone_rec"] = _make(0.4, _clone_rec_sample)
	_streams["clone_play"] = _make(0.6, _clone_play_sample)
	_streams["switch_on"] = _make(0.25, _switch_sample)
	_streams["bridge"] = _make(2.5, _bridge_sample)
	_streams["shatter"] = _make(0.8, _shatter_sample)
	_streams["restore"] = _make(4.0, _restore_sample)
	_streams["dash"] = _make(0.25, _dash_sample)
	var wind := _make(6.0, _wind_sample)
	wind.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wind.loop_end = int(6.0 * RATE)
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = wind
	_ambient.volume_db = -16.0
	add_child(_ambient)
	_ambient.play()
	# Soft ambient pad. All partials are multiples of 1/8 Hz so the 8 s loop is seamless.
	var pad := _make(8.0, _pad_sample)
	pad.loop_mode = AudioStreamWAV.LOOP_FORWARD
	pad.loop_end = int(8.0 * RATE)
	var music := AudioStreamPlayer.new()
	music.stream = pad
	music.volume_db = -13.0
	add_child(music)
	music.play()
	# Second layer: brighter arpeggio shimmer, faded in when the world is restored.
	var shimmer := _make(8.0, _shimmer_sample)
	shimmer.loop_mode = AudioStreamWAV.LOOP_FORWARD
	shimmer.loop_end = int(8.0 * RATE)
	_layer2 = AudioStreamPlayer.new()
	_layer2.stream = shimmer
	_layer2.volume_db = -60.0
	add_child(_layer2)
	_layer2.play()


var _layer2: AudioStreamPlayer


func set_restored_music(on: bool) -> void:
	var tw := create_tween()
	tw.tween_property(_layer2, "volume_db", -12.0 if on else -60.0, 3.0)


func _shimmer_sample(t: float, _d: float) -> float:
	# 8 notes per loop (1 s each), pentatonic, bell-like; integer Hz*8 keeps it seamless.
	var notes := [440.0, 554.375, 659.25, 880.0, 739.875, 659.25, 554.375, 493.875]
	var i := int(t) % 8
	var lt := t - floorf(t)
	return sin(TAU * notes[i] * t) * _env(lt, 0.01, 0.35) * 0.09 + sin(TAU * notes[i] * 2.0 * t) * _env(lt, 0.01, 0.15) * 0.03


func _bolt_sample(t: float, _d: float) -> float:
	var f := lerpf(1400.0, 500.0, t / 0.25)
	return (sin(TAU * f * t) * 0.4 + sin(TAU * f * 1.5 * t) * 0.15) * _env(t, 0.003, 0.06)


func _hit_sample(t: float, _d: float) -> float:
	_lp = lerpf(_lp, randf_range(-1.0, 1.0), 0.4)
	return (_lp * 0.6 + sin(TAU * 320.0 * t) * 0.4) * _env(t, 0.002, 0.05)


func _drone_charge_sample(t: float, _d: float) -> float:
	var f := lerpf(300.0, 1200.0, t / 0.6)
	return sin(TAU * f * t + sin(TAU * 30.0 * t) * 2.0) * minf(t / 0.5, 1.0) * 0.18


func _drone_shot_sample(t: float, _d: float) -> float:
	var f := lerpf(700.0, 200.0, t / 0.35)
	return (sin(TAU * f * t) * 0.35 + sin(TAU * f * 1.01 * t) * 0.2) * _env(t, 0.005, 0.12)


func _drone_down_sample(t: float, _d: float) -> float:
	var f := lerpf(600.0, 60.0, t / 0.9)
	_lp = lerpf(_lp, randf_range(-1.0, 1.0), 0.1)
	return (sin(TAU * f * t) * 0.35 + _lp * 0.4) * _env(t, 0.005, 0.35)


func _hurt_sample(t: float, _d: float) -> float:
	_lp = lerpf(_lp, randf_range(-1.0, 1.0), 0.15)
	return (sin(TAU * 110.0 * t) * 0.5 + _lp * 0.5) * _env(t, 0.003, 0.09)


func _surf_sample(t: float, _d: float) -> float:
	var f := lerpf(200.0, 800.0, minf(t / 1.0, 1.0))
	_lp = lerpf(_lp, randf_range(-1.0, 1.0), 0.05)
	return (sin(TAU * f * t) * 0.25 + _lp * 0.5) * _env(t, 0.2, 0.5)


func _ring_sample(t: float, _d: float) -> float:
	var f := 1046.5 if t < 0.08 else 1568.0
	return sin(TAU * f * t) * _env(fmod(t, 0.08) if t < 0.08 else t - 0.08, 0.003, 0.12) * 0.3


func _clone_rec_sample(t: float, _d: float) -> float:
	return (sin(TAU * 660.0 * t) * 0.2 + sin(TAU * 990.0 * t) * 0.1) * _env(t, 0.01, 0.12)


func _clone_play_sample(t: float, _d: float) -> float:
	var f := lerpf(400.0, 900.0, t / 0.6)
	return (sin(TAU * f * t) * 0.2 + sin(TAU * f * 0.5 * t) * 0.15) * _env(t, 0.05, 0.25)


func _switch_sample(t: float, _d: float) -> float:
	return (sin(TAU * 880.0 * t) * 0.25 + sin(TAU * 1320.0 * t) * 0.12) * _env(t, 0.003, 0.08)


func _bridge_sample(t: float, _d: float) -> float:
	_lp = lerpf(_lp, randf_range(-1.0, 1.0), 0.02)
	var tone := sin(TAU * lerpf(80.0, 160.0, t / 2.5) * t) * 0.3
	return (_lp * 1.8 + tone) * _env(t, 0.3, 1.2)


func _shatter_sample(t: float, _d: float) -> float:
	_lp = lerpf(_lp, randf_range(-1.0, 1.0), 0.6)
	return (_lp * 0.5 + sin(TAU * 2400.0 * t) * 0.1 + sin(TAU * 3100.0 * t) * 0.08) * _env(t, 0.002, 0.25)


func _restore_sample(t: float, _d: float) -> float:
	var chord := [261.63, 329.63, 392.0, 523.25, 659.25, 783.99]
	var v := 0.0
	for i in chord.size():
		var st := i * 0.12
		if t >= st:
			v += sin(TAU * chord[i] * (t - st)) * _env(t - st, 0.4, 1.8) * 0.09
	return v


func _dash_sample(t: float, _d: float) -> float:
	_lp = lerpf(_lp, randf_range(-1.0, 1.0), 0.25)
	return _lp * _env(t, 0.01, 0.08) * 0.7


func _pad_sample(t: float, d: float) -> float:
	# A2, E3, B3, C#4, F#4 (rounded to 1/8 Hz) with slow swells.
	var freqs := [110.0, 164.875, 247.0, 277.125, 370.0]
	var v := 0.0
	for i in freqs.size():
		var swell := 0.55 + 0.45 * sin(TAU * t / d * (1.0 + (i % 2)) + i * 1.3)
		v += sin(TAU * freqs[i] * t) * swell * (0.12 if i == 0 else 0.07)
		v += sin(TAU * freqs[i] * 2.0 * t) * swell * 0.015
	return v


func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(sound):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[sound]
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


# ---------------------------------------------------------------- synthesis

var _noise_state: float = 0.0
var _lp: float = 0.0


func _make(seconds: float, gen: Callable) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	_lp = 0.0
	for i in n:
		var t := float(i) / RATE
		var v: float = clampf(gen.call(t, seconds), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func _env(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / attack
	return exp(-(t - attack) / decay)


func _pulse_sample(t: float, _d: float) -> float:
	var f := lerpf(180.0, 55.0, minf(t / 0.9, 1.0))
	var boom := sin(TAU * f * t) * _env(t, 0.01, 0.35) * 0.8
	var bell := (sin(TAU * 880.0 * t) * 0.25 + sin(TAU * 1320.0 * t + sin(TAU * 6.0 * t)) * 0.15) * _env(t, 0.005, 0.45)
	var shimmer := sin(TAU * (1760.0 + 60.0 * sin(TAU * 5.0 * t)) * t) * _env(t, 0.15, 0.4) * 0.08
	return boom + bell + shimmer


func _reveal_sample(t: float, _d: float) -> float:
	var e := _env(t, 0.02, 0.25)
	return (sin(TAU * 1318.5 * t) * 0.3 + sin(TAU * 1975.5 * t) * 0.18 + sin(TAU * 2637.0 * t) * 0.08) * e


func _relay_sample(t: float, _d: float) -> float:
	var f := lerpf(260.0, 980.0, minf(t / 0.8, 1.0))
	var e := _env(t, 0.3, 0.45)
	return (sin(TAU * f * t) * 0.35 + sin(TAU * f * 1.5 * t) * 0.15) * e


func _gate_sample(t: float, _d: float) -> float:
	_lp = lerpf(_lp, randf_range(-1.0, 1.0), 0.03)
	var e := _env(t, 0.1, 0.7)
	return (_lp * 1.6 + sin(TAU * 55.0 * t) * 0.4 + sin(TAU * 82.5 * t) * 0.2) * e


func _win_sample(t: float, _d: float) -> float:
	var notes := [523.25, 659.25, 783.99, 1046.5, 1318.5]
	var v := 0.0
	for i in notes.size():
		var start := i * 0.18
		if t >= start:
			var lt := t - start
			v += sin(TAU * notes[i] * lt) * _env(lt, 0.02, 1.2) * 0.16
			v += sin(TAU * notes[i] * 2.0 * lt) * _env(lt, 0.02, 0.5) * 0.05
	return v


func _tick_sample(t: float, _d: float) -> float:
	return sin(TAU * 1600.0 * t) * _env(t, 0.002, 0.03) * 0.3


func _ui_sample(t: float, _d: float) -> float:
	return sin(TAU * 1100.0 * t) * _env(t, 0.002, 0.025) * 0.25


func _checkpoint_sample(t: float, _d: float) -> float:
	var f := 659.25 if t < 0.12 else 987.77
	var lt := t if t < 0.12 else t - 0.12
	return sin(TAU * f * lt) * _env(lt, 0.01, 0.25) * 0.3


func _respawn_sample(t: float, _d: float) -> float:
	var f := lerpf(900.0, 300.0, t / 0.6)
	return sin(TAU * f * t) * _env(t, 0.02, 0.2) * 0.25


func _wind_sample(t: float, d: float) -> float:
	_lp = lerpf(_lp, randf_range(-1.0, 1.0), 0.02)
	# Fade edges so the loop seam is inaudible.
	var edge := minf(minf(t, d - t) / 0.5, 1.0)
	var swell := 0.6 + 0.4 * sin(TAU * t / d * 2.0)
	return _lp * 2.2 * swell * edge
