extends Node3D

@export var enemy_scene : PackedScene
@export var spawn_interval = 2.0
@export var spawn_radius = 100.0

var timer = 0.0

func _process(delta):
	timer -= delta
	if timer <= 0:
		spawn_enemy()
		timer = spawn_interval

func spawn_enemy():
	if not enemy_scene:
		enemy_scene = load("res://scenes/enemies/enemy.tscn")
		
	if enemy_scene:
		var enemy = enemy_scene.instantiate()
		get_parent().add_child(enemy)
		print("Spawned Enemy at ", Time.get_time_string_from_system())
		
		# Random point on a sphere surface (approximate)
		var theta = randf() * 2 * PI
		var phi = acos(2 * randf() - 1)
		
		var x = spawn_radius * sin(phi) * cos(theta)
		var y = spawn_radius * sin(phi) * sin(theta)
		var z = spawn_radius * cos(phi)
		
		enemy.global_position = Vector3(x, y, z)
		enemy.look_at(Vector3.ZERO) # Look at planet center
