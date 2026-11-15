extends Control
## Student-facing black-line track editor and timed racing game.
const CANVAS := Vector2(900, 560)
const SCORE_PATH := "user://racing_best_times.json"
const TRACK_LIBRARY_PATH := "user://racing_track_library.json"
const TRACKS_DIR := "user://racing_tracks"
var track_library: Array = []
var active_track_id := ""
var track_selector: OptionButton
var switching_tracks := false
var track_image: Image
var track_texture: Texture2D
var scenery_texture: Texture2D
const SCENERY_PATH := "user://racing_scenery.png"
var car_texture: Texture2D
var car_sprite_width := 42.0
var car_size_spin: SpinBox
var car_front_direction := 0 # 0=Top, 1=Bottom, 2=Left, 3=Right
var car_front_select: OptionButton
var car_preview: TextureRect
var car_front_preview_label: Label
const CAR_SPRITE_PATH := "user://racing_car_sprite.png"
var track_points: Array[Vector2] = []
var playing := false
var car_position := Vector2.ZERO
var car_angle := 0.0
var car_speed := 0.0
var road_width := 48.0
var acceleration := 150.0
var max_forward_speed := 230.0
var brake_strength := 260.0
var coast_drag := 85.0
var total_laps := 3
var lap := 0
var elapsed := 0.0
var timer_started := false
var lap_start := 0.0
var best_lap := INF
var checkpoints := [false, false, false]
var last_progress := 0.0
var last_checkpoint := -1
var scores: Array = []
var track_view: Control
var car_view: Control
var checkpoint_targets: Array[Vector2] = []
var custom_checkpoints: Array[Vector2] = []
var race_mode := false
var placing_checkpoints := false
var placing_start := false
var custom_start_position := Vector2(-1.0, -1.0)
var start_toggle_button: Button
var checkpoint_info: Label
var checkpoint_toggle_button: Button
var road_cells: Dictionary = {}
const ROAD_CELL_SIZE := 24
var road_spin: SpinBox
var laps_spin: SpinBox
var sensor_spin: SpinBox
var lap_sensor_radius := 100.0
var acceleration_spin: SpinBox
var max_speed_spin: SpinBox
var brake_spin: SpinBox
var status: Label
var timer_label: Label
var map_hud_label: Label
var score_label: Label
var dialog: FileDialog
var car_dialog: FileDialog
var scenery_dialog: FileDialog
var scene_panel: VBoxContainer
var race_panel: VBoxContainer
var track_file := "user://racing_track.png"

func _ready() -> void:
	_build()
	_load_track_library()
	_load_track()
	_load_scores()
	_load_car_sprite()
	_update_car_front_preview()
	_load_scenery()
	_update_status()
	set_process(true)

