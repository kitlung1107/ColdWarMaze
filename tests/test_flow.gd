extends SceneTree
const Game=preload("res://scripts/game.gd")
var failures=[]

func check(value: bool,message: String) -> void:
	if not value:failures.append(message)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game=Game.new()
	root.add_child(game)
	await process_frame
	game.study.enabled_save=false
	game.start_game(91024)
	# Render/build all five question interfaces against every bank item.
	for q in game.study.bank:
		game.question=q
		game.context={"kind":"door","position":game.maze.doors.keys()[0]}
		game.prepare_response()
		game.mode="quiz"
		game.rebuild_ui()
		game.responses=[int(q.correct)] if q.type=="mc" else Array(q.correct).duplicate()
		check(game.complete_response(),"response completeness q%d"%q.id)
		check(not game.solution_text().is_empty(),"answer display q%d"%q.id)
		await process_frame
	game.start_game(91024)
	# Chest reward, lamp purchase, equip, no double charging.
	var chest=Vector2i.ZERO
	for p in game.maze.rewards:
		if game.maze.rewards[p].kind=="chest":chest=p;break
	game.begin_question({"kind":"chest","position":chest})
	game.responses=[int(game.question.correct)] if game.question.type=="mc" else Array(game.question.correct).duplicate()
	game.submit()
	check(game.coins==3 and game.maze.rewards[chest].state==1,"chest award")
	game.mode="shop"
	game.buy_lamp("wide")
	check(game.coins==0 and game.lamp=="wide","lamp purchase")
	game.buy_lamp("wide")
	check(game.coins==0,"owned lamp charges twice")
	game.buy_lamp("scan")
	check(game.lamp=="wide","unaffordable lamp purchase")
	# Tower only adds chest markers, never changes floor/door geometry.
	var tower=Vector2i.ZERO
	for p in game.maze.rewards:
		if game.maze.rewards[p].kind=="tower":tower=p;break
	var floor_count=game.maze.floors.size()
	game.begin_question({"kind":"tower","position":tower})
	game.responses=[int(game.question.correct)] if game.question.type=="mc" else Array(game.question.correct).duplicate()
	game.submit()
	check(game.revealed_chests.size()==2,"tower marker count")
	check(game.maze.floors.size()==floor_count,"tower reveals route geometry")
	for p in game.revealed_chests:check(game.maze.rewards[p].kind=="chest","tower reveals non-chest")
	# Full run with every optional challenge deliberately failed.
	game.start_game(87651)
	for p in game.maze.rewards:
		game.begin_question({"kind":game.maze.rewards[p].kind,"position":p})
		game.responses=[-1] if game.question.type=="mc" else Array(game.question.correct).duplicate()
		if game.question.type!="mc":game.responses[0]=-2
		game.submit()
		check(game.maze.rewards[p].state==-1,"reward does not lock")
		game.after_feedback()
		check(game.mode=="play","reward failure incorrectly retries")
	check(game.coins==0 and game.owned==["basic"],"reward failures still gave equipment")
	var did_retry=false
	for target in game.maze.files.keys()+[game.maze.finish]:
		var route=game.maze.path(game.player,target)
		for next in route.slice(1):
			var direction=next-game.player
			game.move(direction)
			if game.mode=="quiz":
				if not did_retry:
					var previous=int(game.question.id)
					game.responses=[-1] if game.question.type=="mc" else Array(game.question.correct).duplicate()
					if game.question.type!="mc":game.responses[0]=-2
					game.submit()
					check(not game.maze.doors[game.context.position],"incorrect answer opened ordinary door")
					game.after_feedback()
					check(game.mode=="quiz" and game.question.id!=previous,"ordinary door did not draw a new question")
					did_retry=true
				game.responses=[int(game.question.correct)] if game.question.type=="mc" else Array(game.question.correct).duplicate()
				game.submit()
				check(game.maze.doors[game.context.position],"correct answer failed to open door")
				game.after_feedback()
				game.move(direction)
			check(game.player==next,"movement failed on solved fallback route")
	check(game.file_count()==3 and game.mode=="summary","full run did not complete")
	game.start_game(91024)
	game.topic=7
	for item in game.study.bank:
		if item.topic=="T7":game.study.session_correct.append(item.id)
	var target_door={"kind":"door","position":game.maze.doors.keys()[0]}
	game.begin_question(target_door)
	check(game.mode=="quiz" and game.question.topic!="T7","exhausted topic did not use another topic")
	game.study.session_correct.clear()
	for item in game.study.bank:game.study.session_correct.append(item.id)
	game.begin_question(target_door)
	check(game.mode=="menu","exhausted bank did not return to menu")
	game.start_game(91024)
	check(game.study.session_correct.is_empty(),"new game retained exclusions")
	game.begin_question(target_door)
	check(game.mode=="quiz" and game.question.topic=="T7","new game did not restore chosen topic")
	print("CHECKED: all 400 question interfaces built; chest coins, lamp prices, tower markers, all reward failures, ordinary-door retry and complete three-file extraction.")
	if failures.is_empty():print("PASS")
	else:
		for f in failures:printerr(f)
	game.free()
	quit(0 if failures.is_empty() else 1)
