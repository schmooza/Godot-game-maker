extends Node
const TrackSave = preload("res://scripts/track_save.gd")
var marks: Array = []
var undone: Array = []
func clear_data() -> void:
	marks.clear()
	undone.clear()
func paint(pos: Vector2, width: float, erase: bool) -> void:
	marks.append({"x": pos.x, "y": pos.y, "width": width, "erase": erase})
	undone.clear()
func paint_segment(a: Vector2, b: Vector2, width: float, erase: bool) -> void:
	marks.append({"x": a.x, "y": a.y, "x2": b.x, "y2": b.y, "width": width, "erase": erase})
	undone.clear()
func undo() -> void:
	if not marks.is_empty():
		undone.append(marks.pop_back())
func redo() -> void:
	if not undone.is_empty():
		marks.append(undone.pop_back())
func contains(pos: Vector2) -> bool:
	var wet := false
	for mark in marks:
		var a := Vector2(float(mark["x"]), float(mark["y"]))
		var b := Vector2(float(mark.get("x2", mark["x"])), float(mark.get("y2", mark["y"])))
		var t: float = clampf((pos - a).dot(b - a) / maxf((b - a).length_squared(), 0.001), 0.0, 1.0)
		if pos.distance_to(a.lerp(b, t)) <= float(mark["width"]) * 0.5:
			wet = not bool(mark["erase"])
	return wet
func save_data(path: String) -> void:
	TrackSave.write_json(path, marks)
func load_data(path: String) -> void:
	clear_data()
	if FileAccess.file_exists(path):
		var data: Variant = TrackSave.read_json(path)
		if data is Array:
			marks = data
