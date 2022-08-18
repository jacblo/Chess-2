extends Node

const piece_resource = preload("res://Piece.tscn")
const piece_vis_resource = preload("res://Animated Show Place.tscn")

var move_number = 0
var last_capture_color = null
signal game_over
signal turn_change


func game_end(color):
	get_tree().paused = true
	print(color+" won!")
	get_node("/root/Node2D/Game Over").visible = true
	emit_signal("game_over", color)

class Piece:
	signal game_end
	signal flip_turn
	var color = null #default to white
	var x = 0
	var y = 0
	var object
	var name = null
	func setPos(_x, _y):
		x = _x
		y = _y
		if object:
			object.x = _x
			object.y = _y
		
		return true # capture if there is a piece there
	
	func convertPos(_x, _y): # clone of one in outside class but since no inheritance I can't use it and it's so simple it's clearer to just copy it here
		var out = Vector2(_x,_y)
		out *= 58
		out -= Vector2(203,203)
		return out

	var last_num = -1
	var last = []
	# cache it so you don't run it over and over as the mouse is held down. also do some checks that the move is legal
	# also visualize the moves possible
	func getPositionsOnce(state):
		if state.move_number == last_num:
			return last

		last_num = state.move_number
		if state.turn != color and color != "misc": # for bear
			last = []
		else:
			var tmp = getPositions(state)

			# remove friendly captures
			last = []
			for pos in tmp:
				if state.board[pos[1]][pos[0]].color != color:
					last.append(pos)

					#visualize the options
					var spot = state.board_vis[pos[1]][pos[0]]
					spot.visible = true
					var anim_player = spot.get_node("Rect/AnimationPlayer")
					anim_player.stop(false)
					anim_player.play("show_pos")
		return last
	
	func getPositions(_state):
		return []
	func spawnPiece(_position):
		if name != null:
			object = piece_resource.instance()
			object.texture = load("res://"+color+"/"+name+".png")
			object.position = _position
			object.x = x
			object.y = y
	
	func capture(_state):
		if object:
			object.delete() # clean up
			object.free()
			object = null # for safety
	
	func kingQueenCapture(state): # both share code
		if object:
			setPos(-1,-1) # -1 will symbolize jail
			var jail = state.jail[0 if color == "white" else 1]
			var end = -1
			for i in range(len(jail)):
				if jail[i] == null:
					jail[i] = self
					end = i
					object.position = Vector2(295 if color == "black" else -295, 29 * (2*i - 1)) # negative if i is 0
					break

			if end == 1: # win condition as both jail spots are taken
				var winner = "white" if color == "black" else "black"
				emit_signal("game_end", winner)

class Elephant extends Piece:
	func _init():
		name = "elephant"
	func getPositions(_state):
		var out = []
		if (x >= 2 and y >= 2):
			out.append([x-2, y-2])
		if (x < 6 and y >= 2):
			out.append([x+2,y-2])
		if (x >= 2 and y < 6):
			out.append([x-2,y+2])
		if (x < 6 and y < 6):
			out.append([x+2,y+2])
		return out

class Fish extends Piece:
	var is_queen = false
	func _init():
		name = "fish"
	
	func setPos(x,y):
		.setPos(x,y)
		if y == (0 if color=="white" else 7):
			is_queen = true
			name = "fish-queen"
			if object:
				object.texture = load("res://"+color+"/"+name+".png")
		return true

	func getPositions(state):
		var out = []
		if is_queen:
			var q = Queen.new()
			q.setPos(x,y)
			out = q.getPositions(state)

		else:
			for i in range(x-1,x+2):
				for j in (range(y-1,y+1) if color == "white" else range(y, y+2)):
					if (i == x and j == y):
						continue
					if (i < 0 or i > 7 or j < 0 or j > 7):
						continue
					if (state.board[j][i].name != null) and (i == x or j == y): # only capture diag
						continue
					out.append([i,j])
					
		return out

class King extends Piece:
	var has_banana = true
	func _init():
		name = "king"
	func getPositions(_state):
		var out = []
		for i in range(x-1,x+2):
			for j in (range(y-1,y+2)):
				if (i == x and j == y):
					continue
				if (i < 0 or i > 7 or j < 0 or j > 7):
					continue
				out.append([i,j])
		return out
	
	func capture(state):
		kingQueenCapture(state)
	
	func removeBanana():
		object.get_node("Banana").free()
		has_banana = false

	func spawnPiece(_position):
		.spawnPiece(_position)
		var banana = Sprite.new()
		banana.name = "Banana"
		banana.texture = load("res://misc/banana.png")
		banana.position = Vector2(-3,-17)
		object.add_child(banana)

