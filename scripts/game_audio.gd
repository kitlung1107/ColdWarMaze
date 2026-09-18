extends Node

const EFFECT_NAMES = ["chest", "door", "tower", "shortcut", "file", "complete", "wrong", "purchase", "switch", "click", "exit_hint", "enter_maze", "help", "topic", "back", "reset_prompt", "footstep", "bump", "locked", "investigate", "select", "place", "files_ready", "insufficient", "incomplete", "shop_open"]
const EFFECT_COOLDOWNS = {"footstep": 120, "bump": 350, "locked": 350, "switch": 120, "incomplete": 650, "insufficient": 650, "exit_hint": 1000}
const EFFECT_DB = {"footstep": -26.0, "bump": -21.0, "locked": -18.0, "select": -21.0, "place": -19.0, "click": -17.0, "switch": -13.0, "exit_hint": -13.0, "incomplete": -15.0, "insufficient": -15.0}
var music_enabled = true
var effects_enabled = true
var exploring = false
var reading = false
var menu_active = false
var app_focused = true
var gain = 0.0
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var effects = {}
var next_voice = 0
var last_effect_ms = {}

func _ready() -> void:
	music = AudioStreamPlayer.new()
	# Keep the looping music on the engine mixer. Web Sample playback uses
	# separate browser sources and recreates them on loop/pause transitions.
	music.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
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
	var active = (menu_active or exploring or reading) and music_enabled and app_focused
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
	var now = Time.get_ticks_msec()
	if now - int(last_effect_ms.get(effect_name, -10000)) < int(EFFECT_COOLDOWNS.get(effect_name, 0)):
		return
	last_effect_ms[effect_name] = now
	var voice = voices[next_voice]
	next_voice = (next_voice + 1) % voices.size()
	voice.stream = effects[effect_name]
	voice.volume_db = EFFECT_DB.get(effect_name, -9.0)
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
