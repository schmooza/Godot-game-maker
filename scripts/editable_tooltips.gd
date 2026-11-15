extends Node
## Reusable student-editable tooltip manager for Adventure and Racing.
## Right-click a menu control while editing to avoid triggering its normal action.
var edit_mode := false
var scope_name: String = ""
var custom: Dictionary = {}
var defaults: Dictionary = {}
var targets: Dictionary = {}
var editor_root: Control
var toolbar: HBoxContainer
var toggle: CheckButton
var dialog: ConfirmationDialog
var edit_field: TextEdit
var selected_key := ""
var known: Dictionary = {}
var overlays: Dictionary = {}

func setup(owner_root: Control, toolbar_row: HBoxContainer, scope: String) -> void:
	editor_root = owner_root
	toolbar = toolbar_row
	scope_name = scope
	_load()
	toggle = CheckButton.new()
	toggle.text = "Edit Tooltips"
	toggle.tooltip_text = "Enable or disable tooltip editing. When enabled, right-click a menu item to change its tooltip."
	toggle.focus_mode = Control.FOCUS_NONE
	toolbar.add_child(toggle)
	toggle.toggled.connect(_toggle)
	dialog = ConfirmationDialog.new()
	dialog.title = "Edit Menu Tooltip"
	dialog.min_size = Vector2i(460,250)
	var body := VBoxContainer.new()
	dialog.add_child(body)
	var hint := Label.new()
	hint.text = "Write a helpful explanation for other students:"
	body.add_child(hint)
	edit_field = TextEdit.new()
	edit_field.custom_minimum_size.y = 115
	body.add_child(edit_field)
	var reset := Button.new()
	reset.text = "Reset to default"
	reset.pressed.connect(_reset_current)
	body.add_child(reset)
	dialog.confirmed.connect(_save_current)
	owner_root.add_child(dialog)
	refresh()

func refresh() -> void:
	# Re-scan after the Adventure editor rebuilds its controls.
	var counts: Dictionary = {}
	_register_tree(toolbar, "toolbar", counts)
	if scope_name == "racing":
		var panel: Node = editor_root.find_child("TooltipScanSidebar",true,false)
		if panel != null:
			_register_tree(panel, "sidebar", counts)
	else:
		var panel: Node = editor_root.find_child("TooltipScanSidebar",true,false)
		if panel != null:
			_register_tree(panel, "sidebar", counts)

func _explain_control(label_text: String, control: Control) -> String:
	var name: String = label_text.strip_edges().to_lower()
	var descriptions: Dictionary = {
		"save": "Save your current changes so they remain when you leave this editor.",
		"play / test": "Run the current game to test objects, interactions and win conditions. Save your changes first.",
		"edit scene": "Open the visual room editor to position objects and change their interactions.",
		"edit adventure code": "Open the editable Adventure rules/code. Changes may affect how the game plays.",
		"add room": "Create another Adventure room. Give it a unique name so doors can lead to it.",
		"add object": "Place a new object in this room. Select it to set its name, image and click action.",
		"add object ": "Place a new object in this room. Select it to set its name, image and click action.",
		"remove selected": "Delete the currently selected object from this room.",
		"import selected image": "Choose an image for the selected object. The image appears in the room.",
		"object name": "Name shown on the object in the room and to the player.",
		"on click (adventure)": "Choose what happens when the player clicks this object: inspect, collect, unlock, change rooms and more.",
		"target object id": "ID of another object that this action affects, such as an object to reveal or change.",
		"message": "Text shown to the player when they interact with this object.",
		"inventory item": "Item added to, or required from, the player's inventory by this interaction.",
		"destination room (go to room / unlock)": "Room to enter when this door or unlock action succeeds.",
		"password (adventure password action)": "Password the player must enter to activate this object.",
		"hp change on click (+ heals, - damages, 0 = none)": "Positive numbers heal the player; negative numbers cause damage; zero leaves health unchanged.",
		"damage explanation (shown to player)": "Message explaining why the player lost health.",
		"starting hp": "Health points the player has at the beginning of the Adventure.",
		"incorrect password message": "Text displayed after a player enters the wrong password.",
		"hidden until revealed": "Hide this object during play until another interaction reveals it.",
		"new room name (e.g. room 2)": "Enter a unique name for the room you are about to create.",
		"edit tooltips": "Turn on tooltip editing, then click a control to customise its explanation.",
		"done editing tooltips": "Finish editing explanations and return to normal controls.",
		"rename": "Apply the name you entered to the selected game, room or stage.",
		"save name": "Save the overall game name so it can be identified in Capstone Mode.",
		"home": "Return to the main game selection menu.",
		"← games": "Return to the game selection menu.",
		"back": "Return to the previous screen. Save first if you want to keep changes.",
		"change type": "Change which of the three game types this Capstone stage uses.",
		"save flow": "Save stage names, links, positions and the starting stage.",
		"play flow": "Start playing the connected Capstone stages from the selected starting stage.",
		"test flow": "Preview the connections between Capstone stages.",
		"set start": "Make the selected stage the first stage of the Capstone game.",
		"open game editor": "Open the original editor for this stage's game type.",
		"link selected game": "Attach the chosen saved game to this Capstone stage.",
		"refresh saved games": "Reload the list of games saved in the three editors.",
		"delete selected": "Remove the selected stage or item. This cannot be undone.",
		"save track": "Save the track layout, hazards, checkpoints and settings.",
		"rename track": "Save a new name for the selected racing track.",
		"new blank track": "Create an empty track for drawing roads and placing checkpoints.",
		"delete selected track": "Permanently remove the selected saved racing track after confirmation.",
	}
	if descriptions.has(name):
		return str(descriptions[name])
	if name.contains("checkpoint"):
		return "Place or adjust a checkpoint the car must pass to complete a lap."
	if name.contains("water"):
		return "Edit water hazards. The car must jump to cross them safely."
	if name.contains("spike"):
		return "Edit spike hazards and their up/down timing."
	if name.contains("jump"):
		return "Change how the car jumps, including its key or time in the air."
	if name.contains("wave"):
		return "Edit or select a boss attack wave. A boss fight can have one or more waves."
	if name.contains("boss"):
		return "Configure the boss fight, including its attacks and settings."
	if control is LineEdit:
		return "Type a value for " + label_text + ". Save to keep the change."
	if control is OptionButton:
		return "Choose an option for " + label_text + "."
	if control is SpinBox:
		return "Adjust this numeric setting."
	if control is BaseButton:
		return "Use " + label_text + " to change the current game or editor."
	return "Configure " + label_text + " for this game."

