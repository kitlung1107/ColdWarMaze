extends SceneTree

const Maze=preload("res://scripts/maze.gd")
const Study=preload("res://scripts/study.gd")
var failures=[]

func check(condition: bool,message: String) -> void:
	if not condition:failures.append(message)

func _initialize() -> void:
	var door_min=100
	var door_max=0
	for seed_number in range(1,251):
		var m=Maze.new()
		m.generate(seed_number)
		check(m.files.size()==3,"file count seed %d" % seed_number)
		var seen=m.distances(m.start)
		check(seen.has(m.finish),"exit reachable")
		check(not m.files.has(m.finish),"exit cannot replace file")
		for pos in m.files:check(seen.has(pos),"file reachable")
		for pos in m.rewards:
			m.rewards[pos].state=-1
			if m.rewards[pos].kind=="shortcut":check(m.manhattan(pos,m.finish)>=5,"shortcut too near exit")
		var necessary={}
		var target_list=m.files.keys()+[m.finish]
		for target in target_list:
			for p in m.path(m.start,target):
				if m.doors.has(p):necessary[p]=true
		check(necessary.size()>=8,"too few unavoidable questions in fallback route %d" % seed_number)
		for pos in m.doors:m.doors[pos]=true
		for target in target_list:
			for p in m.path(m.start,target):check(m.can_walk(p),"all rewards failed but path blocked")
		door_min=mini(door_min,necessary.size())
		door_max=maxi(door_max,necessary.size())
		check(m.visible(m.start,m.start,Vector2i.RIGHT,"basic"),"basic light sees player")
		check(not m.visible(m.start+Vector2i(8,0),m.start,Vector2i.RIGHT,"basic"),"fog not covering distance")
		check(m.visible(m.start+Vector2i(3,0),m.start,Vector2i.RIGHT,"scan"),"scan must reveal through walls")
	var study=Study.new(false)
	check(study.bank.size()==100,"100 questions loaded")
	for q in study.bank:
		var correct=[int(q.correct)] if q.type=="mc" else Array(q.correct)
		check(study.is_correct(q,correct),"correct answer rejected q%d" % q.id)
		var wrong=correct.duplicate()
		wrong[0]=-1
		check(not study.is_correct(q,wrong),"incorrect answer accepted q%d" % q.id)
	for t in range(1,9):
		study.recent.clear()
		study.recent_concepts.clear()
		for i in range(40):
			var previous=study.recent.back() if not study.recent.is_empty() else -1
			var q=study.pick(t,int(previous))
			check(q.topic=="T"+str(t),"topic filter")
			check(q.id!=previous,"immediate repeated question")
	var q=study.bank[0]
	study.record(q,false,[-1])
	check(study.records["1"].last_correct==false,"weakness tracked")
	study.record(q,true,[int(q.correct)])
	check(study.records["1"].seen==2 and study.records["1"].correct==1,"performance counts")
	print("CHECKED: 250 random mazes; 3 files + exit reachable after all reward failures; %d–%d ordinary doors on fallback task routes." % [door_min,door_max])
	print("CHECKED: 100 question answer keys, 320 topic draws, no immediate repeats, fog radius, scan light, performance records.")
	if failures.is_empty():
		print("PASS")
		quit(0)
	else:
		for f in failures:printerr(f)
		quit(1)
