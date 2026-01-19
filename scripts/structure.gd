class_name Structure
extends StaticBody3D

@export var max_health = 50
var current_health
@onready var hp_label = $HPLabel

func _ready():
	add_to_group("structures")
	current_health = max_health
	update_hp_label()

func take_damage(amount):
	current_health -= amount
	print(name, " took ", amount, " damage. Remaining: ", current_health)
	update_hp_label()
	
	# Trigger Base Attack Alert (Global cooldown managed by GM)
	# MOVED TO HQ ONLY
	# GameManager.play_base_attack_alert()
	
	if current_health <= 0:
		die()

func update_hp_label():
	if hp_label:
		hp_label.text = str(int(current_health))

@export var explosion_scene_path = "res://scenes/effects/explosion.tscn"

func die():
	var expl_scene = load(explosion_scene_path)
	if expl_scene:
		var effect = expl_scene.instantiate()
		get_parent().add_child(effect)
		effect.global_position = global_position
		# Effect handles itself (particles/audio in _ready)
		pass
			
	queue_free()
