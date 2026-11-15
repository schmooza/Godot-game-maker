extends Control
var optional_audio: Node
var game_intro: Node
var item_audio_editor: Node
var item_audio_players: Array[AudioStreamPlayer] = []
var editable_tooltips: Node
## Shared student-facing scene editor and test mode for all three game templates.
const VIEW_SIZE := Vector2(960, 540)
var testing := false
var selected := -1
var play_highlight_id := ""
var scene_area: Control
var objects_layer: Control
var backdrop: TextureRect
var status: Label
var object_picker: OptionButton
var x_edit: SpinBox
var y_edit: SpinBox
var w_edit: SpinBox
var h_edit: SpinBox
var label_edit: LineEdit
var action_edit: OptionButton
var target_edit: OptionButton
var blocker_edit: OptionButton
var blocked_message_edit: TextEdit
var message_edit: TextEdit
var post_use_message_edit: TextEdit
var item_edit: LineEdit
var use_effect_edit: OptionButton
var consume_item_edit: CheckBox
var simple_item_picker: OptionButton
var simple_damage: SpinBox
var simple_help: Label
var required_edit: LineEdit
var password_edit: LineEdit
var wrong_edit: LineEdit
var password_row: VBoxContainer
var password_input: LineEdit
var password_submit: Button
var pending_password_id := ""
var damage_message_edit: TextEdit
var damage_edit: SpinBox
var start_hp_edit: SpinBox
var hp_label: Label
var hp_panel: PanelContainer
var win_screen: TextureRect
var win_caption: Label
var current_hp := 3
var restart_pending := false
var hidden_edit: CheckBox
var inventory_label: Label
const ACTIONS := ["inspect", "swap", "reveal", "collect", "unlock", "password", "go_to_room", "win_game", "use_item"]
var file_dialog: FileDialog
var import_slot := ""
var drag_index := -1
var drag_offset := Vector2.ZERO
var state: Dictionary = {}
var won := false
var shots: Array[Vector2] = []
var enemy_shots: Array[Vector2] = []
var game_time := 0.0
var boss_health := 12
var lives := 3
var laps := 0
var race_distance := 0.0
var car_x := 0.5
var player_pos := Vector2(480, 450)
var game_canvas: Control
var editor_panel: ScrollContainer
var mode_banner: Label
var use_item_button: Button
var pending_use_item_id := ""
var play_dialogue: TextEdit
var play_dialogue_panel: Control
var play_layout: HBoxContainer
var viewport_holder: AspectRatioContainer
var main_row: HBoxContainer
var appearance_inputs: Dictionary = {}
var inventory_panel: PanelContainer
var room_picker: OptionButton
var room_name_input: LineEdit
var room_intro_edit: TextEdit
var destination_picker: OptionButton
var room_states: Dictionary = {}
var shared_inventory: Array = []
const APPEARANCE_DEFAULTS := {"dialogue_background":"#242424", "dialogue_text":"#FFFFFF", "dialogue_font_size":18, "inventory_background":"#303030", "inventory_text":"#FFFFFF", "inventory_font_size":16, "scene_tint":"#FFFFFF"}


func _section_panel(title_text: String, accent: Color) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.17, 0.17)
	style.border_width_left = 4
	style.border_color = accent
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	panel.add_child(content)
	var title_label := Label.new()
	title_label.text = title_text
	title_label.add_theme_color_override("font_color", accent)
	title_label.add_theme_font_size_override("font_size", 17)
	content.add_child(title_label)
	return content

func _organise_editor_sections(left: VBoxContainer, instruction: Label, picker: OptionButton, hp_control: SpinBox, appearance_start: Label, help_label: Label) -> void:
	# Use the original control order to avoid changing the underlying game logic.
	var existing := left.get_children()
	var scene_controls: Array[Node] = []
	var item_controls: Array[Node] = []
	var ui_controls: Array[Node] = []
	var group := "items"
	for node in existing:
		if node == instruction:
			group = "scene"
		if node == picker:
			group = "items"
		if node == appearance_start:
			group = "ui"
		if node == help_label:
			group = "scene"
		if node is Button and node.text in ["Import background", "Import winning image"]:
			scene_controls.append(node)
		elif node is Label and node.text in ["PLAYER HIT POINTS (Adventure)", "Starting HP"]:
			scene_controls.append(node)
		elif node == hp_control:
			scene_controls.append(node)
		elif group == "scene":
			scene_controls.append(node)
		elif group == "ui":
			ui_controls.append(node)
		else:
			item_controls.append(node)
	# Keep object selection and the entire quick-action panel together.
	# _section_panel returns its CONTENT VBoxContainer, not its PanelContainer.
	# The previous layout looked for a PanelContainer and accidentally hid the
	# quick actions in the collapsed advanced section.
	var quick_controls: Array[Node] = []
	for node in item_controls.duplicate():
		var is_quick_panel: bool = node is PanelContainer and node.get_child_count() > 0 and node.get_child(0) is VBoxContainer and node.get_child(0).get_child_count() > 0 and node.get_child(0).get_child(0) is Label and str(node.get_child(0).get_child(0).text).begins_with("QUICK INTERACTION SETUP")
		if node == label_edit or (node is Label and node.text == "Object name") or is_quick_panel:
			item_controls.erase(node)
			quick_controls.append(node)
	var scene_content := _section_panel("SCENE & GAME SETTINGS", Color(0.44, 0.76, 0.98))
	var item_content := _section_panel("ITEMS & INTERACTIONS", Color(0.99, 0.73, 0.37))
	var ui_content := _section_panel("UI & APPEARANCE", Color(0.55, 0.87, 0.65))
	for content in [scene_content, item_content, ui_content]:
		var panel: PanelContainer = content.get_parent()
		left.add_child(panel)
	for node in scene_controls:
		node.reparent(scene_content)
	# Keep room/object selection usable without opening Advanced.
	for node in item_controls.duplicate():
		if node == object_picker or node == room_picker or node == room_name_input or (node is Button and node.text in ["Add Room", "Add object", "Remove selected", "Import selected image"]) or (node is Label and node.text == "ROOMS (Adventure)"):
			node.reparent(item_content)
			item_controls.erase(node)
	# Put object name and coloured quick actions immediately after object selection.
	for node in quick_controls:
		node.reparent(item_content)
	# Make the whole quick panel visible, not just its heading.
	var quick_start: int = 0
	for i in range(item_content.get_child_count()):
		if item_content.get_child(i) == object_picker:
			quick_start = i + 1
			break
	for node in quick_controls:
		item_content.move_child(node, quick_start)
		quick_start += 1
	var advanced_toggle := Button.new()
	advanced_toggle.text = "Show advanced interaction settings"
	item_content.add_child(advanced_toggle)
	var advanced_content := VBoxContainer.new()
	advanced_content.visible = false
	item_content.add_child(advanced_content)
	advanced_toggle.pressed.connect(func():
		advanced_content.visible = not advanced_content.visible
		advanced_toggle.text = "Hide advanced interaction settings" if advanced_content.visible else "Show advanced interaction settings"
	)
	for node in item_controls:
		node.reparent(advanced_content)
	for node in ui_controls:
		node.reparent(ui_content)

func _ready() -> void:
	_build()
	_rebuild()
	_install_editable_tooltips()
	_install_optional_audio()
	_install_game_intro()
	_install_item_audio()
	set_process(true)

func _button(parent: Node, caption: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _quick_color_button(parent: Node, caption: String, callback: Callable, tint: Color, tip: String) -> Button:
	var b: Button = _button(parent, caption, callback)
	b.tooltip_text = tip
	b.custom_minimum_size.y = 36
	var normal := StyleBoxFlat.new()
	normal.bg_color = tint
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	b.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = tint.lightened(0.16)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.18)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	return b

func _install_editable_tooltips() -> void:
	var toolbar_row: HBoxContainer = find_child("TooltipToolbar",true,false) as HBoxContainer
	if toolbar_row == null:
		return
	editable_tooltips = load("res://scripts/editable_tooltips.gd").new()
	add_child(editable_tooltips)
	editable_tooltips.setup(self,toolbar_row,"adventure")

func _install_optional_audio() -> void:
	var sidebar: Node = find_child("TooltipScanSidebar",true,false)
	if sidebar == null:
		return
	# ScrollContainer must have a single content child.
	if sidebar is ScrollContainer and sidebar.get_child_count() > 0:
		sidebar = sidebar.get_child(0)
	optional_audio = load("res://scripts/optional_audio.gd").new()
	add_child(optional_audio)
	var sound_events: Array[String] = ["Background Music", "Item Collected", "Door Opened", "Door Locked", "Dialogue", "Damage", "Victory", "Defeat"]
	optional_audio.setup(self,sidebar,"adventure",sound_events)

