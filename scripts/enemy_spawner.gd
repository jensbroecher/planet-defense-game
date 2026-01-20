extends Node3D

@export var spawn_interval = 2.0
@export var spawn_radius = 150.0

# Wave Settings
@export var start_delay = 5.0 # Delay before warnings start
@export var warmup_time = 20.0 # 20 seconds before wave
@export var wave_duration = 60.0 # Enemies spawn for 60 seconds
var current_time = 0.0
var wave_started = false
var spawning_finished = false
var victory_triggered = false
var initial_warning_given = false

var enemy_scenes = [
	"res://scenes/enemies/enemy.tscn",
	"res://scenes/enemies/enemy.tscn",
	"res://scenes/enemies/enemy_heavy.tscn",
	"res://scenes/enemies/enemy_fast.tscn",
	"res://scenes/enemies/enemy_fast.tscn",
	"res://scenes/enemies/enemy_fast.tscn",
	"res://scenes/enemies/dropship.tscn"
]

var loaded_scenes = []

var spawn_timer = 0.0

func _ready():
	for path in enemy_scenes:
		var scene = load(path)
		if scene:
			loaded_scenes.append(scene)
		else:
			push_error("Failed to load enemy scene at path: " + path)
	
	# Delay warning until start_delay passes process

func _process(delta):
	if GameManager.current_state == GameManager.GameState.GAME_OVER or GameManager.current_state == GameManager.GameState.VICTORY:
		return

	current_time += delta
	
	# Phase 0: Start Delay
	if current_time < start_delay:
		return # Wait
		
	if not initial_warning_given:
		initial_warning_given = true
		# Notify UI of start
		GameManager.notify("INCOMING ATTACK IN " + str(int(warmup_time)) + " SECONDS!", 5.0)
		GameManager.play_voice("wave_incoming")
		current_time = 0.0 # Reset time for warmup counting
	
	# Phase 1: Warmup
	if not wave_started:
		if current_time >= warmup_time:
			start_wave()
		else:
			# Optional: Notify countdown at certain intervals?
			if abs(warmup_time - current_time - 10.0) < 0.1: # 10s mark
				GameManager.notify("10 Seconds to Impact!", 2.0)
			if abs(warmup_time - current_time - 5.0) < 0.1:
				GameManager.notify("PREPARE FOR BATTLE!", 2.0)
	
	# Phase 2: Wave Active
	elif not spawning_finished:
		spawn_timer -= delta
		if spawn_timer <= 0:
			spawn_enemy()
			spawn_timer = spawn_interval
			
		# Check if wave duration exceeded
		if current_time >= (warmup_time + wave_duration):
			spawning_finished = true
			GameManager.notify("Wave Spawning Complete! Destroy Remaining Enemies!", 5.0)
	
	# Phase 3: Cleanup
	else:
		if not victory_triggered:
			var enemies = get_tree().get_nodes_in_group("enemies")
			if enemies.size() == 0:
				trigger_victory()

func start_wave():
	wave_started = true
	GameManager.current_state = GameManager.GameState.WAVE_ACTIVE
	GameManager.notify("WARNING: INCOMING ATTACK WAVE!", 5.0)
	print("Wave Started!")

func trigger_victory():
	victory_triggered = true
	GameManager.trigger_victory()

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
