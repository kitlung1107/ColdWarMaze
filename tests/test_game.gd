extends SceneTree

const Maze=preload("res://scripts/maze.gd")
const Study=preload("res://scripts/study.gd")
var failures=[]

func check(condition: bool,message: String) -> void:
	if not condition:failures.append(message)

func _initialize() -> void:
	check_bidirectional_lamp()
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
	check(study.bank.size()==400,"400 questions loaded")
	for topic_number in range(1,9):
		check(study.bank.filter(func(item):return item.topic=="T"+str(topic_number)).size()==50,"50 questions per topic")
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
	print("CHECKED: 400 question answer keys, 320 topic draws, no immediate repeats, fog radius, scan light, performance records.")
	if failures.is_empty():
		print("PASS")
		quit(0)
	else:
		for f in failures:printerr(f)
		quit(1)

func check_bidirectional_lamp() -> void:
	for facing in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var m = Maze.new()
		var origin = Vector2i(15,15)
		var side = Vector2i(-facing.y,facing.x)
		for x in range(-12,13):
			for y in range(-12,13):
				m.floors[origin+facing*x+side*y] = true
		for sign_value in [-1,1]:
			var far = origin+facing*10*sign_value
			check(m.visible(far,origin,facing,"long"),"both directions beyond seven cells")
			check(m.visible(far+side,origin,facing,"long"),"existing beam width preserved")
			check(not m.visible(far+side*2,origin,facing,"long"),"beam does not widen")
			var barrier = origin+facing*5*sign_value
			m.doors[barrier] = false
			check(m.visible(barrier,origin,facing,"long"),"closed door itself visible")
			check(not m.visible(far,origin,facing,"long"),"closed door blocks beam")
			m.doors[barrier] = true
			check(m.visible(far,origin,facing,"long"),"opened door transmits beam")
			m.doors.erase(barrier)
			m.floors.erase(barrier)
			check(not m.visible(far,origin,facing,"long"),"wall blocks beam")
			m.floors[barrier] = true
		check(m.visible(origin+side*2,origin,facing,"long"),"basic side illumination preserved")
		check(not m.visible(origin+side*4,origin,facing,"long"),"no extra lateral reach")
		# L-shaped corridor: the far side of a corner cannot be illuminated.
		m.floors.clear()
		for x in range(9):
			m.floors[origin+facing*x] = true
		for y in range(1,6):
			m.floors[origin+facing*8+side*y] = true
		check(not m.visible(origin+facing*8+side,origin,facing,"long"),"beam cannot turn a corner within its width")
		check(not m.visible(origin+facing*8+side*5,origin,facing,"long"),"beam cannot follow a bend")