class Queen extends Piece:
	func _init():
		name = "queen"
	func getPositions(state):
		var out = []
		var max_x = 7
		var min_x = 0
		var max_y = 7
		var min_y = 0
		var max_positive_diag = 7
		var min_positive_diag = 0
		var max_negative_diag = 7
		var min_negative_diag = 0
		for i in range(8):
			# horizontal
			if i <= max_x and i >= min_x and i!=x:
				out.append([i,y])
				if state.board[y][i].name != null:
					if i<x:
						min_x = i
						for j in range(i):
							var idx = out.find([j, y]) #find the index
							if idx>=0:
								out.remove(idx) #remove
					else:
						max_x = i
			
			# vertical
			if i <= max_y and i >= min_y and i!=y:
				out.append([x,i])
				if state.board[i][x].name != null:
					if i<y:
						min_y = i
						for j in range(i):
							var idx = out.find([x, j]) #find the index
							if idx>=0:
								out.remove(idx) #remove
					else:
						max_y = i
			
			# positive diag
			if i <= max_positive_diag and i >= min_positive_diag and y != i and x-y+i >= 0 and x-y+i <= 7:
				out.append([x-y+i,i])
				if state.board[i][x-y+i].name != null:
					if i<y:
						min_positive_diag = i
						for j in range(i):
							var idx = out.find([x-y+j, j]) #find the index
							if idx>=0:
								out.remove(idx) #remove
					else:
						max_positive_diag = i
			
			# negative diag
			if i <= max_negative_diag and i >= min_negative_diag and y != i and x+y-i >= 0 and x+y-i <= 7:
				out.append([x+y-i,i])
				if state.board[i][x+y-i].name != null:
					if i<y:
						min_negative_diag = i
						for j in range(i):
							var idx = out.find([x+y-j, j]) #find the index
							if idx>=0:
								out.remove(idx) #remove
					else:
						max_negative_diag = i

		return out

	func capture(state):
		kingQueenCapture(state)

class Monkey extends Piece:
	func _init():
		name = "monkey"

	func resetExplored():
		explored = []
		for i in range(8):
			explored.append([])
			for _j in range(8):
				explored[i].append(false)

	var explored = []
	func moveRecurse(board, x, y):
		explored[y][x] = true
		var near = []
		for i in range(x-1,x+2):
			for j in (range(y-1,y+2)):
				if (i == x and j == y):
					continue
				if (i < 0 or i > 7 or j < 0 or j > 7):
					continue
				if (board[j][i].name != null):
					near.append([i,j])
		if len(near) == 0:
			return [[x,y]]
				
		var positions = []
		for item in near:
			var deltaX = (item[0] - x)*2
			var deltaY = (item[1] - y)*2
			var posX = deltaX+x
			var posY = deltaY+y
			if posX < 0 or posY < 0 or posX > 7 or posY > 7:
				continue
			positions.append([posX, posY])
		
		var out = [[x,y]]
		for item in positions:
			if explored[item[1]][item[0]]:
				continue
			if board[item[1]][item[0]].name != null:
				out += [item]
				continue
			out += moveRecurse(board, item[0], item[1])
		return out

	func bananaCatch(state):
		var selectedJail = state.jail[0 if color == "white" else 1]
		var king = selectedJail[0]
		selectedJail[0] = null
		king.setPos(x,y)
		state.board[y][x] = king
		king.object.position = convertPos(x, y)
		king.removeBanana()

		resetExplored()
		var options = moveRecurse(state.board, x, y)
		for opt in options:
			if state.board[opt[1]][opt[0]].color != color:
				setPos(opt[0], opt[1])
				state.board[opt[1]][opt[0]].capture(state)
				state.board[opt[1]][opt[0]] = self
				object.position = convertPos(opt[0], opt[1])
				break
		
		emit_signal("flip_turn")


	func getPositions(state):
		var alone = true
		for i in range(x-1,x+2):
			for j in (range(y-1,y+2)):
				if (i == x and j == y):
					continue
				if (i < 0 or i > 7 or j < 0 or j > 7):
					continue
				if (state.board[j][i].name != null):
					alone = false
					break
			if not alone:
				break

		var k = King.new()
		k.setPos(x,y)
		var out = k.getPositions(state)
		if alone:
			return out

		resetExplored()
		
		out += moveRecurse(state.board, x, y)
		var idx = out.find([x,y])
		out.remove(idx)
		return out

