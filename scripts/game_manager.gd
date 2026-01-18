extends Node

signal credits_changed(new_amount)

var credits = 500
var passive_income_accumulator = 0.0

func _process(delta):
	passive_income_accumulator += delta
	if passive_income_accumulator >= 1.0:
		passive_income_accumulator -= 1.0
		add_credits(1)


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
