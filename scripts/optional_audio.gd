extends Node
## Independent optional audio system. Does not alter existing game data or save files.
var game_id: String = ""
var event_names: Array[String] = []
var config: Dictionary = {}
var players: Dictionary = {}
var file_picker: FileDialog
var chosen_event: String = ""
var event_picker: OptionButton
var volume_dragging: bool = false
var volume_slider: HSlider
var master_slider: HSlider
var enabled_checkbox: CheckBox
var loop_checkbox: CheckBox
var sound_status: Label
var music_player: AudioStreamPlayer
var panel: VBoxContainer

func setup(host: Control, sidebar: Node, game: String, events: Array[String]) -> void:
	game_id = game
	event_names = events
	_load_settings()
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	panel = VBoxContainer.new()
	sidebar.add_child(panel)
	var heading := Label.new()
	heading.text = "♪  SOUND & MUSIC"
	heading.add_theme_color_override("font_color",Color("#8bd6f1"))
	heading.add_theme_font_size_override("font_size",18)
	panel.add_child(heading)
	var description := Label.new()
	description.text = "Optional: one audio file per event (WAV, MP3 or OGG)."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(description)
	event_picker = OptionButton.new()
	for event_name in event_names:
		event_picker.add_item(event_name)
	_refresh_event_labels()
	event_picker.item_selected.connect(func(_i: int): _sync_controls())
	panel.add_child(event_picker)
	var buttons := HBoxContainer.new()
	panel.add_child(buttons)
	_add_button(buttons,"Import",_choose_file)
	_add_button(buttons,"Preview",func(): play(_selected(),true))
	_add_button(buttons,"Stop",stop_all)
	_add_button(buttons,"Remove",_remove_selected)
	var samples := HBoxContainer.new()
	panel.add_child(samples)
	_add_button(samples,"Use Beep",func(): _use_sample("beep"))
	_add_button(samples,"Use Bop",func(): _use_sample("bop"))
	enabled_checkbox = CheckBox.new()
	enabled_checkbox.text = "Enable selected sound"
	enabled_checkbox.toggled.connect(func(value: bool): _set_option("enabled",value))
	panel.add_child(enabled_checkbox)
	loop_checkbox = CheckBox.new()
	loop_checkbox.text = "Loop this sound (music)"
	loop_checkbox.toggled.connect(func(value: bool): _set_option("loop",value))
	panel.add_child(loop_checkbox)
	var volume_label := Label.new()
	volume_label.text = "Selected sound volume"
	panel.add_child(volume_label)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 5
	volume_slider.value_changed.connect(func(value: float): _set_option("volume",value))
	volume_slider.drag_started.connect(func(): volume_dragging = true)
	volume_slider.drag_ended.connect(func(_value_changed: bool):
		volume_dragging = false
		play(_selected(),true))
	panel.add_child(volume_slider)
	var master_label := Label.new()
	master_label.text = "Master volume"
	panel.add_child(master_label)
	master_slider = HSlider.new()
	master_slider.min_value = 0
	master_slider.max_value = 100
	master_slider.step = 5
	master_slider.value = float(config.get("master",80))
	master_slider.value_changed.connect(_set_master)
	panel.add_child(master_slider)
	sound_status = Label.new()
	sound_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(sound_status)
	file_picker = FileDialog.new()
	file_picker.access = FileDialog.ACCESS_FILESYSTEM
	file_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_picker.add_filter("*.wav, *.mp3, *.ogg","Audio files")
	file_picker.file_selected.connect(_import_file)
	host.add_child(file_picker)
	_sync_controls()

func _add_button(parent: Node, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)

func _selected() -> String:
	if event_picker == null or event_names.is_empty():
		return ""
	return event_names[clampi(event_picker.selected,0,event_names.size()-1)]

func _entry(event_name: String) -> Dictionary:
	if not config.has(event_name):
		config[event_name] = {"file":"","enabled":true,"loop":event_name=="Background Music","volume":80.0}
	return config[event_name]

func _refresh_event_labels() -> void:
	if event_picker == null:
		return
	for i in range(event_names.size()):
		var event_name: String = event_names[i]
		var assigned: String = str(_entry(event_name).get("file", ""))
		var filename: String = assigned.get_file() if not assigned.is_empty() else "No sound"
		event_picker.set_item_text(i, event_name + "  —  " + filename)

func _sync_controls() -> void:
	_refresh_event_labels()
	var entry := _entry(_selected())
	enabled_checkbox.set_pressed_no_signal(bool(entry.get("enabled",true)))
	loop_checkbox.set_pressed_no_signal(bool(entry.get("loop",false)))
	volume_slider.set_value_no_signal(float(entry.get("volume",80)))
	var assigned_file: String = str(entry.get("file", ""))
	sound_status.text = "Current sound file: " + (assigned_file.get_file() if not assigned_file.is_empty() else "None assigned")

func _set_option(key: String, value: Variant) -> void:
	_entry(_selected())[key] = value
	_save_settings()
	if key=="volume" or key=="enabled":
		_update_volumes()
	if key == "volume" and volume_slider != null and not volume_dragging:
		play(_selected(),true)

