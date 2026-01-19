class_name Structure
extends StaticBody3D

@export var max_health = 50
var current_health
var is_built = false
@onready var hp_label = $HPLabel

func _ready():
	add_to_group("structures")
	current_health = max_health
	update_hp_label()
	start_teleport()

func start_teleport():
	is_built = false
	# Apply shader to all MeshInstances
	var meshes = find_children("*", "MeshInstance3D", true)
	for mesh in meshes:
		mesh.set_meta("original_material", mesh.material_override)
		mesh.material_override = load("res://scenes/effects/teleport_material.tres").duplicate()
	
	# Tween the progress
	var tween = create_tween()
	tween.tween_method(func(val): 
		for mesh in meshes:
			if mesh.material_override:
				mesh.material_override.set_shader_parameter("progress", val)
	, 0.0, 1.0, 10.0)
	
	tween.tween_callback(func():
		is_built = true
		for mesh in meshes:
			# Restore original or just remove override (assuming override was null initially or we handle it)
			# If we want to restore specifically what was there, we might need to be more careful.
			# But usually stripping the override reveals the mesh's own material.
			mesh.material_override = null
		print(name, " construction complete!")
	)

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
