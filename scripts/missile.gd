extends "res://scripts/projectile.gd"

var target_body : Node3D = null
var steer_speed = 5.0 
var launch_phase_time = 0.5 
var current_time = 0.0

func _physics_process(delta):
	current_time += delta
	
	# Phase 1: Straight, Phase 2: Seek
	if current_time > launch_phase_time and target_body and is_instance_valid(target_body):
		var target_pos = target_body.global_position
		
		# Simple LookAt with interpolation
		# We need to rotate our forward vector (-Z) towards target
		var current_forward = -global_transform.basis.z
		var direction_to_target = (target_pos - global_position).normalized()
		
		# Interpolate direction
		var new_dir = current_forward.lerp(direction_to_target, steer_speed * delta).normalized()
		
		# Look along new direction. We need an Up vector. 
		# If we are in space/planet, Up is gravity normal?
		# Or just use current Up to minimize roll
		var up = global_transform.basis.y
		
		# Avoid looking at exact up/down singularity
		if abs(new_dir.dot(up)) < 0.99:
			look_at(global_position + new_dir, up)
		
	# Call parent movement
	super._physics_process(delta)
