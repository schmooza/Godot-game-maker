extends Control
var controller: Control
func _draw() -> void:
	var c: Variant = controller
	var scale_factor: float = minf(size.x / 900.0, size.y / 560.0)
	var pos: Vector2 = c.car_position
	var angle: float = c.car_angle
	if c.car_texture != null:
		var source_size: Vector2 = c.car_texture.get_size()
		# Car body is a portrait rectangle: front at the short top edge.
		# Draw into a consistent 1:1.7 body shape, regardless of source PNG ratio.
		var sprite_size := Vector2(c.car_sprite_width, c.car_sprite_width * 1.7)
		draw_set_transform(pos * scale_factor, angle, Vector2.ONE * scale_factor)
		draw_texture_rect(c.car_texture, Rect2(-sprite_size * 0.5, sprite_size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# Rectangular default car, with windscreen at the front (short edge).
		var car_rect := Rect2(Vector2(-c.car_sprite_width * 0.5, -c.car_sprite_width * 0.85), Vector2(c.car_sprite_width, c.car_sprite_width * 1.7))
		draw_set_transform(pos * scale_factor, angle, Vector2.ONE * scale_factor)
		draw_rect(car_rect, Color("#d83c39"))
		draw_rect(Rect2(car_rect.position + Vector2(5, 5), Vector2(car_rect.size.x - 10, 9)), Color("#b8e8f5"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
