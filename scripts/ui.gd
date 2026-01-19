extends Control

@onready var build_menu = $BuildMenu
@onready var label_1 = $BuildMenu/HBoxContainer/Label1
@onready var label_2 = $BuildMenu/HBoxContainer/Label2
@onready var label_3 = $BuildMenu/HBoxContainer/Label3
@onready var label_4 = $BuildMenu/HBoxContainer/Label4
@onready var credits_label = $CreditsContainer/CreditsLabel
@onready var message_label = $MessageLabel
@onready var game_over_panel = $GameOverPanel
@onready var victory_panel = $VictoryPanel

func _ready():
	GameManager.connect("credits_changed", _on_credits_changed)
	GameManager.connect("notification_requested", _on_notification)
	GameManager.connect("game_over", _on_game_over)
	GameManager.connect("victory", _on_victory)
	
	update_credits(GameManager.credits)
	message_label.text = "" # Clear initial
	game_over_panel.visible = false
	victory_panel.visible = false

func _on_notification(text, duration):
	message_label.text = text
	message_label.modulate.a = 1.0
	message_label.visible = true
	
	# Simple Timer-based fade or Tween
	var tween = create_tween()
	tween.tween_interval(duration)
	tween.tween_property(message_label, "modulate:a", 0.0, 1.0) # Fade out over 1s
	tween.tween_callback(func(): message_label.text = "")

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

func _on_game_over():
	game_over_panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_victory():
	victory_panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_restart_button_pressed():
	GameManager.restart_game()