func _build() -> void:
	var root := VBoxContainer.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var toolbar := HBoxContainer.new()
	root.add_child(toolbar)
	_button(toolbar, "← Games", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	_button(toolbar, "Import black-line track", _open_track_dialog)
	_button(toolbar, "Import car sprite", _open_car_dialog)
	_button(toolbar, "Import scenery", _open_scenery_dialog)
	_button(toolbar, "Edit Track", _edit_track)
	_button(toolbar, "Play / Test", _start)
	_button(toolbar, "Restart", _start)
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 330
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 310
	scroll.add_child(sidebar)
	scene_panel = _section(sidebar, "TRACK & GAME SETTINGS", Color("#70c2fa"))
	var select_label := Label.new()
	select_label.text = "Saved tracks (each has its own race records)"
	scene_panel.add_child(select_label)
	track_selector = OptionButton.new()
	track_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_selector.item_selected.connect(_select_track)
	scene_panel.add_child(track_selector)
	var instructions := Label.new()
	instructions.text = "Draw ONE continuous closed black line on white.\nSave as PNG and import it.\nUse WASD to drive.\nStay on the generated road."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var sensor_label := Label.new()
	sensor_label.text = "Lap sensor radius (pixels)"
	scene_panel.add_child(sensor_label)
	sensor_spin = SpinBox.new()
	sensor_spin.min_value = 30
	sensor_spin.max_value = 200
	sensor_spin.step = 5
	sensor_spin.value = lap_sensor_radius
	sensor_spin.tooltip_text = "Detection radius for checkpoints and the finish line. Saved separately for each track."
	sensor_spin.value_changed.connect(_on_sensor_radius_changed)
	scene_panel.add_child(sensor_spin)
	var sprite_size_label := Label.new()
	sprite_size_label.text = "Car sprite width (pixels)"
	scene_panel.add_child(sprite_size_label)
	car_size_spin = SpinBox.new()
	car_size_spin.min_value = 16
	car_size_spin.max_value = 100
	car_size_spin.step = 2
	car_size_spin.value = car_sprite_width
	car_size_spin.value_changed.connect(func(value: float): car_sprite_width = value; _save_config(); car_view.queue_redraw())
	scene_panel.add_child(car_size_spin)
	var front_label := Label.new()
	front_label.text = "Which side is the FRONT of your car PNG?"
	front_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scene_panel.add_child(front_label)
	car_front_select = OptionButton.new()
	for side in ["Top", "Bottom", "Left", "Right"]:
		car_front_select.add_item(side)
	car_front_select.item_selected.connect(_on_car_front_changed)
	scene_panel.add_child(car_front_select)
	car_front_preview_label = Label.new()
	car_front_preview_label.text = "FRONT: ↑ Top"
	scene_panel.add_child(car_front_preview_label)
	car_preview = TextureRect.new()
	car_preview.custom_minimum_size = Vector2(140, 110)
	car_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	car_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	scene_panel.add_child(car_preview)
	var drive_heading := Label.new()
	drive_heading.text = "CAR ACCELERATION & BRAKING"
	scene_panel.add_child(drive_heading)
	var accel_label := Label.new()
	accel_label.text = "Acceleration (pixels/s²)"
	scene_panel.add_child(accel_label)
	acceleration_spin = SpinBox.new()
	acceleration_spin.min_value = 20
	acceleration_spin.max_value = 800
	acceleration_spin.step = 10
	acceleration_spin.value = acceleration
	acceleration_spin.value_changed.connect(func(v: float): acceleration = v; _save_config())
	scene_panel.add_child(acceleration_spin)
	var speed_label := Label.new()
	speed_label.text = "Maximum speed (pixels/s)"
	scene_panel.add_child(speed_label)
	max_speed_spin = SpinBox.new()
	max_speed_spin.min_value = 40
	max_speed_spin.max_value = 600
	max_speed_spin.step = 10
	max_speed_spin.value = max_forward_speed
	max_speed_spin.value_changed.connect(func(v: float): max_forward_speed = v; _save_config())
	scene_panel.add_child(max_speed_spin)
	var brake_label := Label.new()
	brake_label.text = "Braking strength (pixels/s²)"
	scene_panel.add_child(brake_label)
	brake_spin = SpinBox.new()
	brake_spin.min_value = 40
	brake_spin.max_value = 1000
	brake_spin.step = 10
	brake_spin.value = brake_strength
	brake_spin.value_changed.connect(func(v: float): brake_strength = v; _save_config())
	scene_panel.add_child(brake_spin)
	var cp_title := Label.new()
	cp_title.text = "CUSTOM LAP CHECKPOINTS"
	scene_panel.add_child(cp_title)
	checkpoint_info = Label.new()
	checkpoint_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scene_panel.add_child(checkpoint_info)
	checkpoint_toggle_button = Button.new()
	checkpoint_toggle_button.text = "START placing checkpoints"
	checkpoint_toggle_button.pressed.connect(_begin_checkpoint_placement)
	scene_panel.add_child(checkpoint_toggle_button)
	_button(scene_panel, "Undo last checkpoint", _undo_checkpoint)
	_button(scene_panel, "Clear checkpoints", _clear_checkpoints)
	_update_checkpoint_info()
	start_toggle_button = Button.new()
	start_toggle_button.text = "SET start position (click road)"
	start_toggle_button.pressed.connect(_toggle_start_placement)
	scene_panel.add_child(start_toggle_button)
	race_panel = _section(sidebar, "RACE TIMES", Color("#8cdea6"))
	timer_label = Label.new()
	race_panel.add_child(timer_label)
	score_label = Label.new()
	race_panel.add_child(score_label)
	# Separate HUD from the track: it has its own reserved row above the canvas.
	var game_column := VBoxContainer.new()
	game_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(game_column)
	var hud_row := HBoxContainer.new()
	game_column.add_child(hud_row)
	var hud_spacer := Control.new()
	hud_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud_row.add_child(hud_spacer)
	var hud_panel := PanelContainer.new()
	hud_row.add_child(hud_panel)
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.07, 0.09, 0.12, 0.95)
	hud_style.corner_radius_top_left = 7
	hud_style.corner_radius_top_right = 7
	hud_style.corner_radius_bottom_left = 7
	hud_style.corner_radius_bottom_right = 7
	hud_style.content_margin_left = 12
	hud_style.content_margin_right = 12
	hud_style.content_margin_top = 7
	hud_style.content_margin_bottom = 7
	hud_panel.add_theme_stylebox_override("panel", hud_style)
	map_hud_label = Label.new()
	map_hud_label.add_theme_color_override("font_color", Color.WHITE)
	map_hud_label.add_theme_font_size_override("font_size", 16)
	map_hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_panel.add_child(map_hud_label)
	var holder := AspectRatioContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.ratio = CANVAS.x / CANVAS.y
	holder.stretch_mode = AspectRatioContainer.STRETCH_FIT
	game_column.add_child(holder)
	var canvas_layer := Control.new()
	canvas_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.add_child(canvas_layer)
	track_view = Control.new()
	track_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track_view.set_script(load("res://scripts/racing_view.gd"))
	track_view.set("controller", self)
	canvas_layer.add_child(track_view)
	track_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	car_view = Control.new()
	car_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	car_view.set_script(load("res://scripts/racing_car_view.gd"))
	car_view.set("controller", self)
	canvas_layer.add_child(car_view)
	car_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status = Label.new()
	root.add_child(status)
	dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.add_filter("*.png", "PNG track")
	dialog.file_selected.connect(_import_track)
	add_child(dialog)
	car_dialog = FileDialog.new()
	car_dialog.access = FileDialog.ACCESS_FILESYSTEM
	car_dialog.use_native_dialog = true
	car_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	car_dialog.add_filter("*.png", "PNG car sprite")
	car_dialog.file_selected.connect(_import_car_sprite)
	add_child(car_dialog)
	scenery_dialog = FileDialog.new()
	scenery_dialog.access = FileDialog.ACCESS_FILESYSTEM
	scenery_dialog.use_native_dialog = true
	scenery_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	scenery_dialog.add_filter("*.png", "PNG scenery")
	scenery_dialog.file_selected.connect(_import_scenery)
	add_child(scenery_dialog)

