extends Control

@export var flare_strength = 1.0
@export var sun_direction = Vector3(0.25, 0.866, -0.433) # Matches shader/light

var flares = []
var visible_time = 0.0

func _ready():
	# Collect all TextureRect children
	for child in get_children():
		if child is TextureRect:
			flares.append({
				"node": child,
				"offset": child.get_meta("offset", 0.0), # 0 = sun, 1 = center, >1 = opposite
				"scale": child.get_meta("scale_mod", 1.0)
			})
	
	# Normalize sun direction
	sun_direction = sun_direction.normalized()

func _process(delta):
	var viewport = get_viewport()
	var camera = viewport.get_camera_3d()
	if not camera:
		visible = false
		return
		
	# Check if looking roughly towards sun
	var cam_forward = -camera.global_transform.basis.z
	var dot = cam_forward.dot(sun_direction)
	
	# If sun is behind camera, hide
	if dot < 0.0:
		modulate.a = lerp(modulate.a, 0.0, 10.0 * delta)
		return

	# Calculate Sun Screen Position
	# We project a point far away in sun direction
	var sun_pos_world = camera.global_position + sun_direction * 1000.0
	if camera.is_position_behind(sun_pos_world):
		modulate.a = lerp(modulate.a, 0.0, 10.0 * delta)
		return
		
	var sun_screen_pos = camera.unproject_position(sun_pos_world)
	var screen_size = viewport.get_visible_rect().size
	var screen_center = screen_size * 0.5
	
	# Raycast check for occlusion
	var space_state = camera.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position + sun_direction * 1000.0)
	query.collision_mask = 1 # Planet
	var result = space_state.intersect_ray(query)
	
	var target_alpha = 1.0
	if result:
		target_alpha = 0.0
	
	# Smooth fade
	modulate.a = lerp(modulate.a, target_alpha, 10.0 * delta)
	
	if modulate.a < 0.01:
		return
		
	# Position elements
	# Vector from Sun to Center
	var sun_to_center = screen_center - sun_screen_pos
	
	for flare in flares:
		var node = flare["node"]
		var offset = flare["offset"]
		# limit distance?
		var pos = sun_screen_pos + sun_to_center * offset
		node.position = pos - node.size * 0.5 # Center the texture
		
