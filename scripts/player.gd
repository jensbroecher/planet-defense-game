extends CharacterBody3D

@export var move_speed = 8.0
@export var acceleration = 25.0
@export var jump_velocity = 8.0
@export var planet_center = Vector3.ZERO
@export var mouse_sensitivity = 0.003
@export var jump_buffer_time = 0.1
@export var coyote_time = 0.15

@onready var camera_rig = $CameraRig
@onready var spring_arm = $CameraRig/SpringArm3D
@onready var camera = $CameraRig/SpringArm3D/Camera3D
@onready var visual_mesh = $MeshInstance3D
@onready var engine_sound = $EngineSound

# Vertical angle limits
# Vertical angle limits
var min_pitch = -80.0
var max_pitch = 80.0
var min_zoom = 5.0
var max_zoom = 20.0
var zoom_speed = 1.0

# Health
@export var max_health = 100
var current_health
@onready var hp_label = $HPLabel

var is_dead = false
var explosion_scene = preload("res://scenes/effects/explosion.tscn")
var dust_trail_scene = preload("res://scenes/effects/dust_trail.tscn")
var dust_trail_node : GPUParticles3D = null
var dust_grace_timer = 0.0

var jump_buffer_timer = 0.0
var coyote_timer = 0.0

func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Set floor max angle to support walking on sphere (though gravity usually handles this)
	floor_max_angle = deg_to_rad(60.0)
	current_health = max_health
	update_hp_label()
	
	# FORCE SpringArm to only collide with Planet (Layer 1)
	spring_arm.collision_mask = 1
	
	
	if dust_trail_scene:
		dust_trail_node = dust_trail_scene.instantiate()
		var tank_pivot = get_node_or_null("TankPivot")
		if tank_pivot:
			tank_pivot.add_child(dust_trail_node)
			# Pivot is rotated 180 (scale -1) sometimes or model is reversed?
			# TankModel is rotated 1.5, 1.5, -1.5? (Scale of 1.5 with Z flipped?)
			# Let's adjust local position. If model faces -Z, behind is +Z.
			dust_trail_node.position = Vector3(0, 0.5, 2.0) 
		else:
			add_child(dust_trail_node)
			dust_trail_node.position = Vector3(0, 0.5, 2.0)
	
	print("Player Ready at: ", global_position)
	print("SpringArm Mask: ", spring_arm.collision_mask)
	
	# Debug Camera
	# print("SpringArm Hit Len: ", spring_arm.get_hit_length(), " | Actual: ", spring_arm.spring_length)

func take_damage(amount):
	if is_dead:
		return
		
	current_health -= amount
	current_health = max(0, current_health) # Clamp to 0
	
	print("Player took damage: ", amount, " Health: ", current_health)
	update_hp_label()
	
	if current_health <= 0:
		die()

func update_hp_label():
	if hp_label:
		hp_label.text = str(int(current_health))

func die():
	if is_dead:
		return
		
	is_dead = true
	print("Player Died!")
	
	# Hide Player Mesh
	if visual_mesh:
		visual_mesh.visible = false
	
	var tank_pivot = get_node_or_null("TankPivot")
	if tank_pivot:
		tank_pivot.visible = false
		
	# Spawn Explosion
	if explosion_scene:
		var expl = explosion_scene.instantiate()
		get_parent().add_child(expl)
		expl.global_position = global_position
	
	GameManager.trigger_game_over()
	# Disable processing/physics?
	set_physics_process(false)
	set_process(false)
	
