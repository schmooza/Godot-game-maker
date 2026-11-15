extends Control
const TrackSave = preload("res://scripts/track_save.gd")
var optional_audio: Node
var game_intro: Node
var _brake_sound_active := false
var editable_tooltips: Node
## Student-facing black-line track editor and timed racing game.
const CANVAS := Vector2(900, 560)
const SCORE_PATH := "user://racing_best_times.json"
const TRACK_LIBRARY_PATH := "user://racing_track_library.json"
const TRACKS_DIR := "user://racing_tracks"
var track_library: Array = []
var active_track_id := ""
var track_selector: OptionButton
var track_name_input: LineEdit
var delete_track_dialog: ConfirmationDialog
var delete_track_id := ""
var switching_tracks := false
var track_image: Image
var track_texture: Texture2D
var scenery_texture: Texture2D
const SCENERY_PATH := "user://racing_scenery.png"
var car_texture: Texture2D
var flying_car_texture: Texture2D
var flying_dialog: FileDialog
var track_painter: Node
var water_hazards: Node
var spike_hazards: Node
var car_jump: Node
var jump_key := KEY_SPACE
var jump_key_selector: OptionButton
var jump_duration := 0.85
var jump_duration_spin: SpinBox
var track_data_loaded := false
var checkpoint_respawn: Node
var paint_mode := "none"
var pending_draw_point := Vector2(-1.0, -1.0)
var paint_brush := 28.0
var paint_brush_spin: SpinBox
const FLYING_SPRITE_PATH := "user://racing_flying_car.png"
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
var lap_record := INF
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
var start_x_spin: SpinBox
var start_y_spin: SpinBox
var start_angle_spin: SpinBox
var manual_start_angle := -1.0
var updating_start_controls := false
var checkpoint_info: Label
var checkpoint_toggle_button: Button
var road_cells: Dictionary = {}
const ROAD_CELL_SIZE := 24
var road_spin: SpinBox
var laps_spin: SpinBox
var sensor_spin: SpinBox
var start_sensor_spin: SpinBox
var lap_sensor_radius := 25.0
var start_sensor_radius := 25.0
var acceleration_spin: SpinBox
var max_speed_spin: SpinBox
var brake_spin: SpinBox
var status: Label
var timer_label: Label
var map_hud_label: Label
var score_label: Label
var last_race_time := -1.0
var dialog: FileDialog
var car_dialog: FileDialog
var scenery_dialog: FileDialog
var scene_panel: VBoxContainer
var race_panel: VBoxContainer
var track_file := "user://racing_track.png"

func _ready() -> void:
	_build()
	_install_racing_modules()
	_install_editable_tooltips()
	_install_optional_audio()
	_install_game_intro()
	_reset_old_tracks_once()
	_load_track_library()
	if track_library.is_empty():
		_new_blank_track()
	# Restore the active track's PNG, painted layers, hazards and checkpoints.
	# Previously only the library metadata was loaded on returning to Racing.
	if not active_track_id.is_empty():
		var selected_index := 0
		for i in range(track_library.size()):
			if str(track_library[i].get("id", "")) == active_track_id:
				selected_index = i
				break
		_select_track(selected_index)
	_load_track()
	_load_scores()
	_load_car_sprite()
	_load_flying_car_sprite()
	_update_car_front_preview()
	_load_scenery()
	_update_status()
	set_process(true)

# One-time migration: start this edition with one blank track.
# Marker prevents resetting student work on subsequent launches.
const BLANK_RESET_MARKER := "user://racing_blank_reset_v1.flag"

func _reset_old_tracks_once() -> void:
	if FileAccess.file_exists(BLANK_RESET_MARKER):
		return
	# Remove the old track library, its backups and all track assets.
	var folder := DirAccess.open(TRACKS_DIR)
	if folder != null:
		folder.list_dir_begin()
		var entry_name := folder.get_next()
		while not entry_name.is_empty():
			if not folder.current_is_dir():
				DirAccess.remove_absolute(TRACKS_DIR + "/" + entry_name)
			entry_name = folder.get_next()
		folder.list_dir_end()
	for legacy_path in [TRACK_LIBRARY_PATH, TRACK_LIBRARY_PATH + ".bak", "user://racing_track.png", SCORE_PATH]:
		if FileAccess.file_exists(legacy_path):
			DirAccess.remove_absolute(legacy_path)
	# Write the marker before creating the first blank track.
	var marker_file := FileAccess.open(BLANK_RESET_MARKER, FileAccess.WRITE)
	if marker_file != null:
		marker_file.store_string("reset complete")
		marker_file.close()

func _save_track_button() -> void:
	_save_current_track()
	status.text = "Track saved."

func _on_jump_key_selected(index: int) -> void:
	jump_key = jump_key_selector.get_item_id(index)
	_save_jump_key()

func _save_jump_key() -> void:
	if active_track_id.is_empty() or switching_tracks:
		return
	for i in range(track_library.size()):
		var entry: Dictionary = track_library[i]
		if str(entry.get("id", "")) == active_track_id:
			entry["jump_key"] = jump_key
			track_library[i] = entry
			_save_track_library()
			break

