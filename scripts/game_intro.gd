extends Node
## Reusable, optional introduction screen for every game.
## Settings and image are stored in user://, separate from existing game data.
var game_id: String
var default_title: String
var title_input: LineEdit
var description_input: TextEdit
var picture_label: Label
var image_picker: FileDialog
var overlay: ColorRect
var image_view: TextureRect
var title_view: Label
var description_view: Label
var on_start: Callable
var current_image := ""
var current_title := ""
var current_description := ""
var intro_enabled := true
var current_sound := ""
var intro_volume := 80.0
var intro_loop := false
var sound_picker: FileDialog
var sound_label: Label
var intro_player: AudioStreamPlayer
var sound_volume_slider: HSlider


func setup(host: Control, sidebar: Node, id: String, game_title: String, default_description: String) -> void:
	game_id = id
	default_title = game_title
	current_title = game_title
	current_description = default_description
	_load_settings()
	var panel := VBoxContainer.new()
	sidebar.add_child(panel)
	var heading := Label.new()
	heading.text = "GAME INTRO SCREEN"
	heading.add_theme_font_size_override("font_size",18)
	heading.add_theme_color_override("font_color",Color("#f3c776"))
	panel.add_child(heading)
	var hint := Label.new()
	hint.text = "Shown before Play / Test. Edit the text and choose an image."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(hint)
	var enabled_toggle := CheckBox.new()
	enabled_toggle.text = "Enable intro screen (uncheck to skip)"
	enabled_toggle.button_pressed = intro_enabled
	enabled_toggle.toggled.connect(func(enabled: bool):
		intro_enabled = enabled
		_save_settings())
	panel.add_child(enabled_toggle)
	title_input = LineEdit.new()
	title_input.placeholder_text = "Game title"
	title_input.text = current_title
	title_input.text_changed.connect(func(value: String):
		current_title = value
		_save_settings())
	panel.add_child(title_input)
	description_input = TextEdit.new()
	description_input.custom_minimum_size = Vector2(0,100)
	description_input.text = current_description
	description_input.text_changed.connect(func():
		current_description = description_input.text
		_save_settings())
	panel.add_child(description_input)
	picture_label = Label.new()
	picture_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(picture_label)
	var buttons := HBoxContainer.new()
	panel.add_child(buttons)
	_button(buttons,"Choose Image",_choose_image)
	_button(buttons,"Remove Image",func():
		current_image = ""
		_save_settings()
		_refresh_picture())
	_button(buttons,"Preview Intro",func(): show_intro(Callable(),true))
	var sound_heading := Label.new()
	sound_heading.text = "INTRO SOUND"
	sound_heading.add_theme_color_override("font_color",Color("#8bd6f1"))
	panel.add_child(sound_heading)
	var sound_buttons := HBoxContainer.new()
	panel.add_child(sound_buttons)
	_button(sound_buttons,"Import Sound",_choose_sound)
	_button(sound_buttons,"Beep",func(): _assign_sound("res://assets/test_sounds/beep.wav"))
	_button(sound_buttons,"Bop",func(): _assign_sound("res://assets/test_sounds/bop.wav"))
	var sound_buttons2 := HBoxContainer.new()
	panel.add_child(sound_buttons2)
	_button(sound_buttons2,"Preview Sound",_play_intro_sound)
	_button(sound_buttons2,"Stop",_stop_intro_sound)
	_button(sound_buttons2,"Remove Sound",func(): _assign_sound(""))
	var sound_loop_toggle := CheckBox.new()
	sound_loop_toggle.text = "Loop intro sound"
	sound_loop_toggle.button_pressed = intro_loop
	sound_loop_toggle.toggled.connect(func(value: bool):
		intro_loop = value
		_save_settings())
	panel.add_child(sound_loop_toggle)
	var volume_caption := Label.new()
	volume_caption.text = "Intro sound volume"
	panel.add_child(volume_caption)
	sound_volume_slider = HSlider.new()
	sound_volume_slider.min_value = 0
	sound_volume_slider.max_value = 100
	sound_volume_slider.step = 5
	sound_volume_slider.value = intro_volume
	sound_volume_slider.value_changed.connect(func(value: float):
		intro_volume = value
		_save_settings()
		if intro_player != null:
			intro_player.volume_linear = intro_volume / 100.0)
	panel.add_child(sound_volume_slider)
	sound_label = Label.new()
	sound_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(sound_label)
	intro_player = AudioStreamPlayer.new()
	add_child(intro_player)
	sound_picker = FileDialog.new()
	sound_picker.access = FileDialog.ACCESS_FILESYSTEM
	sound_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	sound_picker.add_filter("*.wav, *.mp3, *.ogg","Audio files")
	sound_picker.file_selected.connect(_import_sound)
	host.add_child(sound_picker)
	_refresh_sound_label()
	image_picker = FileDialog.new()
	image_picker.access = FileDialog.ACCESS_FILESYSTEM
	image_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_picker.add_filter("*.png, *.jpg, *.jpeg, *.webp","Image files")
	image_picker.file_selected.connect(_import_image)
	host.add_child(image_picker)
	overlay = ColorRect.new()
	overlay.name = "GameIntroductionOverlay"
	overlay.color = Color("#1d2330")
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.z_index = 100
	host.add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(480,440)
	content.add_theme_constant_override("separation",16)
	center.add_child(content)
	title_view = Label.new()
	title_view.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_view.add_theme_font_size_override("font_size",32)
	title_view.add_theme_color_override("font_color",Color("#f7df98"))
	content.add_child(title_view)
	image_view = TextureRect.new()
	image_view.custom_minimum_size = Vector2(420,240)
	image_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(image_view)
	description_view = Label.new()
	description_view.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_view.custom_minimum_size = Vector2(420,65)
	description_view.add_theme_font_size_override("font_size",18)
	content.add_child(description_view)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(actions)
	_button(actions,"Start Game",_begin)
	_button(actions,"Back to Editor",func():
		_stop_intro_sound()
		overlay.hide())
	_refresh_picture()

