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

func _ready():
	add_to_group("enemies")
	projectile_scene = load("res://scenes/projectile.tscn")
	current_health = max_health
	
	# Setup Audio
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	audio_player.unit_size = 15.0 # Hear from distance
	audio_player.max_db = 0.0

func take_damage(amount):
	current_health -= amount
	if current_health <= 0:
		die()

func die():
	GameManager.add_credits(10)
	queue_free()

func _physics_process(delta):
	match current_state:
		State.APPROACHING:
			var dist = global_position.distance_to(planet_center)
			if dist > attack_range:
				var dir = (planet_center - global_position).normalized()
				velocity = dir * move_speed
				move_and_slide()
				look_at(planet_center) # Look at planet
			else:
				current_state = State.ATTACKING
				
		State.ATTACKING:
			attack_timer -= delta
			if attack_timer <= 0:
				attack_timer = fire_rate
				shoot_projectile()
			
			if target == null or not is_instance_valid(target):
				find_target()
			
			if target:
				# Check LOS periodically
				if not has_line_of_sight(target):
					target = null
					current_state = State.APPROACHING
					return

				look_at(target.global_position)

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
