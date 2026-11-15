extends Control
## Independent capstone graph editor. Does not change any training game scripts.
const PATH := "user://capstone_flow.json"
const TYPES := ["Adventure", "Racing", "Boss Fight"]
var graph: GraphEdit
var nodes: Dictionary = {}
var next_id := 1
var selected: String = ""
var status: Label
var name_input: LineEdit
var type_input: OptionButton
var start_input: OptionButton
var run_id := ""
var source_picker: OptionButton
var source_entries: Array = []
var link_button: Button

func _ready() -> void:
	_build()
	_load_flow()

func _button(parent: Node, label: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = label
	parent.add_child(b)
	b.pressed.connect(action)
	return b

func _build() -> void:
	var base := VBoxContainer.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	var top := HBoxContainer.new()
	base.add_child(top)
	_button(top, "Home", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	_button(top, "+ Adventure", func(): _add_stage("Adventure"))
	_button(top, "+ Racing", func(): _add_stage("Racing"))
	_button(top, "+ Boss Fight", func(): _add_stage("Boss Fight"))
	_button(top, "Delete Selected", _delete_selected)
	_button(top, "Save Flow", _save_flow)
	_button(top, "Test Flow", _test_flow)
	_button(top, "Play Flow", _play_flow)
	graph = GraphEdit.new()
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph.right_disconnects = true
	base.add_child(graph)
	graph.connection_request.connect(_connect)
	graph.disconnection_request.connect(_disconnect)
	var bottom := HBoxContainer.new()
	base.add_child(bottom)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Selected stage name"
	name_input.custom_minimum_size.x = 220
	bottom.add_child(name_input)
	_button(bottom, "Rename", _rename)
	type_input = OptionButton.new()
	for t in TYPES:
		type_input.add_item(t)
	bottom.add_child(type_input)
	_button(bottom, "Change Type", _change_type)
	var source_row := HBoxContainer.new()
	base.add_child(source_row)
	var source_label := Label.new()
	source_label.text = "Existing saved game:"
	source_row.add_child(source_label)
	source_picker = OptionButton.new()
	source_picker.custom_minimum_size.x = 240
	source_row.add_child(source_picker)
	_button(source_row, "Refresh Saved Games", _refresh_sources)
	link_button = _button(source_row, "Link Selected Game", _link_source)
	_button(source_row, "Unlink (Placeholder)", _unlink_source)
	_refresh_sources()
	_button(bottom, "Open Game Editor", _open_selected)
	start_input = OptionButton.new()
	bottom.add_child(start_input)
	_button(bottom, "Set Start", _set_start)
	status = Label.new()
	status.text = "Add stages, drag to arrange, connect right ports to left ports. Select a stage to edit it."
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	base.add_child(status)

func _add_stage(kind: String, id := "", title := "", pos := Vector2(90, 90)) -> void:
	if id.is_empty():
		id = "stage_%d" % next_id
		next_id += 1
		pos = Vector2(80 + (nodes.size() % 5) * 210, 80 + int(nodes.size() / 5) * 160)
	var n := GraphNode.new()
	n.name = id
	n.title = title if not title.is_empty() else kind + " " + str(next_id - 1)
	n.position_offset = pos
	n.resizable = false
	var lbl := Label.new()
	lbl.text = kind + " — Not Built"
	lbl.custom_minimum_size = Vector2(155, 42)
	n.add_child(lbl)
	n.set_slot(0, true, 0, Color("#8ac2d8"), true, 0, Color("#8ac2d8"))
	graph.add_child(n)
	n.node_selected.connect(_choose.bind(id))
	nodes[id] = {"node": n, "kind": kind, "source_id": ""}
	_refresh_start()

func _choose(id: String) -> void:
	selected = id
	name_input.text = str(nodes[id]["node"].title)
	type_input.select(TYPES.find(str(nodes[id]["kind"])))
	_refresh_sources()
	status.text = "Selected: " + name_input.text + (" [Not Built]" if str(nodes[id].get("source_id", "")).is_empty() else " [Linked]")

func _rename() -> void:
	if not nodes.has(selected):
		return
	var title := name_input.text.strip_edges()
	if title.is_empty():
		return
	nodes[selected]["node"].title = title
	_refresh_start()
	_save_flow()

func _change_type() -> void:
	if not nodes.has(selected):
		return
	var kind: String = TYPES[type_input.selected]
	nodes[selected]["kind"] = kind
	nodes[selected]["source_id"] = ""
	var n: GraphNode = nodes[selected]["node"]
	n.get_child(0).text = kind + " — Not Built"
	_save_flow()

func _delete_selected() -> void:
	if not nodes.has(selected):
		return
	for c in graph.get_connection_list():
		if c["from_node"] == selected or c["to_node"] == selected:
			graph.disconnect_node(c["from_node"], c["from_port"], c["to_node"], c["to_port"])
	nodes[selected]["node"].queue_free()
	nodes.erase(selected)
	selected = ""
	_refresh_start()
	_save_flow()

func _connect(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	if from_node == to_node:
		status.text = "Self-connections are not supported; connect two different stages to create a loop."
		return
	if not graph.is_node_connected(from_node, from_port, to_node, to_port):
		graph.connect_node(from_node, from_port, to_node, to_port)
	_save_flow()

func _disconnect(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph.disconnect_node(from_node, from_port, to_node, to_port)
	_save_flow()

func _refresh_start() -> void:
	var previous: String = str(start_input.get_selected_metadata()) if start_input.item_count > 0 else ""
	start_input.clear()
	for id in nodes:
		start_input.add_item(str(nodes[id]["node"].title))
		start_input.set_item_metadata(start_input.item_count - 1, id)
		if id == previous:
			start_input.select(start_input.item_count - 1)

func _set_start() -> void:
	if start_input.item_count == 0:
		return
	run_id = str(start_input.get_selected_metadata())
	_save_flow()
	status.text = "Starting stage set: " + str(nodes[run_id]["node"].title)

func _save_flow() -> void:
	var stages: Array = []
	for id in nodes:
		var n: GraphNode = nodes[id]["node"]
		stages.append({"id": id, "title": n.title, "kind": nodes[id]["kind"], "source_id": nodes[id].get("source_id", ""), "x": n.position_offset.x, "y": n.position_offset.y})
	var links: Array = []
	for c in graph.get_connection_list():
		links.append({"from": str(c["from_node"]), "to": str(c["to_node"])})
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		status.text = "Could not save flow."
		return
	f.store_string(JSON.stringify({"stages": stages, "links": links, "start": run_id, "next_id": next_id}, "  "))
	f.close()
	status.text = "Flow saved."

func _load_flow() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary:
		return
	next_id = maxi(1, int(data.get("next_id", 1)))
	for stage in data.get("stages", []):
		if stage is Dictionary:
			var kind := str(stage.get("kind", "Adventure"))
			if kind in TYPES:
				_add_stage(kind, str(stage.get("id", "")), str(stage.get("title", "")), Vector2(float(stage.get("x", 90)), float(stage.get("y", 90))))
			var sid: String = str(stage.get("id", ""))
			if nodes.has(sid):
				nodes[sid]["source_id"] = str(stage.get("source_id", ""))
				_update_node_label(sid)
	for link in data.get("links", []):
		if link is Dictionary:
			var a := str(link.get("from", ""))
			var b := str(link.get("to", ""))
			if nodes.has(a) and nodes.has(b) and a != b:
				graph.connect_node(a, 0, b, 0)
	run_id = str(data.get("start", ""))
	for i in range(start_input.item_count):
		if str(start_input.get_item_metadata(i)) == run_id:
			start_input.select(i)
			break

func _open_selected() -> void:
	if not nodes.has(selected):
		status.text = "Select a stage first."
		return
	var kind := str(nodes[selected]["kind"])
	SharedData.mode = "adventure" if kind == "Adventure" else ("racing" if kind == "Racing" else "boss")
	_save_flow()
	get_tree().change_scene_to_file("res://scenes/shared_editor.tscn" if kind == "Adventure" else ("res://scenes/racing_editor.tscn" if kind == "Racing" else "res://scenes/boss_editor.tscn"))

func _test_flow() -> void:
	if not nodes.has(run_id):
		status.text = "Choose a starting stage and click Set Start first."
		return
	var visited: Dictionary = {}
	var queue: Array[String] = [run_id]
	var order: Array[String] = []
	while not queue.is_empty() and order.size() < 100:
		var id: String = queue.pop_front()
		if visited.has(id):
			continue
		visited[id] = true
		order.append(str(nodes[id]["node"].title))
		for c in graph.get_connection_list():
			if str(c["from_node"]) == id:
				queue.append(str(c["to_node"]))
	status.text = "Flow preview (reachable stages): " + " -> ".join(order) + ". Click Play Flow to play the sequence."

func _play_flow() -> void:
	_save_flow()
	for id in nodes:
		if str(nodes[id].get("source_id", "")).is_empty():
			status.text = "Cannot play: " + str(nodes[id]["node"].title) + " is Not Built. Link a saved game first."
			return
	CapstoneRunner.launch()

func _update_node_label(id: String) -> void:
	if not nodes.has(id):
		return
	var n: GraphNode = nodes[id]["node"]
	n.get_child(0).text = str(nodes[id]["kind"]) + (" — Not Built" if str(nodes[id].get("source_id", "")).is_empty() else " — Linked")

func _refresh_sources() -> void:
	if source_picker == null:
		return
	source_picker.clear()
	source_entries.clear()
	var kind: String = str(nodes[selected]["kind"]) if nodes.has(selected) else "Adventure"
	if kind == "Adventure":
		if FileAccess.file_exists("user://adventure_game_name.json"):
			var adventure_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://adventure_game_name.json"))
			if adventure_data is Dictionary:
				_add_source(str(adventure_data.get("name", "My Adventure")), "adventure_named")
		if FileAccess.file_exists("user://shared_scenes.json"):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://shared_scenes.json"))
			if data is Dictionary:
				var rooms: Variant = data.get("adventure", {}).get("rooms", {})
				if rooms is Dictionary:
					for room in rooms.keys():
						_add_source(str(room), str(room))
				elif rooms is Array:
					for room in rooms:
						_add_source(str(room), str(room))
	elif kind == "Racing":
		if FileAccess.file_exists("user://racing_track_library.json"):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://racing_track_library.json"))
			if data is Dictionary:
				var tracks: Variant = data.get("tracks", [])
				if tracks is Array:
					for track in tracks:
						if track is Dictionary:
							_add_source(str(track.get("name", "Track")), str(track.get("id", "")))
	else:
		if FileAccess.file_exists("user://boss_fight_settings_v2.json"):
			var boss_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://boss_fight_settings_v2.json"))
			var boss_title: String = str(boss_data.get("game_name", "Boss Fight 1")) if boss_data is Dictionary else "Boss Fight 1"
			_add_source(boss_title, "boss_saved")
	if source_entries.is_empty():
		source_picker.add_item("No saved games found")
		source_picker.disabled = true
	else:
		source_picker.disabled = false

func _add_source(title: String, source_id: String) -> void:
	if source_id.is_empty():
		return
	source_picker.add_item(title)
	source_entries.append({"title": title, "id": source_id})

func _link_source() -> void:
	if not nodes.has(selected) or source_picker.selected < 0 or source_picker.selected >= source_entries.size():
		status.text = "Select a stage and an existing saved game first."
		return
	var source: Dictionary = source_entries[source_picker.selected]
	nodes[selected]["source_id"] = str(source["id"])
	nodes[selected]["node"].title = str(source["title"])
	name_input.text = str(source["title"])
	_update_node_label(selected)
	_refresh_start()
	_save_flow()
	status.text = "Linked: " + str(source["title"])

func _unlink_source() -> void:
	if not nodes.has(selected):
		return
	nodes[selected]["source_id"] = ""
	_update_node_label(selected)
	_save_flow()
	status.text = "Placeholder: enter a name and click Rename. Link a saved game before playing."

