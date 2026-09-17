extends SceneTree
const Study=preload("res://scripts/study.gd")

func _initialize() -> void:
	# Run with APPDATA redirected to an isolated test folder.
	var first=Study.new()
	var original=first.records.duplicate(true)
	first.records={}
	var q=first.bank[0]
	first.record(q,false,[-1])
	first.record(q,true,[int(q.correct)])
	var second=Study.new()
	var passed=second.storage_ok and second.records.get("1",{}).get("seen",0)==2 and second.records.get("1",{}).get("correct",0)==1
	second.records=original
	second.save_progress()
	print("PASS: native progress saved and reloaded; original isolated-test data restored." if passed else "FAIL: persistence round-trip")
	quit(0 if passed else 1)