func _install_item_audio() -> void:
	var sidebar: Node = find_child("TooltipScanSidebar",true,false)
	if sidebar == null:
		return
	if sidebar is ScrollContainer and sidebar.get_child_count() > 0:
		sidebar = sidebar.get_child(0)
	item_audio_editor = load("res://scripts/item_audio_editor.gd").new()
	add_child(item_audio_editor)
	item_audio_editor.setup(self,sidebar)
	item_audio_editor.sound_changed.connect(_on_item_sound_changed)
	_sync_item_audio()

func _sync_item_audio() -> void:
	if item_audio_editor == null:
		return
	if selected < 0 or selected >= _items().size():
		item_audio_editor.set_item("","")
		return
	var item: Dictionary = _items()[selected]
	item_audio_editor.set_item(str(item.get("id","")),str(item.get("custom_sound","")))

func _on_item_sound_changed(item_id: String, sound_path: String) -> void:
	for item in _items():
		if str(item.get("id","")) == item_id:
			item["custom_sound"] = sound_path
			_save()
			return

func _play_item_sound(item: Dictionary) -> void:
	var path := str(item.get("custom_sound",""))
	if path.is_empty():
		return
	var stream: AudioStream = preload("res://scripts/item_audio_editor.gd").load_audio(path)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = stream
	player.finished.connect(func():
		item_audio_players.erase(player)
		player.queue_free())
	item_audio_players.append(player)
	player.play()

func _install_game_intro() -> void:
	var sidebar: Node = find_child("TooltipScanSidebar",true,false)
	if sidebar == null:
		return
	if sidebar is ScrollContainer and sidebar.get_child_count() > 0:
		sidebar = sidebar.get_child(0)
	game_intro = load("res://scripts/game_intro.gd").new()
	add_child(game_intro)
	game_intro.setup(self,sidebar,"adventure","Adventure","Explore the rooms, find useful items, solve puzzles and escape!")

func _sound(event_name: String) -> void:
	if optional_audio != null:
		optional_audio.play(event_name)

