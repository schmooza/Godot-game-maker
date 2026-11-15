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
	if c.water_hazards != null:
		for mark in c.water_hazards.marks:
			var pos := Vector2(float(mark["x"]), float(mark["y"]))
			var radius := float(mark["width"]) * 0.5
			var end_pos := Vector2(float(mark.get("x2", mark["x"])), float(mark.get("y2", mark["y"])))
			var tint := Color("#666666") if mark["erase"] else Color("#42b9e8")
			draw_line(pos, end_pos, tint, radius * 2.0, true)
			draw_circle(pos, radius, tint)
			draw_circle(end_pos, radius, tint)
	if c.spike_hazards != null:
		var extended: bool = c.spike_hazards.extended()
		for mark in c.spike_hazards.marks:
			var pos := Vector2(float(mark["x"]), float(mark["y"]))
			var end_pos := Vector2(float(mark.get("x2", mark["x"])), float(mark.get("y2", mark["y"])))
			var width: float = float(mark["width"])
			var tint := Color("#666666") if bool(mark["erase"]) else (Color("#dc4444") if extended else Color("#9b9292"))
			draw_line(pos, end_pos, tint, width, true)
			draw_circle(pos, width * 0.5, tint)
			draw_circle(end_pos, width * 0.5, tint)
			if not bool(mark["erase"]) and extended:
				var distance: float = pos.distance_to(end_pos)
				var steps: int = maxi(1, int(distance / 16.0))
				var direction: Vector2 = (end_pos - pos).normalized()
				var normal: Vector2 = direction.orthogonal()
				for i in range(steps + 1):
					var center: Vector2 = pos.lerp(end_pos, float(i) / float(steps))
					var triangle := PackedVector2Array([center - normal * 7.0, center + normal * 7.0, center + direction * 9.0])
					draw_colored_polygon(triangle, Color("#ffe1a0"))
	if c.paint_mode != "none" and c.pending_draw_point.x >= 0.0:
		draw_circle(c.pending_draw_point, 6.0, Color("#ffcc33"))
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

# Simple point-to-point editor: one click sets A, the next sets B.
# Mouse dragging is deliberately disabled.
func _input(event: InputEvent) -> void:
	if controller == null or not is_visible_in_tree():
		return
	if not (event is InputEventMouseButton):
		return
	var factor: float = minf(size.x / 900.0, size.y / 560.0)
	if factor <= 0.0:
		return
	var local_pos: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
	var inside := Rect2(Vector2.ZERO, size).has_point(local_pos)
	if controller.paint_mode != "none" and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and inside:
		controller._paint_at(local_pos / factor)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and inside:
		if controller.placing_checkpoints or controller.placing_start:
			if controller.placing_start:
				controller._set_start_at(local_pos / factor)
			else:
				controller._add_checkpoint_at(local_pos / factor)
			get_viewport().set_input_as_handled()
