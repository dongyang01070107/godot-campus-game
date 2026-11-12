extends Node

const SAMPLE_RATE := 16000

func play_sfx(kind: String) -> void:
	var stream: AudioStreamWAV
	match kind:
		"click":
			stream = _make_tone(660.0, 0.075, 0)
		"pickup":
			stream = _make_melody([740.0, 988.0], 0.12)
		"hit":
			stream = _make_tone(150.0, 0.28, 1)
		"alert":
			stream = _make_melody([330.0, 220.0], 0.16)
		"bump":
			stream = _make_tone(260.0, 0.1, 1)
		"win":
			stream = _make_melody([523.0, 659.0, 784.0, 1047.0], 0.18)
		_:
			return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -8.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _make_tone(frequency: float, duration: float, waveform: int) -> AudioStreamWAV:
	var sample_count := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in sample_count:
		var time := float(i) / SAMPLE_RATE
		var phase := fposmod(frequency * time, 1.0)
		var wave := sin(TAU * phase)
		if waveform == 1:
			wave = 1.0 if phase < 0.5 else -1.0
		var envelope := minf(1.0, minf(float(i) / (SAMPLE_RATE * 0.012), float(sample_count - i) / (SAMPLE_RATE * 0.035)))
		_write_sample(bytes, i, wave * envelope * 0.22)
	return _make_stream(bytes, sample_count)


func _make_melody(frequencies: Array[float], note_duration: float) -> AudioStreamWAV:
	var sample_count := int(SAMPLE_RATE * note_duration * frequencies.size())
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for i in sample_count:
		var time := float(i) / SAMPLE_RATE
		var note_index := mini(int(time / note_duration), frequencies.size() - 1)
		var local_time := fposmod(time, note_duration)
		var frequency := frequencies[note_index]
		var envelope := minf(1.0, minf(local_time / 0.012, (note_duration - local_time) / 0.025))
		var sample := sin(TAU * frequency * time) * envelope * 0.23
		_write_sample(bytes, i, sample)
	return _make_stream(bytes, sample_count)


func _make_stream(bytes: PackedByteArray, sample_count: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream


func _write_sample(bytes: PackedByteArray, index: int, value: float) -> void:
	var sample := int(clampf(value, -1.0, 1.0) * 32767.0)
	bytes[index * 2] = sample & 0xff
	bytes[index * 2 + 1] = (sample >> 8) & 0xff
