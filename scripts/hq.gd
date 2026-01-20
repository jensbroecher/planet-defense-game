extends "res://scripts/structure.gd"

# Healing Logic
var healing_rate = 10.0 # HP per second (For Player)
@export var self_heal_rate = 5.0 # HP per second (For Self)
var player_in_range = null

func _ready():
	super._ready()
	GameManager.register_hq()

func _exit_tree():
	GameManager.unregister_hq()

func take_damage(amount):
	super.take_damage(amount)
	# Only HQ triggers this alert now
	GameManager.play_base_attack_alert()

func _process(delta):
	if not is_built:
		return
		
	# Self Regeneration
	if current_health < max_health:
		current_health += self_heal_rate * delta
		if current_health > max_health:
			current_health = max_health
		update_hp_label()

	if player_in_range and is_instance_valid(player_in_range):
		# Heal player
		if player_in_range.current_health < player_in_range.max_health:
			player_in_range.current_health += healing_rate * delta
			if player_in_range.current_health > player_in_range.max_health:
				player_in_range.current_health = player_in_range.max_health
			
			# Update player label visual (we need to access method)
			if player_in_range.has_method("update_hp_label"):
				player_in_range.update_hp_label()

func _on_healing_zone_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = body
		# Only play voice if actually damaged
		if body.current_health < body.max_health:
			GameManager.play_voice("repairing")
		print("Player entered healing zone")

func _on_healing_zone_body_exited(body):
	if body == player_in_range:
		player_in_range = null
		print("Player left healing zone")