func _register_tree(node: Node, area: String, counts: Dictionary) -> void:
	for child in node.get_children():
		if child == toggle or child == dialog:
			continue
		if not (child is Control):
			continue
		var control: Control = child
		# Skip the invisible click-catching overlays when scanning again.
		if control.has_meta("tooltip_edit_overlay"):
			continue
		var label_text: String = ""
		if control is BaseButton:
			label_text = (control as BaseButton).text
		elif control is Label:
			label_text = (control as Label).text
		elif control is LineEdit:
			label_text = (control as LineEdit).placeholder_text
		elif control is SpinBox:
			label_text = "Numeric setting"
		elif control is OptionButton:
			label_text = "Selection"
		elif control is TextEdit:
			label_text = "Text setting"
		if not label_text.is_empty():
			var base: String = area + "/" + label_text
			var ordinal: int = int(counts.get(base,0))
			counts[base] = ordinal + 1
			var key: String = base + "/" + str(ordinal)
			targets[control] = key
			var default_tip: String = control.tooltip_text
			if default_tip.is_empty() or default_tip.begins_with("Click to use ") or default_tip.begins_with("Adjust "):
				default_tip = _explain_control(label_text, control)
			if not defaults.has(key):
				defaults[key] = default_tip
			control.tooltip_text = str(custom.get(key, defaults[key]))
			if not overlays.has(control):
				var overlay := Control.new()
				overlay.name = "TooltipEditClickArea"
				overlay.set_meta("tooltip_edit_overlay",true)
				overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				overlay.mouse_filter = Control.MOUSE_FILTER_STOP
				overlay.visible = edit_mode
				control.add_child(overlay)
				overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				overlay.gui_input.connect(_overlay_input.bind(control))
				overlays[control] = overlay
		# Recurse before overlays are appended; skip overlay via metadata.
		_register_tree(control,area,counts)

func _overlay_input(event: InputEvent, control: Control) -> void:
	if not edit_mode:
		return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			selected_key = str(targets.get(control,""))
			if selected_key.is_empty():
				return
			edit_field.text = str(custom.get(selected_key,defaults.get(selected_key,"")))
			dialog.popup_centered()
			(control.get_node("TooltipEditClickArea") as Control).accept_event()

func _toggle(enabled: bool) -> void:
	edit_mode = enabled
	toggle.text = "Done Editing Tooltips" if enabled else "Edit Tooltips"
	toggle.tooltip_text = "Click to exit tooltip editing." if enabled else "Enable tooltip editing, then click a menu item."
	if enabled:
		refresh()
	for control in overlays.keys():
		if is_instance_valid(control) and is_instance_valid(overlays[control]):
			(overlays[control] as Control).visible = enabled

func _save_current() -> void:
	if selected_key.is_empty():
		return
	custom[selected_key] = edit_field.text
	_save()
	_apply()

func _reset_current() -> void:
	if selected_key.is_empty():
		return
	custom.erase(selected_key)
	edit_field.text = str(defaults.get(selected_key,""))
	_save()
	_apply()
	dialog.hide()

func _apply() -> void:
	for control in targets:
		if is_instance_valid(control):
			var key: String = str(targets[control])
			(control as Control).tooltip_text = str(custom.get(key,defaults.get(key,"")))

func _path() -> String:
	return "user://" + scope_name + "_tooltips.json"

func _load() -> void:
	if FileAccess.file_exists(_path()):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path()))
		if parsed is Dictionary:
			custom = parsed

func _save() -> void:
	var file := FileAccess.open(_path(),FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(custom))
		file.close()