func _restore_jump_key() -> void:
	jump_key = KEY_SPACE
	for entry in track_library:
		if str(entry.get("id", "")) == active_track_id:
			jump_key = int(entry.get("jump_key", KEY_SPACE))
			break
	if jump_key_selector != null:
		for i in range(jump_key_selector.item_count):
			if jump_key_selector.get_item_id(i) == jump_key:
				jump_key_selector.select(i)
				return
		jump_key = KEY_SPACE
		jump_key_selector.select(0)

func _on_jump_duration_changed(value: float) -> void:
	jump_duration = value
	if car_jump != null:
		car_jump.duration = jump_duration
	_save_jump_duration()

func _save_jump_duration() -> void:
	if active_track_id.is_empty() or switching_tracks:
		return
	for i in range(track_library.size()):
		var entry: Dictionary = track_library[i]
		if str(entry.get("id", "")) == active_track_id:
			entry["jump_duration"] = jump_duration
			track_library[i] = entry
			_save_track_library()
			break

func _restore_jump_duration() -> void:
	jump_duration = 0.85
	for entry in track_library:
		if str(entry.get("id", "")) == active_track_id:
			jump_duration = clampf(float(entry.get("jump_duration", 0.85)), 0.1, 5.0)
			break
	if jump_duration_spin != null:
		jump_duration_spin.set_value_no_signal(jump_duration)
	if car_jump != null:
		car_jump.duration = jump_duration

func _return_to_games() -> void:
	_save_current_track()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _exit_tree() -> void:
	# Also save if the user leaves via scene navigation or closes the project.
	_save_current_track()

func _save_current_track() -> void:
	if not track_data_loaded or active_track_id.is_empty() or track_painter == null:
		return
	DirAccess.make_dir_recursive_absolute(TRACKS_DIR)
	track_painter.save_data(_drawing_base() + "_road.json")
	water_hazards.save_data(_drawing_base() + "_water.json")
	spike_hazards.save_data(_drawing_base() + "_spikes.json")
	_save_track_library()

func _install_editable_tooltips() -> void:
	var toolbar_row: HBoxContainer = find_child("TooltipToolbar",true,false) as HBoxContainer
	if toolbar_row == null:
		return
	editable_tooltips = load("res://scripts/editable_tooltips.gd").new()
	add_child(editable_tooltips)
	editable_tooltips.setup(self,toolbar_row,"racing")

func _install_optional_audio() -> void:
	var sidebar: Node = find_child("TooltipScanSidebar",true,false)
	if sidebar == null:
		return
	# ScrollContainer must have a single content child.
	if sidebar is ScrollContainer and sidebar.get_child_count() > 0:
		sidebar = sidebar.get_child(0)
	optional_audio = load("res://scripts/optional_audio.gd").new()
	add_child(optional_audio)
	var sound_events: Array[String] = ["Background Music", "Engine", "Acceleration", "Braking", "Checkpoint", "Lap Complete", "Race Finish"]
	optional_audio.setup(self,sidebar,"racing",sound_events)

func _install_game_intro() -> void:
	var sidebar: Node = find_child("TooltipScanSidebar",true,false)
	if sidebar == null:
		return
	if sidebar is ScrollContainer and sidebar.get_child_count() > 0:
		sidebar = sidebar.get_child(0)
	game_intro = load("res://scripts/game_intro.gd").new()
	add_child(game_intro)
	game_intro.setup(self,sidebar,"racing","2D Car Racing","Drive your car around the track, reach checkpoints and beat your best lap time!")

func _sound(event_name: String) -> void:
	if optional_audio != null:
		optional_audio.play(event_name)

