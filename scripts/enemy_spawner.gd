extends Node3D

@export var spawn_interval = 2.0
@export var spawn_radius = 150.0

var enemy_scenes = [
	"res://scenes/enemies/enemy.tscn",
	"res://scenes/enemies/enemy_heavy.tscn",
	"res://scenes/enemies/enemy_fast.tscn",
	"res://scenes/enemies/dropship.tscn"
]

var loaded_scenes = []

var timer = 0.0

func _ready():
	for path in enemy_scenes:
		loaded_scenes.append(load(path))

func _process(delta):
	timer -= delta
	if timer <= 0:
		spawn_enemy()
		timer = spawn_interval

func spawn_enemy():
	if loaded_scenes.size() > 0:
		var scene = loaded_scenes.pick_random()
		var enemy = scene.instantiate()
		get_parent().add_child(enemy)
		print("Spawned Enemy: ", enemy.name, " at ", Time.get_time_string_from_system())
		
		# Random point on a sphere surface (approximate)
		var theta = randf() * 2 * PI
		var phi = acos(2 * randf() - 1)
		
		var x = spawn_radius * sin(phi) * cos(theta)
		var y = spawn_radius * sin(phi) * sin(theta)
		var z = spawn_radius * cos(phi)
		
		enemy.global_position = Vector3(x, y, z)
		enemy.look_at(Vector3.ZERO) # Look at planet center
