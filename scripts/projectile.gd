extends Area3D

var speed = 40.0
var damage = 10
var life_time = 5.0

func _ready():
	# Delete after life_time seconds
	await get_tree().create_timer(life_time).timeout
	queue_free()

func _physics_process(delta):
	position -= transform.basis.z * speed * delta

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
	
	queue_free()