func _build() -> void:
	var root := VBoxContainer.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var toolbar := HBoxContainer.new()
	toolbar.name = "TooltipToolbar"
	root.add_child(toolbar)
	_button(toolbar, "← Games", _return_to_games)
	_button(toolbar, "Import black-line track", _open_track_dialog)
	_button(toolbar, "Import car sprite", _open_car_dialog)
	_button(toolbar, "Import flying car", _open_flying_dialog)
	_button(toolbar, "Import scenery", _open_scenery_dialog)
	_button(toolbar, "Edit Track", _edit_track)
	_button(toolbar, "Save Track", _save_track_button)
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
	sidebar.name = "TooltipScanSidebar"
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
	var name_label := Label.new()
	name_label.text = "Track name"
	scene_panel.add_child(name_label)
	track_name_input = LineEdit.new()
	track_name_input.placeholder_text = "Enter a track name"
	track_name_input.max_length = 40
	track_name_input.text_submitted.connect(func(_entered_name: String): _rename_selected_track())
	scene_panel.add_child(track_name_input)
	_button(scene_panel, "Rename Track", _rename_selected_track)
	_button(scene_panel, "Delete Selected Track", _request_delete_track)
	delete_track_dialog = ConfirmationDialog.new()
	delete_track_dialog.title = "Delete saved track?"
	delete_track_dialog.confirmed.connect(_confirm_delete_track)
	add_child(delete_track_dialog)
	var painter_section := _section(sidebar, "DRAW TRACK & HAZARDS", Color("#52bde2"))
	_button(painter_section, "Road: Point to Point", func(): _set_paint_mode("road"))
	_button(painter_section, "Water: Point to Point", func(): _set_paint_mode("water"))
	_button(painter_section, "Spikes: Point to Point", func(): _set_paint_mode("spikes"))
	_button(painter_section, "Erase Spikes (click A then B)", func(): _set_paint_mode("erase_spikes"))
	var spike_up_label := Label.new()
	spike_up_label.text = "Spikes UP duration (seconds)"
	painter_section.add_child(spike_up_label)
	var spike_up_spin := SpinBox.new()
	spike_up_spin.min_value = 0.1
	spike_up_spin.max_value = 30.0
	spike_up_spin.step = 0.1
	spike_up_spin.value = 2.0
	spike_up_spin.name = "SpikeUpDuration"
	painter_section.add_child(spike_up_spin)
	var spike_down_label := Label.new()
	spike_down_label.text = "Spikes DOWN duration (seconds)"
	painter_section.add_child(spike_down_label)
	var spike_down_spin := SpinBox.new()
	spike_down_spin.min_value = 0.1
	spike_down_spin.max_value = 30.0
	spike_down_spin.step = 0.1
	spike_down_spin.value = 3.0
	spike_down_spin.name = "SpikeDownDuration"
	painter_section.add_child(spike_down_spin)
	spike_up_spin.value_changed.connect(func(v: float):
		if spike_hazards != null:
			spike_hazards.set_timing(v, spike_down_spin.value)
			_save_drawing()
	)
	spike_down_spin.value_changed.connect(func(v: float):
		if spike_hazards != null:
			spike_hazards.set_timing(spike_up_spin.value, v)
			_save_drawing()
	)
	var preview_spikes := CheckBox.new()
	preview_spikes.text = "Preview spike animation in editor"
	preview_spikes.button_pressed = true
	preview_spikes.name = "SpikePreview"
	painter_section.add_child(preview_spikes)
	preview_spikes.toggled.connect(func(enabled: bool):
		if spike_hazards != null:
			spike_hazards.preview_enabled = enabled
	)

	_button(painter_section, "Erase Road (click A then B)", func(): _set_paint_mode("erase_road"))
	_button(painter_section, "Erase Water (click A then B)", func(): _set_paint_mode("erase_water"))
	_button(painter_section, "Stop Drawing", func(): _set_paint_mode("none"))
	paint_brush_spin = SpinBox.new()
	paint_brush_spin.min_value = 8
	paint_brush_spin.max_value = 110
	paint_brush_spin.value = paint_brush
	paint_brush_spin.value_changed.connect(func(v: float): paint_brush = v)
	painter_section.add_child(paint_brush_spin)
	_button(painter_section, "Undo Drawing", _undo_paint)
	_button(painter_section, "Redo Drawing", _redo_paint)
	_button(painter_section, "New Blank Track", _new_blank_track)
	_button(painter_section, "Save Drawing", _save_drawing)
	var jump_control_label := Label.new()
	jump_control_label.text = "Jump control"
	painter_section.add_child(jump_control_label)
	jump_key_selector = OptionButton.new()
	jump_key_selector.add_item("Spacebar", KEY_SPACE)
	jump_key_selector.add_item("J", KEY_J)
	jump_key_selector.add_item("Shift", KEY_SHIFT)
	jump_key_selector.add_item("E", KEY_E)
	jump_key_selector.add_item("F", KEY_F)
	jump_key_selector.item_selected.connect(_on_jump_key_selected)
	painter_section.add_child(jump_key_selector)
	var duration_label := Label.new()
	duration_label.text = "Jump duration (seconds)"
	painter_section.add_child(duration_label)
	jump_duration_spin = SpinBox.new()
	jump_duration_spin.min_value = 0.1
	jump_duration_spin.max_value = 5.0
	jump_duration_spin.step = 0.05
	jump_duration_spin.value = jump_duration
	jump_duration_spin.tooltip_text = "How long the car stays airborne. Does not change speed."
	jump_duration_spin.value_changed.connect(_on_jump_duration_changed)
	painter_section.add_child(jump_duration_spin)
	var jump_hint := Label.new()
	jump_hint.text = "Press the selected Jump key to cross water or raised spikes. Set spike up/down durations above. Hitting raised spikes returns you to the last checkpoint. Import a flying car PNG to change its image in mid-air."
	jump_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	painter_section.add_child(jump_hint)
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
	sensor_label.text = "Checkpoint radius (pixels)"
	scene_panel.add_child(sensor_label)
	sensor_spin = SpinBox.new()
	sensor_spin.min_value = 10
	sensor_spin.max_value = 100
	sensor_spin.step = 1
	sensor_spin.rounded = true
	sensor_spin.value = lap_sensor_radius
	sensor_spin.tooltip_text = "Checkpoint detection radius. Saved per track."
	sensor_spin.value_changed.connect(_on_sensor_radius_changed)
	scene_panel.add_child(sensor_spin)
	var start_sensor_label := Label.new()
	start_sensor_label.text = "Start / finish radius (pixels)"
	scene_panel.add_child(start_sensor_label)
	start_sensor_spin = SpinBox.new()
	start_sensor_spin.min_value = 10
	start_sensor_spin.max_value = 100
	start_sensor_spin.step = 1
	start_sensor_spin.rounded = true
	start_sensor_spin.value = start_sensor_radius
	start_sensor_spin.tooltip_text = "Start / finish detection radius. Saved per track."
	start_sensor_spin.value_changed.connect(_on_start_sensor_radius_changed)
	scene_panel.add_child(start_sensor_spin)
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
	var fine_title := Label.new()
	fine_title.text = "MANUAL START ADJUSTMENT"
	scene_panel.add_child(fine_title)
	var fine_hint := Label.new()
	fine_hint.text = "Fine-tune the start position and car angle. Changes are saved per track."
	fine_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scene_panel.add_child(fine_hint)
	var x_label := Label.new()
	x_label.text = "Start X (pixels)"
	scene_panel.add_child(x_label)
	start_x_spin = SpinBox.new()
	start_x_spin.min_value = 0
	start_x_spin.max_value = int(CANVAS.x)
	start_x_spin.step = 1
	start_x_spin.value_changed.connect(_on_start_position_adjusted)
	scene_panel.add_child(start_x_spin)
	var y_label := Label.new()
	y_label.text = "Start Y (pixels)"
	scene_panel.add_child(y_label)
	start_y_spin = SpinBox.new()
	start_y_spin.min_value = 0
	start_y_spin.max_value = int(CANVAS.y)
	start_y_spin.step = 1
	start_y_spin.value_changed.connect(_on_start_position_adjusted)
	scene_panel.add_child(start_y_spin)
	var angle_label := Label.new()
	angle_label.text = "Starting car angle (degrees)"
	scene_panel.add_child(angle_label)
	start_angle_spin = SpinBox.new()
	start_angle_spin.min_value = 0
	start_angle_spin.max_value = 359
	start_angle_spin.step = 1
	start_angle_spin.value_changed.connect(_on_start_angle_adjusted)
	scene_panel.add_child(start_angle_spin)
	_button(scene_panel, "Reset start angle to AUTO", _reset_start_angle_auto)

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
	flying_dialog = FileDialog.new()
	flying_dialog.access = FileDialog.ACCESS_FILESYSTEM
	flying_dialog.use_native_dialog = true
	flying_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	flying_dialog.add_filter("*.png", "Flying car PNG")
	flying_dialog.file_selected.connect(_import_flying_car_sprite)
	add_child(flying_dialog)
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

