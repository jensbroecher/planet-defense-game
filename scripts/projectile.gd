extends Area3D

@export var speed = 40.0
@export var damage = 10
@export var life_time = 10.0

var explosion_scene = preload("res://scenes/effects/projectile_explosion.tscn")

func _ready():
	# Ensure checking collisions with World (1), Player (2 - usually), Enemies (3), Structures (?)
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	
	# Delete after life_time seconds
	await get_tree().create_timer(life_time).timeout
	if is_instance_valid(self):
		queue_free()

func _physics_process(delta):
	var move_amount = speed * delta
	var forward = -transform.basis.z
	var target_pos = global_position + forward * move_amount
	
	# RayCast ahead to detect collision
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, target_pos)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	if result:
		# Hit something!
		global_position = result.position
		_on_body_entered(result.collider)
	else:
		# Safe to move
		global_position = target_pos

func _on_body_entered(body):
	print("Projectile hit: ", body.name)
	
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	# Always destroy on impact with any body (Planet, Player, Structure)
	var explosion = explosion_scene.instantiate()
	get_tree().root.add_child(explosion)
	explosion.global_position = global_position
	
	queue_free()
