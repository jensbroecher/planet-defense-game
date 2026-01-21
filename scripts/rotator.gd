extends Node3D

@export var rotation_speed: Vector3 = Vector3(0.2, 0.5, 0.1)

func _process(delta: float) -> void:
	rotation += rotation_speed * delta
