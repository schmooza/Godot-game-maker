extends Control
var controller: Control
func _draw() -> void:
	var c: Variant = controller
	var scale_factor: float = minf(size.x / 900.0, size.y / 560.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
	draw_rect(Rect2(Vector2.ZERO, Vector2(900, 560)), Color.WHITE)
	if c.scenery_texture != null:
		draw_texture_rect(c.scenery_texture, Rect2(Vector2.ZERO, Vector2(900, 560)), false)
	if c.track_texture != null:
		draw_texture_rect(c.track_texture, Rect2(Vector2.ZERO, Vector2(900, 560)), false, Color(1, 1, 1, 0.2))
	for p in c.track_points:
		draw_circle(p, c.road_width * 0.5, Color("#666666"))
	for p in c.track_points:
		draw_circle(p, 1.0, Color("#eaeaea"))
	if not c.race_mode:
		if not c.track_points.is_empty():
			var start: Vector2 = c._start_position()
			draw_circle(start, 9, Color("#00cfcf"))
	# In race mode, replace checkpoint sensors with compact road-direction guides.
	# These are hints, not the hidden detection areas.
	if c.race_mode and not c.track_points.is_empty():
		var start: Vector2 = c._start_position()
		draw_circle(start, 5.0, Color("#22d66e"))
		draw_string(ThemeDB.fallback_font, start + Vector2(8, -9), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#166b3b"))
		var points: Array[Vector2] = []
		points.append(start)
		for checkpoint in c.custom_checkpoints:
			points.append(checkpoint)
		points.append(start)
		for i in range(1, points.size() - 1):
			var here: Vector2 = points[i]
			var direction: Vector2 = (points[i + 1] - points[i - 1]).normalized()
			if direction.length_squared() < 0.01:
				direction = (points[i + 1] - here).normalized()
			var tip: Vector2 = here + direction * 14.0
			var back: Vector2 = here - direction * 12.0
			var side: Vector2 = direction.orthogonal() * 8.0
			draw_line(back, tip, Color("#f5d552"), 4.0, true)
			draw_colored_polygon(PackedVector2Array([tip, tip - direction * 12.0 + side, tip - direction * 12.0 - side]), Color("#f5d552"))
	# Checkpoints are editing guides only, never visible in play mode.
	if not c.race_mode:
		for i in range(c.custom_checkpoints.size()):
			var target: Vector2 = c.custom_checkpoints[i]
			draw_arc(target, c.lap_sensor_radius, 0.0, TAU, 48, Color("#f5c542", 0.65), 2.0)
			draw_circle(target, 7.0, Color("#f5c542"))
			draw_string(ThemeDB.fallback_font, target + Vector2(10, -10), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.BLACK)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if controller.placing_checkpoints or controller.placing_start:
			var factor: float = minf(size.x / 900.0, size.y / 560.0)
			if factor > 0.0:
				if controller.placing_start:
					controller._set_start_at(event.position / factor)
				else:
					controller._add_checkpoint_at(event.position / factor)
			accept_event()
