extends RichTextLabel


func _on_BoardController_turn_change(color):
	bbcode_text = "[center]"+color.capitalize()+"'s turn[/center]"