func _button(parent: Node, caption: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(125,40)
	b.pressed.connect(callback)
	parent.add_child(b)

func _settings_path() -> String:
	return "user://intro_" + game_id + ".json"

func _load_settings() -> void:
	if not FileAccess.file_exists(_settings_path()):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_settings_path()))
	if parsed is Dictionary:
		current_title = str(parsed.get("title",current_title))
		current_description = str(parsed.get("description",current_description))
		current_image = str(parsed.get("image",""))
		intro_enabled = bool(parsed.get("enabled",true))
		current_sound = str(parsed.get("sound",""))
		intro_volume = float(parsed.get("sound_volume",80.0))
		intro_loop = bool(parsed.get("sound_loop",false))

func _save_settings() -> void:
	var file := FileAccess.open(_settings_path(),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"title":current_title,"description":current_description,"image":current_image,"enabled":intro_enabled,"sound":current_sound,"sound_volume":intro_volume,"sound_loop":intro_loop}))
		file.close()

func _choose_image() -> void:
	image_picker.popup_centered_ratio(0.7)

func _import_image(path: String) -> void:
	var ext := path.get_extension().to_lower()
	if not ext in ["png","jpg","jpeg","webp"]:
		return
	var data := FileAccess.get_file_as_bytes(path)
	if data.is_empty():
		return
	var target := "user://intro_" + game_id + "." + ext
	var f := FileAccess.open(target,FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(data)
	f.close()
	current_image = target
	_save_settings()
	_refresh_picture()

func _get_texture() -> Texture2D:
	if current_image.is_empty():
		return null
	var img := Image.new()
	if current_image.get_extension().to_lower() == "png":
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(current_image)) != OK:
			return null
	elif current_image.get_extension().to_lower() in ["jpg","jpeg"]:
		if img.load_jpg_from_buffer(FileAccess.get_file_as_bytes(current_image)) != OK:
			return null
	elif current_image.get_extension().to_lower() == "webp":
		if img.load_webp_from_buffer(FileAccess.get_file_as_bytes(current_image)) != OK:
			return null
	else:
		return null
	return ImageTexture.create_from_image(img)

func _refresh_picture() -> void:
	if picture_label != null:
		picture_label.text = "Intro image: " + ("None" if current_image.is_empty() else current_image.get_file())

func show_intro(start_action: Callable, force_preview: bool = false) -> void:
	if not intro_enabled and not force_preview:
		if start_action.is_valid():
			start_action.call()
		return
	on_start = start_action
	title_view.text = current_title
	description_view.text = current_description
	image_view.texture = _get_texture()
	image_view.visible = image_view.texture != null
	overlay.show()
	_play_intro_sound()

func _begin() -> void:
	_stop_intro_sound()
	overlay.hide()
	if on_start.is_valid():
		on_start.call()


func _refresh_sound_label() -> void:
	if sound_label != null:
		sound_label.text = "Assigned intro sound: " + ("None" if current_sound.is_empty() else current_sound.get_file())

func _choose_sound() -> void:
	sound_picker.popup_centered_ratio(0.7)

func _import_sound(path: String) -> void:
	var extension := path.get_extension().to_lower()
	if not extension in ["wav","mp3","ogg"]:
		return
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return
	var destination := "user://intro_sound_" + game_id + "." + extension
	var file := FileAccess.open(destination,FileAccess.WRITE)
	if file == null:
		return
	file.store_buffer(bytes)
	file.close()
	_assign_sound(destination)

func _assign_sound(path: String) -> void:
	_stop_intro_sound()
	current_sound = path
	_save_settings()
	_refresh_sound_label()
	if not path.is_empty():
		_play_intro_sound()

func _play_intro_sound() -> void:
	if intro_player == null or current_sound.is_empty():
		return
	var stream: AudioStream = null
	if current_sound.begins_with("res://"):
		stream = load(current_sound) as AudioStream
	elif FileAccess.file_exists(current_sound):
		match current_sound.get_extension().to_lower():
			"wav": stream = AudioStreamWAV.load_from_file(current_sound)
			"mp3": stream = AudioStreamMP3.load_from_file(current_sound)
			"ogg": stream = AudioStreamOggVorbis.load_from_file(current_sound)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if intro_loop else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = intro_loop
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = intro_loop
	intro_player.stop()
	intro_player.stream = stream
	intro_player.volume_linear = intro_volume / 100.0
	intro_player.play()

func _stop_intro_sound() -> void:
	if intro_player != null:
		intro_player.stop()