func _set_master(value: float) -> void:
	config["master"] = value
	_save_settings()
	_update_volumes()

func _update_volumes() -> void:
	for event_name in players:
		var player: AudioStreamPlayer = players[event_name]
		var entry := _entry(str(event_name))
		player.volume_linear = float(config.get("master",80))/100.0 * float(entry.get("volume",80))/100.0
		if not bool(entry.get("enabled",true)):
			player.stop()

func _choose_file() -> void:
	chosen_event = _selected()
	file_picker.popup_centered_ratio(0.65)

func _import_file(path: String) -> void:
	var ext := path.get_extension().to_lower()
	if not (ext in ["wav","mp3","ogg"]):
		sound_status.text = "Choose WAV, MP3 or OGG."
		return
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		sound_status.text = "Audio file could not be read."
		return
	var destination := "user://audio_" + game_id + "_" + chosen_event.to_snake_case() + "." + ext
	var file := FileAccess.open(destination,FileAccess.WRITE)
	if file == null:
		sound_status.text = "Audio file could not be saved."
		return
	file.store_buffer(bytes)
	file.close()
	_entry(chosen_event)["file"] = destination
	_save_settings()
	if players.has(chosen_event):
		(players[chosen_event] as AudioStreamPlayer).stop()
		(players[chosen_event] as AudioStreamPlayer).queue_free()
		players.erase(chosen_event)
	_sync_controls()

func _use_sample(sound_name: String) -> void:
	var event_name := _selected()
	var sample_path := "res://assets/test_sounds/" + sound_name + ".wav"
	_entry(event_name)["file"] = sample_path
	_entry(event_name)["enabled"] = true
	_entry(event_name)["volume"] = 100.0
	_entry(event_name)["loop"] = false
	config["master"] = maxf(float(config.get("master",80.0)),80.0)
	master_slider.set_value_no_signal(float(config["master"]))
	_save_settings()
	if players.has(event_name):
		(players[event_name] as AudioStreamPlayer).stop()
		(players[event_name] as AudioStreamPlayer).queue_free()
		players.erase(event_name)
	_sync_controls()
	play(event_name,true)

func _remove_selected() -> void:
	var event_name := _selected()
	_entry(event_name)["file"] = ""
	if players.has(event_name):
		(players[event_name] as AudioStreamPlayer).stop()
		(players[event_name] as AudioStreamPlayer).queue_free()
		players.erase(event_name)
	_save_settings()
	_sync_controls()

func _stream(path: String) -> AudioStream:
	# Bundled samples are Godot resources; use ResourceLoader for res://.
	if path.begins_with("res://"):
		var bundled: Resource = load(path)
		if bundled is AudioStream:
			return bundled as AudioStream
	match path.get_extension().to_lower():
		"wav": return AudioStreamWAV.load_from_file(path)
		"mp3": return AudioStreamMP3.load_from_file(path)
		"ogg": return AudioStreamOggVorbis.load_from_file(path)
	return null

func play(event_name: String, preview: bool = false) -> void:
	if not event_names.has(event_name):
		return
	var entry := _entry(event_name)
	if not preview and not bool(entry.get("enabled",true)):
		return
	var path := str(entry.get("file",""))
	if path.is_empty():
		if preview:
			sound_status.text = "No sound assigned to this event. Choose Use Beep or Use Bop."
		return
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		if preview:
			sound_status.text = "Sound file missing: " + path.get_file()
		return
	if not players.has(event_name):
		var stream := _stream(path)
		if stream == null:
			if sound_status != null:
				sound_status.text = "Could not decode audio: " + path.get_file()
			return
		var player := AudioStreamPlayer.new()
		player.stream = stream
		add_child(player)
		players[event_name] = player
	var player: AudioStreamPlayer = players[event_name]
	# Godot stream-specific looping; background music can be stopped explicitly.
	if player.stream is AudioStreamMP3:
		(player.stream as AudioStreamMP3).loop = bool(entry.get("loop",false))
	elif player.stream is AudioStreamOggVorbis:
		(player.stream as AudioStreamOggVorbis).loop = bool(entry.get("loop",false))
	elif player.stream is AudioStreamWAV:
		(player.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if bool(entry.get("loop",false)) else AudioStreamWAV.LOOP_DISABLED
	player.volume_linear = float(config.get("master",80))/100.0 * float(entry.get("volume",80))/100.0
	player.play()
	if preview:
		sound_status.text = "Playing: " + path.get_file() + " (volume " + str(roundi(player.volume_linear * 100.0)) + "%)"

func stop_event(event_name: String) -> void:
	if players.has(event_name):
		(players[event_name] as AudioStreamPlayer).stop()

func stop_all() -> void:
	for event_name in players:
		(players[event_name] as AudioStreamPlayer).stop()

func _settings_path() -> String:
	return "user://audio_" + game_id + "_settings.json"

func _load_settings() -> void:
	config = {"master":80.0}
	if FileAccess.file_exists(_settings_path()):
		var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(_settings_path()))
		if loaded is Dictionary:
			config.merge(loaded,true)

func _save_settings() -> void:
	var file := FileAccess.open(_settings_path(),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(config))
		file.close()
