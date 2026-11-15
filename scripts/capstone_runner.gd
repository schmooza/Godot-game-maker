extends Node
## Capstone-only runtime. Observes existing games; does not modify their scripts.
const FLOW_PATH := "user://capstone_flow.json"
const EDITOR_PATH := "res://scenes/capstone_flow.tscn"
const SCENES := {"Adventure": "res://scenes/shared_editor.tscn", "Racing": "res://scenes/racing_editor.tscn", "Boss Fight": "res://scenes/boss_editor.tscn"}
var active := false
var current_id := ""
var flow: Dictionary = {}
var completed: Array[String] = []
var layer: CanvasLayer
var panel: PanelContainer
var label: Label
var actions: HBoxContainer
var stage_started := false
var transition_pending := false

func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 110
	add_child(layer)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(180, 10)
	panel.custom_minimum_size = Vector2(700, 0)
	layer.add_child(panel)
	var content := VBoxContainer.new()
	panel.add_child(content)
	label = Label.new()
	content.add_child(label)
	actions = HBoxContainer.new()
	content.add_child(actions)
	panel.hide()
	set_process(true)

func launch() -> void:
	if not FileAccess.file_exists(FLOW_PATH):
		_show_message("Save your flow first.")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FLOW_PATH))
	if not parsed is Dictionary:
		_show_message("Flow file is invalid.")
		return
	flow = parsed
	var start_id: String = str(flow.get("start", ""))
	if _stage(start_id).is_empty():
		_show_message("Select a starting stage and click Set Start.")
		return
	for entry in flow.get("stages", []):
		if entry is Dictionary and str(entry.get("source_id", "")).is_empty():
			_show_message("Not Built: " + str(entry.get("title", "Unnamed stage")))
			return
	completed.clear()
	active = true
	_open_stage(start_id)

func _stage(id: String) -> Dictionary:
	for entry in flow.get("stages", []):
		if entry is Dictionary and str(entry.get("id", "")) == id:
			return entry
	return {}

func _open_stage(id: String) -> void:
	var entry: Dictionary = _stage(id)
	if entry.is_empty():
		_finish("Stage not found: " + id)
		return
	current_id = id
	stage_started = false
	transition_pending = true
	panel.hide()
	var kind: String = str(entry.get("kind", ""))
	var source_id: String = str(entry.get("source_id", ""))
	if kind == "Adventure":
		SharedData.active_room = source_id
	elif kind == "Racing" and FileAccess.file_exists("user://racing_track_library.json"):
		var track_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://racing_track_library.json"))
		if track_data is Dictionary:
			track_data["active"] = source_id
			var track_file := FileAccess.open("user://racing_track_library.json", FileAccess.WRITE)
			if track_file != null:
				track_file.store_string(JSON.stringify(track_data))
				track_file.close()
	if not SCENES.has(kind):
		_finish("Unsupported stage type: " + kind)
		return
	if kind == "Adventure":
		SharedData.mode = "adventure"
	elif kind == "Racing":
		SharedData.mode = "racing"
	else:
		SharedData.mode = "boss"
	var err: Error = get_tree().change_scene_to_file(str(SCENES[kind]))
	if err != OK:
		_finish("Could not open stage.")
		return
	_start_after_scene_change()

func _start_after_scene_change() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not active:
		return
	var game: Node = get_tree().current_scene
	var entry: Dictionary = _stage(current_id)
	if game == null or entry.is_empty():
		_finish("Could not load game.")
		return
	var kind: String = str(entry.get("kind", ""))
	var method: String = "_start_test_actual" if kind == "Adventure" else "_start_actual"
	if not game.has_method(method):
		_finish("Game cannot be started: " + kind)
		return
	game.call(method)
	stage_started = true
	transition_pending = false
	_show_controls("Playing: " + str(entry.get("title", kind)))

func _process(_delta: float) -> void:
	if not active or not stage_started or transition_pending:
		return
	var game: Node = get_tree().current_scene
	if game == null:
		return
	var entry: Dictionary = _stage(current_id)
	if entry.is_empty():
		return
	var kind: String = str(entry.get("kind", ""))
	# The game editors can navigate to Home themselves. Stop observing as soon
	# as the active scene is no longer the expected stage scene.
	if not SCENES.has(kind) or game.scene_file_path != str(SCENES[kind]):
		active = false
		stage_started = false
		transition_pending = false
		panel.hide()
		return
	var won := false
	var lost := false
	if kind == "Adventure":
		won = bool(game.get("won"))
		lost = bool(game.get("restart_pending"))
	elif kind == "Racing":
		var lap_value: Variant = game.get("lap")
		var total_value: Variant = game.get("total_laps")
		if (lap_value is int or lap_value is float) and (total_value is int or total_value is float):
			won = int(lap_value) >= int(total_value) and int(total_value) > 0 and not bool(game.get("playing"))
	elif kind == "Boss Fight":
		if bool(game.get("ended")):
			var hp_value: Variant = game.get("boss_hp")
			won = (hp_value is int or hp_value is float) and float(hp_value) <= 0.0
			lost = not won
	if won:
		transition_pending = true
		completed.append(current_id)
		_on_victory()
	elif lost:
		transition_pending = true
		_show_controls("Challenge failed. Retry this stage or return to the flow editor.", true)

func _next_ids() -> Array[String]:
	var result: Array[String] = []
	for link in flow.get("links", []):
		if link is Dictionary and str(link.get("from", "")) == current_id:
			var target: String = str(link.get("to", ""))
			if not _stage(target).is_empty() and not result.has(target):
				result.append(target)
	return result

func _on_victory() -> void:
	var next: Array[String] = _next_ids()
	if next.is_empty():
		_finish("CAPSTONE COMPLETE! You finished " + str(completed.size()) + " stage(s).")
		return
	if next.size() == 1:
		_show_controls("Stage complete! Continue to " + str(_stage(next[0]).get("title", "Next stage")), false, next)
	else:
		_show_controls("Stage complete! Choose the next game:", false, next)

func _show_controls(message: String, failed := false, choices: Array[String] = []) -> void:
	label.text = message
	for child in actions.get_children():
		child.queue_free()
	if not choices.is_empty():
		for id in choices:
			var button := Button.new()
			button.text = "Next: " + str(_stage(id).get("title", id))
			actions.add_child(button)
			button.pressed.connect(_open_stage.bind(id))
	elif failed:
		_add_button("Retry", func(): _open_stage(current_id))
	_add_button("Exit to Flow Editor", stop)
	panel.show()

func _add_button(title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	actions.add_child(button)
	button.pressed.connect(callback)

func _finish(message: String) -> void:
	active = false
	stage_started = false
	transition_pending = false
	_show_controls(message)

func _show_message(message: String) -> void:
	_finish(message)

func stop() -> void:
	active = false
	stage_started = false
	transition_pending = false
	panel.hide()
	get_tree().change_scene_to_file(EDITOR_PATH)
