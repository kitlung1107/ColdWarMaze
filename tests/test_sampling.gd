extends SceneTree

const Study = preload("res://scripts/study.gd")
var failures = []

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _initialize() -> void:
	var study = Study.new(false)
	# Complete a small topic: every successful question must be unique,
	# including when recent/concept filters need to relax.
	var seen = []
	for i in range(50):
		var q = study.pick(7)
		check(not q.is_empty(), "topic exhausted prematurely")
		if q.is_empty(): break
		check(q.id not in seen, "correct question repeated")
		seen.append(q.id)
		study.record(q, true, [])
	check(study.pick(7).is_empty(), "exhausted topic returned a zero-weight question")
	check(not study.pick(0).is_empty(), "other topics became unavailable")
	study.session_seen.clear()
	study.session_correct.clear()
	check(not study.pick(7).is_empty(), "new session did not restore questions")
	study.reset()
	check(study.session_correct.is_empty(), "reset retained session exclusions")
	# Fixed-seed empirical check of the 3:2:1 new/wrong/correct ratio.
	study.bank = study.bank.slice(0,3)
	study.records = {"2": {"last_correct": false}, "3": {"last_correct": true}}
	var counts = [0,0,0]
	seed(1729)
	for i in range(12000):
		study.recent.clear()
		study.recent_concepts.clear()
		study.session_seen.clear()
		var q = study.pick(1)
		counts[int(q.id)-1] += 1
	check(absf(float(counts[0])/12000.0-0.5)<0.025, "unseen weight ratio")
	check(absf(float(counts[1])/12000.0-1.0/3.0)<0.025, "wrong weight ratio")
	check(absf(float(counts[2])/12000.0-1.0/6.0)<0.025, "correct weight ratio")
	print("Sampling counts: ", counts)
	if failures.is_empty():
		print("PASS: sampling weights, session exclusion, exhaustion and reset")
		quit(0)
	else:
		for failure in failures: printerr(failure)
		quit(1)