func _unhandled_input(event):
	if is_dead:
		return
		
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			return
			
		# Rotate SpringArm horizontally (around relative Y) and vertically (around relative X)
		camera_rig.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation_degrees.x = clamp(spring_arm.rotation_degrees.x, min_pitch, max_pitch)
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				# get_viewport().set_input_as_handled() # Optional: consume the click so we don't shoot immediately?
		
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			spring_arm.spring_length = clamp(spring_arm.spring_length - zoom_speed, min_zoom, max_zoom)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			spring_arm.spring_length = clamp(spring_arm.spring_length + zoom_speed, min_zoom, max_zoom)

	if event is InputEventMagnifyGesture:
		# Factor > 1 means pinch out (magnify/zoom in) -> shorten arm
		# Factor < 1 means pinch in (shrink/zoom out) -> lengthen arm
		var new_length = spring_arm.spring_length / event.factor
		spring_arm.spring_length = clamp(new_length, min_zoom, max_zoom)
		
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	# 1. Calculate Up Vector (Normal from planet center)
	var up_vector = (global_position - planet_center).normalized()
	
	# 2. Align Character Up to Planet Normal
	# We verify if we are aligned. If not, rotate the character.
	if up_direction != up_vector:
		up_direction = up_vector
		# Align the basis y vector to the up_vector
		var current_transform = global_transform
		current_transform.basis.y = up_vector
		current_transform.basis.x = -current_transform.basis.z.cross(up_vector)
		current_transform.basis = current_transform.basis.orthonormalized()
		global_transform = global_transform.interpolate_with(current_transform, 10 * delta)

	# 3. Apply Gravity
	if not is_on_floor():
		velocity += -up_vector * 20.0 * delta # 20.0 gravity for snappy feel

	# 4. Handle Jump and Coyote Time
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		if coyote_timer > 0:
			coyote_timer -= delta
			
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
		
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
		if coyote_timer > 0:
			velocity += up_vector * jump_velocity
			jump_buffer_timer = 0.0
			coyote_timer = 0.0

	# 5. Movement
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# Get camera basis ideally aligned strictly to gravity for "forward" calculation?
	# Actual camera forward in global space
	var cam_basis = camera.global_transform.basis
	var cam_forward = -cam_basis.z
	var cam_right = cam_basis.x
	
	# Project onto surface tangent plane
	var forward_dir = cam_forward.slide(up_vector).normalized()
	var right_dir = cam_right.slide(up_vector).normalized()
	
	var direction = (right_dir * input_dir.x + forward_dir * -input_dir.y).normalized()
	

	
	# Preserve vertical velocity (gravity/jump)
	var vert_vel = velocity.project(up_vector)
	# Get current tangential velocity
	var current_tan_vel = velocity - vert_vel
	
	var target_tan_vel = Vector3.ZERO
	if direction:
		target_tan_vel = direction * move_speed
		
		# Rotate visual pivot to face movement direction
		var tank_pivot = get_node_or_null("TankPivot")
		if tank_pivot:
			# FIX DETACHMENT: Force local position to zero to prevent drift
			tank_pivot.position = Vector3.ZERO
			
			# Calculate Local Direction for Rotation
			# We want to look at (global_pos + direction).
			var local_dir = to_local(global_position + direction)
			
			# Calculate desired yaw (rotation around Y, Godot -Z is forward)
			# atan2(-x, -z) aligns -Z to vector
			var target_yaw = atan2(-local_dir.x, -local_dir.z)
			
			# Interpolate angle locally
			tank_pivot.rotation.y = lerp_angle(tank_pivot.rotation.y, target_yaw, 10 * delta)
			
			# Scale is preserved because we don't touch it (pivot.scale remains)

	# Apply Acceleration/Deceleration
	# We move the current tangential velocity towards the target tangential velocity
	var new_tan_vel = current_tan_vel.move_toward(target_tan_vel, acceleration * delta)
	velocity = vert_vel + new_tan_vel

	# Engine Sound Logic
	if engine_sound:
		var speed_ratio = new_tan_vel.length() / move_speed
		# Pitch from 0.8 (idle) to 1.5 (full speed) - adjust to taste
		var target_pitch = 0.8 + (0.7 * speed_ratio)
		engine_sound.pitch_scale = lerp(engine_sound.pitch_scale, target_pitch, 5.0 * delta)
		
		# Ensure it's playing if we have a stream (user might add one later)
		# If no stream is assigned, this does nothing harmful
		if not engine_sound.playing and engine_sound.stream:
			engine_sound.play()

	# SAFETY NET: Prevent falling through planet
	# Planet Radius is 40.0. If we get too deep, force push out.
	var dist_to_center = global_position.distance_to(planet_center)
	if dist_to_center < 39.5: # Allow small overlap for collision, but catch deep penetration
		# Push out to surface
		global_position = planet_center + (global_position - planet_center).normalized() * 40.0
		# Kill downward velocity (slide along normal)
		velocity = velocity.slide(up_vector)

	move_and_slide()
	
	# Dust Trail Logic
	if dust_trail_node:
		# More permissive check: On floor OR very close to ground (e.g. 41.0 radius)
		# This prevents dust cutting out on small bumps or single-frame airtime
		var near_ground = dist_to_center < 41.5
		if (is_on_floor() or near_ground) and velocity.length() > 1.0:
			dust_grace_timer = 0.2
			
		if dust_grace_timer > 0:
			dust_grace_timer -= delta
			if not dust_trail_node.emitting:
				dust_trail_node.emitting = true
		else:
			if dust_trail_node.emitting:
				dust_trail_node.emitting = false

