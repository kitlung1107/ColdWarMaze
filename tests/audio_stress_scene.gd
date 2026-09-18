extends "res://scripts/game.gd"

# Copied into an isolated web test project; never exported with the game.
var stress_elapsed = 0.0
var stress_next = 2.0
var stress_count = 0
var stress_finished = false

func _ready() -> void:
	super._ready()
	study.enabled_save = false
	test_mode = false
	start_game(91024)
	mode = "play"
	owned = ["basic", "wide", "long", "scan"]
	rebuild_ui()
	print("AUDIO_STRESS_READY")

func _process(delta: float) -> void:
	super._process(delta)
	stress_elapsed += delta
	if stress_elapsed >= stress_next and stress_count < 300:
		stress_next += 0.07
		for node in ui.find_children("*", "Button", true, false):
			if node.text == "切換燈":
				node.pressed.emit()
				break
		stress_count += 1
	if stress_elapsed > 27.0 and not stress_finished:
		stress_finished = true
		print("AUDIO_STRESS_DONE count=%d playing=%s paused=%s gain=%s" % [stress_count, game_audio.music.playing, game_audio.music.stream_paused, game_audio.gain])