func _open_flying_dialog() -> void:
	flying_dialog.popup_centered_ratio(0.75)

func _import_flying_car_sprite(path: String) -> void:
	var img := Image.new()
	if img.load(path) != OK:
		status.text = "Could not load flying car PNG."
		return
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	if used.size.x > 0 and used.size.y > 0:
		img = img.get_region(used)
	if img.save_png(FLYING_SPRITE_PATH) == OK:
		flying_car_texture = ImageTexture.create_from_image(img)
		status.text = "Flying car image saved. It appears while jumping."
		car_view.queue_redraw()

func _load_flying_car_sprite() -> void:
	if FileAccess.file_exists(FLYING_SPRITE_PATH):
		var img := Image.new()
		if img.load(FLYING_SPRITE_PATH) == OK:
			flying_car_texture = ImageTexture.create_from_image(img)

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
	# Godot activates focused Buttons with Space. Keep racing controls
	# independent of toolbar focus so Space remains the jump key.
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)

func _request_delete_track() -> void:
	if active_track_id.is_empty():
		status.text = "No track selected."
		return
	if track_library.size() <= 1:
		status.text = "Keep at least one track. Create another before deleting this one."
		return
	var selected_name := active_track_id
	for entry in track_library:
		if str(entry.get("id", "")) == active_track_id:
			selected_name = str(entry.get("name", active_track_id))
			break
	delete_track_id = active_track_id
	delete_track_dialog.dialog_text = "Permanently delete '%s' and its saved drawings, hazards and records? This cannot be undone." % selected_name
	delete_track_dialog.popup_centered()

func _confirm_delete_track() -> void:
	if delete_track_id.is_empty() or track_library.size() <= 1:
		return
	var removed_id := delete_track_id
	delete_track_id = ""
	var index := -1
	for i in range(track_library.size()):
		if str(track_library[i].get("id", "")) == removed_id:
			index = i
			break
	if index < 0:
		return
	# Never save a deleted track back into its old files during selection.
	track_data_loaded = false
	track_library.remove_at(index)
	for suffix: String in [".png", "_road.json", "_water.json", "_spikes.json", "_scenery.png", "_scores.json", "_scores.json.last", "_scores.json.lap"]:
		var file_path: String = str(TRACKS_DIR) + "/" + removed_id + suffix
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
		var backup_path: String = file_path + ".bak"
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
	if track_library.is_empty():
		active_track_id = ""
		track_file = "user://racing_track.png"
		track_points.clear()
		road_cells.clear()
		track_painter.clear_data()
		water_hazards.clear_data()
		spike_hazards.clear_data()
		_refresh_track_selector()
		_save_track_library()
		track_view.queue_redraw()
		status.text = "Track deleted. Create or import a new track."
	else:
		active_track_id = ""
		_refresh_track_selector()
		_select_track(0)
		_refresh_track_selector()
		status.text = "Track deleted. %d of 5 slots used." % track_library.size()

