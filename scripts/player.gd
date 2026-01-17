extends CharacterBody3D

@export var move_speed = 8.0
@export var jump_velocity = 8.0
@export var planet_center = Vector3.ZERO
@export var mouse_sensitivity = 0.003

@onready var camera_rig = $CameraRig
@onready var spring_arm = $CameraRig/SpringArm3D
@onready var camera = $CameraRig/SpringArm3D/Camera3D
@onready var visual_mesh = $MeshInstance3D

# Vertical angle limits
var min_pitch = -80.0
var max_pitch = 80.0

func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Set floor max angle to support walking on sphere (though gravity usually handles this)
	floor_max_angle = deg_to_rad(60.0)

func take_damage(amount):
	print("Player took damage: ", amount)
	# Todo: Health Logic
	
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		# Rotate SpringArm horizontally (around relative Y) and vertically (around relative X)
		camera_rig.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
		spring_arm.rotation_degrees.x = clamp(spring_arm.rotation_degrees.x, min_pitch, max_pitch)
		
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

	# 4. Handle Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity += up_vector * jump_velocity

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
	
	if direction:
		# Preserve vertical velocity (gravity/jump)
		var vert_vel = velocity.project(up_vector)
		velocity = vert_vel + direction * move_speed
		
		# Rotate visual mesh to face movement direction (optional, for aesthetics)
		# NOTE: This can conflict with the character body rotation if not careful.
		# For now, let the CharacterBody rotation handle 'Up', and maybe we don't rotate to face forward yet or we do it simply.
	else:
		# Decelerate tangential velocity only
		var vert_vel = velocity.project(up_vector)
		var tan_vel = velocity - vert_vel
		tan_vel = tan_vel.move_toward(Vector3.ZERO, move_speed)
		velocity = vert_vel + tan_vel

	move_and_slide()

# --- Building System ---
var is_build_mode = false
var build_cooldown = 0.0
const BUILD_RANGE = 20.0
var ghost_structure : Node3D = null

var structure_scenes = [
	"res://scenes/structures/turret.tscn",
	"res://scenes/structures/missile_turret.tscn",
	"res://scenes/structures/laser_turret.tscn"
]
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
		ghost_structure.mesh.material.albedo_color = color
	
	# Emit signal or update UI here if we had reference

func _input(event):
	_unhandled_input(event)
	_unhandled_input_build(event)

func try_build():
	var result = get_raycast_collision()
	if result:
		var point = result.position
		var normal = result.normal
		
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

func _process(delta):
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
		else:
			ghost_structure.visible = false

func get_raycast_collision():
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 1000.0
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = 1 # Only collide with planet (Layer 1)
	return space_state.intersect_ray(query)
