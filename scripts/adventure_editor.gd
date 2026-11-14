extends Control
## Existing GDScript editor plus simple student image replacement.
var editor: CodeEdit
var feedback: Label
var slot_picker: OptionButton
var image_dialog: FileDialog
var is_dirty := false
var save_status: Label

func _ready() -> void:
	_build_ui()
	editor.text = EditorState.source_text
	editor.text_changed.connect(_on_text_changed)
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