const MAX_SAVED_TRACKS := 5

func _can_create_track() -> bool:
	if track_library.size() >= MAX_SAVED_TRACKS:
		status.text = "5 tracks saved (maximum). Select an existing track to edit."
		return false
	return true

func _import_track(path: String) -> void:
	if not _can_create_track():
		return
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
	track_painter.clear_data()
	water_hazards.clear_data()
	spike_hazards.clear_data()
	_save_drawing()
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
		var saved: Variant = TrackSave.read_json(TRACK_LIBRARY_PATH)
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
	_restore_jump_key()
	_restore_jump_duration()
	_restore_sensor_radius()
	_restore_checkpoints()
	_restore_start_position()

func _save_track_library() -> void:
	TrackSave.write_json(TRACK_LIBRARY_PATH, {"active": active_track_id, "tracks": track_library})

func _rename_selected_track() -> void:
	if active_track_id.is_empty() or track_name_input == null:
		return
	var new_name: String = track_name_input.text.strip_edges()
	if new_name.is_empty():
		status.text = "Enter a track name first."
		return
	for i in range(track_library.size()):
		var entry: Dictionary = track_library[i]
		if str(entry.get("id", "")) == active_track_id:
			entry["name"] = new_name
			track_library[i] = entry
			_save_track_library()
			_refresh_track_selector()
			status.text = "Track renamed to: " + new_name
			return

func _refresh_track_selector() -> void:
	if track_selector == null:
		return
	switching_tracks = true
	track_selector.clear()
	if track_name_input != null:
		track_name_input.text = ""
	for i in range(track_library.size()):
		var item: Dictionary = track_library[i]
		track_selector.add_item(str(item.get("name", "Track " + str(i + 1))))
		if str(item.get("id", "")) == active_track_id:
			track_selector.select(i)
			if track_name_input != null:
				track_name_input.text = str(item.get("name", "Track " + str(i + 1)))
	switching_tracks = false

func _on_sensor_radius_changed(value: float) -> void:
	lap_sensor_radius = value
	_save_sensor_radii()
	track_view.queue_redraw()

func _on_start_sensor_radius_changed(value: float) -> void:
	start_sensor_radius = value
	_save_sensor_radii()
	track_view.queue_redraw()

func _save_sensor_radii() -> void:
	if switching_tracks or active_track_id.is_empty():
		return
	for i in range(track_library.size()):
		var entry: Dictionary = track_library[i]
		if str(entry.get("id", "")) == active_track_id:
			entry["lap_sensor_radius"] = lap_sensor_radius
			entry["start_sensor_radius"] = start_sensor_radius
			track_library[i] = entry
			_save_track_library()
			break

func _restore_sensor_radius() -> void:
	var checkpoint_radius := 25.0
	var finish_radius := 25.0
	for entry in track_library:
		if str(entry.get("id", "")) == active_track_id:
			checkpoint_radius = float(entry.get("lap_sensor_radius", 25.0))
			finish_radius = float(entry.get("start_sensor_radius", 25.0))
			break
	lap_sensor_radius = clampf(checkpoint_radius, 10.0, 100.0)
	start_sensor_radius = clampf(finish_radius, 10.0, 100.0)
	switching_tracks = true
	sensor_spin.value = lap_sensor_radius
	start_sensor_spin.value = start_sensor_radius
	switching_tracks = false

func _select_track(index: int) -> void:
	if switching_tracks or index < 0 or index >= track_library.size():
		return
	# Save edits to the previous track before switching.
	_save_current_track()
	active_track_id = str(track_library[index].get("id", ""))
	if track_name_input != null:
		track_name_input.text = str(track_library[index].get("name", ""))
	track_image = null
	track_file = TRACKS_DIR + "/" + active_track_id + ".png"
	_save_track_library()
	_restore_jump_key()
	_restore_jump_duration()
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
	_load_drawing_layers()
	_refresh_painted_road()
	track_data_loaded = true
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
	car_angle = deg_to_rad(manual_start_angle) if manual_start_angle >= 0.0 else _starting_track_angle()
	car_speed = 0.0
	_sync_start_controls()
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
	if optional_audio != null:
		optional_audio.stop_all()
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
	if game_intro != null:
		game_intro.show_intro(Callable(self,"_start_actual"))
	else:
		_start_actual()

func _install_racing_modules() -> void:
	track_painter = load("res://scripts/track_painter.gd").new()
	water_hazards = load("res://scripts/water_hazards.gd").new()
	spike_hazards = load("res://scripts/spike_hazards.gd").new()
	car_jump = load("res://scripts/car_jump.gd").new()
	car_jump.duration = jump_duration
	checkpoint_respawn = load("res://scripts/checkpoint_respawn.gd").new()
	for module in [track_painter, water_hazards, spike_hazards, car_jump, checkpoint_respawn]:
		add_child(module)
	_load_drawing_layers()

