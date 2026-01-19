extends CharacterBody3D

@export var move_speed = 5.0
@export var attack_range = 10.0
@export var damage = 5.0
@export var attack_rate = 1.0

var planet_center = Vector3.ZERO
var target = null
var attack_timer = 0.0

@export var max_health = 20
var current_health

var audio_player : AudioStreamPlayer3D
var attack_sound = preload("res://sounds/enemy/laser-bolt-89300.mp3")

func _ready():
	add_to_group("enemies")
	current_health = max_health
	
	# Setup Audio
	audio_player = AudioStreamPlayer3D.new()
	add_child(audio_player)
	audio_player.unit_size = 10.0
	audio_player.max_db = -5.0

func take_damage(amount):
	current_health -= amount
	if current_health <= 0:
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
	# Gravity & Alignment
	var up_vector = (global_position - planet_center).normalized()
	
	# Align to up_vector
	if up_direction != up_vector:
		up_direction = up_vector
		var current_transform = global_transform
		current_transform.basis.y = up_vector
		current_transform.basis.x = -current_transform.basis.z.cross(up_vector)
		current_transform.basis = current_transform.basis.orthonormalized()
		global_transform = global_transform.interpolate_with(current_transform, 5.0 * delta)
	
	if not is_on_floor():
		velocity += -up_vector * 10.0 * delta
	
	# Logic
	if target == null or not is_instance_valid(target):
		find_target()
		velocity.x = 0
		velocity.z = 0
	
	if target:
		var dist = global_position.distance_to(target.global_position)
		if dist > attack_range:
			# Move towards target
			# We need to move along surface.
			# Direction on plane tangent to surface
			var dir_to_target = (target.global_position - global_position).normalized()
			var forward_dir = dir_to_target.slide(up_vector).normalized()
			
			velocity = forward_dir * move_speed
			
			# Look at target but keep up aligned
			# Basic LookAt might break up alignment if not careful, but CharacterBody logic above fixes it eventually.
			# Or we can do precise rotation.
			# For now let's just let physics process handle movement, and visual might lag slightly or be simple.
			
		else:
			# Attack
			velocity.x = 0
			velocity.z = 0
			attack_timer -= delta
			if attack_timer <= 0:
				attack_timer = attack_rate
				attack_target()

	move_and_slide()

func attack_target():
	if target.has_method("take_damage"):
		target.take_damage(damage)
		if audio_player and attack_sound:
			audio_player.stream = attack_sound
			audio_player.play()

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
