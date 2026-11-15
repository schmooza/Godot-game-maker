extends Node
var position := Vector2.ZERO
var direction := 0.0
func remember(pos: Vector2, angle: float) -> void:
	position = pos
	direction = angle
func respawn(controller: Control) -> void:
	controller.car_position = position
	controller.car_angle = direction
	controller.car_speed = 0.0
	controller.car_jump.reset()
	controller.status.text = "Water! Returned to last checkpoint."
