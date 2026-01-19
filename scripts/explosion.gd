extends Node3D

@onready var particles_fire = $FireParticles
@onready var particles_smoke = $SmokeParticles
@onready var audio_player = $AudioStreamPlayer3D

var sounds = [
	preload("res://sounds/explosions/explosion-3-386885.mp3"),
	preload("res://sounds/explosions/explosion-fx-343683.mp3"),
	preload("res://sounds/explosions/loud-explosion-sound-425458.mp3"),
	preload("res://sounds/explosions/nuclear-explosion-386181.mp3")
]

func _ready():
	# Random Sound
	if sounds.size() > 0 and audio_player:
		audio_player.stream = sounds.pick_random()
		audio_player.pitch_scale = randf_range(0.8, 1.2)
		audio_player.play()
	
	# Start Particles
	if particles_fire: 
		particles_fire.one_shot = true
		particles_fire.emitting = true
		particles_fire.restart()
		
	if particles_smoke: 
		particles_smoke.one_shot = true
		particles_smoke.emitting = true
		particles_smoke.restart()
