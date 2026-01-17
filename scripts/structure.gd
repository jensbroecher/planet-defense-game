class_name Structure
extends StaticBody3D

@export var max_health = 100
var current_health

func _ready():
	add_to_group("structures")
	current_health = max_health

func take_damage(amount):
	current_health -= amount
	if current_health <= 0:
		die()

func die():
	queue_free()
