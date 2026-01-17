extends Control

@onready var build_menu = $BuildMenu
@onready var label_1 = $BuildMenu/HBoxContainer/Label1
@onready var label_2 = $BuildMenu/HBoxContainer/Label2
@onready var label_3 = $BuildMenu/HBoxContainer/Label3
@onready var label_4 = $BuildMenu/HBoxContainer/Label4
@onready var credits_label = $CreditsContainer/CreditsLabel

func _ready():
	GameManager.connect("credits_changed", _on_credits_changed)
	update_credits(GameManager.credits)

func _on_credits_changed(amount):
	update_credits(amount)

func update_credits(amount):
	credits_label.text = "Credits: " + str(amount)

func _process(delta):
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("is_build_mode"):
		build_menu.visible = true
		var idx = player.get("current_structure_index")
		
		# Reset colors
		label_1.modulate = Color(1, 1, 1, 0.5)
		label_2.modulate = Color(1, 1, 1, 0.5)
		label_3.modulate = Color(1, 1, 1, 0.5)
		label_4.modulate = Color(1, 1, 1, 0.5)
		
		# Highlight selected
		if idx == 0: label_1.modulate = Color(0, 1, 0, 1)    # Green for Basic
		if idx == 1: label_2.modulate = Color(0, 0.5, 1, 1)  # Blue for Missile
		if idx == 2: label_3.modulate = Color(1, 1, 0, 1)    # Yellow for Laser
		if idx == 3: label_4.modulate = Color(0, 1, 1, 1)    # Cyan for Power
	else:
		build_menu.visible = false
