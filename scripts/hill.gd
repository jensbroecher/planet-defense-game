extends StaticBody3D

@export var align_to_planet = true

func _ready():
	if align_to_planet:
		perform_alignment()

func perform_alignment():
	# Align Up (Y) with planet normal (position normalized)
	if global_position.is_zero_approx():
		return
		
	var up = global_position.normalized()
	# We want our Y to be 'up'
	var right_guess = Vector3.RIGHT
	if abs(up.dot(right_guess)) > 0.9:
		right_guess = Vector3.BACK
		
	var forward = right_guess.cross(up).normalized()
	var right = up.cross(forward).normalized()
	
	# Reconstruct Basis (columns: x, y, z)
	global_transform.basis = Basis(right, up, forward)
