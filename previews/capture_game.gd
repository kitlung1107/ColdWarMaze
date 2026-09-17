extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var game=load("res://scripts/game.gd").new()
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	game.test_mode=true
	game.start_game(40519)
	for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		game.facing=direction
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/game-uniform-%d-%d.png" % [direction.x,direction.y])
	game.show_menu()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://previews/menu-uniform.png")
	quit()
