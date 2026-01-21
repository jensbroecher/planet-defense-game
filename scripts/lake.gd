@tool
extends Node3D

@export var frames_folder: String = "res://textures/water_128px_frames"
@export var fps: float = 30.0

@export var tiling: int = 6
@export var water_tint: Color = Color(0.15, 0.2, 0.3, 1.0) # Darker water tint
@export var noise_seed: int = 1337
@export var noise_frequency: float = 0.003
@export var noise_fractal_octaves: int = 3

@onready var decal = $Decal

var _frames: Array[ImageTexture] = []
var _time: float = 0.0
var _current_frame_index: int = 0

func _ready() -> void:
	generate_frames()

func generate_frames() -> void:
	_frames.clear()
	
	var dir = DirAccess.open(frames_folder)
	if not dir:
		print("Lake: Could not open directory: ", frames_folder)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	var files = []
	while file_name != "":
		if !dir.current_is_dir() and file_name.ends_with(".png") and !file_name.ends_with(".import"):
			files.append(file_name)
		file_name = dir.get_next()
	files.sort()
	
	if files.size() == 0:
		return

	# Load first frame to determine dimensions
	var first_tex = load(frames_folder + "/" + files[0])
	if not first_tex: 
		return
		
	var source_w = first_tex.get_width()
	var source_h = first_tex.get_height()
	var final_w = source_w * tiling
	var final_h = source_h * tiling
	
	# 1. Prepare Mask Image (O(TotalPixels)) - DONE ONCE
	var noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = noise_fractal_octaves
	
	var noise_img = noise.get_image(final_w, final_h) # Returns L8
	
	# Create the Alpha Mask used for blit_rect_mask
	# Mask needs to be RGBA8 so the Alpha channel exists and works.
	# We want to bake the falloff into this mask's Alpha.
	
	var final_mask = Image.create(final_w, final_h, false, Image.FORMAT_RGBA8)
	var center = Vector2(final_w/2.0, final_h/2.0)
	var max_dist = final_w / 2.0
	
	# Loop pixels once to generate valid mask
	for y in range(final_h):
		for x in range(final_w):
			var n = noise_img.get_pixel(x,y).r
			var dist = center.distance_to(Vector2(x, y))
			# Relaxed falloff to fill more of the lake
			var radial_falloff = 1.0 - smoothstep(max_dist * 0.7, max_dist * 0.95, dist)
			
			if n * radial_falloff > 0.35: # Threshold
				final_mask.set_pixel(x, y, Color(1, 1, 1, 1)) # White = keep
			else:
				final_mask.set_pixel(x, y, Color(0, 0, 0, 0)) # Black = discard

	# 2. Process Frames (Fast Loop using C++ blit)
	for f in files:
		var stream_tex = load(frames_folder + "/" + f)
		if not stream_tex: continue
		
		var img = stream_tex.get_image()
		if not img: continue
		
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
			
		# Tint the small source image (O(SmallPixels)) - Very fast
		if water_tint != Color(1,1,1,1):
			for y in range(source_h):
				for x in range(source_w):
					var c = img.get_pixel(x, y)
					c = c * water_tint
					img.set_pixel(x, y, c)
		
		# Create Tiled Source
		var temp_tiled = Image.create(final_w, final_h, false, Image.FORMAT_RGBA8)
		for tx in range(tiling):
			for ty in range(tiling):
				temp_tiled.blit_rect(img, Rect2i(0, 0, source_w, source_h), Vector2i(tx * source_w, ty * source_h))
				
		# Create Final Frame using Mask - C++ Speed!
		var final_img = Image.create(final_w, final_h, false, Image.FORMAT_RGBA8) # Init 0,0,0,0
		
		# This uses final_mask's Alpha channel to cut out the shape
		final_img.blit_rect_mask(temp_tiled, final_mask, Rect2i(0, 0, final_w, final_h), Vector2i(0, 0))
		
		_frames.append(ImageTexture.create_from_image(final_img))

	# Setup Decal
	if decal:
		if _frames.size() > 0:
			decal.texture_albedo = _frames[0]
			decal.texture_emission = _frames[0]
		
		# Ensure no stray ORM
		decal.texture_orm = null
		decal.emission_energy = 1.0

func _process(delta: float) -> void:
	if _frames.size() == 0:
		return
		
	_time += delta
	var frame_idx = int(_time * fps) % _frames.size()
	
	if frame_idx != _current_frame_index:
		_current_frame_index = frame_idx
		if decal:
			decal.texture_albedo = _frames[_current_frame_index]
			decal.texture_emission = _frames[_current_frame_index]
