extends SceneTree

const Game=preload("res://scripts/game.gd")
var failures=[]
var checked_pairs=0

func check(value: bool, message: String) -> void:
	if not value:failures.append(message)

func count_available_options(node: Node, options: Array) -> int:
	var count=0
	if node is Button and node.text in options and not node.disabled:
		count+=1
	for child in node.get_children():
		count+=count_available_options(child,options)
	return count

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var path="res://data/questions.json"
	var bank=JSON.parse_string(FileAccess.get_file_as_string(path))
	var game=Game.new()
	root.add_child(game)
	await process_frame
	game.study.enabled_save=false
	game.study.bank=bank
	game.start_game(91024)
	var correction_count=0
	for q in bank:
		var correct=[int(q.correct)] if q.type=="mc" else Array(q.correct).duplicate()
		check(game.study.is_correct(q,correct),"answer key rejected q%d"%q.id)
		if q.type!="correct":continue
		correction_count+=1
		var original=q.items.duplicate()
		game.question=q
		game.context={"kind":"door","position":game.maze.doors.keys()[0]}
		game.prepare_response()
		game.mode="quiz"
		game.rebuild_ui()
		check(q.items.size()==4 and q.options.size()==4,"four items and options q%d"%q.id)
		var accepted=0
		for fragment in range(4):
			game.select_correction_fragment(fragment)
			check(count_available_options(game.ui,q.options)==4,"options were filtered by selected fragment q%d"%q.id)
			for option in range(4):
				game.select_correction_replacement(option)
				check(game.complete_response(),"pair incomplete q%d"%q.id)
				var expected=fragment==int(q.correct[0]) and option==int(q.correct[1])
				var actual=game.study.is_correct(q,game.responses)
				check(actual==expected,"incorrect pair grading q%d"%q.id)
				check(game.correction_fragments()[fragment]==q.options[option],"preview mismatch q%d"%q.id)
				check(q.items==original,"preview mutated bank q%d"%q.id)
				if actual:
					accepted+=1
					check("".join(PackedStringArray(game.correction_fragments()))==q.corrected_sentence,"corrected sentence mismatch q%d"%q.id)
				checked_pairs+=1
				await process_frame
		check(accepted==1,"more than one accepted pair q%d"%q.id)
		game.reset_correction()
		check(game.correction_fragments()==original,"reset mismatch q%d"%q.id)
	check(correction_count==22 and checked_pairs==352,"question or pair count")
	game.free()
	if failures.is_empty():
		print("PASS: 400 answer keys; 22 correction interfaces; 352 fragment/option pairs; all four options remain available; previews and reset preserve bank")
	else:
		for failure in failures:printerr(failure)
	quit(0 if failures.is_empty() else 1)
