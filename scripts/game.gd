extends Control

const Maze = preload("res://scripts/maze.gd")
const Study = preload("res://scripts/study.gd")
const GameAudio = preload("res://scripts/game_audio.gd")
const INK = Color("0b131d")
const PANEL = Color("111e28")
const LINE = Color("30424b")
const TEXT = Color("e8e4d5")
const MUTED = Color("9eafb0")
const GOLD = Color("e4b66c")
const TEAL = Color("77c7b3")
const RED = Color("e79683")
const LAMP_NAMES = {"basic":"基本照明", "wide":"廣角燈", "long":"雙向探照燈", "scan":"穿牆掃描燈"}
const PRICES = {"wide":3,"long":4,"scan":5}
const TYPES = {"mc":"史實 MC", "order":"時序排序", "match":"線索配對", "classify":"史實分類", "correct":"史實找錯"}
var maze = Maze.new()
var study
var font
var reading_font: Font
var pixel_font: FontFile
var game_audio
var ui: Control
var mode = "menu"
var topic = 0
var player = Vector2i(1,1)
var facing = Vector2i.DOWN
var coins = 0
var owned = ["basic"]
var lamp = "basic"
var revealed_chests = {}
var question = {}
var context = {}
var responses = []
var shuffled = []
var active_row = 0
var last_correct = false
var attempts = 0
var successes = 0
var elapsed = 0.0
var move_cooldown = 0.0
var held = Vector2i.ZERO
var toast = ""
var toast_time = 0.0
var time = 0.0
var tile = 38.0
var board_origin = Vector2.ZERO
var hud_coins: Label
var hud_files: Label
var hud_lamp: Label
var action_button: Button
var rotate_overlay: Control
var save_warning_shown = false
var test_mode = false
var help_return = "menu"
var last_ui_mode = ""
var last_ui_question = -1
var fullscreen_prompt_poll = 0.0

func _ready() -> void:
	randomize()
	test_mode="--qa" in OS.get_cmdline_user_args()
	game_audio=GameAudio.new()
	add_child(game_audio)
	study=Study.new(not test_mode)
	font=load("res://assets/ArchiveStudySans.otf")
	reading_font=font
	pixel_font=load("res://assets/FusionPixel12TC.otf")
	pixel_font.multichannel_signed_distance_field=false
	pixel_font.antialiasing=TextServer.FONT_ANTIALIASING_NONE
	var theme_resource=Theme.new()
	theme_resource.default_font=font
	theme_resource.default_font_size=22
	theme=theme_resource
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	resized.connect(_on_resize)
	show_menu()
	if test_mode:
		start_game(40519)
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--question="):
				var number=int(arg.trim_prefix("--question="))
				begin_question({"kind":"door","position":maze.doors.keys()[0]})
				question=study.bank[number-1]
				prepare_response()
				rebuild_ui()

func _on_resize() -> void:
	update_layout()
	if is_instance_valid(ui):
		rebuild_ui()

func update_layout() -> void:
	var usable=Vector2(size.x-350,size.y-178)
	tile=floor(minf(usable.x/maze.W,usable.y/maze.H))
	board_origin=Vector2(175+(usable.x-tile*maze.W)/2,100+(usable.y-tile*maze.H)/2)
	queue_redraw()

func _process(delta: float) -> void:
	game_audio.exploring=mode=="play" and size.x>=size.y and not test_mode
	game_audio.reading=mode in ["quiz","feedback"] and size.x>=size.y and not test_mode
	if mode=="fullscreen_prompt":
		fullscreen_prompt_poll-=delta
		if fullscreen_prompt_poll<=0:
			fullscreen_prompt_poll=0.2
			if not JavaScriptBridge.eval("window.cwFullscreenPromptOpen === true"):
				resume()
				notify("收集 3 份文件。金色普通門可重試；寶箱與塔只有一次機會。",7)
	time+=delta
	move_cooldown=maxf(0,move_cooldown-delta)
	toast_time=maxf(0,toast_time-delta)
	if mode=="play" and size.x>=size.y:
		elapsed+=delta
		var direction=held
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction=Vector2i.UP
		elif Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction=Vector2i.DOWN
		elif Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction=Vector2i.LEFT
		elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction=Vector2i.RIGHT
		if direction!=Vector2i.ZERO and move_cooldown<=0:
			move(direction)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if mode=="play":
			if event.keycode in [KEY_W,KEY_UP]:move(Vector2i.UP)
			elif event.keycode in [KEY_S,KEY_DOWN]:move(Vector2i.DOWN)
			elif event.keycode in [KEY_A,KEY_LEFT]:move(Vector2i.LEFT)
			elif event.keycode in [KEY_D,KEY_RIGHT]:move(Vector2i.RIGHT)
			elif event.keycode==KEY_E or event.keycode==KEY_SPACE:
				interact()
			elif event.keycode==KEY_L:
				cycle_lamp()
			elif event.keycode==KEY_ESCAPE:
				mode="pause"
				rebuild_ui()
		elif mode in ["shop","help","pause"] and event.keycode==KEY_ESCAPE:
			resume()