# --- Building System ---
var is_build_mode = false
var build_cooldown = 0.0
const BUILD_RANGE = 20.0
var ghost_structure : Node3D = null

var structure_scenes = [
	"res://scenes/structures/turret.tscn",
	"res://scenes/structures/missile_turret.tscn",
	"res://scenes/structures/laser_turret.tscn",
	"res://scenes/structures/power_plant.tscn",
	"res://scenes/structures/hq.tscn"
]
var structure_costs = [50, 100, 75, 60, 200]
var current_structure_index = 0

func _unhandled_input_build(event):
	if event.is_action_pressed("build_mode"):
		is_build_mode = not is_build_mode
		if is_build_mode:
			print("Build Mode ON")
			if ghost_structure == null:
				create_ghost()
		else:
			print("Build Mode OFF")
			if ghost_structure:
				ghost_structure.queue_free()
				ghost_structure = null

	if is_build_mode:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_1: 
				current_structure_index = 0
				update_ghost_visual()
			if event.keycode == KEY_2: 
				current_structure_index = 1
				update_ghost_visual()
			if event.keycode == KEY_3: 
				current_structure_index = 2
				update_ghost_visual()
			if event.keycode == KEY_4: 
				current_structure_index = 3
				update_ghost_visual()
			if event.keycode == KEY_5: 
				current_structure_index = 4
				update_ghost_visual()
		
		if event.is_action_pressed("fire"):
			try_build()

func create_ghost():
	var mesh = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = Vector3(2,2,2)
	# Create a transparent material
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 1, 0, 0.5)
	mesh.mesh.material = mat
	ghost_structure = mesh
	get_parent().add_child(ghost_structure)
	update_ghost_visual()

func update_ghost_visual():
	if ghost_structure and ghost_structure.mesh and ghost_structure.mesh.material:
		var color = Color(0, 1, 0, 0.5)
		if current_structure_index == 1: color = Color(0, 0, 1, 0.5) # Missile Blue
		if current_structure_index == 2: color = Color(1, 1, 0, 0.5) # Laser Yellow
		if current_structure_index == 3: color = Color(0, 1, 1, 0.5) # Power Cyan
		if current_structure_index == 4: color = Color(1, 0.8, 0, 0.5) # HQ Gold
		ghost_structure.mesh.material.albedo_color = color
	
	# Emit signal or update UI here if we had reference

func _input(event):
	_unhandled_input(event)
	_unhandled_input_build(event)

func try_build():
	# Special Rule: HQ
	if current_structure_index == 4:
		if GameManager.hq_count > 0:
			GameManager.notify("HQ Limit Reached! (Max 1)", 2.0)
			return

	var cost = structure_costs[current_structure_index]
	if not GameManager.has_credits(cost):
		GameManager.notify("Not enough credits! Need: " + str(cost), 2.0)
		GameManager.play_voice("no_resources")
		return

	var result = get_raycast_collision()
	if result:
		var point = result.position
		var normal = result.normal
		
		if GameManager.spend_credits(cost):
			# Load the structure scene
			var path = structure_scenes[current_structure_index]
			var scene = load(path)
			var structure = scene.instantiate()
			get_parent().add_child(structure)
			
			structure.global_position = point
			# Align structure up with normal
			if structure.global_transform.basis.y != normal:
				# Look at logic for aligning Y to normal
				var new_basis = Basis()
				new_basis.y = normal
				new_basis.x = -structure.global_transform.basis.z.cross(normal).normalized()
				new_basis.z = new_basis.x.cross(normal).normalized()
				structure.global_transform.basis = new_basis

			# Check validity before finalizing
			if not check_placement_validity(point, structure.global_transform.basis):
				structure.queue_free()
				GameManager.notify("Construction not possible", 2.0)
				# Restore credits
				GameManager.add_credits(cost)
				return

