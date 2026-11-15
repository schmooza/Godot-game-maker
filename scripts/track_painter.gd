extends Node
const TrackSave = preload("res://scripts/track_save.gd")
var strokes: Array = []
var redo_strokes: Array = []
func clear_data() -> void:
	strokes.clear()
	redo_strokes.clear()
func paint(pos: Vector2, width: float, erase: bool) -> void:
	strokes.append({"x": pos.x, "y": pos.y, "width": width, "erase": erase})
	redo_strokes.clear()
func paint_segment(a: Vector2, b: Vector2, width: float, erase: bool) -> void:
	strokes.append({"x": a.x, "y": a.y, "x2": b.x, "y2": b.y, "width": width, "erase": erase})
	redo_strokes.clear()
func undo() -> void:
	if not strokes.is_empty():
		redo_strokes.append(strokes.pop_back())
func redo() -> void:
	if not redo_strokes.is_empty():
		strokes.append(redo_strokes.pop_back())
func combined_points(base: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = base.duplicate()
	for stroke in strokes:
		var a := Vector2(float(stroke["x"]), float(stroke["y"]))
		var b := Vector2(float(stroke.get("x2", stroke["x"])), float(stroke.get("y2", stroke["y"])))
		var radius := float(stroke["width"]) * 0.5
		var distance := a.distance_to(b)
		var steps := maxi(1, ceili(distance / 3.0))
		if stroke["erase"]:
			var kept: Array[Vector2] = []
			for point in result:
				var t: float = clampf((point - a).dot(b - a) / maxf((b - a).length_squared(), 0.001), 0.0, 1.0)
				if point.distance_to(a.lerp(b, t)) > radius:
					kept.append(point)
			result = kept
		else:
			for i in range(steps + 1):
				result.append(a.lerp(b, float(i) / float(steps)))
	return result
func save_data(path: String) -> void:
	TrackSave.write_json(path, strokes)
func load_data(path: String) -> void:
	clear_data()
	if FileAccess.file_exists(path):
		var data: Variant = TrackSave.read_json(path)
		if data is Array:
			strokes = data
