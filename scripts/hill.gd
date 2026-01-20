@tool
extends StaticBody3D

@export var seed_value: int = 0:
	set(value):
		seed_value = value
		generate_hill()

@export var hill_radius: float = 10.0:
	set(value):
		hill_radius = value
		generate_hill()

@export var hill_height: float = 8.0:
	set(value):
		hill_height = value
		generate_hill()

@export var noise_frequency: float = 0.1:
	set(value):
		noise_frequency = value
		generate_hill()

@onready var mesh_instance = $MeshInstance3D
@onready var collision_shape = $CollisionShape3D

func _ready():
	generate_hill()

func generate_hill():
	if not is_inside_tree():
		return
		
	# Ensure nodes are available (tool mode safety)
	if not mesh_instance: mesh_instance = get_node_or_null("MeshInstance3D")
	if not collision_shape: collision_shape = get_node_or_null("CollisionShape3D")
	
	if not mesh_instance or not collision_shape:
		return
	var noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = noise_frequency
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	# Optional: fractal settings for more detail
	noise.fractal_octaves = 3
	
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Material
	var mat = StandardMaterial3D.new()
	var tex = load("res://textures/rock-1238563_1280.jpg")
	if tex:
		mat.albedo_texture = tex
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = false # Local space is better for moving hills
		mat.uv1_scale = Vector3(0.1, 0.1, 0.1) # Triplanar needs smaller scale usually
	else:
		mat.albedo_color = Color(0.5, 0.5, 0.5) # Fallback gray
	
	st.set_material(mat)
	
	var subdivisions = int(hill_radius * 2) # Resolution matches size roughly
	if subdivisions < 10: subdivisions = 10
	var step = (hill_radius * 2.0) / subdivisions
	
	# Generate Grid
	for z in range(subdivisions + 1):
		for x in range(subdivisions + 1):
			var x_pos = (x * step) - hill_radius
			var z_pos = (z * step) - hill_radius
			
			# Calculate distance from center (0,0) for falloff
			var dist = Vector2(x_pos, z_pos).length()
			var dist_norm = dist / hill_radius
			
			# Falloff: 1 at center, 0 at edge. Using cosine for smoother curve
			# dist_norm is 0..1
			var falloff = 0.0
			if dist_norm < 1.0:
				# Cosine curve: cos(0)=1, cos(pi)= -1. We want 0..pi/2 maybe? or just smoothstep
				falloff = pow(1.0 - pow(dist_norm, 2), 2) # sharper falloff
			
			# Sample noise for detail
			var noise_val = noise.get_noise_2d(x_pos * 5.0, z_pos * 5.0) 
			
			# Combine: Base Shape + Surface Detail
			# Base shape gives the "hill" volume. Noise adds rocky surface.
			var base_height = falloff * hill_height
			var detail = noise_val * (hill_height * 0.2) # detail is 20% of height
			
			var y_pos = base_height + detail
			
			# Force exact edges down to avoid floating gaps, though falloff handles most
			if dist_norm >= 0.9:
				y_pos *= (1.0 - dist_norm) / 0.1 # Fade out last 10% strictly
			
			var uv = Vector2(x, z) / subdivisions
			st.set_uv(uv)
			st.add_vertex(Vector3(x_pos, y_pos, z_pos))
			
	# Generate Indices
	for z in range(subdivisions):
		for x in range(subdivisions):
			var i = z * (subdivisions + 1) + x
			var width = subdivisions + 1
			
			# Triangle 1
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + width)
			
			# Triangle 2
			st.add_index(i + 1)
			st.add_index(i + width + 1)
			st.add_index(i + width)
			
	st.generate_normals()
	var mesh = st.commit()
	
	if mesh_instance:
		mesh_instance.mesh = mesh
	if collision_shape:
		collision_shape.shape = mesh.create_trimesh_shape()
