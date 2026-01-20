extends CharacterBody3D

@export var move_speed = 3.0 # Slow kamikaze
@export var damage = 25.0
@export var max_health = 20

var planet_center = Vector3.ZERO
var target = null

# No shooting needed

var audio_player : AudioStreamPlayer3D

func _ready():
	add_to_group("enemies")
	
	# Setup Audio (maybe persistent engine hum?)
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	audio_player.unit_size = 10.0
	audio_player.max_db = -5.0

func take_damage(amount):
	max_health -= amount
	if max_health <= 0:
		die()

@export var explosion_scene_path = "res://scenes/effects/enemy_explosion.tscn"

func die():
	GameManager.add_credits(5)
	
	if explosion_scene_path:
		var scene = load(explosion_scene_path)
		if scene:
			var expl = scene.instantiate()
			get_parent().add_child(expl)
			expl.global_position = global_position
			
	queue_free()

func _physics_process(delta):
	if target == null or not is_instance_valid(target):
		find_target()
		velocity = Vector3.ZERO
		return
	
	var dir_to_target = (target.global_position - global_position).normalized()
	velocity = dir_to_target * move_speed
	
	# Look at target
	look_at(target.global_position)
	
	# Move using slide to avoid sticking to walls/ground
	move_and_slide()
	
	# Check for collision
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var body = collision.get_collider()
		
		# Contact with player or structure = BOOM
		if body.is_in_group("player") or body.is_in_group("structures"):
			# Deal damage and die
			if body.has_method("take_damage"):
				body.take_damage(damage)
			die()
		elif body == target:
			die()
		# If it's the planet (Layer 1, or not in these groups), we just slide along it, which move_and_slide handles.

func find_target():
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
