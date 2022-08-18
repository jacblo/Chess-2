extends Node2D

func _on_BoardController_game_over(color):
	$AnimationPlayer.play("fade_in_end_screen")
	$Text.bbcode_text = "[center]" + color.capitalize() + " has won!" + "[/center]"

func _on_Button_pressed():
	if get_tree().reload_current_scene() != OK:
		push_error("Failed to reload the scene")
	get_tree().paused = false
