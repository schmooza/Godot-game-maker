extends Node
const TrackSave = preload("res://scripts/track_save.gd")
## Independent, per-track retractable spike layer.
## Timing is configurable and stored separately for each track.
var up_seconds := 2.0
var down_seconds := 3.0
var preview_enabled := true
var marks: Array = []
var undone: Array = []
var cycle_time := 0.0

func tick(delta: float) -> void:
    if preview_enabled:
        cycle_time = fmod(cycle_time + delta, up_seconds + down_seconds)

func extended() -> bool:
    return cycle_time < up_seconds

func set_timing(up: float, down: float) -> void:
    up_seconds = maxf(up, 0.1)
    down_seconds = maxf(down, 0.1)
    cycle_time = fmod(cycle_time, up_seconds + down_seconds)

func clear_data() -> void:
    marks.clear()
    undone.clear()
    cycle_time = 0.0

func paint_segment(a: Vector2, b: Vector2, width: float, erase: bool) -> void:
    marks.append({"x": a.x, "y": a.y, "x2": b.x, "y2": b.y, "width": width, "erase": erase})
    undone.clear()

func undo() -> void:
    if not marks.is_empty():
        undone.append(marks.pop_back())

func redo() -> void:
    if not undone.is_empty():
        marks.append(undone.pop_back())

func danger_at(pos: Vector2) -> bool:
    if not extended():
        return false
    var on_spikes := false
    for mark in marks:
        var a := Vector2(float(mark["x"]), float(mark["y"]))
        var b := Vector2(float(mark.get("x2", mark["x"])), float(mark.get("y2", mark["y"])))
        var ab := b - a
        var t: float = clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
        if pos.distance_to(a.lerp(b, t)) <= float(mark["width"]) * 0.5:
            on_spikes = not bool(mark["erase"])
    return on_spikes

func save_data(path: String) -> void:
    TrackSave.write_json(path, {"marks": marks, "up_seconds": up_seconds, "down_seconds": down_seconds})
func load_data(path: String) -> void:
    clear_data()
    set_timing(2.0, 3.0)
    if FileAccess.file_exists(path):
        var data: Variant = TrackSave.read_json(path)
        if data is Array:
            marks = data # Legacy spike drawings
        elif data is Dictionary:
            if data.get("marks", []) is Array:
                marks = data["marks"]
            set_timing(float(data.get("up_seconds", 2.0)), float(data.get("down_seconds", 3.0)))
