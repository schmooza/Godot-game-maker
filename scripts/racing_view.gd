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
	if not c.track_points.is_empty():
		var start: Vector2 = c._start_position()
		draw_circle(start, 9, Color("#00cfcf"))
