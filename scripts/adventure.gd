extends Control
## Phase 2 playable vertical slice: find the brass key and unlock the door.
## All visuals use built-in Godot controls; no external assets.

var has_key := false
var door_unlocked := false
var drawer_open := false
var won := false
var status: Label
var inventory: Label
var room_title: Label
var objects: VBoxContainer
var back_button: Button


func _ready() -> void:
	_build_ui()
	_show_room()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#263548")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 32)
	add_child(margins)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margins.add_child(layout)

	var top := HBoxContainer.new()
	layout.add_child(top)
	back_button = Button.new()
	back_button.text = "← Back to boards"
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	top.add_child(back_button)

	room_title = Label.new()
	room_title.add_theme_font_size_override("font_size", 28)
	layout.add_child(room_title)

	var hint := Label.new()
	hint.text = "Click objects, inspect clues, and escape the room."
	layout.add_child(hint)

	var area := PanelContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(area)
	var area_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		area_margin.add_theme_constant_override("margin_" + side, 24)
	area.add_child(area_margin)
	objects = VBoxContainer.new()
	objects.add_theme_constant_override("separation", 12)
	area_margin.add_child(objects)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "You wake up in a locked study. Find a way out."
	layout.add_child(status)

	inventory = Label.new()
	layout.add_child(inventory)


func _show_room() -> void:
	for child in objects.get_children():
		child.queue_free()
	room_title.text = "The Locked Study" if not won else "Escape Complete!"
	if won:
		_add_object("You escaped! Play again", _restart)
	else:
		_add_object("Inspect the desk", _inspect_desk)
		_add_object("Open the drawer", _open_drawer)
		_add_object("Inspect the painting", _inspect_painting)
		_add_object("Try the locked door", _try_door)
	inventory.text = "Inventory: Brass key" if has_key else "Inventory: Empty"


func _add_object(caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 64
	button.pressed.connect(action)
	objects.add_child(button)


func _inspect_desk() -> void:
	status.text = "A note reads: 'The answer is behind the painting.'"


func _inspect_painting() -> void:
	status.text = "Behind the painting is a message: 'The drawer is not locked.'"


func _open_drawer() -> void:
	if drawer_open:
		status.text = "The drawer is empty now."
		return
	drawer_open = true
	has_key = true
	status.text = "You found a brass key in the drawer!"
	_show_room()


func _try_door() -> void:
	if has_key:
		door_unlocked = true
		won = true
		status.text = "The key turns. The door opens. You escaped!"
		_show_room()
	else:
		status.text = "The door is locked. You need a key."


func _restart() -> void:
	has_key = false
	door_unlocked = false
	drawer_open = false
	won = false
	status.text = "You wake up in a locked study. Find a way out."
	_show_room()