func _build() -> void:
	var base := VBoxContainer.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.add_theme_constant_override("separation", 5)
	add_child(base)
	var toolbar := HBoxContainer.new()
	toolbar.name = "TooltipToolbar"
	base.add_child(toolbar)
	mode_banner = Label.new()
	mode_banner.text = "EDIT MODE — Arrange your scene"
	mode_banner.add_theme_font_size_override("font_size", 22)
	base.add_child(mode_banner)
	_button(toolbar, "← Games", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	# This editor is Adventure only. Racing and Boss have dedicated editors.
	# Never expose the legacy shared Boss mode (placeholder graphics/no dedicated controls).
	SharedData.mode = "adventure"
	_button(toolbar, "Save", _save)
	_button(toolbar, "Play / Test", _start_test)
	_button(toolbar, "Edit Scene", func(): testing = false; _rebuild())
	_button(toolbar, "Edit Adventure Code", func(): get_tree().change_scene_to_file("res://scenes/adventure_editor.tscn"))

	main_row = HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	base.add_child(main_row)
	var row := main_row
	editor_panel = ScrollContainer.new()
	editor_panel.name = "TooltipScanSidebar"
	editor_panel.custom_minimum_size.x = 280
	editor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(editor_panel)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 270
	editor_panel.add_child(left)
	var room_heading := Label.new()
	room_heading.text = "ROOMS (Adventure)"
	left.add_child(room_heading)
	room_picker = OptionButton.new()
	room_picker.item_selected.connect(_choose_room)
	left.add_child(room_picker)
	room_name_input = LineEdit.new()
	room_name_input.placeholder_text = "New room name (e.g. Room 2)"
	left.add_child(room_name_input)
	_button(left, "Add Room", _add_room)
	var intro_heading := Label.new()
	intro_heading.text = "ROOM INTRODUCTION DIALOGUE  |  Shown when entering this room"
	intro_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(intro_heading)
	room_intro_edit = TextEdit.new()
	room_intro_edit.custom_minimum_size = Vector2(0, 90)
	room_intro_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	room_intro_edit.placeholder_text = "Write what the player sees on entering this room. Leave blank for no introduction."
	room_intro_edit.text_changed.connect(_room_intro_changed)
	left.add_child(room_intro_edit)
	var instruction := Label.new()
	instruction.text = "SCENE EDITOR\nDrag objects in the room.\nSelect an object to edit it.\nImport images or add an object.\nSave, then Play / Test."
	left.add_child(instruction)
	object_picker = OptionButton.new()
	object_picker.item_selected.connect(_select)
	left.add_child(object_picker)
	_button(left, "Add object", _add_object)
	_button(left, "Remove selected", _remove_object)
	_button(left, "Import selected image", _choose_object_image)
	_button(left, "Import background", func(): _choose_image("background"))
	_button(left, "Import winning image", func(): _choose_image("win_screen"))
	var lbl := Label.new()
	lbl.text = "Object name"
	left.add_child(lbl)
	label_edit = LineEdit.new()
	label_edit.text_changed.connect(func(_value: String): _apply_properties())
	left.add_child(label_edit)
	# Student-friendly presets configure the existing action fields; advanced settings remain available.
	var simple_panel := _section_panel("PLAYER INTERACTIONS — SELECT AN OBJECT FIRST", Color(0.53, 0.91, 0.65))
	left.add_child(simple_panel.get_parent())
	simple_help = Label.new()
	simple_help.text = "STEP 1: Select the item object (e.g. gun), then click COLLECT. STEP 2: Select the target (e.g. Enemy), choose the item below, then click USE ITEM ON THIS OBJECT."
	simple_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	simple_panel.add_child(simple_help)
	_quick_color_button(simple_panel, "1. COLLECT THIS OBJECT  |  Add to player inventory", func(): _simple_preset("collect"), Color(0.13, 0.45, 0.25), "Make this object collectible and add it to the player inventory.")
	var item_caption := Label.new()
	item_caption.text = "2. REQUIRED INVENTORY ITEM  |  What will the player use?"
	simple_panel.add_child(item_caption)
	simple_item_picker = OptionButton.new()
	simple_item_picker.tooltip_text = "Choose an item collected earlier. The PLAYER uses this item on the selected object; the object does not attack itself."
	simple_panel.add_child(simple_item_picker)
	var damage_row := HBoxContainer.new()
	simple_panel.add_child(damage_row)
	var damage_caption := Label.new()
	damage_caption.text = "DAMAGE TO SELECTED OBJECT"
	damage_row.add_child(damage_caption)
	simple_damage = SpinBox.new()
	simple_damage.min_value = 1
	simple_damage.max_value = 100
	simple_damage.value = 1
	damage_row.add_child(simple_damage)
	_quick_color_button(simple_panel, "USE ITEM ON THIS OBJECT  |  Player damages target", func(): _simple_preset("attack"), Color(0.62, 0.19, 0.19), "The PLAYER clicks the selected object and uses the inventory item above to damage it.")
	_quick_color_button(simple_panel, "USE ITEM TO UNLOCK THIS OBJECT", func(): _simple_preset("unlock"), Color(0.14, 0.35, 0.63), "Require the selected inventory item to unlock or activate this object.")
	_quick_color_button(simple_panel, "HEAL PLAYER  |  Restore 1 HP", func(): _simple_preset("heal"), Color(0.42, 0.23, 0.58), "Make this object restore one health point when clicked.")
	_quick_color_button(simple_panel, "DOOR BLOCKER WIZARD  |  Set up Enemy + Door", _open_door_blocker_wizard, Color(0.29, 0.38, 0.60), "Connect an enemy, a door and an optional inventory item with dialogue.")
	var advanced_note := Label.new()
	advanced_note.text = "Choose the object first, then its action. Advanced settings remain available below."
	simple_panel.add_child(advanced_note)
	var action_heading := Label.new()
	action_heading.text = "On click (Adventure)"
	left.add_child(action_heading)
	action_edit = OptionButton.new()
	for a in ACTIONS: action_edit.add_item(a.capitalize())
	action_edit.item_selected.connect(func(_i: int): _apply_properties())
	left.add_child(action_edit)
	for field in ["Target object ID", "Message", "Inventory item", "Required item"]:
		var name_label := Label.new()
		name_label.text = field
		left.add_child(name_label)
		if field == "Target object ID":
			target_edit = OptionButton.new()
			target_edit.tooltip_text = "Select the object this action affects. The correct internal ID is saved automatically."
			target_edit.item_selected.connect(func(_i: int): _apply_properties())
			left.add_child(target_edit)
		elif field == "Message":
			message_edit = TextEdit.new()
			message_edit.custom_minimum_size = Vector2(0, 120)
			message_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			message_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			message_edit.scroll_fit_content_height = false
			var dialogue_style := StyleBoxFlat.new()
			dialogue_style.bg_color = Color(0.14, 0.14, 0.14)
			dialogue_style.content_margin_left = 5.0
			dialogue_style.content_margin_top = 5.0
			dialogue_style.content_margin_right = 5.0
			dialogue_style.content_margin_bottom = 5.0
			message_edit.add_theme_stylebox_override("normal", dialogue_style)
			message_edit.text_changed.connect(_apply_properties)
			left.add_child(message_edit)
		else:
			var edit := LineEdit.new()
			edit.text_changed.connect(func(_v: String): _apply_properties())
			left.add_child(edit)
			match field:
				"Inventory item": item_edit = edit
				"Required item": required_edit = edit
	var post_use_label := Label.new()
	post_use_label.text = "POST-USE DIALOGUE (shown after using an item)"
	left.add_child(post_use_label)
	post_use_message_edit = TextEdit.new()
	post_use_message_edit.custom_minimum_size = Vector2(0, 100)
	post_use_message_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	post_use_message_edit.placeholder_text = "Example: The enemy staggers backwards."
	post_use_message_edit.tooltip_text = "Shown after the player successfully uses the required inventory item. The Message field above is the inspection description."
	post_use_message_edit.text_changed.connect(_apply_properties)
	left.add_child(post_use_message_edit)
	var use_heading := Label.new()
	use_heading.text = "USE ITEM ON OBJECT (select Use Item action)"
	left.add_child(use_heading)
	var use_help := Label.new()
	use_help.text = "Required item = inventory name; Target object = choose the object affected.\nHP change below affects the target, not the player."
	use_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(use_help)
	use_effect_edit = OptionButton.new()
	for effect_name in ["Message only", "Damage target", "Reveal target", "Remove target"]:
		use_effect_edit.add_item(effect_name)
	use_effect_edit.tooltip_text = "Choose what using the inventory item does to the target object. Damage uses the HP change value (negative number)."
	use_effect_edit.item_selected.connect(func(_i: int): _apply_properties())
	left.add_child(use_effect_edit)
	consume_item_edit = CheckBox.new()
	consume_item_edit.text = "Consume required item after use"
	consume_item_edit.tooltip_text = "When checked, remove the required item from inventory after a successful interaction."
	consume_item_edit.toggled.connect(func(_v: bool): _apply_properties())
	left.add_child(consume_item_edit)
	var blocker_label := Label.new()
	blocker_label.text = "DOOR BLOCKED BY (Go to Room / Unlock)"
	left.add_child(blocker_label)
	blocker_edit = OptionButton.new()
	blocker_edit.tooltip_text = "Choose an object that must be defeated or removed before this door can open."
	blocker_edit.item_selected.connect(func(_i: int): _apply_properties())
	left.add_child(blocker_edit)
	var blocked_label := Label.new()
	blocked_label.text = "BLOCKED DIALOGUE"
	left.add_child(blocked_label)
	blocked_message_edit = TextEdit.new()
	blocked_message_edit.custom_minimum_size = Vector2(0, 75)
	blocked_message_edit.placeholder_text = "Example: Someone stands in front of the door."
	blocked_message_edit.tooltip_text = "Displayed while the blocking object is still active. No item hints are shown."
	blocked_message_edit.text_changed.connect(_apply_properties)
	left.add_child(blocked_message_edit)
	var destination_label := Label.new()
	destination_label.text = "Destination Room (Go to Room / Unlock)"
	left.add_child(destination_label)
	destination_picker = OptionButton.new()
	destination_picker.item_selected.connect(func(_i: int): _apply_properties())
	left.add_child(destination_picker)
	var password_label := Label.new()
	password_label.text = "Password (Adventure password action)"
	left.add_child(password_label)
	password_edit = LineEdit.new()
	password_edit.secret = false
	password_edit.placeholder_text = "Password or PIN"
	password_edit.text_changed.connect(func(_v: String): _apply_properties())
	left.add_child(password_edit)
	var damage_label := Label.new()
	damage_label.text = "HP change on click (+ heals, - damages, 0 = none)"
	left.add_child(damage_label)
	damage_edit = SpinBox.new()
	damage_edit.min_value = -100
	damage_edit.max_value = 100
	damage_edit.step = 1
	damage_edit.value_changed.connect(func(_value: float): _apply_properties())
	left.add_child(damage_edit)
	var damage_message_label := Label.new()
	damage_message_label.text = "Damage explanation (shown to player)"
	left.add_child(damage_message_label)
	damage_message_edit = TextEdit.new()
	damage_message_edit.custom_minimum_size = Vector2(0, 90)
	damage_message_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	damage_message_edit.placeholder_text = "Example: The painting is cursed!"
	damage_message_edit.text_changed.connect(_apply_properties)
	left.add_child(damage_message_edit)
	var hp_heading := Label.new()
	hp_heading.text = "PLAYER HIT POINTS (Adventure)"
	left.add_child(hp_heading)
	var hp_caption := Label.new()
	hp_caption.text = "Starting HP"
	left.add_child(hp_caption)
	start_hp_edit = SpinBox.new()
	start_hp_edit.min_value = 1
	start_hp_edit.max_value = 100
	start_hp_edit.step = 1
	start_hp_edit.value_changed.connect(_set_start_hp)
	left.add_child(start_hp_edit)
	var wrong_label := Label.new()
	wrong_label.text = "Incorrect password message"
	left.add_child(wrong_label)
	wrong_edit = LineEdit.new()
	wrong_edit.placeholder_text = "Incorrect password. Try again."
	wrong_edit.text_changed.connect(func(_v: String): _apply_properties())
	left.add_child(wrong_edit)
	hidden_edit = CheckBox.new()
	hidden_edit.text = "Hidden until revealed"
	hidden_edit.toggled.connect(func(_v: bool): _apply_properties())
	left.add_child(hidden_edit)
	for field in ["X (%)", "Y (%)", "Width", "Height"]:
		var field_label := Label.new()
		field_label.text = field
		left.add_child(field_label)
		var spin := SpinBox.new()
		spin.min_value = 0 if field.begins_with("X") or field.begins_with("Y") else 20
		spin.max_value = 100 if field.begins_with("X") or field.begins_with("Y") else 400
		spin.step = 1
		spin.value_changed.connect(func(_v: float): _apply_properties())
		left.add_child(spin)
		match field:
			"X (%)": x_edit = spin
			"Y (%)": y_edit = spin
			"Width": w_edit = spin
			"Height": h_edit = spin
	var appearance_heading := Label.new()
	appearance_heading.text = "APPEARANCE (Play Mode)"
	left.add_child(appearance_heading)
	for setting in APPEARANCE_DEFAULTS:
		var heading := Label.new()
		heading.text = setting.replace("_", " ").capitalize()
		left.add_child(heading)
		if setting.ends_with("font_size"):
			var size_input := SpinBox.new()
			size_input.min_value = 10
			size_input.max_value = 36
			size_input.value = APPEARANCE_DEFAULTS[setting]
			size_input.value_changed.connect(_appearance_changed.bind(setting))
			left.add_child(size_input)
			appearance_inputs[setting] = size_input
		else:
			var color_input := LineEdit.new()
			color_input.placeholder_text = "#RRGGBB"
			color_input.text = APPEARANCE_DEFAULTS[setting]
			color_input.text_changed.connect(_appearance_text_changed.bind(setting))
			left.add_child(color_input)
			appearance_inputs[setting] = color_input
	_button(left, "Reset appearance", _reset_appearance)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = "ADVENTURE: Click hidden objects to find clues.\nRACING: Left/Right to dodge, finish 3 laps.\nBOSS: Arrow keys to move, Space to shoot.\n\nObjects use the same image, position and size controls in every game."
	left.add_child(help)
	# Organise the existing editor controls into colour-coded functional sections.
	# Reparenting preserves all existing signal connections and edit behaviour.
	_organise_editor_sections(left, instruction, object_picker, start_hp_edit, appearance_heading, help)
	# In Play Mode the dialogue takes one third and the scene two thirds.
	play_layout = HBoxContainer.new()
	play_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_layout.add_theme_constant_override("separation", 5)
	row.add_child(play_layout)
	play_dialogue_panel = PanelContainer.new()
	play_dialogue_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_dialogue_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_dialogue_panel.size_flags_stretch_ratio = 1.0
	play_layout.add_child(play_dialogue_panel)
	var dialogue_margin := MarginContainer.new()
	play_dialogue_panel.add_child(dialogue_margin)
	var dialogue_stack := VBoxContainer.new()
	dialogue_margin.add_child(dialogue_stack)
	var dialogue_title := Label.new()
	dialogue_title.text = "Dialogue"
	dialogue_stack.add_child(dialogue_title)
	play_dialogue = TextEdit.new()
	play_dialogue.editable = false
	play_dialogue.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	play_dialogue.scroll_fit_content_height = false
	play_dialogue.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_dialogue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var play_style := StyleBoxFlat.new()
	play_style.bg_color = Color(0.14, 0.14, 0.14)
	play_style.content_margin_left = 5.0
	play_style.content_margin_top = 5.0
	play_style.content_margin_right = 5.0
	play_style.content_margin_bottom = 5.0
	play_dialogue.add_theme_stylebox_override("normal", play_style)
	dialogue_stack.add_child(play_dialogue)
	use_item_button = Button.new()
	use_item_button.visible = false
	use_item_button.pressed.connect(_use_selected_item)
	dialogue_stack.add_child(use_item_button)
	password_row = VBoxContainer.new()
	dialogue_stack.add_child(password_row)
	var password_prompt := Label.new()
	password_prompt.text = "Enter password:"
	password_row.add_child(password_prompt)
	password_input = LineEdit.new()
	password_input.placeholder_text = "Password or PIN"
	password_input.secret = false
	password_row.add_child(password_input)
	password_submit = _button(password_row, "Submit", _submit_password)
	password_input.text_submitted.connect(func(_value: String): _submit_password())
	password_row.visible = false
	viewport_holder = AspectRatioContainer.new()
	viewport_holder.ratio = 960.0 / 540.0
	viewport_holder.stretch_mode = AspectRatioContainer.STRETCH_FIT
	viewport_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_holder.size_flags_stretch_ratio = 2.0
	viewport_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	play_layout.add_child(viewport_holder)
	scene_area = Control.new()
	scene_area.custom_minimum_size = Vector2.ZERO
	scene_area.resized.connect(_rebuild)
	scene_area.mouse_filter = Control.MOUSE_FILTER_PASS
	viewport_holder.add_child(scene_area)
	backdrop = TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_area.add_child(backdrop)
	objects_layer = Control.new()
	objects_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	objects_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	scene_area.add_child(objects_layer)
	game_canvas = Control.new()
	game_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_area.add_child(game_canvas)
	game_canvas.draw.connect(_draw_game)
	# Victory image replaces the room, without affecting the dialogue/inventory.
	win_screen = TextureRect.new()
	win_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	win_screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	win_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_screen.visible = false
	scene_area.add_child(win_screen)
	win_caption = Label.new()
	win_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	win_caption.add_theme_font_size_override("font_size", 42)
	win_caption.text = "YOU WIN!"
	win_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win_caption.visible = false
	scene_area.add_child(win_caption)
	# Keep the HP indicator pinned to the top-right of the room image.
	hp_panel = PanelContainer.new()
	hp_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	hp_panel.position = Vector2(-122, 8)
	hp_panel.custom_minimum_size = Vector2(114, 30)
	hp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hp_style := StyleBoxFlat.new()
	hp_style.bg_color = Color(0.10, 0.10, 0.10, 0.85)
	hp_style.set_content_margin_all(5)
	hp_panel.add_theme_stylebox_override("panel", hp_style)
	scene_area.add_child(hp_panel)
	hp_label = Label.new()
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_panel.add_child(hp_label)
	status = Label.new()
	status.text = "Select and drag an object to place it."
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	base.add_child(status)
	status.visible = false
	inventory_panel = PanelContainer.new()
	base.add_child(inventory_panel)
	inventory_label = Label.new()
	inventory_panel.add_child(inventory_label)
	inventory_label.text = "Inventory: Empty"
	inventory_label.custom_minimum_size.y = 28
	inventory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.use_native_dialog = true
	file_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp", "Images")
	file_dialog.file_selected.connect(_image_selected)
	add_child(file_dialog)

func _refresh_room_controls() -> void:
	room_picker.visible = SharedData.mode == "adventure"
	room_name_input.visible = SharedData.mode == "adventure"
	room_picker.clear()
	destination_picker.clear()
	destination_picker.add_item("None / finish game")
	if SharedData.mode != "adventure":
		return
	var rooms := SharedData.room_names()
	for room in rooms:
		room_picker.add_item(str(room))
		destination_picker.add_item(str(room))
	room_picker.select(rooms.find(SharedData.active_room))

func _room_intro_changed() -> void:
	if testing: return
	SharedData.current_scene()["room_intro"] = room_intro_edit.text

func _sync_room_intro() -> void:
	if room_intro_edit == null: return
	room_intro_edit.set_block_signals(true)
	room_intro_edit.text = str(SharedData.current_scene().get("room_intro", ""))
	room_intro_edit.set_block_signals(false)

func _choose_room(index: int) -> void:
	if testing or SharedData.mode != "adventure": return
	var rooms := SharedData.room_names()
	if index < 0 or index >= rooms.size(): return
	SharedData.active_room = str(rooms[index])
	selected = 0
	_rebuild()

func _add_room() -> void:
	if testing or SharedData.mode != "adventure": return
	if SharedData.add_room(room_name_input.text):
		selected = -1
		room_name_input.clear()
		SharedData.save()
		_rebuild()
		status.text = "New room created. Import a background and add objects."
	else:
		status.text = "Enter a unique room name."

func _change_room(destination: String) -> void:
	if not SharedData.room_names().has(destination):
		return
	room_states[SharedData.active_room] = state
	SharedData.active_room = destination
	state = room_states.get(destination, {})
	state["items"] = shared_inventory
	pending_password_id = ""
	play_highlight_id = ""
	_rebuild()

func _appearance() -> Dictionary:
	var scene: Dictionary = SharedData.current_scene()
	var saved: Dictionary = scene.get("appearance", {})
	var result := APPEARANCE_DEFAULTS.duplicate()
	for key in saved:
		if result.has(key): result[key] = saved[key]
	return result

func _appearance_text_changed(value: String, setting: String) -> void:
	if not value.begins_with("#") or not value.is_valid_html_color(): return
	SharedData.current_scene()["appearance"] = _appearance()
	SharedData.current_scene()["appearance"][setting] = value
	_apply_appearance()

func _appearance_changed(value: float, setting: String) -> void:
	SharedData.current_scene()["appearance"] = _appearance()
	SharedData.current_scene()["appearance"][setting] = int(value)
	_apply_appearance()

func _reset_appearance() -> void:
	SharedData.current_scene()["appearance"] = APPEARANCE_DEFAULTS.duplicate()
	_sync_appearance_inputs()
	_apply_appearance()

func _sync_appearance_inputs() -> void:
	var config := _appearance()
	for setting in appearance_inputs:
		var input: Control = appearance_inputs[setting]
		input.set_block_signals(true)
		if input is SpinBox: input.value = float(config[setting])
		elif input is LineEdit: input.text = str(config[setting])
		input.set_block_signals(false)

func _apply_appearance() -> void:
	var config := _appearance()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(str(config["dialogue_background"]))
	style.content_margin_left = 5.0
	style.content_margin_top = 5.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 5.0
	play_dialogue.add_theme_stylebox_override("normal", style)
	play_dialogue.add_theme_color_override("font_readonly_color", Color.html(str(config["dialogue_text"])))
	play_dialogue.add_theme_color_override("font_color", Color.html(str(config["dialogue_text"])))
	play_dialogue.add_theme_font_size_override("font_size", int(config["dialogue_font_size"]))
	var inventory_style := StyleBoxFlat.new()
	inventory_style.bg_color = Color.html(str(config["inventory_background"]))
	inventory_style.content_margin_left = 5.0
	inventory_style.content_margin_right = 5.0
	inventory_panel.add_theme_stylebox_override("panel", inventory_style)
	inventory_label.add_theme_color_override("font_color", Color.html(str(config["inventory_text"])))
	inventory_label.add_theme_font_size_override("font_size", int(config["inventory_font_size"]))
	backdrop.modulate = Color.html(str(config["scene_tint"]))

func _starting_hp() -> int:
	return maxi(1, int(SharedData.current_scene().get("starting_hp", 3)))

func _set_start_hp(value: float) -> void:
	if testing: return
	SharedData.current_scene()["starting_hp"] = int(value)

func _items() -> Array:
	return SharedData.current_scene()["objects"]

func _mark_visual(control: Control, active: bool, in_play: bool) -> void:
	# Keep the image itself highlighted in Play Mode; outline only in Edit Mode.
	control.modulate = Color(1.0, 0.95, 0.65) if active and in_play else Color.WHITE
	var outline := control.get_node_or_null("SelectionOutline") as Panel
	if outline == null:
		outline = Panel.new()
		outline.name = "SelectionOutline"
		outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		control.add_child(outline)
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0, 0, 0, 0)
	border.draw_center = false
	border.set_border_width_all(3)
	border.border_color = Color(1.0, 0.85, 0.25) if in_play else Color(0.3, 0.85, 1.0)
	outline.add_theme_stylebox_override("panel", border)
	outline.visible = active

