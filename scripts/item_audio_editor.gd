extends VBoxContainer
## Optional per-item sound override. Lives outside the Adventure editor implementation.
signal sound_changed(item_id: String, sound_path: String)
var current_id := ""
var current_path := ""
var picker: FileDialog
var assigned: Label
var preview_player: AudioStreamPlayer
var host: Control

func setup(owner: Control, sidebar: Node) -> void:
	host = owner
	var section := PanelContainer.new()
	sidebar.add_child(section)
	var content := VBoxContainer.new()
	section.add_child(content)
	var heading := Label.new()
	heading.text = "ADVANCED: CUSTOM ITEM SOUND"
	heading.add_theme_color_override("font_color",Color("#f6bf6c"))
	content.add_child(heading)
	var hint := Label.new()
	hint.text = "Optional. Select an item first. Its sound plays when clicked, alongside normal game sounds."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	assigned = Label.new()
	assigned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(assigned)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	_button(actions,"Import",_choose)
	_button(actions,"Beep",func(): _assign("res://assets/test_sounds/beep.wav"))
	_button(actions,"Bop",func(): _assign("res://assets/test_sounds/bop.wav"))
	var actions2 := HBoxContainer.new()
	content.add_child(actions2)
	_button(actions2,"Preview",func(): preview(current_path))
	_button(actions2,"Remove",func(): _assign(""))
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.add_filter("*.wav, *.mp3, *.ogg","Audio files")
	picker.file_selected.connect(_import_file)
	owner.add_child(picker)
	preview_player = AudioStreamPlayer.new()
	add_child(preview_player)
	set_item("","")

func _button(parent: Node, caption: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = caption
	b.pressed.connect(callback)
	parent.add_child(b)

func set_item(item_id: String, sound_path: String) -> void:
	current_id = item_id
	current_path = sound_path
	if assigned != null:
		assigned.text = ("Select an item to assign its sound." if item_id.is_empty() else "Selected item sound: " + ("None" if sound_path.is_empty() else sound_path.get_file()))

func _choose() -> void:
	if current_id.is_empty():
		return
	picker.popup_centered_ratio(0.65)

func _import_file(path: String) -> void:
	if current_id.is_empty():
		return
	var ext := path.get_extension().to_lower()
	if not ext in ["wav","mp3","ogg"]:
		return
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return
	var safe_id := current_id.validate_filename()
	var output := "user://item_sound_" + safe_id + "." + ext
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(bytes)
	file.close()
	_assign(output)

func _assign(path: String) -> void:
	if current_id.is_empty():
		return
	current_path = path
	sound_changed.emit(current_id,path)
	set_item(current_id,path)
	if not path.is_empty():
		preview(path)

func preview(path: String) -> void:
	if path.is_empty():
		return
	var stream := load_audio(path)
	if stream == null:
		return
	preview_player.stop()
	preview_player.stream = stream
	preview_player.play()

static func load_audio(path: String) -> AudioStream:
	if path.is_empty():
		return null
	# Decode WAV directly for bundled test sounds, even before Godot imports assets.
	if path.begins_with("res://") and path.get_extension().to_lower() != "wav":
		return load(path) as AudioStream
	if not FileAccess.file_exists(path):
		return null
	match path.get_extension().to_lower():
		"wav": return AudioStreamWAV.load_from_file(path)
		"mp3": return AudioStreamMP3.load_from_file(path)
		"ogg": return AudioStreamOggVorbis.load_from_file(path)
	return null
