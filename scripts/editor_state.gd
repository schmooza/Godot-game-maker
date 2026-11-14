extends Node
## Shared student code and project state. The original adventure remains unchanged.

const SAVE_PATH := "user://student_adventure.gd"
const TEMPLATE_PATH := "res://templates/room_rules.gd"
var source_text: String = ""
var active_rules: Object


func _ready() -> void:
	load_student_code()


func load_student_code() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			source_text = file.get_as_text()
			return
	source_text = FileAccess.get_file_as_string(TEMPLATE_PATH)


func save_student_code(code: String) -> bool:
	# Write to a temporary file first, preserving the last good copy on write failure.
	var temp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(code)
	file.flush()
	file.close()
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_save := ProjectSettings.globalize_path(SAVE_PATH)
	# Rename on the same volume replaces the previous saved code.
	if DirAccess.rename_absolute(absolute_temp, absolute_save) != OK:
		return false
	source_text = code
	return true

func reset_to_template() -> void:
	source_text = FileAccess.get_file_as_string(TEMPLATE_PATH)


func compile_rules(code: String) -> String:
	var script := GDScript.new()
	script.source_code = code
	var result := script.reload()
	if result != OK:
		return "GDScript has an error. Check the Output/Debugger panel in Godot."
	if not script.can_instantiate():
		return "The script could not be instantiated."
	var instance: Variant = script.new()
	for method_name in ["get_room_title", "get_objects", "interact"]:
		if not instance.has_method(method_name):
			return "Missing required function: " + method_name
	var items: Variant = instance.call("get_objects")
	if not (items is Array):
		return "get_objects() must return an Array."
	for item in items:
		if not (item is Dictionary) or not item.has("id") or not item.has("label"):
			return "Each object must have id and label fields."
	active_rules = instance
	return ""