func _refresh_object_highlights() -> void:
	var items := _items()
	for i in range(mini(items.size(), objects_layer.get_child_count())):
		var control := objects_layer.get_child(i) as Control
		if control == null: continue
		var active := str(items[i].get("id", "")) == play_highlight_id if testing else i == selected
		_mark_visual(control, active, testing)

func _rebuild() -> void:
	if editable_tooltips != null:
		editable_tooltips.call_deferred("refresh")
	_refresh_room_controls()
	_sync_room_intro()
	_sync_appearance_inputs()
	_apply_appearance()
	start_hp_edit.set_block_signals(true)
	start_hp_edit.value = _starting_hp()
	start_hp_edit.set_block_signals(false)
	backdrop.texture = SharedData.texture("background")
	var victory_visible := testing and SharedData.mode == "adventure" and won
	win_screen.texture = SharedData.texture("win_screen") if victory_visible else null
	win_screen.visible = victory_visible and win_screen.texture != null
	win_caption.visible = victory_visible and win_screen.texture == null
	# Hide room objects on victory; keep the health indicator available during play.
	objects_layer.visible = not victory_visible
	game_canvas.visible = not victory_visible
	hp_panel.visible = testing and SharedData.mode == "adventure" and not victory_visible
	_update_hp_label()
	for c in objects_layer.get_children():
		objects_layer.remove_child(c)
		c.queue_free()
	object_picker.clear()
	var items := _items()
	var scale_factor := minf(scene_area.size.x / VIEW_SIZE.x, scene_area.size.y / VIEW_SIZE.y)
	if scale_factor <= 0.0: scale_factor = 1.0
	for i in range(items.size()):
		var item: Dictionary = items[i]
		object_picker.add_item(str(item.get("label", item.get("id", "Object"))))
		if testing and SharedData.mode == "adventure":
			if state.get("collected_" + str(item["id"]), false): continue
			if bool(item.get("hidden", false)) and not state.get("revealed_" + str(item["id"]), false): continue
		var b := TextureButton.new()
		# Do not draw Godot keyboard-focus outlines on clickable play objects.
		# The editor retains its normal object-selection behaviour.
		if testing:
			b.focus_mode = Control.FOCUS_NONE
		var texture_slot := str(item["id"])
		if testing and state.get("swapped_" + texture_slot, false):
			texture_slot += "_open"
		b.texture_normal = SharedData.texture(texture_slot)
		if b.texture_normal == null and texture_slot.ends_with("_open"):
			b.texture_normal = SharedData.texture(str(item["id"]))
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.position = Vector2(float(item["x"]) * scene_area.size.x, float(item["y"]) * scene_area.size.y) - Vector2(float(item["w"]), float(item["h"])) * scale_factor / 2.0
		b.size = Vector2(float(item["w"]), float(item["h"])) * scale_factor
		b.tooltip_text = str(item["label"]) if not testing else ""
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if testing else Control.CURSOR_ARROW
		if b.texture_normal == null:
			var fallback := Button.new()
			if testing:
				fallback.focus_mode = Control.FOCUS_NONE
			fallback.text = str(item["label"]) if not testing else ""
			fallback.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if testing else Control.CURSOR_ARROW
			fallback.position = b.position
			fallback.size = b.size
			if testing:
				fallback.pressed.connect(_interact.bind(str(item["id"])))
			else:
				# Text-only custom objects must receive drag events too.
				fallback.gui_input.connect(_drag_input.bind(i))
			objects_layer.add_child(fallback)
			b.queue_free()
		else:
			if testing:
				b.pressed.connect(_interact.bind(str(item["id"])))
			else:
				b.gui_input.connect(_drag_input.bind(i))
			objects_layer.add_child(b)
	_refresh_object_highlights()
	_refresh_simple_items()
	if not testing and items.size() > 0:
		_select(clampi(selected, 0, items.size() - 1))
	elif not testing:
		selected = -1
	mode_banner.text = ("PLAY MODE — " if testing else "EDIT MODE — ") + (SharedData.active_room if SharedData.mode == "adventure" else SharedData.mode.capitalize())
	editor_panel.visible = not testing
	play_dialogue_panel.visible = testing
	# The editor uses the whole width for the scene; Play Mode is 1:2.
	viewport_holder.size_flags_stretch_ratio = 2.0 if testing else 1.0
	status.visible = not testing
	if testing:
		# Student-authored, per-room introduction; never prescribe a puzzle solution.
		status.text = str(SharedData.current_scene().get("room_intro", ""))
		play_dialogue.text = status.text
	else:
		status.text = "EDIT: Drag objects on the scene. Save your layout before testing."
	if use_item_button != null:
		use_item_button.visible = testing and not pending_use_item_id.is_empty() and SharedData.mode == "adventure"
	password_row.visible = testing and not pending_password_id.is_empty() and SharedData.mode == "adventure"
	_update_inventory()
	game_canvas.queue_redraw()