func _open_scenery_dialog() -> void:
	scenery_dialog.popup_centered_ratio(0.75)

func _import_scenery(path: String) -> void:
	var image := Image.new()
	if image.load(path) != OK:
		status.text = "Could not load scenery PNG."
		return
	image.convert(Image.FORMAT_RGBA8)
	# The scenery fills the entire track canvas; it is not used for road detection.
	image.resize(int(CANVAS.x), int(CANVAS.y), Image.INTERPOLATE_LANCZOS)
	if image.save_png(_scenery_path()) != OK:
		status.text = "Could not save scenery PNG."
		return
	scenery_texture = ImageTexture.create_from_image(image)
	status.text = "Scenery imported. The road is drawn on top."
	track_view.queue_redraw()

func _load_scenery() -> void:
	scenery_texture = null
	if not FileAccess.file_exists(_scenery_path()):
		track_view.queue_redraw()
		return
	var image := Image.new()
	if image.load(_scenery_path()) == OK:
		scenery_texture = ImageTexture.create_from_image(image)
		track_view.queue_redraw()

func _open_car_dialog() -> void:
	car_dialog.popup_centered_ratio(0.75)

func _import_car_sprite(path: String) -> void:
	var image := Image.new()
	if image.load(path) != OK:
		status.text = "Could not load car PNG."
		return
	image.convert(Image.FORMAT_RGBA8)
	# Trim transparent padding so the car fills its visible rectangle.
	var used: Rect2i = image.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		image = image.get_region(used)
	# Preserve the artist's original orientation. The Front selector
	# controls rotation at draw time, without modifying the PNG.
	# Preserve the imported image detail; scale only when drawing.
	# Limit very large imports to keep student projects responsive.
	var factor: float = minf(1.0, 512.0 / float(maxi(image.get_width(), image.get_height())))
	if factor < 1.0:
		image.resize(maxi(1, int(image.get_width() * factor)), maxi(1, int(image.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
	if image.save_png(CAR_SPRITE_PATH) != OK:
		status.text = "Could not save car sprite."
		return
	car_texture = ImageTexture.create_from_image(image)
	status.text = "Car sprite imported. Select its front direction in the editor."
	_update_car_front_preview()
	car_view.queue_redraw()

func _load_car_sprite() -> void:
	if not FileAccess.file_exists(CAR_SPRITE_PATH):
		return
	var image := Image.new()
	if image.load(CAR_SPRITE_PATH) == OK:
		car_texture = ImageTexture.create_from_image(image)
	_update_car_front_preview()

func _on_car_front_changed(index: int) -> void:
	car_front_direction = index
	_save_config()
	_update_car_front_preview()
	if car_view != null:
		car_view.queue_redraw()

func _update_car_front_preview() -> void:
	if car_front_select != null:
		car_front_select.select(car_front_direction)
	if car_front_preview_label != null:
		var labels := ["↑ Top", "↓ Bottom", "← Left", "→ Right"]
		car_front_preview_label.text = "FRONT: " + labels[car_front_direction]
	if car_preview != null:
		car_preview.texture = car_texture

func _car_front_rotation() -> float:
	match car_front_direction:
		1: return PI
		2: return PI * 0.5
		3: return -PI * 0.5
	return 0.0

func _open_track_dialog() -> void:
	if dialog == null:
		return
	dialog.popup_centered_ratio(0.75)

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
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_build_road_cells()
	track_texture = ImageTexture.create_from_image(img)
	# Every import creates a separate track and an empty leaderboard.
	DirAccess.make_dir_recursive_absolute(TRACKS_DIR)
	active_track_id = str(Time.get_ticks_usec())
	track_file = TRACKS_DIR + "/" + active_track_id + ".png"
	if img.save_png(track_file) != OK:
		status.text = "Could not save imported track."
		return
	var track_name := path.get_file().get_basename()
	track_library.append({"id": active_track_id, "name": track_name})
	_save_track_library()
	_refresh_track_selector()
	scores = []
	_update_score_label()
	scenery_texture = null
	custom_checkpoints.clear()
	placing_checkpoints = false
	placing_start = false
	_restore_start_position()
	_update_start_button()
	_update_checkpoint_info()
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

func _scenery_path() -> String:
	if active_track_id.is_empty():
		return SCENERY_PATH
	return TRACKS_DIR + "/" + active_track_id + "_scenery.png"

func _load_track_library() -> void:
	track_library.clear()
	if FileAccess.file_exists(TRACK_LIBRARY_PATH):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(TRACK_LIBRARY_PATH))
		if saved is Dictionary:
			var saved_tracks: Variant = saved.get("tracks", [])
			if saved_tracks is Array:
				track_library = saved_tracks
			active_track_id = str(saved.get("active", ""))
	# Preserve an existing single-track installation and its old leaderboard.
	if track_library.is_empty() and FileAccess.file_exists("user://racing_track.png"):
		DirAccess.make_dir_recursive_absolute(TRACKS_DIR)
		active_track_id = "original"
		DirAccess.copy_absolute("user://racing_track.png", TRACKS_DIR + "/original.png")
		if FileAccess.file_exists(SCENERY_PATH):
			DirAccess.copy_absolute(SCENERY_PATH, _scenery_path())
		track_library.append({"id": active_track_id, "name": "Original track"})
		_save_track_library()
	if active_track_id.is_empty() and not track_library.is_empty():
		active_track_id = str(track_library[0].get("id", ""))
	track_file = TRACKS_DIR + "/" + active_track_id + ".png" if not active_track_id.is_empty() else "user://racing_track.png"
	_refresh_track_selector()
	_restore_sensor_radius()
	_restore_checkpoints()
	_restore_start_position()

func _save_track_library() -> void:
	var file := FileAccess.open(TRACK_LIBRARY_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"active": active_track_id, "tracks": track_library}))

