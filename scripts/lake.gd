@tool
extends Node3D

@export var frames_folder: String = "res://textures/water_128px_frames"
@export var fps: float = 30.0

@export var tiling: int = 3
@export var water_tint: Color = Color(0.35, 0.45, 0.55, 1.0) # Default slight blue-grey, can be overridden to brown in inspector
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
	
	# 1. Create Noise Mask
	var noise = FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = noise_frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = noise_fractal_octaves
	
	var mask_image = noise.get_image(256 * tiling, 256 * tiling)
	
	# Apply threshold manually to create hard edges or soft edges for the mask
	# Since get_image returns grayscale noise
	
	var dir = DirAccess.open(frames_folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var files = []
		while file_name != "":
			if !dir.current_is_dir() and file_name.ends_with(".png") and !file_name.ends_with(".import"):
				files.append(file_name)
			file_name = dir.get_next()
		
		files.sort()
		
		for f in files:
			var stream_tex = load(frames_folder + "/" + f)
			if stream_tex:
				var img = stream_tex.get_image() # Original 128x128 image
				if img:
					# Convert to RGBA8 to match the target image format for blitting
					if img.get_format() != Image.FORMAT_RGBA8:
						img.convert(Image.FORMAT_RGBA8)
						
					# Create larger image for tiling
					var tiled_width = img.get_width() * tiling
					var tiled_height = img.get_height() * tiling
					var final_img = Image.create(tiled_width, tiled_height, false, Image.FORMAT_RGBA8)
					
					# Tile the image
					for x in range(tiling):
						for y in range(tiling):
							final_img.blit_rect(img, Rect2(0, 0, img.get_width(), img.get_height()), Vector2(x * img.get_width(), y * img.get_height()))
					
					# Resize mask to match if needed (though we generated it large enough)
					if mask_image.get_width() != tiled_width:
						mask_image.resize(tiled_width, tiled_height)
						
					# Apply Mask (Alpha)
					# Iterate pixels - expensive but done only once at startup
					for y in range(tiled_height):
						for x in range(tiled_width):
							var mask_val = mask_image.get_pixel(x, y).r
							# Create a hole in the middle (island) or just a lake shape
							# Let's assume white = water, black = land
							# Simple threshold
							var alpha = 0.0
							# Center bias to fade edges
							var center = Vector2(tiled_width/2.0, tiled_height/2.0)
							var dist = center.distance_to(Vector2(x, y))
							var max_dist = tiled_width / 2.0
							var radial_falloff = 1.0 - smoothstep(max_dist * 0.5, max_dist, dist)
							
							if mask_val * radial_falloff > 0.4: # Threshold
								alpha = 1.0
							else:
								alpha = 0.0
								
							var col = final_img.get_pixel(x,y)
							# Apply tint
							col = col * water_tint
							
							# Apply alpha mask
							col.a = alpha
							
							# IMPORTANT: Multi-multiply RGB by alpha (or just clear it)
							# because Decal Emission might ignore alpha and just read RGB.
							# If alpha is 0, we want RGB to be black so it doesn't emit.
							col.r *= alpha
							col.g *= alpha
							col.b *= alpha
							
							final_img.set_pixel(x, y, col)
					
					var tex = ImageTexture.create_from_image(final_img)
					_frames.append(tex)
	else:
		print("Lake: Could not open directory: ", frames_folder)
				
	# Setup Decal Texture Initial State
	if _frames.size() > 0 and decal:
		decal.texture_albedo = _frames[0]
		decal.texture_emission = _frames[0]
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