func style(bg: Color, border: Color = LINE, width: int = 2) -> StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=bg
	s.border_color=border
	s.set_border_width_all(width)
	s.set_corner_radius_all(3)
	s.content_margin_left=16
	s.content_margin_right=16
	s.content_margin_top=10
	s.content_margin_bottom=10
	return s

func label(text_value: String, font_size: int = 24, color: Color = TEXT) -> Label:
	var l=Label.new()
	l.text=text_value
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	return l

func button(text_value: String, action: Callable, selected: bool = false, min_height: int = 54) -> Button:
	var b=Button.new()
	b.text=text_value
	b.focus_mode=Control.FOCUS_NONE
	b.custom_minimum_size.y=min_height
	b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size",23)
	b.add_theme_color_override("font_color",GOLD if selected else TEXT)
	b.add_theme_color_override("font_hover_color",TEXT)
	b.add_theme_color_override("font_disabled_color",Color("58676d"))
	b.add_theme_stylebox_override("normal",style(Color("26332f") if selected else Color("1a2a33"),GOLD if selected else LINE))
	b.add_theme_stylebox_override("hover",style(Color("2a3d40"),TEAL))
	b.add_theme_stylebox_override("pressed",style(Color("34463c"),GOLD))
	b.add_theme_stylebox_override("focus",style(Color(0,0,0,0),TEAL))
	b.add_theme_stylebox_override("disabled",style(Color("131e26"),Color("26343d")))
	b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(action)
	return b

func box(parent: Node, gap: int = 12) -> VBoxContainer:
	var v=VBoxContainer.new()
	v.add_theme_constant_override("separation",gap)
	v.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	return v

func row(parent: Node, gap: int = 12) -> HBoxContainer:
	var r=HBoxContainer.new()
	r.add_theme_constant_override("separation",gap)
	r.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(r)
	return r

func clear_ui() -> void:
	held=Vector2i.ZERO
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	hud_coins=null
	hud_files=null
	hud_lamp=null
	action_button=null

func rebuild_ui() -> void:
	# Keep questions, choices and answer explanations in the original reading font.
	font=reading_font if mode in ["quiz","feedback"] else pixel_font
	theme.default_font=font
	var old_scroll=0
	var current_question=int(question.get("id",-1))
	if mode==last_ui_mode and current_question==last_ui_question:
		var previous_scrolls=ui.find_children("*","ScrollContainer",true,false)
		if not previous_scrolls.is_empty():old_scroll=previous_scrolls[0].scroll_vertical
	clear_ui()
	update_layout()
	if mode=="menu": menu_ui()
	elif mode in ["play","fullscreen_prompt"]: play_ui()
	elif mode=="quiz": quiz_ui()
	elif mode=="feedback": feedback_ui()
	elif mode=="shop": shop_ui()
	elif mode=="help": help_ui()
	elif mode=="pause": pause_ui()
	elif mode=="summary": summary_ui()
	var current_scrolls=ui.find_children("*","ScrollContainer",true,false)
	if not current_scrolls.is_empty() and old_scroll>0:current_scrolls[0].set_deferred("scroll_vertical",old_scroll)
	last_ui_mode=mode
	last_ui_question=current_question
	if size.x<size.y:
		var cover=ColorRect.new()
		cover.color=INK
		cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ui.add_child(cover)
		var note=label("請把裝置轉為橫向\n\n探索與答題已暫停\n橫向畫面有較大的閱讀及操作空間",32,GOLD)
		note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		note.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		note.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
		cover.add_child(note)

func panel_at(rect: Rect2) -> VBoxContainer:
	var panel=PanelContainer.new()
	panel.position=rect.position
	panel.size=rect.size
	panel.add_theme_stylebox_override("panel",style(PANEL,LINE))
	ui.add_child(panel)
	return box(panel,12)

func modal(title: String, subtitle: String) -> VBoxContainer:
	var dim=ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color=Color(0.015,0.025,0.04,0.87)
	ui.add_child(dim)
	var outer=PanelContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.offset_left=24
	outer.offset_right=-24
	outer.offset_top=16
	outer.offset_bottom=-16
	outer.add_theme_stylebox_override("panel",style(PANEL,GOLD))
	ui.add_child(outer)
	var content=box(outer,8)
	content.add_child(label(title,30,GOLD))
	if not subtitle.is_empty(): content.add_child(label(subtitle,19,MUTED))
	var scroll=ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_constant_override("scrollbar_width",10)
	content.add_child(scroll)
	var inner=box(scroll,14)
	inner.set_meta("footer",content)
	return inner

func footer(inner: Control) -> HBoxContainer:
	return row(inner.get_meta("footer"),12)

func show_menu() -> void:
	mode="menu"
	rebuild_ui()

