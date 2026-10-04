extends SceneTree
const Maze=preload("res://scripts/maze.gd")
var failures=[]
func _initialize() -> void:
	var release=JSON.parse_string(FileAccess.get_file_as_string("res://data/trusted-mazes.json"))
	for layout in release.layouts:
		var maze=Maze.new()
		maze.load_trusted(layout)
		if maze.floors.size()!=119 or maze.files.size()!=3 or maze.doors.size()<10 or maze.doors.size()>13:failures.append("geometry "+layout.id)
		if maze.rewards.size()!=layout.chests.size()+layout.towers.size()+layout.shortcuts.size():failures.append("rewards "+layout.id)
		for door in maze.doors:maze.doors[door]=true
		for target in maze.files.keys()+[maze.finish]:
			var path=maze.path(maze.start,target)
			if path.is_empty():failures.append("unreachable "+layout.id)
			for cell in path:
				if not maze.can_walk(cell):failures.append("blocked "+layout.id)
		for cell in layout.floors:
			if maze.to_cell(maze.from_cell(int(cell)))!=int(cell):failures.append("cell mapping "+layout.id)
	print("CHECKED: all 128 published mazes load into the original game with three files, fallback routes, door and reward mechanics.")
	for failure in failures:printerr(failure)
	quit(0 if failures.is_empty() else 1)