class Rook extends Piece:
	func _init():
		name = "rook"
	func getPositions(state):
		var out = []
		for i in range(8):
			for j in range(8):
				if state.board[j][i].name == null:
					out.append([i,j])
				elif state.last_capture_color == color and [abs(i-x),abs(j-y)] in [[0,1],[1,0]]: # if the crow isn't hungry and it is in one of the four directions
					out.append([i,j])
		return out

class Bear extends Piece:
	var centered = true
	func _init():
		name = "bear"
		color = "misc"
		setPos(-2,-2) # -2 will symbolize bear

	
	func centeredPlayMove(state, _x, _y):
		state.board[_y][_x] = self
		object.centered_bear = false
		setPos(_x,_y)
		object.position = convertPos(_x, _y)

		emit_signal("flip_turn")

	func setPos(_x, _y):
		x = _x
		y = _y
		if object:
			object.x = _x
			object.y = _y
		
		return false # never capture if there is a piece there (only makes a difference in the first turn)

	func getPositions(state):
		var out = []
		if centered:
			for i in range(3,5):
				for j in range(3,5):
					if state.board[j][i].name == null:
						out.append([i,j])
			centered = false
			return out
	
		for i in range(x-1,x+2):
			for j in (range(y-1,y+2)):
				if (i == x and j == y):
					continue
				if (i < 0 or i > 7 or j < 0 or j > 7):
					continue
				if (state.board[j][i].name != null):
					continue
				out.append([i,j])
		return out
	
	func spawnPiece(_position):
		object = piece_resource.instance()
		object.texture = load("res://"+color+"/"+name+".png")
		object.position = _position
		object.x = x
		object.y = y
		object.centered_bear = true

var board = [
	[Rook.new(), Monkey.new(), Fish.new(), Queen.new(), King.new(), Fish.new(), Monkey.new(), Rook.new(),],
	[Fish.new(), Fish.new(), Elephant.new(), Fish.new(), Fish.new(), Elephant.new(), Fish.new(), Fish.new(),],
	[Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(),],
	[Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(),],
	[Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(),],
	[Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(), Piece.new(),],
	[Fish.new(), Fish.new(), Elephant.new(), Fish.new(), Fish.new(), Elephant.new(), Fish.new(), Fish.new(),],
	[Rook.new(), Monkey.new(), Fish.new(), Queen.new(), King.new(), Fish.new(), Monkey.new(), Rook.new(),],
]

var board_vis = []

var jail = [
	[null, null], # left
	[null, null], # right
]
var startingBear = Bear.new()

var turn = "white"

func get_state():
	return {
		"board": board,
		"startingBear": startingBear,
		"turn": turn,
		"last_capture_color": last_capture_color,
		"move_number": move_number,
		"jail": jail,
		"board_vis": board_vis,
	}

func convertPos(x, y):
	var out = Vector2(x,y)
	out *= 58
	out -= Vector2(203,203)
	return out


func resetVis():
	for row in board_vis:
		for piece in row:
			var anim_player = piece.get_node("Rect/AnimationPlayer")
			anim_player.stop(false)
			anim_player.play("hide_pos")

func flip_turn():
	turn = "white" if turn == "black" else "black"
	move_number += 1
	emit_signal("turn_change", turn)


# Called when the node enters the scene tree for the first time.
func _ready():
	# connect to both kings and both queens
	for y in [0, 7]:
		for x in [3, 4]:
			board[y][x].connect("game_end", self, "game_end")

	# initialize and connect to the the centered bear
	startingBear.spawnPiece(Vector2(0,0))
	add_child(startingBear.object)
	startingBear.connect("flip_turn", self, "flip_turn")
	
	# initialize all pieces
	for row in range(8):
		board_vis.append([])
		for item in range(8):
			# visualize possible moves board
			var object = piece_vis_resource.instance()
			object.position = convertPos(item, row)
			board_vis[row].append(object)
			object.visible = false
			add_child(object)

			# actual board
			if board[row][item].name != null:
				board[row][item].color = "black" if (row < 4) else "white"
			board[row][item].setPos(item, row)
			board[row][item].spawnPiece(convertPos(item, row))
			if board[row][item].object != null: # if there is a piece there
				# connect to monkeys
				if board[row][item].name == "monkey":
					board[row][item].connect("flip_turn", self, "flip_turn")
				
				add_child(board[row][item].object)
		