func _refresh_simple_items() -> void:
	if simple_item_picker == null:
		return
	var previous: String = ""
	if simple_item_picker.selected >= 0:
		previous = str(simple_item_picker.get_item_metadata(simple_item_picker.selected))
	simple_item_picker.clear()
	simple_item_picker.add_item("Choose collected item...")
	simple_item_picker.set_item_metadata(0, "")
	var selection_index: int = 0
	for entry in _items():
		if str(entry.get("action", "")) != "collect":
			continue
		var item_name: String = str(entry.get("item", ""))
		if item_name.is_empty():
			item_name = str(entry.get("label", ""))
		if item_name.is_empty():
			continue
		var index: int = simple_item_picker.item_count
		simple_item_picker.add_item(item_name)
		simple_item_picker.set_item_metadata(index, item_name)
		if item_name == previous:
			selection_index = index
	simple_item_picker.select(selection_index)

func _simple_preset(preset: String) -> void:
	if testing or selected < 0 or selected >= _items().size():
		return
	var obj: Dictionary = _items()[selected]
	var item_name: String = ""
	if simple_item_picker.selected > 0:
		item_name = str(simple_item_picker.get_item_metadata(simple_item_picker.selected))
	if preset in ["attack", "unlock"] and item_name.is_empty():
		simple_help.text = "First make another object collectible, then select its item name above."
		return
	match preset:
		"collect":
			obj["action"] = "collect"
			obj["item"] = str(obj.get("label", "Item"))
			obj["hp_change"] = 0
		"attack":
			obj["action"] = "use_item"
			obj["required"] = item_name
			obj["target"] = str(obj.get("id", ""))
			obj["use_effect"] = 1
			obj["hp_change"] = -int(simple_damage.value)
			obj["consume_item"] = false
		"unlock":
			obj["action"] = "unlock"
			obj["required"] = item_name
			obj["hp_change"] = 0
		"heal":
			obj["action"] = "inspect"
			obj["hp_change"] = 1
	_select(selected)
	simple_help.text = ("Player collects " + str(obj.get("label", "item")) + "." if preset == "collect" else "Player uses " + item_name + " on " + str(obj.get("label", "target")) + "." if preset == "attack" else "Player uses " + item_name + " to unlock " + str(obj.get("label", "object")) + "." if preset == "unlock" else "Player heals by clicking " + str(obj.get("label", "object")) + ".") + " Click Save, then Play / Test."

