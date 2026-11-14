extends Control
## Basic image-based escape room. The puzzle logic is unchanged.
## Replace images using Edit Adventure (Student) on the main board.

var has_key := false
var door_unlocked := false
var drawer_open := false
var won := false
var status: Label
var inventory: HBoxContainer
var room_title: Label
var objects: GridContainer


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

	var back_button := Button.new()
	back_button.text = "← Back to boards"
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	layout.add_child(back_button)

	room_title = Label.new()
	room_title.add_theme_font_size_override("font_size", 28)
	layout.add_child(room_title)

	var hint := Label.new()
	hint.text = "Click the pictures to investigate. Replace images in Edit Adventure (Student)."
	layout.add_child(hint)

	var area := PanelContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(area)

	var room_background := TextureRect.new()
	room_background.texture = AssetStore.get_texture("background")
	room_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(room_background)

	var area_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		area_margin.add_theme_constant_override("margin_" + side, 24)
	area.add_child(area_margin)
	objects = GridContainer.new()
	objects.columns = 2
	objects.add_theme_constant_override("h_separation", 16)
	objects.add_theme_constant_override("v_separation", 16)
	area_margin.add_child(objects)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "You wake up in a locked study. Find a way out."
	layout.add_child(status)

	inventory = HBoxContainer.new()
	inventory.add_theme_constant_override("separation", 12)
	layout.add_child(inventory)


func _show_room() -> void:
	for child in objects.get_children():
		objects.remove_child(child)
		child.queue_free()
	for child in inventory.get_children():
		inventory.remove_child(child)
		child.queue_free()

	room_title.text = "The Locked Study" if not won else "Escape Complete!"
	if won:
		var again := Button.new()
		again.text = "Play again"
		again.pressed.connect(_restart)
		objects.add_child(again)
	else:
		_add_object("desk", "Inspect the desk", _inspect_desk)
		_add_object("drawer", "Open the drawer", _open_drawer)
		_add_object("painting", "Inspect the painting", _inspect_painting)
		_add_object("door", "Try the locked door", _try_door)

	var inventory_label := Label.new()
	inventory_label.text = "Inventory: Brass key" if has_key else "Inventory: Empty"
	inventory.add_child(inventory_label)
	if has_key:
		var key_icon := TextureRect.new()
		key_icon.texture = AssetStore.get_texture("key")
		key_icon.custom_minimum_size = Vector2(54, 54)
		key_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		key_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		inventory.add_child(key_icon)


func _add_object(slot: String, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(230, 160)
	button.text = caption
	button.icon = AssetStore.get_texture(slot)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
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
