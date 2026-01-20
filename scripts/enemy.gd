extends CharacterBody3D

enum State { APPROACHING, ATTACKING }
enum AttackType { LIGHT, STANDARD, HEAVY, BEAM }

@export var attack_type : AttackType = AttackType.STANDARD
@export var move_speed = 10.0
@export var attack_range = 60.0 # Stopping distance from planet center (Planet rad is 40)
@export var fire_rate = 2.0
@export var projectile_scene : PackedScene

# Attack Stats Configuration
var attack_data = {
	AttackType.LIGHT: {
		"damage": 5,
		"sound": preload("res://sounds/enemy/laser-bolt-89300.mp3"),
		"pitch": 1.0
	},
	AttackType.STANDARD: {
		"damage": 10,
		"sound": preload("res://sounds/enemy/sci-fi-weapon-laser-shot-04-316416.mp3"),
		"pitch": 1.0
	},
	AttackType.HEAVY: {
		"damage": 25,
		"sound": preload("res://sounds/enemy/scifi-laser-gun-shot-3-341613.mp3"),
		"pitch": 1.0
	},
	AttackType.BEAM: {
		"damage": 5,
		"sound": preload("res://sounds/enemy/beam-8-43831.mp3"),
		"pitch": 1.0
	}
}

var current_state = State.APPROACHING
var planet_center = Vector3.ZERO
var attack_timer = 0.0
var target = null

@export var max_health = 30
var current_health

# Audio
var audio_player : AudioStreamPlayer3D

# Randomization
var orbit_direction = 1.0 # 1 or -1
var orbit_seed = 0.0

func _ready():
	add_to_group("enemies")
	# projectile_scene is now set via Inspector/Export
	current_health = max_health
	
	# Randomize
	orbit_direction = 1.0 if randf() > 0.5 else -1.0
	orbit_seed = randf() * 100.0
	
	# Randomize initial attack delay so they don't all fire at once
	attack_timer = randf_range(0.0, fire_rate * 2.0)
	
	# Optional: Slight variance in move speed or fire rate per unit
	fire_rate = fire_rate * randf_range(0.8, 1.25)
	move_speed = move_speed * randf_range(0.9, 1.1)

	# Setup Audio
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	audio_player.unit_size = 15.0 # Hear from distance
	audio_player.max_db = 0.0

func take_damage(amount):
	current_health -= amount
	if current_health <= 0:
		die()

@export var explosion_scene_path = "res://scenes/effects/enemy_explosion.tscn"

func die():
	GameManager.add_credits(10)
	
	# Spawn explosion
	if explosion_scene_path:
		var scene = load(explosion_scene_path)
		if scene:
			var expl = scene.instantiate()
			get_parent().add_child(expl)
			expl.global_position = global_position
	
	queue_free()

func _physics_process(delta):
	# Find target if none
	if target == null or not is_instance_valid(target):
		find_target()
	
	# Always attack if cooldown ready (and has target)
	attack_timer -= delta
	if attack_timer <= 0:
		attack_timer = fire_rate
		shoot_projectile()
		
	# Movement Logic
	var desired_velocity = Vector3.ZERO
	
	if target and is_instance_valid(target):
		# Move towards target but maintain distance (attack_range)
		var dist = global_position.distance_to(target.global_position)
		var dir_to_target = (target.global_position - global_position).normalized()
		
		# Define desired velocity based on range
		# Wobble the desired range slightly
		var time = Time.get_ticks_msec() / 1000.0
		var current_desired_range = attack_range + sin(time + orbit_seed) * 10.0
		
		# Hysteresis / dead zone to prevent jitter
		if dist > current_desired_range + 5.0:
			# Too far, move closer
			desired_velocity = dir_to_target * move_speed
		elif dist < current_desired_range - 5.0:
			# Too close, back up or orbit tightly (push away from target)
			# Ideally we want to orbit but maybe backing up is better to maintain range
			desired_velocity = -dir_to_target * (move_speed * 0.5)
		else:
			# In ideal range (+/- 5 units), circle/strafe around target
			# Vector from planet center to us (Up)
			var up_vec = (global_position - planet_center).normalized()
			
			# Cross product of Direction To Target and UpVec gives a sideways vector
			# This creates an orbit/circle path
			# Multiply by randomized orbit_direction
			var orbit_vec = dir_to_target.cross(up_vec).normalized() * orbit_direction
			
			desired_velocity = orbit_vec * (move_speed * 0.8) # Slightly slower when orbiting
	else:
		# No target, just move towards planet center but stop at range
		var dist = global_position.distance_to(planet_center)
		if dist > attack_range:
			desired_velocity = (planet_center - global_position).normalized() * move_speed
		else:
			desired_velocity = Vector3.ZERO
	
	# Apply Steering / Acceleration
	var steering_speed = 2.0 # Adjust for turn rate
	velocity = velocity.lerp(desired_velocity, delta * steering_speed)
	
	# Rotation: Look where we are going
	if velocity.length_squared() > 1.0:
		# smooth look_at
		var target_look = global_position + velocity * 2.0
		# We need to use valid up vector to avoid flipping when looking straight up/down relative to world Y
		# But since we are in space/planet, maybe just standard look_at is mostly fine if we don't cross poles perfectly
		# Better: just look_at. 
		# If it jitters, we can lerp the basis, but let's try direct look_at fitst.
		look_at(target_look)
	
	move_and_slide()

