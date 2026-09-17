extends "res://scripts/game.gd"

# Preview only: the production game keeps the previously approved artwork.
const DEMO_PIXELS = [
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
const DEMO_COLORS = {
	"h":Color("302d30"),"j":Color("514743"),"s":Color("ddbb94"),
	"o":Color("111d27"),"n":Color("202940"),"w":Color("e9ddba"),
	"g":Color("c5a66c"),"t":Color("24333f"),"p":Color("252b44"),
	"q":Color("4c526b"),"f":Color("111d27"),"l":Color("c5a66c"),"u":Color("f2d791")
}

func _draw() -> void:
	super._draw()
	if mode!="play":return
	var pos=board_origin+Vector2(player)*tile
	draw_tile(player,pos)
	var unit=tile/20.0
	var offset=pos+Vector2(1,1)*unit
	for y in range(DEMO_PIXELS.size()):
		for x in range(DEMO_PIXELS[y].length()):
			var key=DEMO_PIXELS[y][x]
			if DEMO_COLORS.has(key):
				draw_rect(Rect2(offset+Vector2(x,y)*unit,Vector2.ONE*ceil(unit)),DEMO_COLORS[key])