func menu_ui() -> void:
	var shell=PanelContainer.new()
	shell.position=Vector2(size.x*0.50,28)
	shell.size=Vector2(size.x*0.47,size.y-56)
	shell.add_theme_stylebox_override("panel",style(PANEL,LINE))
	ui.add_child(shell)
	var scroll=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	var right=box(scroll,10)
	right.add_child(label("開始一趟檔案任務",27,GOLD))
	right.add_child(label("收集三份文件，找到出口。\n沒有倒數，每次都有新迷宮與問題。",21,MUTED))
	var selection=OptionButton.new()
	selection.custom_minimum_size.y=54
	selection.add_theme_font_size_override("font_size",24)
	for t in Study.TOPICS: selection.add_item(t)
	selection.select(topic)
	selection.item_selected.connect(func(index):topic=index)
	right.add_child(selection)
	right.add_child(button("進入迷宮  →",func():start_game(),true,60))
	var stats=study.stats()
	right.add_child(label("本機學習紀錄",19,TEAL))
	right.add_child(label("已練習 %d / 100 題     待重溫 %d 題" % [stats.unique,stats.weak],22))
	var actions=row(right)
	actions.add_child(button("玩法說明",func():help_return="menu";mode="help"; rebuild_ui()))
	actions.add_child(button("重設紀錄",confirm_reset))
	right.add_child(label("不用登入 · 紀錄只存於目前瀏覽器或裝置\n共用裝置可重設。更換網址或瀏覽器不會同步。",18,MUTED))
	var copyright_label=label("FORM 6  /  HKDSE HISTORY\n100 題・5 種題型・隨機探索",20,TEAL)
	copyright_label.position=Vector2(40,size.y-86)
	copyright_label.size=Vector2(size.x*0.4,65)
	ui.add_child(copyright_label)

func start_game(seed_number: int = -1) -> void:
	play_sound("click")
	maze.generate(randi_range(1,999999) if seed_number<0 else seed_number)
	player=maze.start
	facing=Vector2i.RIGHT
	coins=0
	owned=["basic"]
	lamp="basic"
	revealed_chests.clear()
	study.recent.clear()
	study.recent_concepts.clear()
	study.session_seen.clear()
	attempts=0
	successes=0
	elapsed=0
	mode="play"
	rebuild_ui()
	notify("收集 3 份文件。金色普通門可重試；寶箱與塔只有一次機會。",7)
	if OS.has_feature("web") and not test_mode:
		if JavaScriptBridge.eval("typeof window.cwOfferFullscreen === 'function' && window.cwOfferFullscreen()"):
			mode="fullscreen_prompt"
			fullscreen_prompt_poll=0.2

func play_ui() -> void:
	var top=panel_at(Rect2(20,14,size.x-40,72))
	var bar=row(top,22)
	bar.add_child(label("冷戰 / 地下檔案",24,GOLD))
	hud_files=label("文件  %d / 3" % file_count(),23,TEAL)
	bar.add_child(hud_files)
	hud_coins=label("金幣  %d" % coins,23,GOLD)
	bar.add_child(hud_coins)
	var menu_btn=button("暫停",func():mode="pause";rebuild_ui(),false,46)
	menu_btn.custom_minimum_size.x=100
	menu_btn.size_flags_horizontal=Control.SIZE_SHRINK_END
	bar.add_child(menu_btn)
	var left=panel_at(Rect2(20,105,145,190))
	left.add_child(label("本局任務",20,TEAL))
	left.add_child(label("找回三份\n機密文件",24))
	left.add_child(label("出口需集齊\n文件才開放",18,MUTED))
	var controls=Control.new()
	controls.position=Vector2(5,size.y-226)
	controls.size=Vector2(180,210)
	ui.add_child(controls)
	var directions=[Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]
	var positions=[Vector2(60,0),Vector2(0,64),Vector2(120,64),Vector2(60,128)]
	var symbols=["↑","←","→","↓"]
	for i in range(4):
		var direction=directions[i]
		var b=button(symbols[i],func():pass,false,60)
		b.position=positions[i]
		b.size=Vector2(60,60)
		for state_name in ["normal","hover","pressed"]:
			var s=style(Color("21333c"),LINE)
			s.content_margin_left=3
			s.content_margin_right=3
			b.add_theme_stylebox_override(state_name,s)
		b.button_down.connect(func():held=direction;move(direction))
		b.button_up.connect(func():held=Vector2i.ZERO)
		controls.add_child(b)
	var right=panel_at(Rect2(size.x-166,105,146,230))
	right.add_child(label("照明裝備",19,TEAL))
	hud_lamp=label(LAMP_NAMES[lamp],23,GOLD)
	right.add_child(hud_lamp)
	right.add_child(button("切換燈",cycle_lamp,false,52))
	right.add_child(button("買燈",func():mode="shop";rebuild_ui(),false,58))
	var action_panel=panel_at(Rect2(size.x-166,size.y-170,146,150))
	action_button=button("調查",interact,true,82)
	action_panel.add_child(action_button)
	action_panel.add_child(label("E / 空白鍵\n也可調查",17,MUTED))
	update_hud()

