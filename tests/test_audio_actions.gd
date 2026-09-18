extends SceneTree

class ObservedGame:
	extends "res://scripts/game.gd"
	var sounds: Array[String] = []
	func play_sound(effect_name: String) -> void:
		sounds.append(effect_name)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game = ObservedGame.new()
	root.add_child(game)
	await process_frame
	game.study.enabled_save = false
	game.start_game(91024)
	game.sounds.clear()
	for node in game.ui.find_children("*", "Button", true, false):
		if node.text == "買燈":
			node.pressed.emit()
			break
	assert(game.mode == "shop" and game.sounds == ["shop_open"])
	game.test_mode = false
	game._process(0.01)
	assert(game.game_audio.reading)
	game.test_mode = true
	game.sounds.clear()
	game.coins = 0
	game.buy_lamp("wide")
	assert(game.sounds == ["insufficient"] and game.coins == 0 and game.owned == ["basic"])
	game.resume()
	game.owned = ["basic", "wide", "long", "scan"]
	for i in range(300):
		game.sounds.clear()
		for node in game.ui.find_children("*", "Button", true, false):
			if node.text == "切換燈":
				node.pressed.emit()
				break
		assert(game.mode == "play" and game.sounds == ["switch"])
	game.sounds.clear()
	game.player = Vector2i(1, 1)
	game.move(Vector2i.LEFT)
	assert(game.sounds == ["bump"] and game.player == Vector2i(1, 1))
	var step_found = false
	for position in game.maze.floors:
		var next = position + Vector2i.RIGHT
		if not game.maze.can_walk(position) or not game.maze.can_walk(next):continue
		if game.maze.rewards.has(next) or next == game.maze.finish:continue
		game.player = position
		game.maze.files = {next: false, Vector2i(-1,-1): true, Vector2i(-2,-2): true}
		game.sounds.clear()
		game.move(Vector2i.RIGHT)
		assert(game.sounds == ["footstep", "files_ready"] and game.file_count() == 3)
		step_found = true
		break
	assert(step_found)
	game.sounds.clear()
	game.begin_question({"kind":"door", "position":game.maze.doors.keys()[0]})
	assert(game.sounds == ["investigate"])
	for q in game.study.bank:
		game.question = q
		game.prepare_response()
		game.rebuild_ui()
		var attempts_before = game.attempts
		var records_before = game.study.records.duplicate(true)
		game.sounds.clear()
		var confirm = game.ui.find_child("ConfirmAnswer", true, false)
		assert(not confirm.disabled)
		confirm.pressed.emit()
		assert(game.sounds == ["incomplete"])
		assert(game.attempts == attempts_before and game.mode == "quiz")
		assert(game.study.records == records_before)
	print("PASS: shop sound/ducking, insufficient funds guard, 300 lamp presses without double audio, collision, final file, investigation, and all 100 incomplete answers remain ungraded.")
	game.queue_free()
	await process_frame
	quit()
