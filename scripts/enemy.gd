extends CharacterBody3D

enum State { APPROACHING, ATTACKING }
var current_state = State.APPROACHING

@export var move_speed = 10.0
@export var attack_range = 60.0 # Stopping distance from planet center (Planet rad is 40)
@export var fire_rate = 2.0
@export var projectile_scene : PackedScene

var planet_center = Vector3.ZERO
var attack_timer = 0.0
var target = null

@export var max_health = 30
var current_health

func _ready():
	add_to_group("enemies")
	projectile_scene = load("res://scenes/projectile.tscn")
	current_health = max_health

func take_damage(amount):
	current_health -= amount
	if current_health <= 0:
		die()

func die():
	GameManager.add_credits(10)
	queue_free()

func _physics_process(delta):
	match current_state:
		State.APPROACHING:
			var dist = global_position.distance_to(planet_center)
			if dist > attack_range:
				var dir = (planet_center - global_position).normalized()
				velocity = dir * move_speed
				move_and_slide()
				look_at(planet_center) # Look at planet
			else:
				current_state = State.ATTACKING
				
		State.ATTACKING:
			attack_timer -= delta
			if attack_timer <= 0:
				attack_timer = fire_rate
				shoot_projectile()
			
			# Orbit or minimal movement? For now just static hovering and looking at target.
			if target == null or not is_instance_valid(target):
				find_target()
			
			if target:
				look_at(target.global_position)

func find_target():
	# Find nearest structure or player
	var structures = get_tree().get_nodes_in_group("structures")
	var player = get_tree().get_first_node_in_group("player")
	
	var candidates = []
	if player: candidates.append(player)
	candidates.append_array(structures)
	
	var nearest = null
	var min_dist = INF
	
	for c in candidates:
		var d = global_position.distance_to(c.global_position)
		if d < min_dist:
			min_dist = d
			nearest = c
			
	target = nearest

func shoot_projectile():
	if projectile_scene:
		var proj = projectile_scene.instantiate()
		get_parent().add_child(proj)
		proj.global_position = global_position
		proj.look_at(global_position - global_transform.basis.z * 10.0) # Look forward
