extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	for variant in ["current","matched"]:
		var source="res://scripts/game.gd" if variant=="current" else "res://previews/matched_style.gd"
		var game=load(source).new()
		root.add_child(game)
		game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await process_frame
		game.test_mode=true
		game.start_game(40519)
		game.lamp="wide"
		for cell in game.maze.floors:
			if cell.x<5 or cell.y<4:continue
			if game.maze.can_walk(cell) and game.maze.can_walk(cell+Vector2i.RIGHT) and game.maze.can_walk(cell+Vector2i.RIGHT*2):
				game.player=cell
				break
		game.facing=Vector2i.RIGHT
		game.toast_time=0
		game.rebuild_ui()
		game.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://previews/style-%s.png" % variant)
		var center=(game.board_origin+(Vector2(game.player)+Vector2(0.5,0.5))*game.tile)*root.get_stretch_transform().get_scale()
		var image=root.get_texture().get_image()
		var crop=image.get_region(Rect2i(Vector2i(center)-Vector2i(110,110),Vector2i(220,220)))
		crop.resize(660,660,Image.INTERPOLATE_NEAREST)
		crop.save_png("res://previews/style-%s-detail.png" % variant)
		game.queue_free()
		await process_frame
	quit()
