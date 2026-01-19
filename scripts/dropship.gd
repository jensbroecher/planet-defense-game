extends CharacterBody3D

enum State { APPROACHING, DROPPING, DEPARTING }
var current_state = State.APPROACHING

@export var move_speed = 15.0
@export var drop_height = 60.0 # From planet center (Radius 40 + 20)
var planet_center = Vector3.ZERO
var ground_enemy_scene : PackedScene

var drop_count = 3
var drop_timer = 0.0
var drop_interval = 1.0

func _ready():
	add_to_group("enemies") # Use same group so turrets target it
	# Preload ground enemy
	ground_enemy_scene = load("res://scenes/enemies/enemy_ground.tscn")

@export var explosion_scene_path = "res://scenes/effects/enemy_explosion.tscn"

func take_damage(amount):
	queue_free() # One hit kill
	die()

func die():
	GameManager.add_credits(20)
	
	if explosion_scene_path:
		var scene = load(explosion_scene_path)
		if scene:
			var expl = scene.instantiate()
			get_parent().add_child(expl)
			expl.global_position = global_position
			
	queue_free()

func _physics_process(delta):
	# Always look at planet center for "belly down" orientation? 
	# Or look forward. Let's look forward.
	
	match current_state:
		State.APPROACHING:
			var dist = global_position.distance_to(planet_center)
			if dist > drop_height:
				var dir = (planet_center - global_position).normalized()
				velocity = dir * move_speed
				move_and_slide()
				look_at(planet_center)
			else:
				current_state = State.DROPPING
				
		State.DROPPING:
			drop_timer -= delta
			if drop_timer <= 0:
				drop_timer = drop_interval
				if drop_count > 0:
					spawn_unit()
					drop_count -= 1
				else:
					current_state = State.DEPARTING
		
		State.DEPARTING:
			# Fly away from planet
			var dir = (global_position - planet_center).normalized()
			velocity = dir * move_speed
			move_and_slide()
			look_at(global_position + dir * 10.0) # Look away
			
			if global_position.distance_to(planet_center) > 200.0:
				queue_free()

func spawn_unit():
	if ground_enemy_scene:
		var unit = ground_enemy_scene.instantiate()
		get_parent().add_child(unit)
		unit.global_position = global_position - (global_position - planet_center).normalized() * 5.0 # Spawn slightly below
		unit.planet_center = planet_center
		print("Dropship deployed unit")
