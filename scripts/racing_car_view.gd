extends Control
var controller: Control
func _draw() -> void:
	var c: Variant = controller
	var scale_factor: float = minf(size.x / 900.0, size.y / 560.0)
	var pos: Vector2 = c.car_position
	var angle: float = c.car_angle
	var jumping: bool = c.car_jump != null and c.car_jump.airborne()
	var display_texture: Texture2D = c.flying_car_texture if jumping and c.flying_car_texture != null else c.car_texture
	if jumping:
		draw_circle(pos * scale_factor + Vector2(5, 8), c.car_sprite_width * 0.55 * scale_factor, Color(0, 0, 0, 0.25))
	if display_texture != null:
		var source_size: Vector2 = display_texture.get_size()
		# Preserve the source aspect ratio. Scale the long axis to car length;
		# the student chooses which edge is the front, without reimporting.
		var long_edge: float = c.car_sprite_width * 1.7
		var factor: float = long_edge / maxf(source_size.x, source_size.y)
		var sprite_size: Vector2 = source_size * factor
		# Rotate the PNG's chosen front edge to face local UP, then steer.
		draw_set_transform(pos * scale_factor, angle + c._car_front_rotation(), Vector2.ONE * scale_factor * (1.2 if jumping else 1.0))
		draw_texture_rect(display_texture, Rect2(-sprite_size * 0.5, sprite_size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# Rectangular default car, with windscreen at the front (short edge).
		var car_rect := Rect2(Vector2(-c.car_sprite_width * 0.5, -c.car_sprite_width * 0.85), Vector2(c.car_sprite_width, c.car_sprite_width * 1.7))
		draw_set_transform(pos * scale_factor, angle, Vector2.ONE * scale_factor * (1.2 if jumping else 1.0))
		draw_rect(car_rect, Color("#d83c39"))
		draw_rect(Rect2(car_rect.position + Vector2(5, 5), Vector2(car_rect.size.x - 10, 9)), Color("#b8e8f5"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