func update_hud() -> void:
	if is_instance_valid(hud_coins): hud_coins.text="金幣  %d" % coins
	if is_instance_valid(hud_files): hud_files.text="文件  %d / 3" % file_count()
	if is_instance_valid(hud_lamp): hud_lamp.text=LAMP_NAMES[lamp]

func file_count() -> int:
	var count=0
	for found in maze.files.values():
		if found:count+=1
	return count

func notify(message: String, duration: float = 4.0) -> void:
	toast=message
	toast_time=duration

func move(direction: Vector2i) -> void:
	if mode!="play" or size.x<size.y:return
	facing=direction
	move_cooldown=0.15
	var next=player+direction
	if maze.doors.has(next) and not maze.doors[next]:
		begin_question({"kind":"door","position":next})
		return
	if maze.rewards.has(next) and maze.rewards[next].kind=="shortcut" and maze.rewards[next].state!=1:
		if maze.rewards[next].state==0:begin_question({"kind":"shortcut","position":next})
		else:notify("這扇捷徑已封鎖。普通道路仍然可通行。")
		return
	if not maze.can_walk(next):return
	player=next
	if maze.files.has(player) and not maze.files[player]:
		maze.files[player]=true
		play_sound("file")
		notify("取得機密文件！ %d / 3" % file_count())
	if player==maze.finish:
		if file_count()==3:
			mode="summary"
			play_sound("complete")
			rebuild_ui()
		else:
			notify("出口已找到，還需要 %d 份文件。" % (3-file_count()))
			play_sound("exit_hint")
	elif maze.rewards.has(player):
		var r=maze.rewards[player]
		if r.state==0:notify("發現%s，按「調查」挑戰。" % ("寶箱" if r.kind=="chest" else "瞭望塔"))
	update_hud()

func interact() -> void:
	if mode!="play":return
	var targets=[player,player+facing,player+Vector2i.UP,player+Vector2i.RIGHT,player+Vector2i.DOWN,player+Vector2i.LEFT]
	for p in targets:
		if maze.rewards.has(p) and maze.rewards[p].state==0:
			begin_question({"kind":maze.rewards[p].kind,"position":p})
			return
	for p in targets:
		if maze.doors.has(p) and not maze.doors[p]:
			begin_question({"kind":"door","position":p})
			return
	notify("附近沒有可挑戰的物件。沿走廊繼續探索。")

func begin_question(target: Dictionary, avoid_id: int = -1) -> void:
	context=target
	question=study.pick(topic,avoid_id)
	prepare_response()
	mode="quiz"
	rebuild_ui()

func prepare_response() -> void:
	responses=[]
	active_row=0
	if question.type in ["match","classify"]:
		responses.resize(question.items.size())
		responses.fill(-1)
	elif question.type=="correct":responses=[-1,-1]
	shuffled=[]
	var count=question.items.size() if question.type=="order" else question.options.size()
	for i in range(count):shuffled.append(i)
	shuffled.shuffle()

func quiz_ui() -> void:
	var names={"door":"普通門", "chest":"寶箱", "tower":"瞭望塔", "shortcut":"捷徑門"}
	var consequence="答錯可讀解說，再抽新題。" if context.kind=="door" else "只有一次機會；答錯本局鎖定這個物件。"
	var inner=modal(names[context.kind]+"  /  "+TYPES[question.type],"題目 %03d  ·  %s" % [int(question.id),consequence])
	inner.add_child(label(question.prompt,26))
	if question.type=="mc":
		for index in shuffled:
			inner.add_child(button(question.options[index],func():responses=[index];rebuild_ui(),responses==[index],62))
	elif question.type=="order":
		inner.add_child(label("依先後逐張點選；再點已選卡片可取消該步及之後次序。",19,TEAL))
		for index in shuffled:
			var selected=responses.find(index)
			var prefix=(str(selected+1)+"  /  ") if selected>=0 else "＋  "
			inner.add_child(button(prefix+question.items[index],func():select_order(index),selected>=0,60))
	elif question.type=="match":
		inner.add_child(label("先選左邊項目，再點右邊答案。完成全部項目後確認。",19,TEAL))
		var columns=row(inner,18)
		var left=box(columns,10)
		var right=box(columns,10)
		left.size_flags_stretch_ratio=1
		right.size_flags_stretch_ratio=1.3
		for i in range(question.items.size()):
			var selected_text="未選" if responses[i]<0 else question.options[responses[i]]
			left.add_child(button(question.items[i]+"\n→ "+selected_text,func():active_row=i;rebuild_ui(),i==active_row,74))
		for index in shuffled:
			var b=button(question.options[index],func():assign(index),responses[active_row]==index,74)
			if question.type=="match" and index in responses and responses[active_row]!=index:b.disabled=true
			right.add_child(b)
	elif question.type=="classify":
		inner.add_child(label("逐項選類別；可按編號返回檢查。全部完成後確認。",19,TEAL))
		var steps=row(inner,8)
		for i in range(question.items.size()):
			var caption=str(i+1)+(" 已選" if responses[i]>=0 else " 待選")
			steps.add_child(button(caption,func():active_row=i;rebuild_ui(),active_row==i,48))
		inner.add_child(label(question.items[active_row],30,GOLD))
		var categories=row(inner,12)
		for index in shuffled:
			categories.add_child(button(question.options[index],func():assign(index),responses[active_row]==index,76))
	elif question.type=="correct":
		for i in range(question.items.size()):
			inner.add_child(button(question.items[i],func():responses[0]=i;rebuild_ui(),responses[0]==i,48))
		inner.add_child(label("選擇正確的替代文字：",20,TEAL))
		var grid=GridContainer.new()
		grid.columns=2
		grid.add_theme_constant_override("h_separation",12)
		grid.add_theme_constant_override("v_separation",10)
		inner.add_child(grid)
		for index in shuffled:
			grid.add_child(button(question.options[index],func():responses[1]=index;rebuild_ui(),responses[1]==index,64))
	var actions=footer(inner)
	actions.add_child(label("答題期間探索暫停。",18,MUTED))
	var submit_button=button("確認答案  →",submit,true,56)
	submit_button.disabled=not complete_response()
	actions.add_child(submit_button)

