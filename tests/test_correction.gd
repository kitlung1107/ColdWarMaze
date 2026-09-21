extends SceneTree

const Game=preload("res://scripts/game.gd")
var failures=[]

func check(value: bool, message: String) -> void:
	if not value:failures.append(message)

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	for i in range(4):await process_frame

func run() -> void:
	var game=Game.new()
	root.add_child(game)
	await settle()
	game.study.enabled_save=false
	game.start_game(91024)
	for character in "還原原句":
		check(game.reading_font.has_char(character.unicode_at(0)),"missing reset glyph: "+character)
	for q in game.study.bank:
		if q.type!="correct":continue
		game.question=q
		game.context={"kind":"door","position":game.maze.doors.keys()[0]}
		game.mode="quiz"
		game.prepare_response()
		game.rebuild_ui()
		var original=q.items.duplicate()
		var attempts_before=game.attempts
		check(game.ui.find_child("ResetCorrection",true,false).disabled,"reset initially disabled")
		check(not game.ui.find_child("ConfirmAnswer",true,false).disabled,"incomplete confirm accepts reminder")
		game.ui.find_child("ConfirmAnswer",true,false).pressed.emit()
		check(game.attempts==attempts_before and game.mode=="quiz","incomplete confirm never grades")
		game.select_correction_replacement(0)
		check(game.responses==[-1,-1],"replacement requires fragment")
		game.select_correction_fragment(0)
		check(not game.ui.find_child("ResetCorrection",true,false).disabled,"selection enables reset")
		check(not game.complete_response(),"fragment alone incomplete")
		for option in range(q.options.size()):
			game.select_correction_replacement(option)
			check(game.correction_fragments()[0]==q.options[option],"live replacement preview")
			check(game.correction_fragments().slice(1)==original.slice(1),"only selected fragment changes")
			check(not game.ui.find_child("ConfirmAnswer",true,false).disabled,"complete choice enables confirm")
		game.select_correction_fragment(0)
		check(game.responses[1]>=0,"reselect edited fragment keeps preview")
		game.select_correction_fragment(1)
		check(game.responses==[1,-1] and game.correction_fragments()==original,"switch restores old edit and clears replacement")
		game.reset_correction()
		check(game.responses==[-1,-1] and game.correction_fragments()==original,"reset clears both selections")
		game.select_correction_fragment(int(q.correct[0]))
		game.select_correction_replacement(int(q.correct[1]))
		check(game.study.is_correct(q,game.responses),"original answer indices preserved")
		check(game.attempts==attempts_before and game.mode=="quiz","preview never grades")
		check(q.items==original,"bank remains unchanged")
		for dimensions in [Vector2i(667,375),Vector2i(844,390),Vector2i(1024,768),Vector2i(1366,768)]:
			root.content_scale_size=Vector2i.ZERO
			root.size=dimensions
			game.size=dimensions
			game.rebuild_ui()
			await settle()
			var sentence=game.ui.find_child("CorrectionSentence",true,false)
			var confirm=game.ui.find_child("ConfirmAnswer",true,false)
			var scroll=game.ui.find_children("*","ScrollContainer",true,false)[0]
			check(sentence.size.x<=dimensions.x-48,"sentence fits width")
			check(sentence.get_content_height()<=sentence.size.y+1,"sentence never clips wrapped lines")
			check(confirm.get_global_rect().end.y<=dimensions.y,"footer stays visible")
			check(scroll.size.y>60,"scroll remains usable")
			check(scroll.get_h_scroll_bar().max_value<=scroll.size.x+1,"no horizontal overflow")
			var reset=game.ui.find_child("ResetCorrection",true,false)
			check(reset.size.x>=140 and reset.size.y>=48,"reset has a readable touch target")
			if "--capture" in OS.get_cmdline_user_args() and q.id==44:
				DirAccess.make_dir_recursive_absolute("res://qa")
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://qa/correction-%dx%d.png" % [dimensions.x,dimensions.y])
				scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
				await settle()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://qa/correction-%dx%d-scrolled.png" % [dimensions.x,dimensions.y])
			if dimensions.x==1366:
				scroll.scroll_vertical=0
				await settle()
				var click=InputEventMouseButton.new()
				click.position=sentence.global_position+Vector2(12,24)
				click.button_index=MOUSE_BUTTON_LEFT
				click.pressed=true
				root.push_input(click)
				click=click.duplicate()
				click.pressed=false
				root.push_input(click)
				await settle()
				check(game.responses[0]==0,"sentence hit testing selects first fragment")
	print("CHECKED: all 22 correction questions, live preview, switching, reset, immutable grading data, and phone/tablet/desktop layouts.")
	for failure in failures:printerr(failure)
	print("PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
