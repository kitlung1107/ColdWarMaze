extends SceneTree

func _initialize() -> void:
	var bank=JSON.parse_string(FileAccess.get_file_as_string("res://data/questions.json"))
	assert(bank is Array and bank.size()==400)
	var font=load("res://assets/ArchiveStudySans.otf")
	var chars={}
	var corrections=0
	for q in bank:
		if q.type=="correct":
			corrections+=1
			assert(q.items.size()==4 and q.option_targets.size()==4)
		for field in ["prompt","title","explanation","answer_text"]:
			for character in str(q.get(field,"")):chars[character.unicode_at(0)]=true
		for text in q.get("items",[])+q.get("options",[]):
			for character in str(text):chars[character.unicode_at(0)]=true
	for codepoint in chars:
		if codepoint>32:assert(font.has_char(codepoint),"missing glyph U+%04X"%codepoint)
	assert(corrections==22)
	print("PASS: exported pack contains 400 questions, 22 revised corrections and all required font glyphs")
	quit(0)