func select_order(index: int) -> void:
	var found=responses.find(index)
	if found>=0:responses=responses.slice(0,found)
	else:responses.append(index)
	rebuild_ui()

func assign(index: int) -> void:
	responses[active_row]=index
	var next=responses.find(-1)
	if next>=0:active_row=next
	rebuild_ui()

func complete_response() -> bool:
	if question.type=="mc":return responses.size()==1
	if question.type=="order":return responses.size()==question.items.size()
	return not responses.has(-1)

func submit() -> void:
	if not complete_response():return
	play_sound("click")
	last_correct=study.is_correct(question,responses)
	attempts+=1
	if last_correct:successes+=1
	study.record(question,last_correct,responses)
	var p=context.position
	if context.kind=="door":
		if last_correct:maze.doors[p]=true
	else:
		maze.rewards[p].state=1 if last_correct else -1
		if last_correct and context.kind=="chest":coins+=3
		if last_correct and context.kind=="tower":
			var choices=[]
			for pos in maze.rewards:
				if maze.rewards[pos].kind=="chest" and maze.rewards[pos].state==0 and not revealed_chests.has(pos):choices.append(pos)
			choices.sort_custom(func(a,b):return maze.manhattan(a,p)<maze.manhattan(b,p))
			for pos in choices.slice(0,2):revealed_chests[pos]=true
	mode="feedback"
	play_sound(str(context.kind) if last_correct else "wrong")
	rebuild_ui()

func solution_text() -> String:
	if question.type=="mc":return question.options[int(question.correct)]
	if question.type=="order":
		return question.answer_text
	if question.type in ["match","classify"]:
		var parts=PackedStringArray()
		for i in range(question.items.size()):parts.append(question.items[i]+" → "+question.options[int(question.correct[i])])
		return "\n".join(parts)
	return "錯誤片段："+question.items[int(question.correct[0])]+"\n應改為："+question.options[int(question.correct[1])]

func feedback_ui() -> void:
	var inner=modal("判斷正確" if last_correct else "先記住這個史實", "題目 %03d  ·  筆記第 %s 頁" % [int(question.id),question.pages])
	inner.add_child(label("正確答案",21,TEAL))
	inner.add_child(label(solution_text(),26))
	inner.add_child(label(question.explanation,25,MUTED))
	var outcome=""
	if context.kind=="door":outcome="門已開啟，本局不會再關閉。" if last_correct else "讀完解說後，按下方按鈕抽一題新題目。"
	elif not last_correct:outcome="這個物件本局已鎖定。你仍可沿普通道路完成任務。"
	elif context.kind=="chest":outcome="獲得 3 枚金幣，可用於購買探照燈。"
	elif context.kind=="tower":outcome="標示最多 2 個未開寶箱。只顯示位置，不揭開道路或出口。"
	else:outcome="捷徑已開啟，可以少繞一段路。"
	inner.add_child(label(outcome,24,GOLD if last_correct else RED))
	if not study.storage_ok:inner.add_child(label("目前瀏覽器無法保存紀錄；本次仍可繼續遊玩。",20,RED))
	footer(inner).add_child(button("再抽一題  →" if context.kind=="door" and not last_correct else "繼續探索  →",after_feedback,true))

func after_feedback() -> void:
	if context.kind=="door" and not last_correct:
		begin_question(context,int(question.id))
	else:resume()

func resume() -> void:
	mode="play"
	rebuild_ui()

