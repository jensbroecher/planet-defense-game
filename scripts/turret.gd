extends Structure

@export var fire_rate = 1.0
@export var range = 250.0
@export var projectile_scene : PackedScene
@export var max_burst_time = 0.0 # 0 = Infinite
@export var overheat_cooldown = 3.0

var current_burst_time = 0.0
var is_overheated = false
var overheat_timer = 0.0

@onready var head = $Head
@onready var muzzle = $Head/Muzzle
var gun : Node3D = null

var fire_timer = 0.0
var target : Node3D = null

func _ready():
	super._ready() # specific to GdScript 2.0 / Godot 4
	if not projectile_scene:
		projectile_scene = load("res://scenes/projectile_player.tscn")
	
	# Try to find a child named "Gun" under Head, or check if Muzzle is child of something else
	if head.has_node("Gun"):
		gun = head.get_node("Gun")
		# If muzzle is child of Gun, update reference (though it might already be correct if path matches)
		if gun.has_node("Muzzle"):
			muzzle = gun.get_node("Muzzle")
	
	# Fallback if muzzle isn't set correctly by onready (e.g. if path changed)
	if not muzzle:
		# Search recursively or check standard paths
		if head.has_node("Muzzle"):
			muzzle = head.get_node("Muzzle")

func _process(delta):
	fire_timer -= delta
	
	# Check Power
	if not check_power() or not is_built:
		return # No power or not fully built, idle

	if target == null or not is_instance_valid(target):
		find_target()
	
	if target:
		# Overheat Logic
		if is_overheated:
			overheat_timer -= delta
			if overheat_timer <= 0:
				is_overheated = false
				current_burst_time = 0.0
				print(name, " cooled down!")
			return # Cannot fire while overheating
			
		var dist = global_position.distance_to(target.global_position)
		if dist > range or not check_line_of_sight(target):
			target = null
			current_burst_time = 0.0 # Reset burst if we lost target
			return

		# Aim
		if gun:
			# Advanced logic: Head rotates Y (yaw), Gun rotates X (pitch)
			
			# 1. Rotate Head (Yaw)
			# Project target onto the plane defined by the turret's vertical axis (Y)
			# to ensure the head rotates ONLY horizontally (Yaw) relative to the turret base.
			
			var head_pos = head.global_position
			var turret_up = global_transform.basis.y
			var to_target = target.global_position - head_pos
			
			# Flatten target vector onto the turret's horizontal plane
			# V_flat = V - (V dot N) * N
			var dist_y = to_target.dot(turret_up)
			var target_flat = target.global_position - (turret_up * dist_y)
			
			# Calculate local target position relative to Head's parent (Turret Base)
			# This is robust because Head rotates around Parent's Y axis.
			var target_local = head.get_parent().to_local(target_flat)
			
			# Calculate desired yaw angle
			# In Godot -Z is forward. atan2(-x, -z) gives the angle to face the point.
			var desired_yaw = atan2(-target_local.x, -target_local.z)
			
			# Apply smoothed rotation
			head.rotation.y = lerp_angle(head.rotation.y, desired_yaw, delta * 5.0)
			
			# 2. Rotate Gun (Pitch)
			# Find target in Gun's local space
			var target_local_gun = gun.to_local(target.global_position)
			
			# Calculate pitch
			# We want +Rotation.X to pitch DOWN (Right Hand Rule).
			# If target is BELOW (y < 0), we want Positive Pitch.
			# atan2(-y, -z) gives positive angle when y is negative.
			# UPDATE: User says pitch was inverted. Trying standard atan2(y, -z).
			var pitch = atan2(target_local_gun.y, -target_local_gun.z)
			
			# Apply smoothed rotation
			gun.rotation.x = lerp_angle(gun.rotation.x, pitch, delta * 5.0)
			
			# Clamp pitch to limited range (-30 to 30 degrees)
			gun.rotation.x = clamp(gun.rotation.x, deg_to_rad(-30), deg_to_rad(30))
			
		else:
			# Simple logic: Head looks directly at target (Yaw + Pitch)
			# Used for laser turret or others without a separate Gun
			head.look_at(target.global_position, global_transform.basis.y)
		
		if fire_timer <= 0:
			shoot()
			fire_timer = fire_rate
			
			# Increment Burst
			if max_burst_time > 0:
				current_burst_time += fire_rate # Add time per shot? Or just use delta in process?
				# Using fire_rate is better for discrete shots, but delta is better for continuous.
				# Let's use delta in the main loop instead? 
				# Actually, we are in process(delta), let's just add delta while valid target.
				pass
		
		# Track Burst Time continuously while targeting/firing
		if max_burst_time > 0:
			current_burst_time += delta
			if current_burst_time >= max_burst_time:
				is_overheated = true
				overheat_timer = overheat_cooldown
				print(name, " OVERHEATED!")
				# Optional: Play overheat sound

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
	query.collision_mask = 9 # Check collision with Planet (Layer 1) and Structures (Layer 4)
	query.exclude = [self.get_rid()]
	
	var result = space_state.intersect_ray(query)
	if result:
		if result.collider == target_node:
			return true # Hit the target (unlikely if target is not Layer 1 or 4, but good for safety)
		return false # Blocked by something else
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
		
		# Pass Target to Missile (Heat Seeking)
		if "target_body" in proj:
			proj.target_body = target
		
		# Recoil Animation
		if gun and gun.has_node("GunMesh"):
			var mesh = gun.get_node("GunMesh")
			var tween = create_tween()
			# Recoil backward (local Z)
			# Gun is scale 4. Mesh is scale -0.4.
			# Let's just move the Gun node itself? No, Gun rotates.
			# Moving Mesh visual is safer.
			# GunMesh local Z+ is "Forward" relative to Gun because of 180 rotation?
			# Gun: -Z is Forward. GunMesh: Rotated 180 around Y.
			# So GunMesh local +Z is Gun -Z (Forward).
			# We want to move GunMesh "Backward" (Gun +Z).
			# So we move GunMesh local -Z?
			# Let's try moving GunMesh.position.z
			# Recoil back: 0.05 (Reduced from 0.15 per user request)
			tween.tween_property(mesh, "position:z", 0.05, 0.05)
			tween.tween_property(mesh, "position:z", 0.0, 0.2)
			
		# Muzzle Flash
		if head.has_node("MuzzleFlash"):
			var flash = head.get_node("MuzzleFlash")
			flash.visible = true
			# Rotate randomly?
			flash.rotation.z = randf_range(0, TAU)
			var timer = get_tree().create_timer(0.05)
			timer.timeout.connect(func(): if is_instance_valid(flash): flash.visible = false)
		
		# Play audio if exists
		if has_node("AudioStreamPlayer3D"):
			$AudioStreamPlayer3D.play()