func playMove(x1,y1, x2,y2):
	last_capture_color = board[y2][x2].color
	if board[y1][x1].setPos(x2, y2):
		board[y2][x2].capture(get_state())
	
	# update board
	board[y2][x2] = board[y1][x1]
	board[y1][x1] = Piece.new()
	
	board[y2][x2].object.position = convertPos(x2, y2) # move the sprite into position
	
	flip_turn()


var last_move_number = 0
var last = false
func checkBananaCatch(color):
	if move_number == last_move_number: # only calc once per turn as otherwise it's a waste
		return last
	last_move_number = move_number
	
	var selectedJail = jail[0 if color == "white" else 1]
	var selectedSide = (0 if color == "white" else 7)
	if (selectedJail[0] == null):
		return false
	if (selectedJail[0].name == "king" and # if the king is in the jail
			board[3][selectedSide].name == "monkey" and # and the monkey is near
			selectedJail[0].has_banana): # and the king has a banana
		
		board[3][selectedSide].resetExplored()
		var options = board[3][selectedSide].moveRecurse(board, selectedSide, 3)
		for opt in options:
			if board[opt[1]][opt[0]].color != color:
				last = true
				return true
	last = false
	return false


# Drag and Drop code (code format changed to what they had)

# Based on JuanCarlos "Juanky" Aguilera
# Based on Github Repo: https://github.com/JCAguilera/godot3-drag-and-drop


func invertConvertPos(position):
	position += Vector2(232,232)
	position /= 58
	return [int(position.x), int(position.y)]

var sprites = []
var top_sprite = null

func _input(_event):
	if Input.is_action_just_pressed("left_click"): #When we click
		top_sprite = weakref(_top_sprite()) #Get the sprite on top (largest z_index)
		if top_sprite.get_ref(): #If there's a sprite
			top_sprite.get_ref().dragging = true #We set dragging to true
			top_sprite.get_ref().z_index = 100 #We set the z_index to the highest
	if Input.is_action_just_released("left_click"): #When we release
		if top_sprite && top_sprite.get_ref():
			if top_sprite.get_ref().get("snap_pos") != null:
				var position = invertConvertPos(top_sprite.get_ref().get("snap_pos"))
				
				if top_sprite.get_ref().centered_bear:
					startingBear.centeredPlayMove(get_state(), position[0], position[1])
				elif (position[0] < 0 or position[0] > 7) and board[top_sprite.get_ref().get("y")][top_sprite.get_ref().get("x")].name == "monkey" and checkBananaCatch(turn):
					board[top_sprite.get_ref().get("y")][top_sprite.get_ref().get("x")].bananaCatch(get_state())
				elif position in board[top_sprite.get_ref().get("y")][top_sprite.get_ref().get("x")].getPositionsOnce(get_state()):
					playMove(top_sprite.get_ref().get("x"), top_sprite.get_ref().get("y"), position[0], position[1])
				else: # reset position
					board[top_sprite.get_ref().get("y")][top_sprite.get_ref().get("x")].object.position = convertPos(top_sprite.get_ref().get("x"),top_sprite.get_ref().get("y"))
			if top_sprite.get_ref(): # if not freed
				top_sprite.get_ref().dragging = false #Set dragging to false
				top_sprite.get_ref().z_index = 0 #Set the z_index back
				top_sprite = null #Top sprite to null
		resetVis()

func snapPosition(position, x, y):
	var piece
	if x==-2: # bear
		piece = startingBear
	else:
		piece = board[y][x]
	var out = invertConvertPos(position)
	if (out[0] < 0 or out[0] > 7) and checkBananaCatch(turn):
		return Vector2(295 if turn == "black" else -295, -29)
	if out in piece.getPositionsOnce(get_state()):
		return convertPos(out[0], out[1])
	
	if piece.getPositionsOnce(get_state()) == []:
		return null # no possible moves so don't allow motion
	return convertPos(x, y) #don't move

class SpritesSorter: #Custom sorter
	static func z_index(a, b): #Sort by z_index
		if a.z_index > b.z_index:
			return true
		return false

func _add_sprite(sprt): #Add sprite to list
	if not sprites.find(sprt) == -1: #If sprite exists
		return #Do nothing
	sprites.append(sprt) #Add sprite to list

func _remove_sprite(sprt): #Remove sprite from list
	var idx = sprites.find(sprt) #find the index
	if idx>=0:
		sprites.remove(idx) #remove

func _top_sprite(): #Get the top sprite
	if len(sprites) == 0: #If the list is empty
		return null
	sprites.sort_custom(SpritesSorter, "z_index") #Sort by z_index
	return sprites[0] #Return top sprite
