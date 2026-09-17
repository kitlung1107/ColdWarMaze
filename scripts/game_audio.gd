extends Node

const EFFECT_NAMES = ["chest", "door", "tower", "shortcut", "file", "complete", "wrong", "purchase", "switch", "click", "exit_hint"]
var music_enabled = true
var effects_enabled = true
var exploring = false
var reading = false
var app_focused = true
var gain = 0.0
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var effects = {}
var next_voice = 0
var last_exit_hint_ms = -1000

func _ready() -> void:
	music = AudioStreamPlayer.new()
	var track = load("res://assets/audio/exploration.wav").duplicate() as AudioStreamWAV
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_begin = 0
	track.loop_end = int(round(track.get_length() * track.mix_rate))
	music.stream = track
	music.volume_db = -80.0
	add_child(music)
	for effect_name in EFFECT_NAMES:
		effects[effect_name] = load("res://assets/audio/%s.wav" % effect_name)
	for i in range(4):
		var voice = AudioStreamPlayer.new()
		voice.volume_db = -9.0
		add_child(voice)
		voices.append(voice)

func _process(delta: float) -> void:
	var active = (exploring or reading) and music_enabled and app_focused
	var target = (0.09 if reading else 0.28) if active else 0.0
	gain = move_toward(gain, target, delta * 0.65)
	# A paused player still owns its playback. Do not restart it on resume.
	if active and not music.has_stream_playback():
		music.play()
	# Web Sample playback restarts its source on every unpause call, even
	# when already playing. Only send actual pause-state transitions.
	set_music_paused(not active and gain <= 0.0)
	music.volume_db = linear_to_db(maxf(gain, 0.0001))

func set_music_paused(paused: bool) -> void:
	if music.stream_paused != paused:
		music.stream_paused = paused

func play_effect(effect_name: String) -> void:
	if not effects_enabled or not app_focused or not effects.has(effect_name):
		return
	if effect_name == "exit_hint":
		var now = Time.get_ticks_msec()
		if now - last_exit_hint_ms < 1000:
			return
		last_exit_hint_ms = now
	var voice = voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = effects[effect_name]
	voice.volume_db = -17.0 if effect_name == "click" else -13.0 if effect_name in ["switch", "exit_hint"] else -9.0
	voice.play()

func toggle_music() -> void:
	music_enabled = not music_enabled

func toggle_effects() -> void:
	effects_enabled = not effects_enabled
	if not effects_enabled:
		for voice in voices:
			voice.stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		app_focused = false
		gain = 0.0
		if is_instance_valid(music):
			music.volume_db = -80.0
			set_music_paused(true)
		for voice in voices:
			voice.stop()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		app_focused = true