func _refresh_track_selector() -> void:
	if track_selector == null:
		return
	switching_tracks = true
	track_selector.clear()
	for i in range(track_library.size()):
		var item: Dictionary = track_library[i]
		track_selector.add_item(str(item.get("name", "Track " + str(i + 1))))
		if str(item.get("id", "")) == active_track_id:
			track_selector.select(i)
	switching_tracks = false

func _on_sensor_radius_changed(value: float) -> void:
	lap_sensor_radius = value
	if switching_tracks or active_track_id.is_empty():
		return
	for i in range(track_library.size()):
		var entry: Dictionary = track_library[i]
		if str(entry.get("id", "")) == active_track_id:
			entry["lap_sensor_radius"] = lap_sensor_radius
			track_library[i] = entry
			_save_track_library()
			break

func _restore_sensor_radius() -> void:
	var radius := 100.0
	for entry in track_library:
		if str(entry.get("id", "")) == active_track_id:
			radius = float(entry.get("lap_sensor_radius", 100.0))
			break
	lap_sensor_radius = clampf(radius, 30.0, 200.0)
	# Avoid overwriting the stored value while switching tracks.
	switching_tracks = true
	sensor_spin.value = lap_sensor_radius
	switching_tracks = false

func _select_track(index: int) -> void:
	if switching_tracks or index < 0 or index >= track_library.size():
		return
	active_track_id = str(track_library[index].get("id", ""))
	track_file = TRACKS_DIR + "/" + active_track_id + ".png"
	_save_track_library()
	_restore_sensor_radius()
	_restore_checkpoints()
	_restore_start_position()
	placing_checkpoints = false
	placing_start = false
	_update_start_button()
	playing = false
	timer_started = false
	elapsed = 0.0
	lap_start = 0.0
	lap = 0
	best_lap = INF
	car_speed = 0.0
	track_points.clear()
	track_texture = null
	road_cells.clear()
	if FileAccess.file_exists(track_file):
		var img := Image.new()
		if img.load(track_file) == OK:
			track_image = img
			track_texture = ImageTexture.create_from_image(img)
			track_points = _extract_line(img)
			_build_road_cells()
	_load_scenery()
	_load_scores()
	_reset_car()
	_update_status()
	track_view.queue_redraw()
	car_view.queue_redraw()
	status.text = "Track selected. Press Play / Test to race."

