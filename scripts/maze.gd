extends RefCounted

const W = 21
const H = 13
const DIRS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
var rng = RandomNumberGenerator.new()
var floors = {}
var doors = {}
var rewards = {}
var files = {}
var start = Vector2i(1, 1)
var finish = Vector2i.ZERO
var seed_value = 0

func generate(value: int) -> void:
	seed_value = value
	rng.seed = value
	floors.clear()
	doors.clear()
	rewards.clear()
	files.clear()
	var stack = [start]
	floors[start] = true
	while not stack.is_empty():
		var cell = stack.back()
		var candidates = []
		for d in DIRS:
			var next = cell + d * 2
			if next.x > 0 and next.x < W - 1 and next.y > 0 and next.y < H - 1 and not floors.has(next):
				candidates.append(d)
		if candidates.is_empty():
			stack.pop_back()
		else:
			var direction = candidates[rng.randi_range(0, candidates.size()-1)]
			floors[cell + direction] = true
			floors[cell + direction * 2] = true
			stack.append(cell + direction * 2)
	var distance = distances(start)
	var rooms = []
	for p in floors:
		if p.x % 2 == 1 and p.y % 2 == 1 and p != start:
			rooms.append(p)
	rooms.sort_custom(func(a,b): return distance[a] > distance[b])
	finish = rooms[0]
	var chosen = [start, finish]
	for i in range(3):
		var best = Vector2i.ZERO
		var best_score = -1.0
		var maps = []
		for c in chosen:
			maps.append(distances(c))
		for p in rooms:
			if p in chosen or distance[p] < 10:
				continue
			var spread = 10000
			for m in maps:
				spread = mini(spread, m[p])
			var score = float(spread) + float(distance[p]) * 0.25
			if score > best_score:
				best_score = score
				best = p
		chosen.append(best)
		files[best] = false
	# All ordinary doors lie on the original tree, never on optional routes.
	var route_halls = []
	for goal in chosen.slice(1):
		var route = path(start, goal)
		for cell in route:
			if (cell.x % 2 == 0 or cell.y % 2 == 0) and cell not in route_halls and distance[cell] > 2:
				route_halls.append(cell)
		if files.has(goal) and route.size() >= 2:
			doors[route[-2]] = false
	route_halls.sort_custom(func(a,b): return distance[a] < distance[b])
	for i in range(10):
		if route_halls.is_empty():
			break
		var idx = clampi(int(float(i) / 10.0 * route_halls.size()), 0, route_halls.size()-1)
		doors[route_halls[idx]] = false
	# Reward rooms are all optional. Failure never removes the original route.
	var free = []
	for p in rooms:
		if p not in chosen and distance[p] >= 4:
			free.append(p)
	shuffle(free)
	for i in range(mini(9, free.size())):
		rewards[free[i]] = {"kind": "chest" if i < 6 else "tower", "state": 0}
	var shortcut_candidates = []
	for y in range(1,H-1):
		for x in range(1,W-1):
			var p = Vector2i(x,y)
			if floors.has(p) or (x % 2 == y % 2) or manhattan(p, finish) < 5:
				continue
			var axis = Vector2i.RIGHT if x % 2 == 0 else Vector2i.DOWN
			if floors.has(p-axis) and floors.has(p+axis):
				if path(p-axis,p+axis).size() >= 10:
					shortcut_candidates.append(p)
	shuffle(shortcut_candidates)
	for p in shortcut_candidates.slice(0,3):
		rewards[p] = {"kind":"shortcut", "state":0}

func shuffle(a: Array) -> void:
	for i in range(a.size()-1,0,-1):
		var j = rng.randi_range(0,i)
		var temp = a[i]
		a[i] = a[j]
		a[j] = temp

func manhattan(a: Vector2i,b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

func distances(origin: Vector2i) -> Dictionary:
	var out = {origin:0}
	var queue = [origin]
	var idx = 0
	while idx < queue.size():
		var p = queue[idx]
		idx += 1
		for d in DIRS:
			var next = p+d
			if floors.has(next) and not out.has(next):
				out[next] = out[p]+1
				queue.append(next)
	return out

func path(a: Vector2i,b: Vector2i) -> Array:
	var parents = {a:a}
	var queue = [a]
	var idx = 0
	while idx < queue.size() and not parents.has(b):
		var p = queue[idx]
		idx+=1
		for d in DIRS:
			var next = p+d
			if floors.has(next) and not parents.has(next):
				parents[next] = p
				queue.append(next)
	if not parents.has(b):
		return []
	var result = [b]
	while result.back()!=a:
		result.append(parents[result.back()])
	result.reverse()
	return result

func can_walk(p: Vector2i) -> bool:
	if rewards.has(p) and rewards[p].kind == "shortcut":
		return rewards[p].state == 1
	return floors.has(p) and (not doors.has(p) or doors[p])

func opaque(p: Vector2i) -> bool:
	return not can_walk(p)

func visible(p: Vector2i, from: Vector2i, facing: Vector2i, lamp: String) -> bool:
	var delta = p-from
	var dist = Vector2(delta).length()
	var allowed = dist <= 2.6
	if lamp == "wide":
		allowed = dist <= 4.5
	elif lamp == "long":
		var lateral = absi(delta.x*facing.y-delta.y*facing.x)
		allowed = allowed or lateral <= 1
	elif lamp == "scan":
		allowed = dist <= 3.5
	if not allowed:
		return false
	if lamp == "scan":
		return true
	# Raycast occlusion; destination wall remains visible, cells behind it do not.
	var steps = maxi(absi(delta.x), absi(delta.y))*3
	var previous = from
	for i in range(1,steps):
		var point = Vector2i((Vector2(from)+Vector2(delta)*float(i)/float(steps)).round())
		if point==previous or point==p:
			continue
		previous=point
		if opaque(point):
			return false
	return true