func cycle_lamp() -> void:
	if mode!="play":return
	lamp=owned[(owned.find(lamp)+1)%owned.size()]
	if owned.size()==1:notify("目前只有基本照明。開寶箱賺金幣後可購買新燈。")
	else:
		notify("已切換："+LAMP_NAMES[lamp])
		play_sound("switch")
	update_hud()

func shop_ui() -> void:
	var inner=modal("照明補給", "金幣 %d  ·  已購入的燈本局可無限切換，沒有電池倒數。" % coins)
	var descriptions={"wide":"照亮附近較大範圍；適合分岔路。牆壁仍會擋光。", "long":"保留基本照明，前後直照通道盡頭；不拐彎，牆壁與未開門會擋光。", "scan":"揭開附近牆後的小片區域；適合判斷繞路方向。"}
	for key in ["wide","long","scan"]:
		inner.add_child(label(LAMP_NAMES[key]+"  /  %d 金幣" % PRICES[key],26,GOLD))
		inner.add_child(label(descriptions[key],22,MUTED))
		var b=button("裝備" if key in owned else "購買並裝備",func():buy_lamp(key),lamp==key,54)
		b.disabled=key not in owned and coins<PRICES[key]
		inner.add_child(b)
	footer(inner).add_child(button("返回迷宮",resume))

func buy_lamp(key: String) -> void:
	if key not in owned:
		if coins<PRICES[key]:return
		coins-=PRICES[key]
		owned.append(key)
		play_sound("purchase")
	elif lamp!=key:
		play_sound("switch")
	lamp=key
	rebuild_ui()

func pause_ui() -> void:
	var inner=modal("任務暫停", "文件 %d / 3  ·  已答 %d 題  ·  本局編號 %d" % [file_count(),attempts,maze.seed_value])
	inner.add_child(button("繼續探索",resume,true))
	var audio_options=row(inner)
	audio_options.add_child(button("音樂："+("開" if game_audio.music_enabled else "關"),func():game_audio.toggle_music();rebuild_ui()))
	audio_options.add_child(button("音效："+("開" if game_audio.effects_enabled else "關"),func():game_audio.toggle_effects();rebuild_ui()))
	if OS.has_feature("web"):
		inner.add_child(button("全畫面遊玩",request_fullscreen))
	inner.add_child(button("玩法說明",func():help_return="play";mode="help";rebuild_ui()))
	inner.add_child(label("離開本局會重新生成迷宮；已保存的學習紀錄保留。",22,MUTED))
	inner.add_child(button("結束本局，返回主頁",show_menu))

func play_sound(effect_name: String) -> void:
	if not test_mode:
		game_audio.play_effect(effect_name)

func request_fullscreen() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (typeof window.cwRequestFullscreen === 'function') window.cwRequestFullscreen();")

func help_ui() -> void:
	var inner=modal("探索手冊", "沒有倒數，可以慢慢閱讀與思考。")
	for entry in ["目標：走進文件所在格，收集 3 份後到綠色出口。", "移動：觸控方向鍵，或鍵盤 WASD / 方向鍵。調查：右側按鈕、E 或空白鍵。", "普通門：答對保持開啟；答錯先看正確答案及解說，再抽新題。", "寶箱／瞭望塔／捷徑：只有一次機會，答錯後本局鎖定。", "寶箱：答對得 3 金幣，只可買探照燈。瞭望塔：只標示最多兩個寶箱位置。", "迷霧：離開照明範圍便重新覆蓋；已開的門仍保持打開。", "三種燈：廣角看附近、雙向探照燈看前後直路、掃描看牆後；L 鍵或按鈕切換。", "保底路線：所有獎勵都失敗，仍可憑基本照明和普通門完成任務。", "學習紀錄：存在本機；較弱內容會適量重現，換裝置或清除瀏覽器資料不會保留。"]:
		inner.add_child(label(entry,24))
	footer(inner).add_child(button("返回",func():
		if help_return=="menu":show_menu()
		else:resume()))

func confirm_reset() -> void:
	clear_ui()
	var inner=modal("重設本機學習紀錄？", "這會清除目前裝置的答題次數及弱項紀錄。")
	inner.add_child(label("適合換另一位同學使用同一部裝置。",26))
	var actions=footer(inner)
	actions.add_child(button("取消",show_menu))
	actions.add_child(button("確認重設",func():study.reset();show_menu(),true))

