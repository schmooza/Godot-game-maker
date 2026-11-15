extends Control
## Existing GDScript editor plus simple student image replacement.
var editor: CodeEdit
var feedback: Label
var slot_picker: OptionButton
var image_dialog: FileDialog
var is_dirty := false
var save_status: Label
var adventure_name_input: LineEdit
var adventure_heading: Label
const CUSTOM_OBJECTS_PATH := "user://adventure_custom_objects.json"
const CUSTOM_IMAGES_DIR := "user://adventure_custom_images"
var custom_objects: Array = []
var custom_list: ItemList
var custom_name: LineEdit
var custom_description: LineEdit
var custom_collect: CheckBox
var custom_image_dialog: FileDialog
var custom_feedback: Label
const ADVENTURE_NAME_PATH := "user://adventure_game_name.json"

func _ready() -> void:
	_build_ui()
	editor.text = EditorState.source_text
	editor.text_changed.connect(_on_text_changed)
	_load_adventure_name()
	_load_custom_objects()
	_update_status()

func _build_ui() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 8)
	add_child(layout)
	var toolbar := HBoxContainer.new()
	layout.add_child(toolbar)
	_add_button(toolbar, "Back", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	_add_button(toolbar, "Save", _save)
	_add_button(toolbar, "Play / Test", _play)
	_add_button(toolbar, "Reset note", _reset)

	var name_bar := HBoxContainer.new()
	layout.add_child(name_bar)
	adventure_heading = Label.new()
	adventure_heading.text = "ADVENTURE: My Adventure"
	adventure_heading.add_theme_font_size_override("font_size", 23)
	adventure_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_bar.add_child(adventure_heading)
	adventure_name_input = LineEdit.new()
	adventure_name_input.text = "My Adventure"
	adventure_name_input.placeholder_text = "Adventure game name"
	adventure_name_input.custom_minimum_size.x = 230
	name_bar.add_child(adventure_name_input)
	_add_button(name_bar, "Save Name", _save_adventure_name)
	adventure_name_input.text_submitted.connect(func(_value: String): _save_adventure_name())
	var heading := Label.new()
	heading.text = "Adventure Board > Room Rules (editable GDScript)"
	heading.add_theme_font_size_override("font_size", 20)
	layout.add_child(heading)
	var help := Label.new()
	help.text = "Edit the code, or select an image slot and import your picture. Save, then Play / Test."
	layout.add_child(help)

	var assets := HBoxContainer.new()
	layout.add_child(assets)
	var asset_label := Label.new()
	asset_label.text = "Image slot:"
	assets.add_child(asset_label)
	slot_picker = OptionButton.new()
	for slot in AssetStore.SLOTS:
		slot_picker.add_item(slot)
	assets.add_child(slot_picker)
	_add_button(assets, "Import PNG/JPG/WebP", _choose_image)
	_add_button(assets, "Reset image", _reset_image)

	var custom_bar := HBoxContainer.new()
	layout.add_child(custom_bar)
	var custom_title := Label.new()
	custom_title.text = "VISIBLE CUSTOM OBJECTS"
	custom_bar.add_child(custom_title)
	_add_button(custom_bar, "Add Object", _add_custom_object)
	_add_button(custom_bar, "Remove Selected", _remove_custom_object)
	_add_button(custom_bar, "Import Object Image", _choose_custom_image)
	var custom_fields := HBoxContainer.new()
	layout.add_child(custom_fields)
	custom_list = ItemList.new()
	custom_list.custom_minimum_size = Vector2(185, 85)
	custom_list.item_selected.connect(_select_custom_object)
	custom_fields.add_child(custom_list)
	var field_stack := VBoxContainer.new()
	field_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_fields.add_child(field_stack)
	custom_name = LineEdit.new()
	custom_name.placeholder_text = "Object name"
	field_stack.add_child(custom_name)
	custom_description = LineEdit.new()
	custom_description.placeholder_text = "Description when clicked"
	field_stack.add_child(custom_description)
	custom_collect = CheckBox.new()
	custom_collect.text = "Collect when clicked"
	field_stack.add_child(custom_collect)
	_add_button(custom_fields, "Save Object", _save_custom_object)
	custom_feedback = Label.new()
	custom_feedback.text = "Objects appear in the Adventure room. Select an object to edit it."
	layout.add_child(custom_feedback)
	custom_image_dialog = FileDialog.new()
	custom_image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	custom_image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	custom_image_dialog.use_native_dialog = true
	custom_image_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp", "Images")
	custom_image_dialog.file_selected.connect(_import_custom_image)
	add_child(custom_image_dialog)

	editor = CodeEdit.new()
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.add_theme_font_size_override("font_size", 16)
	editor.gutters_draw_line_numbers = true
	editor.syntax_highlighter = CodeHighlighter.new()
	layout.add_child(editor)
	save_status = Label.new()
	layout.add_child(save_status)
	feedback = Label.new()
	feedback.text = "Images are stored in your Windows user profile."
	layout.add_child(feedback)

	image_dialog = FileDialog.new()
	image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	image_dialog.use_native_dialog = true
	image_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp", "Images")
	image_dialog.file_selected.connect(_import_image)
	add_child(image_dialog)

func _load_custom_objects() -> void:
	custom_objects.clear()
	if FileAccess.file_exists(CUSTOM_OBJECTS_PATH):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(CUSTOM_OBJECTS_PATH))
		if saved is Array:
			custom_objects = saved
	_refresh_custom_list()

