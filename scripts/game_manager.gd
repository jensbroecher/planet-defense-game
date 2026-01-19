extends Node

signal credits_changed(new_amount)
signal notification_requested(text, duration)
signal game_over
signal victory
signal wave_state_changed(state_name)

enum GameState { PRE_WAVE, WAVE_ACTIVE, WAVE_CLEARED, GAME_OVER, VICTORY }
var current_state = GameState.PRE_WAVE

var credits = 500

func notify(text, duration=2.0):
	emit_signal("notification_requested", text, duration)
	print("NOTIFICATION: ", text) # Keep console for debug
var passive_income_accumulator = 0.0
var hq_count = 0

func register_hq():
	hq_count += 1
	print("HQ Registered. Count: ", hq_count)

func unregister_hq():
	hq_count = max(0, hq_count - 1)
	print("HQ Unregistered. Count: ", hq_count)




func add_credits(amount):
	credits += amount
	emit_signal("credits_changed", credits)
	print("Credits added: ", amount, " | Total: ", credits)

func spend_credits(amount):
	if credits >= amount:
		credits -= amount
		emit_signal("credits_changed", credits)
		print("Credits spent: ", amount, " | Total: ", credits)
		return true
	else:
		print("Not enough credits!")
		return false

func has_credits(amount):
	return credits >= amount

func trigger_game_over():
	if current_state != GameState.GAME_OVER:
		current_state = GameState.GAME_OVER
		emit_signal("game_over")
		print("GAME OVER TRIGGERED")

func trigger_victory():
	if current_state != GameState.VICTORY:
		current_state = GameState.VICTORY
		emit_signal("victory")
		print("VICTORY TRIGGERED")

func restart_game():
	# Reset values
	credits = 500
	passive_income_accumulator = 0.0
	hq_count = 0
	current_state = GameState.PRE_WAVE
	get_tree().reload_current_scene()
# Audio
var voice_player: AudioStreamPlayer
var voices = {
	"wave_incoming": preload("res://sounds/voices/attack wave incoming.mp3"),
	"base_attack": preload("res://sounds/voices/base is under attack.mp3"),
	"no_resources": preload("res://sounds/voices/not enough resources.mp3"),
	"repairing": preload("res://sounds/voices/repairing.mp3")
}

func _ready():
	voice_player = AudioStreamPlayer.new()
	add_child(voice_player)
	voice_player.volume_db = 0.0 # Adjust as needed

func play_voice(key):
	if voices.has(key):
		# Don't interrupt if same voice is playing? Or just play.
		# For alerts, we probably want to hear them.
		voice_player.stream = voices[key]
		voice_player.play()
		print("Playing Voice: ", key)

var base_attack_cooldown = 0.0

func _process(delta):
	# ... existing process code ...
	if base_attack_cooldown > 0:
		base_attack_cooldown -= delta

	passive_income_accumulator += delta
	if passive_income_accumulator >= 1.0:
		passive_income_accumulator -= 1.0
		add_credits(1)

func play_base_attack_alert():
	if base_attack_cooldown <= 0:
		play_voice("base_attack")
		base_attack_cooldown = 15.0 # Don't repeat for 15 seconds
