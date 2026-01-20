extends Control

func _ready():
	# Wait 2 seconds then go to main menu
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