func _drawing_base() -> String:
	return TRACKS_DIR + "/" + active_track_id

func _load_drawing_layers() -> void:
	track_painter.load_data(_drawing_base() + "_road.json")
	water_hazards.load_data(_drawing_base() + "_water.json")
	spike_hazards.load_data(_drawing_base() + "_spikes.json")
	var up_control: SpinBox = find_child("SpikeUpDuration", true, false)
	var down_control: SpinBox = find_child("SpikeDownDuration", true, false)
	if up_control != null:
		up_control.set_value_no_signal(spike_hazards.up_seconds)
	if down_control != null:
		down_control.set_value_no_signal(spike_hazards.down_seconds)

	if track_view != null:
		track_view.queue_redraw()

func _save_drawing() -> void:
	DirAccess.make_dir_recursive_absolute(TRACKS_DIR)
	track_painter.save_data(_drawing_base() + "_road.json")
	water_hazards.save_data(_drawing_base() + "_water.json")
	spike_hazards.save_data(_drawing_base() + "_spikes.json")
	status.text = "Road and hazard drawing saved."

func _set_paint_mode(mode: String) -> void:
	paint_mode = mode
	pending_draw_point = Vector2(-1.0, -1.0)
	playing = false
	race_mode = false
	placing_checkpoints = false
	placing_start = false
	status.text = "Drawing: " + mode + " — click point A, then point B. Continue clicking to extend."
	track_view.queue_redraw()

func _paint_at(pos: Vector2) -> void:
	if paint_mode == "none":
		return
	pos = pos.clamp(Vector2.ZERO, CANVAS)
	if pending_draw_point.x < 0.0:
		pending_draw_point = pos
		status.text = "Point A set. Click point B to draw a segment."
		track_view.queue_redraw()
		return
	var from_point: Vector2 = pending_draw_point
	if from_point.distance_to(pos) < 2.0:
		return
	if paint_mode == "road" or paint_mode == "erase_road":
		track_painter.paint_segment(from_point, pos, paint_brush, paint_mode == "erase_road")
		track_points = track_painter.combined_points(_base_road_points())
		_build_road_cells()
	elif paint_mode == "water" or paint_mode == "erase_water":
		water_hazards.paint_segment(from_point, pos, paint_brush, paint_mode == "erase_water")
	else:
		spike_hazards.paint_segment(from_point, pos, paint_brush, paint_mode == "erase_spikes")
	pending_draw_point = pos
	_save_drawing()
	status.text = "Segment added. Click next point to extend, or Stop Drawing."
	track_view.queue_redraw()

func _finish_paint() -> void:
	_save_drawing()

func _undo_paint() -> void:
	pending_draw_point = Vector2(-1.0, -1.0)
	if paint_mode == "water" or paint_mode == "erase_water":
		water_hazards.undo()
	elif paint_mode == "spikes" or paint_mode == "erase_spikes":
		spike_hazards.undo()
	else:
		track_painter.undo()
	_refresh_painted_road()

func _redo_paint() -> void:
	pending_draw_point = Vector2(-1.0, -1.0)
	if paint_mode == "water" or paint_mode == "erase_water":
		water_hazards.redo()
	elif paint_mode == "spikes" or paint_mode == "erase_spikes":
		spike_hazards.redo()
	else:
		track_painter.redo()
	_refresh_painted_road()

func _base_road_points() -> Array[Vector2]:
	if track_image != null:
		return _extract_line(track_image)
	return [] as Array[Vector2]

func _refresh_painted_road() -> void:
	track_points = track_painter.combined_points(_base_road_points())
	_build_road_cells()
	if track_data_loaded:
		_save_drawing()
	track_view.queue_redraw()

func _new_blank_track() -> void:
	if not _can_create_track():
		return
	_save_current_track()
	DirAccess.make_dir_recursive_absolute(TRACKS_DIR)
	active_track_id = str(Time.get_ticks_usec())
	track_file = TRACKS_DIR + "/" + active_track_id + ".png"
	track_image = null
	track_texture = null
	track_points.clear()
	road_cells.clear()
	track_painter.clear_data()
	water_hazards.clear_data()
	spike_hazards.clear_data()
	track_library.append({"id": active_track_id, "name": "Drawn Track " + active_track_id})
	_save_track_library()
	_refresh_track_selector()
	custom_checkpoints.clear()
	custom_start_position = Vector2(-1, -1)
	_save_drawing()
	_load_scores()
	_reset_car()
	_set_paint_mode("road")
	status.text = "New track. Click points to draw road segments, then place checkpoints."

func _start_actual() -> void:
	# Save the edited track before beginning a play test.
	_save_current_track()
	# Exit drawing mode before racing so the map receives game input.
	paint_mode = "none"
	pending_draw_point = Vector2(-1.0, -1.0)
	if track_points.size() < 2:
		status.text = "Draw a road or import a black-line track before racing."
		return
	_reset_car()
	car_jump.reset()
	playing = true
	# Clear focus from any editor widget (including SpinBoxes) before driving.
	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control != null:
		focused_control.release_focus()
	_sound("Background Music")
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
	checkpoint_respawn.remember(_nearest_road_point(_start_position()), car_angle)
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