func _load_track() -> void:
	var cfg: Dictionary = SharedData.scenes.get("racing", {})
	road_width = float(cfg.get("road_width", 48.0))
	car_sprite_width = float(cfg.get("car_sprite_width", 42.0))
	car_front_direction = clampi(int(cfg.get("car_front_direction", 0)), 0, 3)
	_update_car_front_preview()
	car_size_spin.value = car_sprite_width
	total_laps = int(cfg.get("race_laps", 3))
	acceleration = float(cfg.get("acceleration", 150.0))
	max_forward_speed = float(cfg.get("max_speed", 230.0))
	brake_strength = float(cfg.get("brake_strength", 260.0))
	acceleration_spin.value = acceleration
	max_speed_spin.value = max_forward_speed
	brake_spin.value = brake_strength
	road_spin.value = road_width
	laps_spin.value = total_laps
	if FileAccess.file_exists(track_file):
		var img := Image.new()
		if img.load(track_file) == OK:
			track_image = img
			track_texture = ImageTexture.create_from_image(img)
			track_points = _extract_line(img)
			_build_road_cells()
	_reset_car()

func _save_config() -> void:
	SharedData.scenes["racing"]["road_width"] = road_width
	SharedData.scenes["racing"]["car_sprite_width"] = car_sprite_width
	SharedData.scenes["racing"]["car_front_direction"] = car_front_direction
	SharedData.scenes["racing"]["race_laps"] = total_laps
	SharedData.scenes["racing"]["acceleration"] = acceleration
	SharedData.scenes["racing"]["max_speed"] = max_forward_speed
	SharedData.scenes["racing"]["brake_strength"] = brake_strength
	SharedData.save()

func _reset_car() -> void:
	if track_points.is_empty():
		car_position = CANVAS / 2.0
	else:
			car_position = _start_position()
	car_angle = _starting_track_angle()
	car_speed = 0.0
	if car_view != null:
		car_view.queue_redraw()