func _open_door_blocker_wizard() -> void:
	if testing or SharedData.mode != "adventure":
		return
	if _items().size() < 2:
		status.text = "Add at least two objects (a blocker and a door) first."
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Door Blocker Wizard"
	dialog.ok_button_text = "Create Door Blocker"
	dialog.min_size = Vector2i(560, 500)
	add_child(dialog)
	# Keep the built-in Cancel/Create buttons visible while the fields scroll.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 390)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	scroll.add_child(content)
	var intro := Label.new()
	intro.text = "Choose the blocker and the door. The player sees dialogue, not item hints."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)
	var enemy_picker := OptionButton.new()
	var door_picker := OptionButton.new()
	for entry in _items():
		var name: String = str(entry.get("label", "Object"))
		enemy_picker.add_item(name)
		enemy_picker.set_item_metadata(enemy_picker.item_count - 1, str(entry.get("id", "")))
		door_picker.add_item(name)
		door_picker.set_item_metadata(door_picker.item_count - 1, str(entry.get("id", "")))
		if name.to_lower().contains("enemy") or name.to_lower().contains("guard"):
			enemy_picker.select(enemy_picker.item_count - 1)
		if name.to_lower().contains("door") or name.to_lower().contains("gate"):
			door_picker.select(door_picker.item_count - 1)
	_wizard_field(content, "Object blocking the door", enemy_picker)
	_wizard_field(content, "Door to block", door_picker)
	var item_picker := OptionButton.new()
	item_picker.add_item("No item required (remove blocker manually)")
	item_picker.set_item_metadata(0, "")
	for entry in _items():
		if str(entry.get("action", "")) == "collect":
			var item_name: String = str(entry.get("item", ""))
			if item_name.is_empty(): item_name = str(entry.get("label", ""))
			item_picker.add_item(item_name)
			item_picker.set_item_metadata(item_picker.item_count - 1, item_name)
	_wizard_field(content, "Inventory item used on blocker", item_picker)
	var enemy_message := LineEdit.new()
	enemy_message.placeholder_text = "A dangerous enemy watches the doorway."
	_wizard_field(content, "Blocker description (inspection)", enemy_message)
	var blocked_message := LineEdit.new()
	blocked_message.text = "Someone stands in front of the door."
	_wizard_field(content, "Dialogue when door is blocked", blocked_message)
	var post_message := LineEdit.new()
	post_message.text = "The enemy falls. The path is clear."
	_wizard_field(content, "Dialogue after using the item", post_message)
	var warning := Label.new()
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(warning)
	dialog.confirmed.connect(func() -> void:
		var blocker_id: String = str(enemy_picker.get_item_metadata(enemy_picker.selected))
		var door_id: String = str(door_picker.get_item_metadata(door_picker.selected))
		if blocker_id == door_id:
			status.text = "Choose two different objects for the blocker and door."
			return
		var blocker: Dictionary = _find_object(blocker_id)
		var door: Dictionary = _find_object(door_id)
		if blocker.is_empty() or door.is_empty(): return
		var required_item: String = str(item_picker.get_item_metadata(item_picker.selected))
		if not enemy_message.text.strip_edges().is_empty():
			blocker["message"] = enemy_message.text
		if not required_item.is_empty():
			blocker["action"] = "use_item"
			blocker["required"] = required_item
			blocker["target"] = blocker_id
			blocker["use_effect"] = 1
			blocker["hp_change"] = -1
			blocker["consume_item"] = false
			blocker["post_use_message"] = post_message.text
		door["blocked_by"] = blocker_id
		door["blocked_message"] = blocked_message.text
		if str(door.get("action", "")) not in ["go_to_room", "unlock"]:
			door["action"] = "go_to_room"
		_select(selected)
		status.text = "Door blocker created. Set the door destination, then Save and Play / Test."
	)
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	dialog.confirmed.connect(func() -> void: dialog.queue_free(), CONNECT_DEFERRED)
	dialog.popup_centered(Vector2i(580, 540))

func _wizard_field(parent: VBoxContainer, caption: String, field: Control) -> void:
	var label := Label.new()
	label.text = caption
	parent.add_child(label)
	parent.add_child(field)

func _refresh_target_options(current_target: String) -> void:
	# The label is for students; the internal ID is stored as item metadata.
	target_edit.clear()
	target_edit.add_item("None")
	target_edit.set_item_metadata(0, "")
	var matching_index: int = 0
	for entry in _items():
		var object_id: String = str(entry.get("id", ""))
		var object_name: String = str(entry.get("label", "Unnamed object"))
		var index: int = target_edit.item_count
		target_edit.add_item(object_name)
		target_edit.set_item_metadata(index, object_id)
		if object_id == current_target:
			matching_index = index
	if not current_target.is_empty() and matching_index == 0:
		var missing_index: int = target_edit.item_count
		target_edit.add_item("Missing object (" + current_target + ")")
		target_edit.set_item_metadata(missing_index, current_target)
		matching_index = missing_index
	target_edit.select(matching_index)

func _refresh_blocker_options(current_id: String) -> void:
	blocker_edit.clear()
	blocker_edit.add_item("None (door is not blocked)")
	blocker_edit.set_item_metadata(0, "")
	var match_index: int = 0
	for entry in _items():
		var object_id: String = str(entry.get("id", ""))
		if selected >= 0 and selected < _items().size() and object_id == str(_items()[selected].get("id", "")):
			continue
		var index: int = blocker_edit.item_count
		blocker_edit.add_item(str(entry.get("label", "Unnamed object")))
		blocker_edit.set_item_metadata(index, object_id)
		if object_id == current_id: match_index = index
	if not current_id.is_empty() and match_index == 0:
		var index: int = blocker_edit.item_count
		blocker_edit.add_item("Missing object (" + current_id + ")")
		blocker_edit.set_item_metadata(index, current_id)
		match_index = index
	blocker_edit.select(match_index)

func _door_is_blocked(obj: Dictionary) -> bool:
	var blocker_id: String = str(obj.get("blocked_by", ""))
	if blocker_id.is_empty(): return false
	if bool(state.get("collected_" + blocker_id, false)): return false
	# A missing blocker should not permanently trap a player.
	return not _find_object(blocker_id).is_empty()

func _select(index: int) -> void:
	if index < 0 or index >= _items().size(): return
	selected = index
	_refresh_object_highlights()
	object_picker.select(index)
	var o: Dictionary = _items()[index]
	_sync_item_audio()
	label_edit.set_block_signals(true)
	x_edit.set_block_signals(true)
	y_edit.set_block_signals(true)
	w_edit.set_block_signals(true)
	h_edit.set_block_signals(true)
	for widget in [action_edit, target_edit, blocker_edit, blocked_message_edit, message_edit, post_use_message_edit, item_edit, required_edit, password_edit, wrong_edit, hidden_edit, damage_edit, damage_message_edit, destination_picker, use_effect_edit, consume_item_edit]:
		widget.set_block_signals(true)
	label_edit.text = str(o["label"])
	x_edit.value = round(float(o["x"]) * 100.0)
	y_edit.value = round(float(o["y"]) * 100.0)
	w_edit.value = float(o["w"])
	h_edit.value = float(o["h"])
	action_edit.select(maxi(0, ACTIONS.find(str(o.get("action", "inspect")))))
	var destination := str(o.get("destination_room", ""))
	var destination_index := SharedData.room_names().find(destination) + 1 if SharedData.mode == "adventure" else 0
	destination_picker.select(maxi(0, destination_index))
	_refresh_target_options(str(o.get("target", "")))
	_refresh_blocker_options(str(o.get("blocked_by", "")))
	blocked_message_edit.text = str(o.get("blocked_message", ""))
	message_edit.text = str(o.get("message", ""))
	post_use_message_edit.text = str(o.get("post_use_message", ""))
	item_edit.text = str(o.get("item", ""))
	required_edit.text = str(o.get("required", ""))
	use_effect_edit.select(clampi(int(o.get("use_effect", 0)), 0, 3))
	consume_item_edit.button_pressed = bool(o.get("consume_item", false))
	password_edit.text = str(o.get("password", ""))
	wrong_edit.text = str(o.get("wrong_message", "Incorrect password. Try again."))
	damage_edit.value = int(o.get("hp_change", -int(o.get("damage", 0))))
	damage_message_edit.text = str(o.get("damage_message", ""))
	hidden_edit.button_pressed = bool(o.get("hidden", false))
	for widget in [label_edit, x_edit, y_edit, w_edit, h_edit, action_edit, target_edit, blocker_edit, blocked_message_edit, message_edit, post_use_message_edit, item_edit, required_edit, password_edit, wrong_edit, hidden_edit, damage_edit, damage_message_edit, destination_picker, use_effect_edit, consume_item_edit]:
		widget.set_block_signals(false)

