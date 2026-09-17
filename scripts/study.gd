extends RefCounted

const TOPICS = ["全部冷戰內容", "成因與特徵", "對立形成 1945–53", "關係起伏 1953–64", "關係緩和", "冷戰再起 1979–85", "冷戰結束 1985–91", "冷戰後國際秩序", "美蘇角色比較"]
const SAVE_PATH = "user://study_v1.json"
var bank = []
var records = {}
var recent = []
var recent_concepts = []
var storage_ok = true
var enabled_save = true
var session_seen = []
var turn = 0

func _init(save_enabled: bool = true) -> void:
	enabled_save=save_enabled
	bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json"))
	if enabled_save:
		load_progress()

func load_progress() -> void:
	var raw = ""
	if OS.has_feature("web"):
		raw = str(JavaScriptBridge.eval("(function(){try{return localStorage.getItem('coldwar-study-v1')||''}catch(e){return ''}})()"))
	elif FileAccess.file_exists(SAVE_PATH):
		raw=FileAccess.get_file_as_string(SAVE_PATH)
	var parsed=JSON.parse_string(raw) if not raw.is_empty() else null
	if parsed is Dictionary and parsed.get("version",0)==1 and parsed.get("records") is Dictionary:
		for key in parsed.records:
			var value=parsed.records[key]
			if value is Dictionary and value.get("seen",0) is float and value.get("correct",0) is float:
				records[str(key)]=value

func save_progress() -> void:
	if not enabled_save:
		return
	var raw=JSON.stringify({"version":1,"records":records})
	if OS.has_feature("web"):
		var result=JavaScriptBridge.eval("(function(){try{localStorage.setItem('coldwar-study-v1',"+JSON.stringify(raw)+");return true}catch(e){return false}})()")
		storage_ok=result==true
	else:
		var file=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
		storage_ok=file!=null
		if file:
			file.store_string(raw)

func reset() -> void:
	records.clear()
	recent.clear()
	recent_concepts.clear()
	session_seen.clear()
	save_progress()

func pick(topic: int, avoid_id: int = -1) -> Dictionary:
	var pool=[]
	for q in bank:
		if (topic==0 or q.topic=="T"+str(topic)) and q.id!=avoid_id:
			pool.append(q)
	var filtered=pool.filter(func(q):return q.id not in recent and q.concept not in recent_concepts)
	if filtered.is_empty():
		filtered=pool.filter(func(q):return q.id not in recent)
	if filtered.is_empty():
		filtered=pool
	if topic==0:
		var available=[]
		for q in filtered:
			if q.topic not in available:
				available.append(q.topic)
		var selected=available.pick_random()
		filtered=filtered.filter(func(q):return q.topic==selected)
	var total=0.0
	var weights=[]
	for q in filtered:
		var record=records.get(str(int(q.id)),{})
		var weight=3.0 if record.is_empty() else (5.0 if not record.get("last_correct",true) else 1.0)
		if q.id in session_seen:
			weight*=0.3
		weights.append(weight)
		total+=weight
	var ticket=randf()*total
	var selected_q=filtered.back()
	for i in range(filtered.size()):
		ticket-=weights[i]
		if ticket<=0:
			selected_q=filtered[i]
			break
	recent.append(selected_q.id)
	recent_concepts.append(selected_q.concept)
	if recent.size()>5:
		recent.pop_front()
	if recent_concepts.size()>2:
		recent_concepts.pop_front()
	session_seen.append(selected_q.id)
	return selected_q

func record(q: Dictionary, correct: bool, responses: Array) -> void:
	var key=str(int(q.id))
	var entry=records.get(key,{"seen":0,"correct":0})
	entry.seen+=1
	entry.correct+=1 if correct else 0
	entry.last_correct=correct
	entry.last_response=responses
	records[key]=entry
	save_progress()

func is_correct(q: Dictionary, response: Array) -> bool:
	if q.type=="mc":
		return response.size()==1 and response[0]==int(q.correct)
	if response.size()!=q.correct.size():
		return false
	for i in range(response.size()):
		if response[i]!=int(q.correct[i]):
			return false
	return true

func stats() -> Dictionary:
	var seen=0
	var good=0
	var weak=0
	for item in records.values():
		seen+=int(item.seen)
		good+=int(item.correct)
		if not item.get("last_correct",true):
			weak+=1
	return {"attempts":seen,"correct":good,"unique":records.size(),"weak":weak}
