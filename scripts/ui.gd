extends Control

@onready var build_menu = $BuildMenu
@onready var label_1 = $BuildMenu/HBoxContainer/Label1
@onready var label_2 = $BuildMenu/HBoxContainer/Label2
@onready var label_3 = $BuildMenu/HBoxContainer/Label3

func _process(delta):
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("is_build_mode"):
		build_menu.visible = true
		var idx = player.get("current_structure_index")
		
		# Reset colors
		label_1.modulate = Color(1, 1, 1, 0.5)
		label_2.modulate = Color(1, 1, 1, 0.5)
		label_3.modulate = Color(1, 1, 1, 0.5)
		
		# Highlight selected
		if idx == 0: label_1.modulate = Color(0, 1, 0, 1)    # Green for Basic
		if idx == 1: label_2.modulate = Color(0, 0.5, 1, 1)  # Blue for Missile
		if idx == 2: label_3.modulate = Color(1, 1, 0, 1)    # Yellow for Laser
	else:
		build_menu.visible = false
