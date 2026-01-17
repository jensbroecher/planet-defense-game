extends Node

signal credits_changed(new_amount)

var credits = 100

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