func summary_ui() -> void:
	var inner=modal("檔案已成功帶出", "三份文件已集齊，這一趟任務完成。")
	inner.add_child(label("3 / 3",64,GOLD))
	inner.add_child(label("本局答題 %d 次  ·  答對 %d 次\n探索約 %d 分鐘（不計答題及暫停）" % [attempts,successes,int(elapsed/60)],28))
	var weak=[]
	for q in study.bank:
		if q.id in study.session_seen and not study.records.get(str(int(q.id)),{}).get("last_correct",true):weak.append(q.title)
	inner.add_child(label("下次適量重溫："+("、".join(PackedStringArray(weak.slice(0,5))) if not weak.is_empty() else "本局作答的內容表現穩定。"),23,TEAL))
	inner.add_child(label("下一局會重新抽取迷宮、文件位置及題目。",23,MUTED))
	var actions=footer(inner)
	actions.add_child(button("返回主頁",show_menu))
	actions.add_child(button("再探索一局  →",func():start_game(),true))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),INK)
	if not font:return
	if mode=="menu" or maze.floors.is_empty():
		draw_menu_art()
		return
	draw_rect(Rect2(board_origin-Vector2(6,6),Vector2(maze.W,maze.H)*tile+Vector2(12,12)),Color("26343e"))
	for y in range(maze.H):
		for x in range(maze.W):
			var cell=Vector2i(x,y)
			var pos=board_origin+Vector2(cell)*tile
			var visible=maze.visible(cell,player,facing,lamp)
			if not visible:
				draw_rect(Rect2(pos,Vector2.ONE*tile),Color("0c151f") if (x+y)%2==0 else Color("0d1721"))
				if (x*7+y*11)%9==0:draw_rect(Rect2(pos+Vector2(tile*0.3,tile*0.5),Vector2(2,2)),Color("1a2b36"))
			else:
				draw_tile(cell,pos)
				if maze.files.has(cell) and not maze.files[cell]:sprite("file",pos,tile)
				if cell==maze.finish:sprite("exit",pos,tile)
				if cell==maze.start:sprite("entry",pos,tile)
				if maze.rewards.has(cell):
					var r=maze.rewards[cell]
					sprite(r.kind,pos,tile,r.state)
				if maze.doors.has(cell):sprite("door",pos,tile,1 if maze.doors[cell] else 0)
			if revealed_chests.has(cell) and maze.rewards[cell].state==0 and not visible:
				sprite("beacon",pos,tile)
	sprite("player",board_origin+Vector2(player)*tile,tile)
	var facing_center=board_origin+(Vector2(player)+Vector2(0.5,0.5))*tile
	draw_line(facing_center+Vector2(facing)*tile*0.35,facing_center+Vector2(facing)*tile*0.52,GOLD,3)
	if toast_time>0 and mode=="play":
		var area=Rect2(190,size.y-85,size.x-380,42)
		draw_rect(area,Color("1e302f"))
		draw_string(font,area.position+Vector2(12,28),toast,HORIZONTAL_ALIGNMENT_LEFT,area.size.x-24,19,TEXT)

func draw_tile(cell: Vector2i,pos: Vector2) -> void:
	var floor_here=maze.floors.has(cell) or (maze.rewards.has(cell) and maze.rewards[cell].kind=="shortcut")
	if floor_here:
		draw_rect(Rect2(pos,Vector2.ONE*tile),Color("34403d") if (cell.x+cell.y)%2==0 else Color("303c3b"))
		draw_rect(Rect2(pos+Vector2(2,2),Vector2(tile-4,1)),Color("46534a"))
		if (cell.x*5+cell.y*3)%4==0:draw_rect(Rect2(pos+Vector2(tile*0.62,tile*0.68),Vector2(4,2)),Color("202d30"))
	else:
		draw_rect(Rect2(pos,Vector2.ONE*tile),Color("18282e"))
		draw_rect(Rect2(pos+Vector2(1,1),Vector2(tile-2,tile*0.62)),Color("526064"))
		draw_rect(Rect2(pos+Vector2(1,1),Vector2(tile-2,3)),Color("718079"))
		draw_line(pos+Vector2(0,tile*0.31),pos+Vector2(tile,tile*0.31),Color("303e45"),2)
		draw_line(pos+Vector2(tile*0.46,0),pos+Vector2(tile*0.46,tile*0.3),Color("303e45"),2)
		draw_line(pos+Vector2(tile*0.75,tile*0.32),pos+Vector2(tile*0.75,tile*0.62),Color("303e45"),2)
		draw_rect(Rect2(pos+Vector2(2,tile*0.63),Vector2(tile-4,3)),Color("263941"))

