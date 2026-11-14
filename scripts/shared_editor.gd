extends Control
## Shared student-facing scene editor and test mode for all three game templates.
const VIEW_SIZE := Vector2(960, 540)
var testing := false
var selected := -1
var scene_area: Control
var objects_layer: Control
var backdrop: TextureRect
var status: Label
var object_picker: OptionButton
var x_edit: SpinBox
var y_edit: SpinBox
var w_edit: SpinBox
var h_edit: SpinBox
var label_edit: LineEdit
var file_dialog: FileDialog
var import_slot := ""
var drag_index := -1
var drag_offset := Vector2.ZERO
var state: Dictionary = {}
var won := false
var shots: Array[Vector2] = []
var enemy_shots: Array[Vector2] = []
var game_time := 0.0
var boss_health := 12
var lives := 3
var laps := 0
var race_distance := 0.0
var car_x := 0.5
var player_pos := Vector2(480, 450)
var game_canvas: Control

func _ready() -> void:
	_build()
	_rebuild()
	set_process(true)

func _button(parent: Node, caption: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _build() -> void:
	var base := VBoxContainer.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.add_theme_constant_override("separation", 5)
	add_child(base)
	var toolbar := HBoxContainer.new()
	base.add_child(toolbar)
	_button(toolbar, "← Games", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	var mode_picker := OptionButton.new()
	for m in SharedData.MODES:
		mode_picker.add_item({"adventure":"Adventure","racing":"Car racing","boss":"Boss fight"}[m])
	mode_picker.select(SharedData.MODES.find(SharedData.mode))
	mode_picker.item_selected.connect(func(index: int): SharedData.mode = SharedData.MODES[index]; testing = false; _rebuild())
	toolbar.add_child(mode_picker)
	_button(toolbar, "Save", _save)
	_button(toolbar, "Play / Test", _start_test)
	_button(toolbar, "Edit Scene", func(): testing = false; _rebuild())
	_button(toolbar, "Reset Scene", _reset_scene)
	_button(toolbar, "Edit Adventure Code", func(): get_tree().change_scene_to_file("res://scenes/adventure_editor.tscn"))

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	base.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 255
	row.add_child(left)
	var instruction := Label.new()
	instruction.text = "SCENE EDITOR\nDrag objects in the room.\nSelect an object to edit it.\nImport images or add an object.\nSave, then Play / Test."
	left.add_child(instruction)
	object_picker = OptionButton.new()
	object_picker.item_selected.connect(_select)
	left.add_child(object_picker)
	_button(left, "Add object", _add_object)
	_button(left, "Remove selected", _remove_object)
	_button(left, "Import selected image", _choose_object_image)
	_button(left, "Import background", func(): _choose_image("background"))
	var lbl := Label.new()
	lbl.text = "Object name"
	left.add_child(lbl)
	label_edit = LineEdit.new()
	label_edit.text_changed.connect(func(_value: String): _apply_properties())
	left.add_child(label_edit)
	for field in ["X (%)", "Y (%)", "Width", "Height"]:
		var field_label := Label.new()
		field_label.text = field
		left.add_child(field_label)
		var spin := SpinBox.new()
		spin.min_value = 0 if field.begins_with("X") or field.begins_with("Y") else 20
		spin.max_value = 100 if field.begins_with("X") or field.begins_with("Y") else 400
		spin.step = 1
		spin.value_changed.connect(func(_v: float): _apply_properties())
		left.add_child(spin)
		match field:
			"X (%)": x_edit = spin
			"Y (%)": y_edit = spin
			"Width": w_edit = spin
			"Height": h_edit = spin
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = "ADVENTURE: Click hidden objects to find clues.\nRACING: Left/Right to dodge, finish 3 laps.\nBOSS: Arrow keys to move, Space to shoot.\n\nObjects use the same image, position and size controls in every game."
	left.add_child(help)
	var viewport_holder := AspectRatioContainer.new()
	viewport_holder.ratio = 960.0 / 540.0
	viewport_holder.stretch_mode = AspectRatioContainer.STRETCH_FIT
	viewport_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(viewport_holder)
	scene_area = Control.new()
	scene_area.custom_minimum_size = VIEW_SIZE
	scene_area.mouse_filter = Control.MOUSE_FILTER_PASS
	viewport_holder.add_child(scene_area)
	backdrop = TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_area.add_child(backdrop)
	objects_layer = Control.new()
	objects_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	objects_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	scene_area.add_child(objects_layer)
	game_canvas = Control.new()
	game_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_area.add_child(game_canvas)
	game_canvas.draw.connect(_draw_game)
	status = Label.new()
	status.text = "Select and drag an object to place it."
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	base.add_child(status)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.use_native_dialog = true
	file_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp", "Images")
	file_dialog.file_selected.connect(_image_selected)
	add_child(file_dialog)

func _items() -> Array:
	return SharedData.scenes[SharedData.mode]["objects"]

func _rebuild() -> void:
	backdrop.texture = SharedData.texture("background")
	for c in objects_layer.get_children():
		objects_layer.remove_child(c)
		c.queue_free()
	object_picker.clear()
	var items := _items()
	for i in range(items.size()):
		var item: Dictionary = items[i]
		object_picker.add_item(str(item.get("label", item.get("id", "Object"))))
		var b := TextureButton.new()
		b.texture_normal = SharedData.texture(str(item["id"]))
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.position = Vector2(float(item["x"]) * 960.0, float(item["y"]) * 540.0) - Vector2(float(item["w"]), float(item["h"])) / 2.0
		b.size = Vector2(float(item["w"]), float(item["h"]))
		b.tooltip_text = str(item["label"]) if not testing else ""
		if b.texture_normal == null:
			var fallback := Button.new()
			fallback.text = str(item["label"]) if not testing else "?"
			fallback.position = b.position
			fallback.size = b.size
			if testing:
				fallback.pressed.connect(_interact.bind(str(item["id"])))
			else:
				fallback.pressed.connect(_select.bind(i))
			objects_layer.add_child(fallback)
			b.queue_free()
		else:
			if testing:
				b.pressed.connect(_interact.bind(str(item["id"])))
			else:
				b.gui_input.connect(_drag_input.bind(i))
			objects_layer.add_child(b)
	if not testing and items.size() > 0:
		_select(clampi(selected, 0, items.size() - 1))
	elif not testing:
		selected = -1
	if testing:
		status.text = "TEST: " + {"adventure":"Find the key and unlock the door.","racing":"Use ← → to dodge obstacles. Complete 3 laps.","boss":"Move with arrow keys. Shoot with Space."}[SharedData.mode]
	else:
		status.text = "EDIT: Drag objects on the scene. Save your layout before testing."
	game_canvas.queue_redraw()

func _select(index: int) -> void:
	if index < 0 or index >= _items().size(): return
	selected = index
	object_picker.select(index)
	var o: Dictionary = _items()[index]
	label_edit.set_block_signals(true)
	x_edit.set_block_signals(true)
	y_edit.set_block_signals(true)
	w_edit.set_block_signals(true)
	h_edit.set_block_signals(true)
	label_edit.text = str(o["label"])
	x_edit.value = round(float(o["x"]) * 100.0)
	y_edit.value = round(float(o["y"]) * 100.0)
	w_edit.value = float(o["w"])
	h_edit.value = float(o["h"])
	for widget in [label_edit, x_edit, y_edit, w_edit, h_edit]:
		widget.set_block_signals(false)

func _apply_properties() -> void:
	if testing or selected < 0 or selected >= _items().size(): return
	var o: Dictionary = _items()[selected]
	o["label"] = label_edit.text
	o["x"] = x_edit.value / 100.0
	o["y"] = y_edit.value / 100.0
	o["w"] = w_edit.value
	o["h"] = h_edit.value
	_rebuild()

func _drag_input(event: InputEvent, index: int) -> void:
	if testing: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_select(index)
				drag_index = index
				drag_offset = get_global_mouse_position() - objects_layer.get_child(index).global_position
			else:
				drag_index = -1
	if event is InputEventMouseMotion and drag_index == index:
		var local := objects_layer.get_global_transform().affine_inverse() * get_global_mouse_position()
		var item: Dictionary = _items()[index]
		var middle := local - drag_offset + Vector2(float(item["w"]),float(item["h"])) / 2.0
		item["x"] = clampf(middle.x / 960.0, 0.0, 1.0)
		item["y"] = clampf(middle.y / 540.0, 0.0, 1.0)
		objects_layer.get_child(index).position = Vector2(item["x"] * 960.0, item["y"] * 540.0) - Vector2(float(item["w"]),float(item["h"])) / 2.0
		_select(index)

func _add_object() -> void:
	if testing: return
	var id := "object_" + str(Time.get_ticks_msec())
	_items().append({"id":id,"label":"New clue","x":0.5,"y":0.5,"w":80,"h":80})
	selected = _items().size() - 1
	_rebuild()

func _remove_object() -> void:
	if testing or selected < 0: return
	_items().remove_at(selected)
	selected = 0
	_rebuild()

func _choose_object_image() -> void:
	if selected < 0: return
	_choose_image(str(_items()[selected]["id"]))

func _choose_image(slot: String) -> void:
	import_slot = slot
	file_dialog.popup_centered_ratio(0.7)

func _image_selected(path: String) -> void:
	status.text = "Image imported." if SharedData.import_image(import_slot,path) else "Could not import image."
	_rebuild()

func _save() -> void:
	status.text = "Saved scene layouts." if SharedData.save() else "Save failed."

func _reset_scene() -> void:
	SharedData.reset_defaults()
	SharedData.save()
	selected = 0
	testing = false
	_rebuild()

func _start_test() -> void:
	if not SharedData.save():
		status.text = "Save failed. Cannot test."
		return
	if SharedData.mode == "adventure":
		var err := EditorState.compile_rules(EditorState.source_text)
		if not err.is_empty():
			status.text = err
			return
	testing = true
	state.clear()
	won = false
	shots.clear()
	enemy_shots.clear()
	boss_health = 12
	lives = 3
	laps = 0
	race_distance = 0.0
	car_x = 0.5
	player_pos = Vector2(480,450)
	game_time = 0.0
	_rebuild()

func _interact(id: String) -> void:
	if not testing or won: return
	if SharedData.mode != "adventure": return
	var result: Variant = EditorState.active_rules.call("interact",id,state.duplicate(true))
	if not (result is Dictionary): return
	status.text = str(result.get("message",""))
	if result.has("set_flag"): state[str(result["set_flag"])] = true
	if result.has("add_item"):
		var inventory: Array = state.get("items",[])
		inventory.append(result["add_item"])
		state["items"] = inventory
	if result.get("win",false):
		won = true
		status.text += "  YOU WIN! Click Edit Scene to build another room."

func _process(delta: float) -> void:
	if not testing or won: return
	if SharedData.mode == "racing":
		if Input.is_key_pressed(KEY_LEFT): car_x -= delta * 0.6
		if Input.is_key_pressed(KEY_RIGHT): car_x += delta * 0.6
		car_x = clampf(car_x,0.28,0.72)
		race_distance += delta * 0.22
		laps = int(race_distance)
		if laps >= 3:
			won = true
			status.text = "FINISH! Three laps completed."
		elif absf(car_x - 0.53) < 0.055 and fmod(race_distance,1.0) > 0.42 and fmod(race_distance,1.0) < 0.46:
			race_distance = maxf(0.0,race_distance - 0.12)
			status.text = "Obstacle hit! Time penalty."
		else:
			status.text = "Lap " + str(laps + 1) + " / 3 — use left/right arrows."
	elif SharedData.mode == "boss":
		var move := Vector2.ZERO
		if Input.is_key_pressed(KEY_LEFT): move.x -= 1
		if Input.is_key_pressed(KEY_RIGHT): move.x += 1
		if Input.is_key_pressed(KEY_UP): move.y -= 1
		if Input.is_key_pressed(KEY_DOWN): move.y += 1
		player_pos += move.normalized() * delta * 260.0
		player_pos = player_pos.clamp(Vector2(20,20),Vector2(940,520))
		game_time += delta
		if Input.is_key_pressed(KEY_SPACE) and fmod(game_time,0.17) < delta:
			shots.append(player_pos)
		if fmod(game_time,0.8) < delta:
			enemy_shots.append(Vector2(480 + sin(game_time) * 200.0,100))
		for i in range(shots.size()-1,-1,-1):
			shots[i].y -= 420.0 * delta
			if shots[i].y < 0:
				shots.remove_at(i)
			elif shots[i].distance_to(Vector2(480 + sin(game_time)*200.0,100)) < 70:
				shots.remove_at(i)
				boss_health -= 1
		for i in range(enemy_shots.size()-1,-1,-1):
			enemy_shots[i].y += 220.0 * delta
			if enemy_shots[i].y > 540:
				enemy_shots.remove_at(i)
			elif enemy_shots[i].distance_to(player_pos) < 24:
				enemy_shots.remove_at(i)
				lives -= 1
		if boss_health <= 0:
			won = true
			status.text = "Boss defeated! YOU WIN!"
		elif lives <= 0:
			won = true
			status.text = "Game over. Click Play / Test to retry."
		else:
			status.text = "Boss HP: " + str(boss_health) + "  |  Lives: " + str(lives)
	game_canvas.queue_redraw()

func _draw_game() -> void:
	if not testing: return
	if SharedData.mode == "racing":
		game_canvas.draw_rect(Rect2(Vector2(car_x*960.0-23,420),Vector2(46,75)),Color("#f7c65b"))
		game_canvas.draw_rect(Rect2(Vector2(0,0),Vector2(150,35)),Color("#222222aa"))
		game_canvas.draw_string(ThemeDB.fallback_font,Vector2(12,24),"Lap " + str(mini(laps+1,3)) + " / 3",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
	elif SharedData.mode == "boss":
		game_canvas.draw_circle(player_pos,20,Color("#68e3ff"))
		game_canvas.draw_circle(Vector2(480+sin(game_time)*200.0,100),45,Color("#e85b89"))
		for bullet in shots: game_canvas.draw_circle(bullet,6,Color.YELLOW)
		for bullet in enemy_shots: game_canvas.draw_circle(bullet,9,Color.ORANGE_RED)