# Estimate the local road direction using nearby black pixels.
# Follow the road tangent toward the first student-defined checkpoint.
# This makes the car face the intended lap direction at spawn.
func _starting_track_angle() -> float:
	if track_points.is_empty():
		return 0.0
	var center: Vector2 = car_position
	var radius: float = maxf(24.0, road_width * 0.6)
	var radius_sq: float = radius * radius
	var mean := Vector2.ZERO
	var count: int = 0
	for point in track_points:
		if point.distance_squared_to(center) <= radius_sq:
			mean += point
			count += 1
	if count < 3:
		return 0.0
	mean /= float(count)
	var xx: float = 0.0
	var xy: float = 0.0
	var yy: float = 0.0
	for point in track_points:
		if point.distance_squared_to(center) <= radius_sq:
			var delta: Vector2 = point - mean
			xx += delta.x * delta.x
			xy += delta.x * delta.y
			yy += delta.y * delta.y
	# Principal axis of local black-line pixels (tangent to the road).
	var theta: float = 0.5 * atan2(2.0 * xy, xx - yy)
	var tangent := Vector2(cos(theta), sin(theta))
	# The checkpoint sequence determines which of the two road directions is correct.
	# Point the front toward checkpoint 1, rather than always choosing "up".
	if not custom_checkpoints.is_empty():
		var to_first: Vector2 = custom_checkpoints[0] - center
		if to_first.length_squared() > 0.001 and tangent.dot(to_first) < 0.0:
			tangent = -tangent
	else:
		# Before checkpoints exist, use the old deterministic orientation.
		if tangent.y > 0.0 or (absf(tangent.y) < 0.01 and tangent.x < 0.0):
			tangent = -tangent
	return Vector2.UP.angle_to(tangent)

func _edit_track() -> void:
	playing = false
	race_mode = false
	placing_checkpoints = false
	placing_start = false
	_update_checkpoint_info()
	_update_start_button()
	_reset_car()
	status.text = "EDIT TRACK: checkpoints and start marker visible. Use the left panel to edit."
	track_view.queue_redraw()
	_update_status()

func _start() -> void:
	if track_points.size() < 100:
		status.text = "Import a black-line track first."
		return
	_reset_car()
	playing = true
	race_mode = true
	placing_checkpoints = false
	placing_start = false
	_update_checkpoint_info()
	_update_start_button()
	track_view.queue_redraw()
	lap = 0
	elapsed = 0.0
	timer_started = false
	lap_start = 0.0
	best_lap = INF
	if custom_checkpoints.size() < 3:
		playing = false
		race_mode = false
		track_view.queue_redraw()
		status.text = "Place at least 3 checkpoints around this track before racing."
		return
	checkpoint_targets = custom_checkpoints.duplicate()
	checkpoints = []
	checkpoints.resize(checkpoint_targets.size())
	checkpoints.fill(false)
	last_checkpoint = -1
	# The old automatic bounds checkpoints are no longer used.
	var bounds := Rect2(track_points[0], Vector2.ZERO)
	for point in track_points:
		bounds = bounds.expand(point)
	# Checkpoints are student-defined, in the order they were placed.
	_update_status()

func _build_road_cells() -> void:
	road_cells.clear()
	for point in track_points:
		var key := Vector2i(int(floor(point.x / ROAD_CELL_SIZE)), int(floor(point.y / ROAD_CELL_SIZE)))
		if not road_cells.has(key):
			road_cells[key] = []
		road_cells[key].append(point)

func _on_road(p: Vector2) -> bool:
	if road_cells.is_empty() and not track_points.is_empty():
		_build_road_cells()
	var radius: float = road_width * 0.5
	var limit: float = radius * radius
	var cell := Vector2i(int(floor(p.x / ROAD_CELL_SIZE)), int(floor(p.y / ROAD_CELL_SIZE)))
	var reach: int = int(ceil(radius / ROAD_CELL_SIZE)) + 1
	for y in range(cell.y - reach, cell.y + reach + 1):
		for x in range(cell.x - reach, cell.x + reach + 1):
			var key := Vector2i(x, y)
			if road_cells.has(key):
				for point in road_cells[key]:
					if point.distance_squared_to(p) < limit:
						return true
	return false

func _process(delta: float) -> void:
	if not playing:
		return
	# WASD-only controls; physical keys avoid focused UI widgets consuming input.
	var steer := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var throttle := Input.is_physical_key_pressed(KEY_W)
	var braking := Input.is_physical_key_pressed(KEY_S)
	if throttle and not braking:
		car_speed = move_toward(car_speed, max_forward_speed, acceleration * delta)
	elif braking and not throttle:
		# S brakes a moving car, then reverses when stopped.
		if car_speed > 0.0:
			car_speed = move_toward(car_speed, 0.0, brake_strength * delta)
		else:
			car_speed = move_toward(car_speed, -max_forward_speed * 0.45, acceleration * delta)
	else:
		car_speed = move_toward(car_speed, 0.0, coast_drag * delta)
	if abs(car_speed) > 5:
		car_angle += steer * 2.4 * delta * sign(car_speed)
	var next := car_position + Vector2.UP.rotated(car_angle) * car_speed * delta
	if _on_road(next):
		# Start the clock only after the car actually moves on the road.
		if not timer_started and next.distance_squared_to(car_position) > 0.000001:
			timer_started = true
		car_position = next
	else:
		car_speed = 0.0
	if timer_started:
		elapsed += delta
		_check_lap()
	_update_status()
	car_view.queue_redraw()