func _apply_properties() -> void:
	if testing or selected < 0 or selected >= _items().size(): return
	var o: Dictionary = _items()[selected]
	o["label"] = label_edit.text
	o["x"] = x_edit.value / 100.0
	o["y"] = y_edit.value / 100.0
	o["w"] = w_edit.value
	o["h"] = h_edit.value
	o["action"] = ACTIONS[action_edit.selected]
	o["destination_room"] = destination_picker.get_item_text(destination_picker.selected) if destination_picker.selected > 0 else ""
	o["target"] = str(target_edit.get_item_metadata(target_edit.selected)) if target_edit.selected >= 0 else ""
	o["blocked_by"] = str(blocker_edit.get_item_metadata(blocker_edit.selected)) if blocker_edit.selected >= 0 else ""
	o["blocked_message"] = blocked_message_edit.text
	o["message"] = message_edit.text
	o["post_use_message"] = post_use_message_edit.text
	o["item"] = item_edit.text
	o["required"] = required_edit.text
	o["use_effect"] = use_effect_edit.selected
	o["consume_item"] = consume_item_edit.button_pressed
	o["password"] = password_edit.text
	o["wrong_message"] = wrong_edit.text
	o["hp_change"] = int(damage_edit.value)
	o["damage"] = 0 # Legacy field retained for older saves
	o["damage_message"] = damage_message_edit.text
	o["hidden"] = hidden_edit.button_pressed
	# Do not rebuild the editor while a LineEdit has keyboard focus.
	# Rebuilding called _select(), which reset the caret to position zero.
	# Update only the selected object and its list label in place.
	object_picker.set_item_text(selected, str(o["label"]))
	# Keep target names in sync when students rename an object.
	var target_id: String = str(o.get("target", ""))
	var previous_selection: int = target_edit.selected
	var previous_id: String = str(target_edit.get_item_metadata(previous_selection)) if previous_selection >= 0 else ""
	_refresh_target_options(previous_id)
	var previous_blocker: String = str(o.get("blocked_by", ""))
	blocker_edit.set_block_signals(true)
	_refresh_blocker_options(previous_blocker)
	blocker_edit.set_block_signals(false)

	if selected < objects_layer.get_child_count():
		var visual: Control = objects_layer.get_child(selected)
		var area_size := scene_area.size
		visual.position = Vector2(float(o["x"]) * area_size.x, float(o["y"]) * area_size.y) - Vector2(float(o["w"]), float(o["h"])) * minf(area_size.x / 960.0, area_size.y / 540.0) / 2.0
		visual.size = Vector2(float(o["w"]), float(o["h"])) * minf(area_size.x / 960.0, area_size.y / 540.0)
		visual.tooltip_text = str(o["label"])

func _select_with_sound(index: int) -> void:
	_select(index)
	if index >= 0 and index < _items().size():
		_play_item_sound(_items()[index])

func _drag_input(event: InputEvent, index: int) -> void:
	if testing: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_select_with_sound(index)
				drag_index = index
				drag_offset = get_global_mouse_position() - objects_layer.get_child(index).global_position
			else:
				drag_index = -1
	if event is InputEventMouseMotion and drag_index == index:
		var local := objects_layer.get_global_transform().affine_inverse() * get_global_mouse_position()
		var item: Dictionary = _items()[index]
		var factor := minf(scene_area.size.x / VIEW_SIZE.x, scene_area.size.y / VIEW_SIZE.y)
		var middle := local - drag_offset + Vector2(float(item["w"]),float(item["h"])) * factor / 2.0
		item["x"] = clampf(middle.x / scene_area.size.x, 0.0, 1.0)
		item["y"] = clampf(middle.y / scene_area.size.y, 0.0, 1.0)
		objects_layer.get_child(index).position = Vector2(item["x"] * scene_area.size.x, item["y"] * scene_area.size.y) - Vector2(float(item["w"]),float(item["h"])) * factor / 2.0
		_select(index)

func _add_object() -> void:
	if testing: return
	var id := "object_" + str(Time.get_ticks_msec())
	_items().append({"id":id,"label":"New clue","x":0.5,"y":0.5,"w":80,"h":80,"action":"inspect","message":"You found a clue."})
	selected = _items().size() - 1
	_rebuild()

func _remove_object() -> void:
	if testing or selected < 0: return
	_items().remove_at(selected)
	selected = 0
	_rebuild()

func _choose_object_image() -> void:
	if selected < 0: return
	_choose_image(str(_items()[selected]["id"]))

func _choose_image(slot: String) -> void:
	import_slot = slot
	file_dialog.popup_centered_ratio(0.7)

func _image_selected(path: String) -> void:
	status.text = "Image imported." if SharedData.import_image(import_slot,path) else "Could not import image."
	_rebuild()

func _save() -> void:
	status.text = "Saved scene layouts." if SharedData.save() else "Save failed."

func _reset_scene() -> void:
	SharedData.reset_mode()
	SharedData.save()
	selected = 0
	testing = false
	_rebuild()

func _start_test() -> void:
	if game_intro != null:
		game_intro.show_intro(Callable(self,"_start_test_actual"))
	else:
		_start_test_actual()

func _start_test_actual() -> void:
	play_highlight_id = ""
	pending_use_item_id = ""
	if use_item_button != null: use_item_button.visible = false
	if not SharedData.save():
		status.text = "Save failed; starting test with unsaved changes."
	testing = true
	_sound("Background Music")
	state.clear()
	room_states.clear()
	shared_inventory.clear()
	SharedData.active_room = "Room 1"
	SharedData.ensure_rooms()
	state["items"] = shared_inventory
	current_hp = _starting_hp()
	restart_pending = false
	pending_password_id = ""
	password_input.clear()
	won = false
	shots.clear()
	enemy_shots.clear()
	boss_health = 12
	lives = 3
	laps = 0
	race_distance = 0.0
	car_x = 0.5
	player_pos = Vector2(480,450)
	game_time = 0.0
	_rebuild()

func _find_object(id: String) -> Dictionary:
	for entry in _items():
		var obj: Dictionary = entry
		if str(obj.get("id", "")) == id: return obj
	return {}

func _update_hp_label() -> void:
	if hp_label != null:
		hp_label.text = "Hit Points: " + str(current_hp) + "/" + str(_starting_hp())

func _update_inventory() -> void:
	if inventory_label == null: return
	var items: Array = state.get("items", [])
	inventory_label.text = "Inventory: " + (", ".join(items) if testing and not items.is_empty() else "Empty")
	if testing and SharedData.mode == "adventure":
		_update_hp_label()

func _use_selected_item() -> void:
	if not testing or pending_use_item_id.is_empty(): return
	var id := pending_use_item_id
	pending_use_item_id = ""
	use_item_button.visible = false
	_interact(id, true)