func find_target():
	# Find nearest structure or player
	var structures = get_tree().get_nodes_in_group("structures")
	var player = get_tree().get_first_node_in_group("player")
	
	var candidates = []
	if player: candidates.append(player)
	candidates.append_array(structures)
	
	var nearest = null
	var min_dist = INF
	
	for c in candidates:
		if not has_line_of_sight(c):
			continue
			
		var d = global_position.distance_to(c.global_position)
		if d < min_dist:
			min_dist = d
			nearest = c
			
	target = nearest

func has_line_of_sight(target_node):
	var space_state = get_world_3d().direct_space_state
	
	# Raise target point slightly above surface to avoid clipping planet geometry
	# Target is likely on surface, ray might hit ground immediately if targeting base.
	var target_up = (target_node.global_position - planet_center).normalized()
	var target_pos = target_node.global_position + target_up * 3.0
	
	# Ray from us to target center
	var query = PhysicsRayQueryParameters3D.create(global_position, target_pos)
	query.collision_mask = 1 # Check Planet (Layer 1) blockage
	query.exclude = [self] # Don't hit ourselves
	
	var result = space_state.intersect_ray(query)
	if result:
		# If we hit something, it's blocking view (Planet)
		# Unless it's the target itself (unlikely if mask is only 1 and target is typically on another layer or a sub-collider)
		# NOTE: If structures are also on Layer 1, this might return the structure itself, which is fine (visible).
		if result.collider == target_node:
			return true
		return false # Blocked by planet
	
	return true # Clear path

func shoot_projectile():
	if target and not has_line_of_sight(target):
		return # Don't shoot if blocked
		
	if projectile_scene:
		# Get stats for current attack type
		var stats = attack_data.get(attack_type, attack_data[AttackType.STANDARD])
		
		# Play Sound
		if stats.sound:
			audio_player.stream = stats.sound
			audio_player.pitch_scale = stats.get("pitch", 1.0)
			audio_player.play()
		
		# Spawn Projectile logic
		var proj = projectile_scene.instantiate()
		get_parent().add_child(proj)
		
		# Initial position at enemy center
		proj.global_position = global_position
		
		# Configure Projectile damage
		if "damage" in proj:
			proj.damage = stats.damage
		
		# Aim at target
		if target and is_instance_valid(target):
			proj.look_at(target.global_position)
		else:
			proj.look_at(global_position - global_transform.basis.z * 10.0)
			
		# Move projectile forward to clear enemy collision
		# Assuming Enemy is roughly 1-2 units radius
		proj.global_position -= proj.global_transform.basis.z * 3.0
		
		# Add Spread (reduce accuracy)
		var spread_angle = deg_to_rad(5.0) # 5 degrees spread
		proj.rotate_object_local(Vector3.UP, randf_range(-spread_angle, spread_angle))
		proj.rotate_object_local(Vector3.RIGHT, randf_range(-spread_angle, spread_angle))