func sprite(kind: String,pos: Vector2,side: float,state: int=0) -> void:
	var pixels=[]
	var colors={"a":GOLD,"b":Color("77513a"),"c":Color("e9ddba"),"d":TEAL,"e":Color("376962"),"f":Color("111d27"),"r":RED,"s":Color("8a9a99"),"h":Color("31444b")}
	match kind:
		"player":pixels=["............","....aaaa....","...aaaaaa...","...bbbbbb...","...bccbcb...","....bbbb....","...dddddd...","..adddddda..","...dddddd...","....eeee....","...ee..ee...","..fff..fff.."]
		"file":pixels=["............","...cccccc...","...caaaaac..","...caaaaac..","...cbbbbbc..","...caaaaac..","...cbbbbbc..","...caaaaac..","...cbbbccc..","...cccccc...","............","............"]
		"chest":pixels=["............","............","..bbbbbbbb..",".baaaaaaaab.",".abbbbbbbba.",".aaaaaaaaaa.",".bbbacabbbb.",".bbbacabbbb.",".bbbbbbbbbb.",".aaaaaaaaaa.","............","............"]
		"tower":pixels=["....dddd....","..ddeeeddd..","..deeeeed...","....dd......","....ss......","...ssss.....","....ss......","....ss......","...ssss.....","..ssssss....","............","............"]
		"door":
			pixels=[".aaaaaaaaaa.",".abbbbbbbba.",".abhbbbhbba.",".abhbbbhbba.",".abhbbbhbba.",".abhbbbhbba.",".abbbbbacba.",".abhbbbhbba.",".abhbbbhbba.",".abhbbbhbba.",".aaaaaaaaaa.","............"] if state==0 else [".aa......aa.",".ab......ba.",".ab......ba.",".ab......ba.",".ab......ba.",".ab......ba.",".ab......ba.",".ab......ba.",".ab......ba.",".ab......ba.",".aa......aa.","............"]
		"shortcut":
			pixels=[".ssssssssss.",".shhhhhhhhs.",".shddhhhhhs.",".shhddhhhhs.",".shhhddhhhs.",".shhhhddhhs.",".shhhhddhhs.",".shhhddhhhs.",".shhddhhhhs.",".shddhhhhhs.",".ssssssssss.","............"] if state!=1 else [".ss......ss.",".sh......hs.",".sh......hs.",".sh......hs.",".sh......hs.",".sh......hs.",".sh......hs.",".sh......hs.",".sh......hs.",".sh......hs.",".ss......ss.","............"]
		"exit":pixels=["..dddddddd..","..deeeeeed..","..deeffeed..","..deeffeed..","..deeffeed..","..deeffeed..","..deeffeed..","..deeffeed..","..deeffeed..","..dddddddd..",".dddddddddd.","............"]
		"entry":pixels=["............","............","............","............","............","............","....ssss....","...ssssss...","..ssssssss..",".ssssssssss.","............","............"]
		"beacon":pixels=["............",".....a......","....aaa.....",".....a......","............","...aaaaaa...","..abbbbbba..","..aaacaaaa..","..bbbbbbbb..","..aaaaaaaa..","............","............"]
	var unit=side/14.0
	var offset=pos+Vector2(unit,unit)
	for y in range(pixels.size()):
		for x in range(pixels[y].length()):
			var c=pixels[y][x]
			if colors.has(c):
				var color=colors[c]
				if state==-1:color=color.darkened(0.65)
				if state==1 and kind in ["chest","tower"]:color=color.darkened(0.4)
				draw_rect(Rect2(offset+Vector2(x,y)*unit,Vector2.ONE*ceil(unit)),color)
	if state==-1:
		draw_line(pos+Vector2(side*0.25,side*0.25),pos+Vector2(side*0.75,side*0.75),RED,3)
		draw_line(pos+Vector2(side*0.75,side*0.25),pos+Vector2(side*0.25,side*0.75),RED,3)

func draw_menu_art() -> void:
	var art_scale=minf(size.x*0.48/550.0,(size.y-104)/570.0)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*art_scale)
	var left=size.x*0.48
	for y in range(3,14):
		for x in range(1,13):
			var pos=Vector2(30+x*36,70+y*31)
			var shade=Color("14252c") if (x+y)%3 else Color("1d3037")
			draw_rect(Rect2(pos,Vector2(34,29)),shade)
	draw_rect(Rect2(120,228,284,266),Color("40545a"))
	draw_rect(Rect2(149,254,226,240),Color("22333a"))
	draw_rect(Rect2(177,280,170,214),Color("0c171e"))
	draw_rect(Rect2(190,293,144,201),Color("253832"))
	for i in range(4):
		draw_rect(Rect2(138-i*16,493+i*16,248+i*32,12),Color("52605c").darkened(float(i)*0.15))
	sprite("player",Vector2(210,398),112)
	sprite("file",Vector2(360,418),64)
	sprite("chest",Vector2(68,450),72)
	for p in [Vector2(129,345),Vector2(377,345)]:
		draw_rect(Rect2(p,Vector2(10,32)),Color("6e5140"))
		draw_rect(Rect2(p+Vector2(-4,-10),Vector2(18,21)),GOLD)
		draw_rect(Rect2(p+Vector2(1,-18),Vector2(9,20)),Color("f2d791"))
	draw_string(font,Vector2(58,85),"冷戰",HORIZONTAL_ALIGNMENT_LEFT,left-70,44,GOLD)
	draw_string(font,Vector2(58,143),"地下檔案",HORIZONTAL_ALIGNMENT_LEFT,left-70,48,TEXT)
	draw_string(font,Vector2(60,180),"在迷霧之中，找回歷史的線索。",HORIZONTAL_ALIGNMENT_LEFT,left-70,20,MUTED)
	draw_set_transform(Vector2.ZERO)
