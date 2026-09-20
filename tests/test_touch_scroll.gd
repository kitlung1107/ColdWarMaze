extends SceneTree

const Game = preload("res://scripts/game.gd")
var failures = []

func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message)

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	for i in range(4):await process_frame

func touch(position: Vector2, down: bool, canceled: bool = false) -> void:
	var event = InputEventScreenTouch.new()
	event.position = position
	event.pressed = down
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func drag(position: Vector2) -> void:
	var event = InputEventScreenDrag.new()
	event.position = position
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func mouse(position: Vector2, down: bool, device: int = 0, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event = InputEventMouseButton.new()
	event.position = position
	event.button_index = button
	event.pressed = down
	event.device = device
	root.push_input(event, true)

func run() -> void:
	Input.emulate_mouse_from_touch = true
	var game = Game.new()
	root.add_child(game)
	await settle()
	game.study.enabled_save = false
	game.start_game(91024)
	for dimensions in [Vector2i(667,375), Vector2i(844,390), Vector2i(1024,768), Vector2i(1366,768)]:
		root.content_scale_size = Vector2i.ZERO
		root.size = dimensions
		game.size = dimensions
		for kind in ["mc", "correct"]:
			for q in game.study.bank:
				if q.type == kind:
					game.question = q
					break
			game.context = {"kind":"door", "position":game.maze.doors.keys()[0]}
			game.mode = "quiz"
			game.prepare_response()
			game.rebuild_ui()
			await settle()
			var scroll = game.ui.find_children("*", "ScrollContainer", true, false)[0]
			var inner = scroll.get_child(0)
			var target: Control = game.ui.find_child("CorrectionSentence", true, false) if kind == "correct" else inner.get_child(1)
			# Force overflow on large displays too, without changing target geometry.
			var spacer = Control.new()
			spacer.custom_minimum_size.y = 900
			inner.add_child(spacer)
			await settle()
			check(is_equal_approx(scroll.get_v_scroll_bar().size.x,16), "16px scrollbar at %s" % dimensions)
			var point = target.global_position + Vector2(12,24)
			var before = game.responses.duplicate()
			touch(point,true)
			check(game.responses == before, "touch down never selects")
			drag(point-Vector2(0,45))
			check(scroll.scroll_vertical >= 40, "swipe from %s scrolls at %s" % [kind, dimensions])
			drag(point)
			touch(point,false)
			mouse(point,false,InputEvent.DEVICE_ID_EMULATION)
			await settle()
			check(game.responses == before, "return to origin and emulated release never select")
			scroll.scroll_vertical = 0
			await settle()
			var text_point = inner.get_child(0).global_position + Vector2(10,10)
			touch(text_point,true)
			drag(text_point-Vector2(0,40))
			touch(text_point-Vector2(0,40),false)
			check(scroll.scroll_vertical >= 35, "question text swipe scrolls")
			scroll.scroll_vertical = 0
			await settle()
			touch(point,true)
			touch(point,false,true)
			await settle()
			check(game.responses == before,"canceled touch never selects")
			touch(point,true)
			drag(point+Vector2(2,2))
			touch(point+Vector2(2,2),false)
			await settle()
			check(game.responses != before,"light tap selects %s at %s" % [kind,dimensions])
			if kind == "correct":
				check(game.responses[0] == 0,"tap selects first underlined fragment")
				scroll = game.ui.find_children("*", "ScrollContainer", true, false)[0]
				var replacements = game.ui.find_children("*", "GridContainer", true, false)[0]
				var replacement = replacements.get_child(0)
				scroll.ensure_control_visible(replacement)
				await settle()
				point = replacement.global_position + Vector2(20,20)
				before = game.responses.duplicate()
				touch(point,true)
				drag(point-Vector2(0,35))
				touch(Vector2(-20,-20),false)
				await settle()
				check(game.responses == before,"replacement swipe with release outside never selects")
				scroll.ensure_control_visible(replacement)
				await settle()
				point = replacement.global_position + Vector2(20,20)
				touch(point,true)
				touch(point,false)
				await settle()
				check(game.responses[1] >= 0,"replacement tap selects")
				game.select_correction_replacement(0)
				check(game.correction_fragments()[0] == game.question.options[0],"preview retained")
				game.reset_correction()
			else:
				game.responses = []
				game.rebuild_ui()
			await settle()
			scroll = game.ui.find_children("*", "ScrollContainer", true, false)[0]
			inner = scroll.get_child(0)
			target = game.ui.find_child("CorrectionSentence",true,false) if kind == "correct" else inner.get_child(1)
			point = target.global_position + Vector2(12,24)
			mouse(point,true)
			mouse(point,false)
			await settle()
			check(game.responses[0] >= 0,"desktop click selects")
			scroll = game.ui.find_children("*", "ScrollContainer", true, false)[0]
			spacer = Control.new()
			spacer.custom_minimum_size.y = 900
			scroll.get_child(0).add_child(spacer)
			await settle()
			mouse(scroll.global_position+Vector2(20,20),true,0,MOUSE_BUTTON_WHEEL_DOWN)
			check(scroll.scroll_vertical > 0,"desktop wheel scrolls")
	root.size = Vector2i(375,667)
	game.size = root.size
	game.rebuild_ui()
	await settle()
	var paused_response = game.responses.duplicate()
	var covered_scroll = game.ui.find_children("*", "ScrollContainer", true, false)[0]
	check(not covered_scroll.is_processing_input(),"portrait cover disables touch interception")
	touch(covered_scroll.global_position+Vector2(20,20),true)
	touch(covered_scroll.global_position+Vector2(20,20),false)
	await settle()
	check(game.responses == paused_response,"portrait remains paused")
	for failure in failures:printerr(failure)
	print("PASS: touch text/buttons/fragments, sticky drag cancellation, canceled touch, tap jitter, desktop click/wheel, 16px bar, four dimensions" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