func _process(delta):
	_handle_auto_shoot()
	if is_build_mode and ghost_structure:
		var result = get_raycast_collision()
		if result:
			ghost_structure.visible = true
			ghost_structure.global_position = result.position
			# Align ghost
			var normal = result.normal
			var new_basis = Basis()
			new_basis.y = normal
			# Use camera forward for X alignment preference?
			var cam_forward = -camera.global_transform.basis.z
			new_basis.x = cam_forward.cross(normal).normalized()
			new_basis.z = new_basis.x.cross(normal).normalized()
			ghost_structure.global_transform.basis = new_basis
			
			# Update Ghost Color based on validity
			var is_valid = check_placement_validity(ghost_structure.global_position, new_basis)
			var target_color = Color(0, 1, 0, 0.5)
			if current_structure_index == 1: target_color = Color(0, 0, 1, 0.5)
			if current_structure_index == 2: target_color = Color(1, 1, 0, 0.5)
			if current_structure_index == 3: target_color = Color(0, 1, 1, 0.5)
			if current_structure_index == 4: target_color = Color(1, 0.8, 0, 0.5)
			
			if not is_valid:
				target_color = Color(1, 0, 0, 0.5)
			
			if ghost_structure.mesh and ghost_structure.mesh.material:
				ghost_structure.mesh.material.albedo_color = target_color
		elif ghost_structure:
			ghost_structure.visible = false

func get_raycast_collision():
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000.0
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 1 # Only collide with planet (Layer 1)
	return space_state.intersect_ray(query)

func check_placement_validity(pos: Vector3, basis: Basis) -> bool:
	var space_state = get_world_3d().direct_space_state
	var params = PhysicsShapeQueryParameters3D.new()
	var shape = BoxShape3D.new()
	# Structure size is 2x2x2. We check slightly smaller to allow touching but not overlapping center?
	# Or keep full size. Let's use 1.9 to be safe.
	shape.size = Vector3(1.9, 1.9, 1.9)
	params.shape = shape
	
	# Structure pivots are at bottom (0,0,0). Center of BoxShape is at (0,1,0) relative to pivot.
	var center_pos = pos + basis.y * 1.0
	params.transform = Transform3D(basis, center_pos)
	
	params.collision_mask = 8 # Structures Layer
	
	var results = space_state.intersect_shape(params)
	return results.size() == 0

# --- Auto Shoot System ---
@onready var auto_shoot_timer = $AutoShootTimer
var projectile_scene = preload("res://scenes/projectile_player.tscn")
var auto_aim_range = 30.0

func _handle_auto_shoot():
	if not auto_shoot_timer.is_stopped():
		return

	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		return
		
	# Find nearest
	var nearest = null
	var min_dist = auto_aim_range
	for body in enemies:
		var d = global_position.distance_to(body.global_position)
		if d < min_dist:
			min_dist = d
			nearest = body
	
	if nearest:
		shoot_at(nearest)
		auto_shoot_timer.start()

func shoot_at(target_node):
	# Check Line of Sight mainly to avoid shooting through planet
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.0, 0), target_node.global_position)
	query.collision_mask = 1 # Planet Layer
	var result = space_state.intersect_ray(query)
	
	if result:
		# Hit Planet?
		return # Blocked by planet

	if projectile_scene:
		var proj = projectile_scene.instantiate()
		get_parent().add_child(proj)
		# Spawn at camera/player position, maybe slightly offset forward
		proj.global_position = global_position + Vector3(0, 1.5, 0)
		proj.look_at(target_node.global_position)
		
		# Set Damage (Laser Turret = 10)
		if "damage" in proj:
			proj.damage = 10

func _on_auto_shoot_timer_timeout():
	pass # Timer creates the delay, we check in process