func _check_lap() -> void:
	# Student-defined checkpoints must be crossed in placement order.
	# This prevents repeated finish-line crossings from awarding laps.
	if track_points.is_empty():
		return
	var targets := checkpoint_targets
	for i in range(targets.size()):
		if last_checkpoint == i - 1 and car_position.distance_to(targets[i]) < lap_sensor_radius:
			checkpoints[i] = true
			last_checkpoint = i
	if last_checkpoint == targets.size() - 1 and car_position.distance_to(_start_position()) < lap_sensor_radius:
		var lap_time := elapsed - lap_start
		if lap_time > 2.0:
			best_lap = min(best_lap, lap_time)
			lap += 1
			lap_start = elapsed
			last_checkpoint = -1
			checkpoints.fill(false)
			if lap >= total_laps:
				playing = false
				_record_score(elapsed)
				_update_score_label()
				status.text = "RACE COMPLETE! Time: " + _fmt(elapsed)


func _update_start_button() -> void:
	if start_toggle_button != null:
		start_toggle_button.text = "STOP setting start (click again)" if placing_start else "SET start position (click road)"

func _toggle_start_placement() -> void:
	if track_points.is_empty():
		status.text = "Import a track before setting its start."
		return
	playing = false
	race_mode = false
	placing_checkpoints = false
	_update_checkpoint_info()
	placing_start = not placing_start
	_update_start_button()
	status.text = "Click the road to set the start / finish position." if placing_start else "Start placement finished."
	track_view.queue_redraw()

func _set_start_at(map_position: Vector2) -> void:
	if not placing_start or playing:
		return
	if not _on_road(map_position):
		status.text = "The start must be on the road."
		return
	var snapped: Vector2 = _nearest_track(map_position)
	for checkpoint in custom_checkpoints:
		if snapped.distance_to(checkpoint) < lap_sensor_radius * 2.1:
			status.text = "Start is too close to a checkpoint. Choose another location."
			return
	custom_start_position = snapped
	_save_start_position()
	_reset_car()
	placing_start = false
	_update_start_button()
	status.text = "Start / finish saved for this track. Car aligned to the road."
	track_view.queue_redraw()

func _save_start_position() -> void:
	if active_track_id.is_empty():
		return
	for i in range(track_library.size()):
		var entry: Dictionary = track_library[i]
		if str(entry.get("id", "")) == active_track_id:
			entry["start_position"] = [custom_start_position.x, custom_start_position.y]
			track_library[i] = entry
			_save_track_library()
			break

func _restore_start_position() -> void:
	custom_start_position = Vector2(-1.0, -1.0)
	for entry in track_library:
		if str(entry.get("id", "")) == active_track_id:
			var stored: Variant = entry.get("start_position", [])
			if stored is Array and stored.size() == 2:
				custom_start_position = Vector2(float(stored[0]), float(stored[1]))
			break

func _update_checkpoint_info() -> void:
	if checkpoint_info == null:
		return
	var count := custom_checkpoints.size()
	checkpoint_info.text = "%d checkpoint(s) placed. Click START, then click the road in driving order. Click STOP when finished. Minimum 3. Finish is the car's start position." % count
	if checkpoint_toggle_button != null:
		checkpoint_toggle_button.text = "STOP placing checkpoints (click again)" if placing_checkpoints else "START placing checkpoints"

func _begin_checkpoint_placement() -> void:
	if track_points.is_empty():
		status.text = "Import a track before placing checkpoints."
		return
	playing = false
	race_mode = false
	placing_start = false
	_update_start_button()
	placing_checkpoints = not placing_checkpoints
	_update_checkpoint_info()
	status.text = "Click the road to add checkpoints in driving order." if placing_checkpoints else "Checkpoint placement finished."
	track_view.queue_redraw()

