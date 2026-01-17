extends "res://scripts/structure.gd"

# Power Plant Logic
# Turrets look for nodes in "power_sources" group.

func _ready():
	add_to_group("power_sources")
	super._ready()
