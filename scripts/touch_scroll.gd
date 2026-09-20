extends ScrollContainer

# Own touch input before child buttons/RichTextLabel can consume it. Only a
# completed tap is replayed to GUI controls; a drag never presses a child.
const TAP_SLOP = 12.0
var finger = -1
var origin = Vector2.ZERO
var initial_scroll = 0.0
var dragged = false
var scrollbar_finger = -1

func _ready() -> void:
	var bar = get_v_scroll_bar()
	bar.custom_minimum_size.x = 16
	for state in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]:
		var skin = StyleBoxFlat.new()
		skin.bg_color = Color("30424b") if state.begins_with("scroll") else Color("9eafb0")
		skin.content_margin_left = 8
		skin.content_margin_right = 8
		skin.content_margin_top = 8
		skin.content_margin_bottom = 8
		bar.add_theme_stylebox_override(state, skin)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():return
	# Touch-to-mouse emulation must not activate a child a second time, or
	# deliver a drag's release to an answer. Real desktop mouse input is intact.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		if scrollbar_finger >= 0:return
		if finger < 0 and get_v_scroll_bar().visible and get_v_scroll_bar().get_global_rect().has_point(event.position):return
		if finger >= 0 or get_global_rect().has_point(event.position):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.index == scrollbar_finger:
			if not event.pressed:scrollbar_finger = -1
			return
		if event.pressed:
			if finger >= 0:
				dragged = true
				get_viewport().set_input_as_handled()
			elif get_global_rect().has_point(event.position):
				# Leave direct scrollbar interaction to Godot.
				if get_v_scroll_bar().visible and get_v_scroll_bar().get_global_rect().has_point(event.position):
					scrollbar_finger = event.index
					return
				finger = event.index
				origin = event.position
				initial_scroll = scroll_vertical
				dragged = false
				get_viewport().set_input_as_handled()
		elif event.index == finger:
			get_viewport().set_input_as_handled()
			var tap = not dragged and not event.canceled and origin.distance_to(event.position) <= TAP_SLOP
			finger = -1
			if tap and get_global_rect().has_point(event.position):_tap.call_deferred(origin)
	elif event is InputEventScreenDrag and event.index == finger:
		get_viewport().set_input_as_handled()
		if origin.distance_to(event.position) > TAP_SLOP:dragged = true
		if dragged:scroll_vertical = int(initial_scroll + origin.y - event.position.y)

func _tap(position: Vector2) -> void:
	if not is_inside_tree():return
	var viewport = get_viewport()
	for down in [true, false]:
		var click = InputEventMouseButton.new()
		click.position = position
		click.global_position = position
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		click.pressed = down
		viewport.push_input(click, true)
