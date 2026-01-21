extends Sprite3D

func _ready() -> void:
	# Face the center of the world (Planet)
	look_at(Vector3.ZERO)
	
	# Sprite3D looks down -Z, so looking at center puts the "back" of the sprite to the center.
	# We need to rotate it 180 degrees so the texture faces the planet.
	rotate_y(PI)
