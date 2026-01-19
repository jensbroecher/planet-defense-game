extends Structure

@export var fire_rate = 1.0
@export var range = 50.0
@export var projectile_scene : PackedScene

@onready var head = $Head
@onready var muzzle = $Head/Muzzle

var fire_timer = 0.0
var target : Node3D = null

func _ready():
	super._ready() # specific to GdScript 2.0 / Godot 4
	if not projectile_scene:
		projectile_scene = load("res://scenes/projectile_player.tscn")

func _process(delta):
	fire_timer -= delta
	
	# Check Power
	if not check_power() or not is_built:
		return # No power or not fully built, idle

	if target == null or not is_instance_valid(target):
		find_target()
	
	if target:
		var dist = global_position.distance_to(target.global_position)
		if dist > range or not check_line_of_sight(target):
			target = null
			return

		# Aim Head
		# Simple LookAt logic for now. 
		# We need to look at target but keep "up" aligned with structure "up" (planet normal)
		# Actually, head is child of structure, so its local Y is already aligned with structure Y if structure is aligned.
		# But look_at in global space is easiest.
		
		# We want the head to rotate around local Y only (aim azimuth) and maybe local X (pitch)?
		# For simple box turret, just looking at is fine.
		head.look_at(target.global_position, global_transform.basis.y)
		
		if fire_timer <= 0:
			shoot()
			fire_timer = fire_rate

func check_power():
	var sources = get_tree().get_nodes_in_group("power_sources")
	for s in sources:
		# Check if source is built (if it has that property)
		if "is_built" in s and not s.is_built:
			continue
			
		if global_position.distance_to(s.global_position) <= 50.0:
			return true
	return false

func check_line_of_sight(target_node):
	var space_state = get_world_3d().direct_space_state
	var origin = muzzle.global_position
	var end = target_node.global_position
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 1 # Check collision with Planet (Layer 1) only
	
	var result = space_state.intersect_ray(query)
	if result:
		return false # Blocked by planet
	return true

func find_target():
	# Find nearest enemy in group "enemies"
	# We need to add enemies to group "enemies"
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest = null
	var min_dist = range
	
	for e in enemies:
		var d = global_position.distance_to(e.global_position)
		if d < min_dist:
			min_dist = d
			nearest = e
			
	target = nearest

func shoot():
	if projectile_scene:
		var proj = projectile_scene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = muzzle.global_position
		proj.look_at(target.global_position)
		
		# Play audio if exists
		if has_node("AudioStreamPlayer3D"):
			$AudioStreamPlayer3D.play()
