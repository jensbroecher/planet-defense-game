@tool
extends Node3D

@export var frames_folder: String = "res://textures/water_128px_frames"
@export var fps: float = 30.0

@onready var water_rect = $SubViewport/Mask/Water
@onready var decal = $Decal

var _frames: Array[Texture2D] = []
var _time: float = 0.0
var _current_frame_index: int = 0

func _ready() -> void:
	load_frames()

func load_frames() -> void:
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
			var tex = load(frames_folder + "/" + f)
			if tex:
				_frames.append(tex)
				
	if _frames.size() > 0 and water_rect:
		water_rect.texture = _frames[0]
		
	# Setup Decal Texture
	if decal:
		decal.texture_albedo = $SubViewport.get_texture()

func _process(delta: float) -> void:
	# Ensure Decal has texture (fix for initialization order)
	if decal and decal.texture_albedo == null:
		decal.texture_albedo = $SubViewport.get_texture()
		
	if _frames.size() == 0:
		# Try reloading if empty (e.g. script recompile)
		load_frames()
		return
		
	_time += delta
	var frame_idx = int(_time * fps) % _frames.size()
	
	if frame_idx != _current_frame_index:
		_current_frame_index = frame_idx
		if water_rect:
			water_rect.texture = _frames[_current_frame_index]
