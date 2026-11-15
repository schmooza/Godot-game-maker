extends Control
## Student-facing black-line track editor and timed racing game.
const CANVAS := Vector2(900, 560)
const SCORE_PATH := "user://racing_best_times.json"
var track_image: Image
var track_texture: Texture2D
var track_points: Array[Vector2] = []
var playing := false
var car_position := Vector2.ZERO
var car_angle := 0.0
var car_speed := 0.0
var road_width := 48.0
var total_laps := 3
var lap := 0
var elapsed := 0.0
var lap_start := 0.0
var best_lap := INF
var checkpoints := [false, false, false]
var last_progress := 0.0
var last_checkpoint := -1
var scores: Array = []
var track_view: Control
var road_spin: SpinBox
var laps_spin: SpinBox
var status: Label
var timer_label: Label
var score_label: Label
var dialog: FileDialog
var scene_panel: VBoxContainer
var race_panel: VBoxContainer
var track_file := "user://racing_track.png"

func _ready() -> void:
	_load_scores()
	_build()
	_load_track()
	_update_status()
	set_process(true)

func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)
	_button(toolbar, "← Games", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	_button(toolbar, "Import black-line track", func(): dialog.popup_centered_ratio(0.75))
	_button(toolbar, "Edit Track", func(): playing = false; _update_status(); track_view.queue_redraw())
	_button(toolbar, "Play / Test", _start)
	_button(toolbar, "Restart", _start)
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 265
	content.add_child(scroll)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 250
	scroll.add_child(sidebar)
	scene_panel = _section(sidebar, "TRACK & GAME SETTINGS", Color("#70c2fa"))
	var instructions := Label.new()
	instructions.text = "Draw ONE continuous closed black line on white.\nSave as PNG and import it.\nUse arrow keys or WASD to drive.\nStay on the generated road."
	scene_panel.add_child(instructions)
	var road_label := Label.new()
	road_label.text = "Road width (pixels)"
	scene_panel.add_child(road_label)
	road_spin = SpinBox.new()
	road_spin.min_value = 18
	road_spin.max_value = 120
	road_spin.value = 48
	road_spin.value_changed.connect(func(v: float): road_width = v; _save_config(); track_view.queue_redraw())
	scene_panel.add_child(road_spin)
	var lap_label := Label.new()
	lap_label.text = "Race laps"
	scene_panel.add_child(lap_label)
	laps_spin = SpinBox.new()
	laps_spin.min_value = 1
	laps_spin.max_value = 20
	laps_spin.value = 3
	laps_spin.value_changed.connect(func(v: float): total_laps = int(v); _save_config(); _update_status())
	scene_panel.add_child(laps_spin)
	_button(scene_panel, "Set car start at first track point", _reset_car)
	race_panel = _section(sidebar, "RACE TIMES", Color("#8cdea6"))
	timer_label = Label.new()
	race_panel.add_child(timer_label)
	score_label = Label.new()
	race_panel.add_child(score_label)
	var holder := AspectRatioContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.ratio = CANVAS.x / CANVAS.y
	content.add_child(holder)
	track_view = Control.new()
	track_view.custom_minimum_size = CANVAS
	track_view.set_script(load("res://scripts/racing_view.gd"))
	track_view.set("controller", self)
	holder.add_child(track_view)
	status = Label.new()
	root.add_child(status)
	dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.png", "PNG track")
	dialog.file_selected.connect(_import_track)
	add_child(dialog)

func _section(parent: Node, title: String, accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#292929")
	style.border_width_left = 4
	style.border_color = accent
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var body := VBoxContainer.new()
	panel.add_child(body)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_color_override("font_color", accent)
	body.add_child(heading)
	return body

func _button(parent: Node, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(action)
	parent.add_child(button)

func _import_track(path: String) -> void:
	var img := Image.new()
	if img.load(path) != OK:
		status.text = "Could not load PNG."
		return
	img.convert(Image.FORMAT_RGBA8)
	img.resize(int(CANVAS.x), int(CANVAS.y), Image.INTERPOLATE_BILINEAR)
	var detected := _extract_line(img)
	if detected.size() < 100:
		status.text = "Track not detected. Draw one continuous black line on white."
		return
	track_image = img
	track_points = detected
	track_texture = ImageTexture.create_from_image(img)
	img.save_png(track_file)
	_reset_car()
	playing = false
	status.text = "Track imported. Set road width, then Play / Test."
	track_view.queue_redraw()

func _extract_line(img: Image) -> Array[Vector2]:
	# Black pixels become road centreline; sampled for efficient collision tests.
	var pts: Array[Vector2] = []
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			var c := img.get_pixel(x, y)
			if c.r < 0.38 and c.g < 0.38 and c.b < 0.38 and c.a > 0.6:
				pts.append(Vector2(x, y))
	return pts

func _load_track() -> void:
	var cfg: Dictionary = SharedData.scenes.get("racing", {})
	road_width = float(cfg.get("road_width", 48.0))
	total_laps = int(cfg.get("race_laps", 3))
	road_spin.value = road_width
	laps_spin.value = total_laps
	if FileAccess.file_exists(track_file):
		var img := Image.new()
		if img.load(track_file) == OK:
			track_image = img
			track_texture = ImageTexture.create_from_image(img)
			track_points = _extract_line(img)
	_reset_car()

func _save_config() -> void:
	SharedData.scenes["racing"]["road_width"] = road_width
	SharedData.scenes["racing"]["race_laps"] = total_laps
	SharedData.save()

func _reset_car() -> void:
	if track_points.is_empty():
		car_position = CANVAS / 2.0
	else:
		# Pick the leftmost point as a deterministic start/finish marker.
		car_position = track_points[0]
		for p in track_points:
			if p.x < car_position.x:
				car_position = p
	car_angle = -PI / 2.0
	car_speed = 0.0
	if track_view != null:
		track_view.queue_redraw()

func _start() -> void:
	if track_points.size() < 100:
		status.text = "Import a black-line track first."
		return
	_reset_car()
	playing = true
	lap = 0
	elapsed = 0.0
	lap_start = 0.0
	best_lap = INF
	checkpoints = [false, false, false]
	last_checkpoint = -1
	_update_status()

func _on_road(p: Vector2) -> bool:
	var limit := (road_width * 0.5) * (road_width * 0.5)
	for point in track_points:
		if point.distance_squared_to(p) < limit:
			return true
	return false

func _process(delta: float) -> void:
	if not playing:
		return
	var steer := Input.get_axis("ui_left", "ui_right")
	var accelerate := Input.get_axis("ui_down", "ui_up")
	car_speed = move_toward(car_speed, accelerate * 230.0, 230.0 * delta)
	if abs(car_speed) > 5:
		car_angle += steer * 2.4 * delta * sign(car_speed)
	var next := car_position + Vector2.UP.rotated(car_angle) * car_speed * delta
	if _on_road(next):
		car_position = next
	else:
		car_speed = 0.0
	elapsed += delta
	_check_lap()
	_update_status()
	track_view.queue_redraw()

func _check_lap() -> void:
	# Three spatial checkpoints in order, followed by the start area.
	# This prevents repeated finish-line crossings from awarding laps.
	if track_points.is_empty():
		return
	var bounds := Rect2(track_points[0], Vector2.ZERO)
	for p in track_points:
		bounds = bounds.expand(p)
	var targets := [_nearest_track(Vector2(bounds.end.x, bounds.position.y + bounds.size.y * 0.35)), _nearest_track(Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.end.y)), _nearest_track(Vector2(bounds.position.x, bounds.position.y + bounds.size.y * 0.65))]
	for i in range(3):
		if last_checkpoint == i - 1 and car_position.distance_to(targets[i]) < max(road_width, 65.0):
			checkpoints[i] = true
			last_checkpoint = i
	if last_checkpoint == 2 and car_position.distance_to(_start_position()) < road_width * 0.75:
		var lap_time := elapsed - lap_start
		if lap_time > 2.0:
			best_lap = min(best_lap, lap_time)
			lap += 1
			lap_start = elapsed
			last_checkpoint = -1
			checkpoints = [false, false, false]
			if lap >= total_laps:
				playing = false
				_record_score(elapsed)
				status.text = "RACE COMPLETE! Time: " + _fmt(elapsed)

func _nearest_track(pos: Vector2) -> Vector2:
	var best := track_points[0]
	var distance := INF
	for point in track_points:
		var d := point.distance_squared_to(pos)
		if d < distance:
			distance = d
			best = point
	return best

func _start_position() -> Vector2:
	var leftmost := track_points[0]
	for p in track_points:
		if p.x < leftmost.x:
			leftmost = p
	return leftmost

func _fmt(seconds: float) -> String:
	var minutes := int(seconds) / 60
	return "%02d:%05.2f" % [minutes, fmod(seconds, 60.0)]

func _update_status() -> void:
	if timer_label == null:
		return
	timer_label.text = "Lap: %d / %d\nCurrent: %s\nBest lap: %s" % [lap, total_laps, _fmt(elapsed - lap_start), "—" if is_inf(best_lap) else _fmt(best_lap)]
	var rows := "TOP 10 RACE TIMES\n"
	for i in range(min(10, scores.size())):
		rows += "%d. %s\n" % [i + 1, _fmt(float(scores[i]))]
	score_label.text = rows

func _record_score(time: float) -> void:
	scores.append(time)
	scores.sort()
	if scores.size() > 10:
		scores.resize(10)
	var f := FileAccess.open(SCORE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(scores))

func _load_scores() -> void:
	if FileAccess.file_exists(SCORE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCORE_PATH))
		if parsed is Array:
			scores = parsed
