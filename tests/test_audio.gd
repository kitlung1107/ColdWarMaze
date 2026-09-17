extends SceneTree

const GameAudio = preload("res://scripts/game_audio.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var sound = GameAudio.new()
	root.add_child(sound)
	sound.set_process(false)
	assert(sound.effects.size() == 11)
	assert(is_equal_approx(sound.music.stream.get_length(), 10.0))
	assert(sound.music.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(sound.music.stream.loop_end == 441000)
	sound.exploring = true
	sound._process(1.0)
	assert(sound.music.playing and is_equal_approx(sound.gain, 0.28))
	var original_playback = sound.music.get_stream_playback()
	for frame in range(120):
		sound._process(1.0 / 60.0)
	assert(sound.music.get_stream_playback() == original_playback)
	sound.exploring = false
	sound.reading = true
	sound._process(1.0)
	assert(sound.music.playing and not sound.music.stream_paused)
	assert(is_equal_approx(sound.gain, 0.09))
	sound.play_effect("chest")
	assert(sound.voices[0].playing)
	sound.toggle_effects()
	assert(not sound.voices[0].playing)
	sound.play_effect("door")
	assert(not sound.voices[1].playing)
	sound.toggle_music()
	sound._process(1.0)
	assert(sound.music.stream_paused)
	sound.toggle_music()
	sound._process(1.0)
	assert(not sound.music.stream_paused)
	assert(sound.music.get_stream_playback() == original_playback)
	sound._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(sound.music.stream_paused and sound.gain == 0.0)
	sound._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	sound._process(1.0)
	assert(not sound.music.stream_paused)
	assert(sound.music.get_stream_playback() == original_playback)
	print("PASS: music loops, reading ducks without stopping, independent toggles, focus mute/resume; eleven effects loaded.")
	sound.music.stop()
	for voice in sound.voices:
		voice.stop()
	sound.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit()
