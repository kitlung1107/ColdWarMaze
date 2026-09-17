extends RefCounted

const COLORS = {
	"o":Color("090d17"), "h":Color("302729"), "j":Color("57433d"),
	"s":Color("f4bc94"), "r":Color("d98a71"), "n":Color("202940"),
	"w":Color("f2ecdb"), "g":Color("d9b479"), "t":Color("354361"),
	"v":Color("8a99bb"), "b":Color("667fa5"), "p":Color("252b44"),
	"q":Color("4c526b"), "f":Color("201e25"), "k":Color("4e4141")
}

static func origin(pos: Vector2, side: float) -> Vector2:
	return pos+Vector2(side*0.05,side*0.05)

static func hand(pos: Vector2, side: float, direction: Vector2i) -> Vector2:
	var unit=side/20.0
	return origin(pos,side)+Vector2(2 if direction==Vector2i.LEFT else 13,10)*unit

static func draw_student(canvas: CanvasItem, pos: Vector2, side: float, direction: Vector2i) -> void:
	var unit=side/20.0
	var offset=origin(pos,side)
	for y in range(PIXELS.size()):
		for x in range(mini(13,PIXELS[y].length())):
			var color=PIXELS[y][x]
			if not COLORS.has(color):continue
			var px=15-x if direction==Vector2i.LEFT else x
			canvas.draw_rect(Rect2(offset+Vector2(px,y)*unit,Vector2.ONE*unit),COLORS[color])
	# The flashlight pivots at the same hand in all four travel directions.
	var start=hand(pos,side,direction)
	var forward=Vector2(direction)
	var across=Vector2(-direction.y,direction.x)
	for x in range(4):
		var half_width=1
		for y in range(-half_width,half_width+1):
			var color=Color("090d17")
			if x==1 and y==0:color=Color("4e4141")
			if x==3:color=Color("eac781") if absi(y)==half_width else Color("fff3cb")
			canvas.draw_rect(Rect2(start+(forward*x+across*y)*unit,Vector2.ONE*unit),color)

static func draw_beam(canvas: CanvasItem, pos: Vector2, side: float, direction: Vector2i, maze=null, board: Vector2=Vector2.ZERO, player: Vector2i=Vector2i.ZERO, lamp: String="basic") -> void:
	var unit=side/20.0
	var start=hand(pos,side,direction)+Vector2(direction)*4*unit
	var forward=Vector2(direction)
	var across=Vector2(-direction.y,direction.x)
	var step=maxf(1.0,side/18.0)
	for i in range(24):
		var distance=i*step
		var center=start+forward*distance
		if maze!=null:
			var cell=Vector2i(((center-board)/side).floor())
			if cell!=player and maze.opaque(cell):break
		var width=2*unit+distance*0.38
		for j in range(-int(width/step),int(width/step)+1):
			var point=center+across*j*step
			if maze!=null:
				var cell=Vector2i(((point-board)/side).floor())
				if not maze.visible(cell,player,direction,lamp):continue
			var alpha=0.23*(1.0-float(i)/24.0)
			canvas.draw_rect(Rect2(point,Vector2.ONE*step),Color(1.0,0.80,0.43,alpha))

# Approved two-eye school uniform, shared by the maze and menu.
const PIXELS = [
	".....hhhhhh......",
	"....hhjjhhhh.....",
	"...hhhhhhhhh.....",
	"..hhhsssssshh....",
	"..hhssssssss.....",
	"..hhssossoss.....",
	"..hhssssssss.....",
	"..hh.sssss.......",
	"..h.nnwwwnn......",
	"...nngwtgnnn.....",
	"...nngttgnnssflu.",
	"...snngtgnnn.....",
	".....ppqppp......",
	"....pqqqqqpp.....",
	".....ss.ss.......",
	".....nn.nn.......",
	".....nn.nn.......",
	"....fff.fff......",
]