func _undo_checkpoint() -> void:
	if not custom_checkpoints.is_empty():
		custom_checkpoints.pop_back()
		_save_checkpoints()
	_update_checkpoint_info()
	track_view.queue_redraw()

func _clear_checkpoints() -> void:
	custom_checkpoints.clear()
	placing_checkpoints = false
	_update_checkpoint_info()
	_save_checkpoints()
	_update_checkpoint_info()
	track_view.queue_redraw()

func _add_checkpoint_at(map_position: Vector2) -> void:
	if not placing_checkpoints or playing:
		return
	if not _on_road(map_position):
		status.text = "Place checkpoints on the road."
		return
	var snapped := _nearest_track(map_position)
	# Avoid overlapping sensors, which would allow checkpoint skipping.
	var min_gap: float = lap_sensor_radius * 2.1
	if snapped.distance_to(_start_position()) < min_gap:
		status.text = "Checkpoint too close to the finish/start sensor."
		return
	for other in custom_checkpoints:
		if snapped.distance_to(other) < min_gap:
			status.text = "Checkpoint too close to another checkpoint."
			return
	custom_checkpoints.append(snapped)
	_reset_car()
	_save_checkpoints()
	_update_checkpoint_info()
	status.text = "Checkpoint %d placed. Add more or click Place again to finish." % custom_checkpoints.size()
	track_view.queue_redraw()

func _save_checkpoints() -> void:
	if active_track_id.is_empty():
		return
	var positions: Array = []
	for point in custom_checkpoints:
		positions.append([point.x, point.y])
	for i in range(track_library.size()):
		var entry: Dictionary = track_library[i]
		if str(entry.get("id", "")) == active_track_id:
			entry["checkpoints"] = positions
			track_library[i] = entry
			_save_track_library()
			break

func _restore_checkpoints() -> void:
	custom_checkpoints.clear()
	for entry in track_library:
		if str(entry.get("id", "")) == active_track_id:
			var stored: Variant = entry.get("checkpoints", [])
			if stored is Array:
				for pair in stored:
					if pair is Array and pair.size() == 2:
						custom_checkpoints.append(Vector2(float(pair[0]), float(pair[1])))
			break
	_update_checkpoint_info()

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
	if custom_start_position.x >= 0.0 and custom_start_position.y >= 0.0:
		return custom_start_position
	if track_points.is_empty():
		return CANVAS / 2.0
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
	if map_hud_label != null:
		var shown_lap: int = mini(lap + 1, total_laps)
		var current_time: float = maxf(0.0, elapsed - lap_start)
		var record_text := "--:--" if scores.is_empty() else _fmt(float(scores[0]))
		var next_checkpoint_text := "FINISH" if last_checkpoint >= custom_checkpoints.size() - 1 else str(last_checkpoint + 2)
		if last_checkpoint < 0:
			next_checkpoint_text = "1"
		map_hud_label.text = "LAP  %d / %d\nTIME  %s\nBEST LAP  %s\nRECORD  %s\nSPEED  %d px/s\nNEXT  %s" % [shown_lap, total_laps, _fmt(current_time), "--:--" if is_inf(best_lap) else _fmt(best_lap), record_text, int(round(absf(car_speed))), next_checkpoint_text]

	if not playing:
		_update_score_label()

func _update_score_label() -> void:
	var record_text := "--:--" if scores.is_empty() else _fmt(float(scores[0]))
	var rows := "BEST RACE RECORD: %s\nTOP 10 RACE TIMES\n" % record_text
	for i in range(min(10, scores.size())):
		rows += "%d. %s\n" % [i + 1, _fmt(float(scores[i]))]
	score_label.text = rows

func _record_score(time: float) -> void:
	scores.append(time)
	scores.sort()
	if scores.size() > 10:
		scores.resize(10)
	var f := FileAccess.open(_score_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(scores))

func _score_path() -> String:
	if active_track_id.is_empty():
		return SCORE_PATH
	return TRACKS_DIR + "/" + active_track_id + "_scores.json"

func _load_scores() -> void:
	scores = []
	var path := _score_path()
	if active_track_id == "original" and not FileAccess.file_exists(path) and FileAccess.file_exists(SCORE_PATH):
		DirAccess.copy_absolute(SCORE_PATH, path)
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Array:
			scores = parsed
	_update_score_label()
