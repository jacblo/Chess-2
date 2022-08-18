extends CheckButton

var board

export var clean: Texture
export var unclean: Texture

func _ready():
	board = get_node("/root/Node2D/BoardController/Board")

func toggled(state):
	board.texture = clean if state else unclean