func _interact(id: String, applying_item: bool = false) -> void:
	if not testing or won or restart_pending or SharedData.mode != "adventure": return
	var obj := _find_object(id)
	if obj.is_empty(): return
	_play_item_sound(obj)
	play_highlight_id = id
	_refresh_object_highlights()
	var action := str(obj.get("action", "inspect"))
	pending_use_item_id = ""
	if use_item_button != null: use_item_button.visible = false
	if action == "use_item" and not applying_item:
		var description := str(obj.get("message", "")).strip_edges()
		if description.is_empty(): description = "You inspect the " + str(obj.get("label", "object")) + "."
		var required_item := str(obj.get("required", "")).strip_edges()
		if not required_item.is_empty() and state.get("items", []).has(required_item):
			pending_use_item_id = id
			use_item_button.text = "Use " + required_item
			use_item_button.visible = true
		play_dialogue.text = description
		return
	var hp_change := 0 if action == "use_item" else int(obj.get("hp_change", -int(obj.get("damage", 0))))
	var damage := maxi(0, -hp_change)
	var healed := 0
	if hp_change > 0:
		var previous_hp := current_hp
		current_hp = mini(_starting_hp(), current_hp + hp_change)
		healed = current_hp - previous_hp
		_update_hp_label()
	var damage_explanation := str(obj.get("damage_message", "")).strip_edges()
	if damage > 0 and damage_explanation.is_empty():
		damage_explanation = "The " + str(obj.get("label", "object")) + " hurt you!"
	if damage > 0:
		_sound("Damage")
		current_hp = maxi(0, current_hp - damage)
		_update_hp_label()
		if current_hp == 0:
			pending_password_id = ""
			restart_pending = true
			_sound("Defeat")
			status.text = damage_explanation + "  (-" + str(damage) + " HP)\nHP: 0. GAME OVER! Restarting..."
			play_dialogue.text = status.text
			_update_inventory()
			get_tree().create_timer(2.0).timeout.connect(_restart_after_death)
			return
	pending_password_id = ""
	var message := str(obj.get("message", ""))
	match action:
		"use_item":
			var required_name: String = str(obj.get("required", "")).strip_edges()
			var inventory: Array = state.get("items", [])
			if required_name.is_empty():
				status.text = "Set Required item to the name of an inventory item."
			elif not inventory.has(required_name):
				status.text = message if not message.is_empty() else "You inspect the " + str(obj.get("label", "object")) + "."
			else:
				var effect: int = int(obj.get("use_effect", 0))
				var target_id: String = str(obj.get("target", "")).strip_edges()
				var target_obj: Dictionary = _find_object(target_id)
				if effect != 0 and target_obj.is_empty():
					status.text = "Choose a target object for this effect."
				else:
					match effect:
						1:
							var amount: int = absi(int(obj.get("hp_change", 0)))
							if amount == 0: amount = 1
							var target_hp: int = int(state.get("target_hp_" + target_id, target_obj.get("target_hp", 1)))
							target_hp = maxi(0, target_hp - amount)
							state["target_hp_" + target_id] = target_hp
							if target_hp == 0: state["collected_" + target_id] = true
						2:
							state["revealed_" + target_id] = true
						3:
							state["collected_" + target_id] = true
					if bool(obj.get("consume_item", false)):
						inventory.erase(required_name)
						state["items"] = inventory
						shared_inventory = inventory
					var post_use_message: String = str(obj.get("post_use_message", "")).strip_edges()
					status.text = post_use_message if not post_use_message.is_empty() else "Used " + required_name + "."
		"password":
			pending_password_id = id
			password_input.clear()
			status.text = "Enter the password for " + str(obj.get("label", "object")) + "."
		"inspect":
			_sound("Dialogue")
			status.text = message if not message.is_empty() else "You inspect the " + str(obj["label"]) + "."
		"swap":
			state["swapped_" + id] = not bool(state.get("swapped_" + id, false))
			status.text = message if not message.is_empty() else "The object changes."
		"reveal":
			var target := str(obj.get("target", ""))
			if _find_object(target).is_empty():
				status.text = "Select a target object in the editor."
				return
			state["revealed_" + target] = true
			status.text = message if not message.is_empty() else "Something has appeared."
		"collect":
			_sound("Item Collected")
			var item_name := str(obj.get("item", str(obj["label"])))
			if item_name.is_empty(): item_name = str(obj["label"])
			var inventory: Array = state.get("items", [])
			if not inventory.has(item_name): inventory.append(item_name)
			state["items"] = inventory
			shared_inventory = inventory
			state["collected_" + id] = true
			status.text = message if not message.is_empty() else "Collected: " + item_name
		"go_to_room":
			if _door_is_blocked(obj):
				status.text = str(obj.get("blocked_message", "")) if not str(obj.get("blocked_message", "")).strip_edges().is_empty() else "The way is blocked."
				play_dialogue.text = status.text
				return
			var destination := str(obj.get("destination_room", ""))
			if SharedData.room_names().has(destination):
				_sound("Door Opened")
				_change_room(destination)
				play_dialogue.text = message if not message.is_empty() else "You entered " + destination + "."
				return
			_sound("Door Locked")
			status.text = "Choose a valid Destination Room in Edit Mode."
		"win_game":
			_sound("Victory")
			won = true
			status.text = message if not message.is_empty() else "You escaped!"
			status.text += "  YOU WIN!"
		"unlock":
			if _door_is_blocked(obj):
				status.text = str(obj.get("blocked_message", "")) if not str(obj.get("blocked_message", "")).strip_edges().is_empty() else "The way is blocked."
				play_dialogue.text = status.text
				return
			var required := str(obj.get("required", ""))
			var inventory: Array = state.get("items", [])
			if not required.is_empty() and not inventory.has(required):
				_sound("Door Locked")
				status.text = "Locked. You need: " + required
			else:
				_sound("Door Opened")
				# Consume the required item only when the unlock succeeds.
				if not required.is_empty():
					inventory.erase(required)
					state["items"] = inventory
				shared_inventory = inventory
				var destination := str(obj.get("destination_room", ""))
				if SharedData.room_names().has(destination):
					_change_room(destination)
					play_dialogue.text = message if not message.is_empty() else "Door unlocked. Entered " + destination + "."
					return
				_sound("Victory")
				won = true
				status.text = message if not message.is_empty() else "Unlocked!"
				status.text += "  YOU WIN!"
	if damage > 0:
		status.text = damage_explanation + "  (-" + str(damage) + " HP)\n" + status.text
	elif hp_change > 0:
		status.text = ("Healed +" + str(healed) + " HP" if healed > 0 else "HP already full") + " (" + str(current_hp) + "/" + str(_starting_hp()) + ")\n" + status.text
	var result_message := status.text
	_rebuild()
	status.text = result_message
	play_dialogue.text = result_message
	_update_inventory()

func _restart_after_death() -> void:
	if restart_pending and testing and SharedData.mode == "adventure":
		_start_test()

func _submit_password() -> void:
	if not testing or SharedData.mode != "adventure" or pending_password_id.is_empty(): return
	var obj := _find_object(pending_password_id)
	if obj.is_empty(): return
	if password_input.text.strip_edges().is_empty():
		status.text = "Please enter a password."
		play_dialogue.text = status.text
		password_input.grab_focus()
		return
	if password_input.text != str(obj.get("password", "")):
		status.text = str(obj.get("wrong_message", "Incorrect password. Try again."))
		if status.text.is_empty(): status.text = "Incorrect password. Try again."
		play_dialogue.text = status.text
		password_input.select_all()
		password_input.grab_focus()
		return
	var target := str(obj.get("target", ""))
	if not target.is_empty():
		if _find_object(target).is_empty():
			play_dialogue.text = "Select a target object in the editor."
			return
		state["revealed_" + target] = true
	# A correct password does not automatically end the game.
	pending_password_id = ""
	var message := str(obj.get("message", ""))
	_rebuild()
	status.text = message if not message.is_empty() else "Correct password!"
	if won: status.text += "  YOU WIN!"
	play_dialogue.text = status.text
	_update_inventory()

func _process(delta: float) -> void:
	if not testing or won: return
	if SharedData.mode == "racing":
		if Input.is_key_pressed(KEY_LEFT): car_x -= delta * 0.6
		if Input.is_key_pressed(KEY_RIGHT): car_x += delta * 0.6
		car_x = clampf(car_x,0.28,0.72)
		race_distance += delta * 0.22
		laps = int(race_distance)
		if laps >= 3:
			won = true
			status.text = "FINISH! Three laps completed."
		elif absf(car_x - 0.53) < 0.055 and fmod(race_distance,1.0) > 0.42 and fmod(race_distance,1.0) < 0.46:
			race_distance = maxf(0.0,race_distance - 0.12)
			status.text = "Obstacle hit! Time penalty."
		else:
			status.text = "Lap " + str(laps + 1) + " / 3 — use left/right arrows."
	elif SharedData.mode == "boss":
		var move := Vector2.ZERO
		if Input.is_key_pressed(KEY_LEFT): move.x -= 1
		if Input.is_key_pressed(KEY_RIGHT): move.x += 1
		if Input.is_key_pressed(KEY_UP): move.y -= 1
		if Input.is_key_pressed(KEY_DOWN): move.y += 1
		player_pos += move.normalized() * delta * 260.0
		player_pos = player_pos.clamp(Vector2(20,20),Vector2(940,520))
		game_time += delta
		if Input.is_key_pressed(KEY_SPACE) and fmod(game_time,0.17) < delta:
			_sound("Player Shooting")
			shots.append(player_pos)
		if fmod(game_time,0.8) < delta:
			_sound("Boss Shooting")
			enemy_shots.append(Vector2(480 + sin(game_time) * 200.0,100))
		for i in range(shots.size()-1,-1,-1):
			shots[i].y -= 420.0 * delta
			if shots[i].y < 0:
				shots.remove_at(i)
			elif shots[i].distance_to(Vector2(480 + sin(game_time)*200.0,100)) < 70:
				shots.remove_at(i)
				boss_health -= 1
		for i in range(enemy_shots.size()-1,-1,-1):
			enemy_shots[i].y += 220.0 * delta
			if enemy_shots[i].y > 540:
				enemy_shots.remove_at(i)
			elif enemy_shots[i].distance_to(player_pos) < 24:
				enemy_shots.remove_at(i)
				_sound("Damage")
				lives -= 1
		if boss_health <= 0:
			_sound("Victory")
			won = true
			status.text = "Boss defeated! YOU WIN!"
		elif lives <= 0:
			_sound("Defeat")
			won = true
			status.text = "Game over. Click Play / Test to retry."
		else:
			status.text = "Boss HP: " + str(boss_health) + "  |  Lives: " + str(lives)
	# Adventure dialogue changes on interaction, not every rendered frame.
	# Updating it each frame overwrites password feedback immediately.
	if SharedData.mode != "adventure":
		play_dialogue.text = status.text
	game_canvas.queue_redraw()

func _draw_game() -> void:
	if not testing: return
	game_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(scene_area.size.x / 960.0, scene_area.size.y / 540.0))
	if SharedData.mode == "racing":
		game_canvas.draw_rect(Rect2(Vector2(car_x*960.0-23,420),Vector2(46,75)),Color("#f7c65b"))
		game_canvas.draw_rect(Rect2(Vector2(0,0),Vector2(150,35)),Color("#222222aa"))
		game_canvas.draw_string(ThemeDB.fallback_font,Vector2(12,24),"Lap " + str(mini(laps+1,3)) + " / 3",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
	elif SharedData.mode == "boss":
		game_canvas.draw_circle(player_pos,20,Color("#68e3ff"))
		game_canvas.draw_circle(Vector2(480+sin(game_time)*200.0,100),45,Color("#e85b89"))
		for bullet in shots: game_canvas.draw_circle(bullet,6,Color.YELLOW)
		for bullet in enemy_shots: game_canvas.draw_circle(bullet,9,Color.ORANGE_RED)