func _nearest_road_point(pos: Vector2) -> Vector2:
	# Checkpoints can be placed just outside the painted road. Respawn safely on it.
	if _on_road(pos) or track_points.is_empty():
		return pos
	var closest: Vector2 = track_points[0]
	var best_distance := closest.distance_squared_to(pos)
	for point in track_points:
		var distance := point.distance_squared_to(pos)
		if distance < best_distance:
			best_distance = distance
			closest = point
	return closest

func _process(delta: float) -> void:
	if spike_hazards != null:
		spike_hazards.tick(delta)
		if track_view != null:
			track_view.queue_redraw()
	if not playing:
		return
	# WASD-only controls; physical keys avoid focused UI widgets consuming input.
	var steer := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var throttle := Input.is_physical_key_pressed(KEY_W)
	var braking := Input.is_physical_key_pressed(KEY_S)
	if throttle and not braking:
		if car_speed <= 0.0:
			_sound("Acceleration")
			_sound("Engine")
		car_speed = move_toward(car_speed, max_forward_speed, acceleration * delta)
	elif braking and not throttle:
		if car_speed > 0.0 and not Input.is_physical_key_pressed(KEY_W):
			if not _brake_sound_active:
				_sound("Braking")
			_brake_sound_active = true
		# S brakes a moving car, then reverses when stopped.
		if car_speed > 0.0:
			car_speed = move_toward(car_speed, 0.0, brake_strength * delta)
		else:
			car_speed = move_toward(car_speed, -max_forward_speed * 0.45, acceleration * delta)
	else:
		_brake_sound_active = false
		car_speed = move_toward(car_speed, 0.0, coast_drag * delta)
	if abs(car_speed) > 5:
		car_angle += steer * 2.4 * delta * sign(car_speed)
	var was_airborne: bool = car_jump.airborne()
	car_jump.tick(delta, Input.is_physical_key_pressed(jump_key))
	var next := car_position + Vector2.UP.rotated(car_angle) * car_speed * delta
	# On landing, the car must be back on a road and clear of water.
	# Otherwise it respawns rather than becoming stranded off-track.
	if was_airborne and not car_jump.airborne() and (not _on_road(next) or (water_hazards.contains(next) or spike_hazards.danger_at(next))):
		checkpoint_respawn.respawn(self)
		_update_status()
		car_view.queue_redraw()
		return
	if (water_hazards.contains(next) or spike_hazards.danger_at(next)) and not car_jump.airborne():
		checkpoint_respawn.respawn(self)
		_update_status()
		car_view.queue_redraw()
		return
	if _on_road(next) or car_jump.airborne():
		# Start the clock only after the car actually moves on the road.
		if not timer_started and next.distance_squared_to(car_position) > 0.000001:
			timer_started = true
		car_position = next
	else:
		if not _on_road(car_position):
			checkpoint_respawn.respawn(self)
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
			_sound("Checkpoint")
			last_checkpoint = i
			checkpoint_respawn.remember(_nearest_road_point(targets[i]), car_angle)
	if last_checkpoint == targets.size() - 1 and car_position.distance_to(_start_position()) < start_sensor_radius:
		var lap_time := elapsed - lap_start
		if lap_time > 2.0:
			best_lap = min(best_lap, lap_time)
			if lap_time < lap_record:
				lap_record = lap_time
				_save_lap_record()
			lap += 1
			_sound("Lap Complete")
			lap_start = elapsed
			last_checkpoint = -1
			checkpoint_respawn.remember(_nearest_road_point(_start_position()), car_angle)
			checkpoints.fill(false)
			if lap >= total_laps:
				if optional_audio != null:
					optional_audio.stop_event("Background Music")
				_sound("Race Finish")
				playing = false
				_record_score(elapsed)
				_update_score_label()
				_update_status()
				status.text = "RACE COMPLETE! Time: " + _fmt(elapsed)


func _update_start_button() -> void:
	if start_toggle_button != null:
		start_toggle_button.text = "STOP setting start (click again)" if placing_start else "SET start position (click road)"

func _toggle_start_placement() -> void:
	paint_mode = "none"
	pending_draw_point = Vector2(-1.0, -1.0)
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
			entry["start_angle_degrees"] = manual_start_angle
			track_library[i] = entry
			_save_track_library()
			break

func _restore_start_position() -> void:
	custom_start_position = Vector2(-1.0, -1.0)
	manual_start_angle = -1.0
	for entry in track_library:
		if str(entry.get("id", "")) == active_track_id:
			var stored: Variant = entry.get("start_position", [])
			if stored is Array and stored.size() == 2:
				custom_start_position = Vector2(float(stored[0]), float(stored[1]))
			manual_start_angle = float(entry.get("start_angle_degrees", -1.0))
			break
	_sync_start_controls()

func _sync_start_controls() -> void:
	if start_x_spin == null or start_y_spin == null or start_angle_spin == null:
		return
	updating_start_controls = true
	var start_pos: Vector2 = _start_position()
	start_x_spin.value = start_pos.x
	start_y_spin.value = start_pos.y
	var angle: float = deg_to_rad(manual_start_angle) if manual_start_angle >= 0.0 else _starting_track_angle()
	start_angle_spin.value = posmod(int(round(rad_to_deg(angle))), 360)
	updating_start_controls = false