func _refresh_custom_list() -> void:
	custom_list.clear()
	for obj in custom_objects:
		custom_list.add_item(str(obj.get("name", "Object")))

func _persist_custom_objects() -> void:
	var f := FileAccess.open(CUSTOM_OBJECTS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(custom_objects))
		f.close()

func _add_custom_object() -> void:
	var new_id: String = str(Time.get_ticks_usec())
	custom_objects.append({"id": new_id, "name": "New Object", "description": "You examine the object.", "collect": false, "image": ""})
	_persist_custom_objects()
	_refresh_custom_list()
	custom_list.select(custom_objects.size() - 1)
	_select_custom_object(custom_objects.size() - 1)

func _select_custom_object(index: int) -> void:
	if index < 0 or index >= custom_objects.size():
		return
	var obj: Dictionary = custom_objects[index]
	custom_name.text = str(obj.get("name", ""))
	custom_description.text = str(obj.get("description", ""))
	custom_collect.button_pressed = bool(obj.get("collect", false))

func _save_custom_object() -> void:
	var index: int = custom_list.get_selected_items()[0] if not custom_list.get_selected_items().is_empty() else -1
	if index < 0 or custom_name.text.strip_edges().is_empty():
		custom_feedback.text = "Select an object and enter a name."
		return
	custom_objects[index]["name"] = custom_name.text.strip_edges()
	custom_objects[index]["description"] = custom_description.text
	custom_objects[index]["collect"] = custom_collect.button_pressed
	_persist_custom_objects()
	_refresh_custom_list()
	custom_list.select(index)
	custom_feedback.text = "Object saved."

func _remove_custom_object() -> void:
	if custom_list.get_selected_items().is_empty():
		return
	custom_objects.remove_at(custom_list.get_selected_items()[0])
	_persist_custom_objects()
	_refresh_custom_list()

func _choose_custom_image() -> void:
	if custom_list.get_selected_items().is_empty():
		custom_feedback.text = "Select an object first."
		return
	custom_image_dialog.popup_centered_ratio(0.7)

func _import_custom_image(path: String) -> void:
	if custom_list.get_selected_items().is_empty():
		return
	var index: int = custom_list.get_selected_items()[0]
	var img := Image.new()
	if img.load(path) != OK:
		custom_feedback.text = "Could not read image."
		return
	DirAccess.make_dir_recursive_absolute(CUSTOM_IMAGES_DIR)
	var destination: String = CUSTOM_IMAGES_DIR + "/" + str(custom_objects[index].get("id", "object")) + ".png"
	if img.save_png(destination) == OK:
		custom_objects[index]["image"] = destination
		_persist_custom_objects()
		custom_feedback.text = "Object image imported."
	else:
		custom_feedback.text = "Could not save image."

func _load_adventure_name() -> void:
	var title: String = "My Adventure"
	if FileAccess.file_exists(ADVENTURE_NAME_PATH):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ADVENTURE_NAME_PATH))
		if data is Dictionary:
			title = str(data.get("name", title))
	adventure_name_input.text = title
	adventure_heading.text = "ADVENTURE: " + title

func _save_adventure_name() -> void:
	var title: String = adventure_name_input.text.strip_edges()
	if title.is_empty():
		return
	var file := FileAccess.open(ADVENTURE_NAME_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"name":title}))
	file.close()
	adventure_heading.text = "ADVENTURE: " + title

func _add_button(parent: Control, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(callback)
	parent.add_child(button)

func _on_text_changed() -> void:
	is_dirty = editor.text != EditorState.source_text
	_update_status()

func _update_status() -> void:
	if save_status != null:
		save_status.text = "Unsaved code changes" if is_dirty else "Code saved"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_dirty:
		_save()

func _selected_slot() -> String:
	return str(AssetStore.SLOTS[slot_picker.selected])

func _choose_image() -> void:
	image_dialog.popup_centered_ratio(0.7)

func _import_image(path: String) -> void:
	feedback.text = AssetStore.import_image(_selected_slot(), path)

func _reset_image() -> void:
	feedback.text = AssetStore.clear_image(_selected_slot())

func _save() -> void:
	if EditorState.save_student_code(editor.text):
		is_dirty = false
		_update_status()
		feedback.text = "Saved to your Windows user profile."
	else:
		feedback.text = "Save failed. Check folder permissions."

func _play() -> void:
	var error := EditorState.compile_rules(editor.text)
	if not error.is_empty():
		feedback.text = error
		return
	if not EditorState.save_student_code(editor.text):
		feedback.text = "Could not save changes. Game not launched."
		return
	is_dirty = false
	_update_status()
	get_tree().change_scene_to_file("res://scenes/student_adventure.tscn")

func _reset() -> void:
	EditorState.reset_to_template()
	editor.text = EditorState.source_text
	is_dirty = true
	_update_status()
	feedback.text = "Template restored in editor. Click Save to keep it."
