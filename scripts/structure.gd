class_name Structure
extends StaticBody3D

@export var max_health = 50
var current_health
var is_built = false
@onready var hp_label = $HPLabel
var flash_scene = preload("res://scenes/effects/teleport_flash.tscn")
var audio_started = false

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
	var duration = 4.0 # Faster build for testing? Or typically 10.0
	
	# Add AudioPlayer3D dynamically
	var sfx = AudioStreamPlayer3D.new()
	sfx.stream = load("res://sounds/scifi-anime-whoosh-24-201456.mp3")
	sfx.unit_size = 20.0
	sfx.max_distance = 100.0
	add_child(sfx)
	
	tween.tween_method(func(val): 
		for mesh in meshes:
			if mesh.material_override:
				mesh.material_override.set_shader_parameter("progress", val)
		
		# Play audio near end (whoosh)
		if val > 0.7 and not audio_started:
			audio_started = true
			sfx.play()
			
	, 0.0, 1.0, duration)
	
	tween.tween_callback(func():
		is_built = true
		for mesh in meshes:
			mesh.material_override = null
		
		# Spawn Flash Particles
		if flash_scene:
			var flash = flash_scene.instantiate()
			add_child(flash)
			flash.emitting = true
			
		print(name, " construction complete!")
		sfx.queue_free() # Clean up audio after it's done (actually wait for finish?) 
		# Better to let it finish or keep it if reusable. 
		# For oneshot whoosh, just queue_free after some time.
		get_tree().create_timer(2.0).timeout.connect(sfx.queue_free)
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