func _on_start_position_adjusted(_value: float) -> void:
	if updating_start_controls or track_points.is_empty():
		return
	var proposed := Vector2(start_x_spin.value, start_y_spin.value)
	if not _on_road(proposed):
		status.text = "Start is off the road. Adjust X / Y until it is on the road."
		return
	custom_start_position = proposed
	_save_start_position()
	_reset_car()
	track_view.queue_redraw()
	status.text = "Start position saved for this track."

func _on_start_angle_adjusted(value: float) -> void:
	if updating_start_controls or track_points.is_empty():
		return
	manual_start_angle = value
	_save_start_position()
	_reset_car()
	status.text = "Manual starting angle saved for this track."

func _reset_start_angle_auto() -> void:
	manual_start_angle = -1.0
	_save_start_position()
	_reset_car()
	status.text = "Starting angle restored to automatic road alignment."

func _update_checkpoint_info() -> void:
	if checkpoint_info == null:
		return
	var count := custom_checkpoints.size()
	checkpoint_info.text = "%d checkpoint(s) placed. Click START, then click the road in driving order. Click STOP when finished. Minimum 3. Finish is the car's start position." % count
	if checkpoint_toggle_button != null:
		checkpoint_toggle_button.text = "STOP placing checkpoints (click again)" if placing_checkpoints else "START placing checkpoints"

func _begin_checkpoint_placement() -> void:
	paint_mode = "none"
	pending_draw_point = Vector2(-1.0, -1.0)
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
	if snapped.distance_to(_start_position()) < lap_sensor_radius + start_sensor_radius + 5.0:
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
	timer_label.text = "Lap: %d / %d\nCurrent: %s\nBest lap this race: %s\nLAP RECORD: %s" % [lap, total_laps, _fmt(elapsed - lap_start), "—" if is_inf(best_lap) else _fmt(best_lap), "—" if is_inf(lap_record) else _fmt(lap_record)]
	if map_hud_label != null:
		var shown_lap: int = mini(lap + 1, total_laps)
		var current_time: float = maxf(0.0, elapsed - lap_start)
		if not playing and lap >= total_laps and last_race_time >= 0.0:
			current_time = last_race_time
		var record_text := "--:--" if scores.is_empty() else _fmt(float(scores[0]))
		var next_checkpoint_text := "FINISH" if last_checkpoint >= custom_checkpoints.size() - 1 else str(last_checkpoint + 2)
		if last_checkpoint < 0:
			next_checkpoint_text = "1"
		map_hud_label.text = "LAP  %d / %d\nTIME  %s\nLAP RECORD  %s\n3 LAP TOTAL RECORD  %s\nSPEED  %d px/s\nNEXT  %s" % [shown_lap, total_laps, _fmt(current_time), "--:--" if is_inf(lap_record) else _fmt(lap_record), record_text, int(round(absf(car_speed))), next_checkpoint_text]

	if not playing:
		_update_score_label()

func _update_score_label() -> void:
	var record_text := "--:--" if scores.is_empty() else _fmt(float(scores[0]))
	var last_text := "--:--" if last_race_time < 0.0 else _fmt(last_race_time)
	var rows := "LAP RECORD: %s\nLAST RACE: %s\n3 LAP TOTAL RECORD: %s\nTOP 10 RACE TIMES\n" % ["—" if is_inf(lap_record) else _fmt(lap_record), last_text, record_text]
	for i in range(min(10, scores.size())):
		rows += "%d. %s\n" % [i + 1, _fmt(float(scores[i]))]
	score_label.text = rows

func _record_score(time: float) -> void:
	last_race_time = time
	scores.append(time)
	scores.sort()
	if scores.size() > 10:
		scores.resize(10)
	var f := FileAccess.open(_score_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(scores))
		f.close()
	var last_file := FileAccess.open(_score_path() + ".last", FileAccess.WRITE)
	if last_file != null:
		last_file.store_string(str(time))
		last_file.close()

func _score_path() -> String:
	if active_track_id.is_empty():
		return SCORE_PATH
	return TRACKS_DIR + "/" + active_track_id + "_scores.json"

func _lap_record_path() -> String:
	return _score_path() + ".lap"

func _save_lap_record() -> void:
	var file := FileAccess.open(_lap_record_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(str(lap_record))
		file.close()

func _load_scores() -> void:
	lap_record = INF
	if FileAccess.file_exists(_lap_record_path()):
		var stored := FileAccess.get_file_as_string(_lap_record_path()).to_float()
		if stored > 0.0:
			lap_record = stored
	scores = []
	last_race_time = -1.0
	if FileAccess.file_exists(_score_path() + ".last"):
		last_race_time = FileAccess.get_file_as_string(_score_path() + ".last").to_float()
	var path := _score_path()
	if active_track_id == "original" and not FileAccess.file_exists(path) and FileAccess.file_exists(SCORE_PATH):
		DirAccess.copy_absolute(SCORE_PATH, path)
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Array:
			scores = parsed
	_update_score_label()
