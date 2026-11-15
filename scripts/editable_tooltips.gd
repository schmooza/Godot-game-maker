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
			if default_tip.is_empty():
				default_tip = "Click to use " + label_text + "." if control is BaseButton else "Adjust " + label_text + " for this game."
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
