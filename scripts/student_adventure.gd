extends Control
## Simple clickable object images, with coloured placeholders when no image is imported.
var state: Dictionary = {}
var object_grid: GridContainer
var heading: Label
var message: Label
var inventory: HBoxContainer
var won := false

func _ready() -> void:
	if EditorState.active_rules == null:
		var error := EditorState.compile_rules(EditorState.source_text)
		if not error.is_empty():
			push_error(error)
			get_tree().call_deferred("change_scene_to_file", "res://scenes/adventure_editor.tscn")
			return
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)
	var edit_button := Button.new()
	edit_button.text = "← Edit room rules / images"
	edit_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/adventure_editor.tscn"))
	layout.add_child(edit_button)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 24)
	layout.add_child(heading)

	var room := PanelContainer.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(room)
	var backdrop := TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.texture = AssetStore.get_texture("background")
	room.add_child(backdrop)
	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 20)
	room.add_child(padding)
	object_grid = GridContainer.new()
	object_grid.columns = 3
	padding.add_child(object_grid)

	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.text = "Click an object to investigate."
	layout.add_child(message)
	inventory = HBoxContainer.new()
	layout.add_child(inventory)

func _refresh() -> void:
	for child in object_grid.get_children():
		object_grid.remove_child(child)
		child.queue_free()
	for child in inventory.get_children():
		inventory.remove_child(child)
		child.queue_free()
	heading.text = str(EditorState.active_rules.call("get_room_title"))
	if won:
		var again := Button.new()
		again.text = "Play again"
		again.pressed.connect(_restart)
		object_grid.add_child(again)
	else:
		var objects: Variant = EditorState.active_rules.call("get_objects")
		for item in objects:
			var object_id := str(item.get("id", ""))
			var button := Button.new()
			button.custom_minimum_size = Vector2(180, 130)
			button.text = str(item.get("label", "Object"))
			button.icon = AssetStore.get_texture(object_id)
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.pressed.connect(func(): _interact(object_id))
			object_grid.add_child(button)
	var label := Label.new()
	label.text = "Inventory: " + str(state.get("items", []))
	inventory.add_child(label)
	if state.get("has_key", false):
		var key_texture: Texture2D = AssetStore.get_texture("key")
		if key_texture != null:
			var key_image := TextureRect.new()
			key_image.texture = key_texture
			key_image.custom_minimum_size = Vector2(48, 48)
			key_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			key_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			inventory.add_child(key_image)

func _interact(object_id: String) -> void:
	var result: Variant = EditorState.active_rules.call("interact", object_id, state.duplicate(true))
	if not (result is Dictionary):
		message.text = "Your interact() function must return a Dictionary."
		return
	message.text = str(result.get("message", ""))
	if result.has("set_flag"):
		state[str(result["set_flag"])] = true
	if result.has("add_item"):
		var items: Array = state.get("items", [])
		items.append(str(result["add_item"]))
		state["items"] = items
	if result.get("win", false):
		won = true
	_refresh()

func _restart() -> void:
	state.clear()
	won = false
	message.text = "Click an object to investigate."
	_refresh()
