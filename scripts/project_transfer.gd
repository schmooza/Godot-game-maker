extends Node
## Standalone import/export of user:// project data, including audio and images.
## ZIP archive includes a manifest to prevent accidental import of unrelated ZIPs.
var status: Label
var export_dialog: FileDialog
var import_dialog: FileDialog
var confirmation: ConfirmationDialog
var pending_import := ""
var import_mode: OptionButton
var import_scope := "all"
var selected_files: Array[String] = []
const MANIFEST := "postit_project_manifest.json"

func setup(host: Control, output: Label) -> void:
	status = output
	export_dialog = FileDialog.new()
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.add_filter("*.zip","Post-it project ZIP")
	export_dialog.file_selected.connect(_export)
	host.add_child(export_dialog)
	import_dialog = FileDialog.new()
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.add_filter("*.zip","Post-it project ZIP")
	import_dialog.file_selected.connect(_confirm_import)
	host.add_child(import_dialog)
	import_mode = OptionButton.new()
	import_mode.add_item("All games (full restore)")
	import_mode.add_item("Adventure only")
	import_mode.add_item("Racing only")
	import_mode.add_item("Bullet Hell only")
	import_mode.item_selected.connect(func(i: int): import_scope = ["all","adventure","racing","boss"][i])
	# Scope picker is part of the import confirmation, not a persistent game setting.
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Replace saved project data?"
	confirmation.dialog_text = "Import can replace existing saved data. Choose what to restore below. A backup of replaced files will be created automatically."
	# ConfirmationDialog is a Window; it has no get_vbox() method.
	# Place the selection control directly in its content area.
	confirmation.min_size = Vector2i(550, 240)
	confirmation.add_child(import_mode)
	import_mode.position = Vector2(20, 125)
	import_mode.custom_minimum_size = Vector2(500, 36)
	import_mode.size = Vector2(500, 36)
	confirmation.confirmed.connect(_import)
	host.add_child(confirmation)

func choose_export() -> void:
	# Save in-memory Adventure edits before archiving.
	SharedData.save()
	export_dialog.popup_centered_ratio(0.7)

func choose_import() -> void:
	import_dialog.popup_centered_ratio(0.7)

func _export(path: String) -> void:
	if not path.to_lower().ends_with(".zip"):
		path += ".zip"
	var zipper := ZIPPacker.new()
	if zipper.open(path) != OK:
		status.text = "Export failed: cannot create ZIP."
		return
	var manifest := JSON.stringify({"app":"postit-game-engine","format":1})
	zipper.start_file(MANIFEST)
	zipper.write_file(manifest.to_utf8_buffer())
	zipper.close_file()
	var root := ProjectSettings.globalize_path("user://")
	var paths: Array[String] = []
	_collect(root,"",paths)
	for relative in paths:
		var absolute := root.path_join(relative)
		var content := FileAccess.get_file_as_bytes(absolute)
		if zipper.start_file("data/"+relative) == OK:
			zipper.write_file(content)
			zipper.close_file()
	zipper.close()
	status.text = "Exported " + str(paths.size()) + " saved files to " + path.get_file()

func _collect(root: String, relative: String, results: Array[String]) -> void:
	var folder := root.path_join(relative)
	var directory := DirAccess.open(folder)
	if directory == null:
		return
	directory.list_dir_begin()
	while true:
		var name := directory.get_next()
		if name.is_empty():
			break
		if name.begins_with(".") or name == "postit_import_backup.zip":
			continue
		var child := relative.path_join(name)
		if directory.current_is_dir():
			_collect(root,child,results)
		else:
			results.append(child)
	directory.list_dir_end()

func _confirm_import(path: String) -> void:
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		status.text = "Import failed: invalid ZIP."
		return
	var valid := reader.file_exists(MANIFEST)
	if valid:
		var parsed: Variant = JSON.parse_string(reader.read_file(MANIFEST).get_string_from_utf8())
		valid = parsed is Dictionary and parsed.get("app","") == "postit-game-engine"
	reader.close()
	if not valid:
		status.text = "Import refused: this is not a Post-it project export."
		return
	pending_import = path
	confirmation.popup_centered()

func _belongs_to_scope(relative: String) -> bool:
	if import_scope == "all":
		return true
	var filename := relative.get_file()
	if import_scope == "adventure":
		return filename.begins_with("adventure_") or filename.begins_with("intro_adventure") or filename.begins_with("intro_sound_adventure") or filename.begins_with("audio_adventure") or filename.begins_with("item_sound_") or filename == "student_adventure.gd" or relative.begins_with("adventure_images/") or filename == "shared_scenes.json" or filename.begins_with("shared_")
	if import_scope == "racing":
		return filename.begins_with("racing_") or relative.begins_with("racing_tracks/") or filename.begins_with("intro_racing") or filename.begins_with("intro_sound_racing") or filename.begins_with("audio_racing")
	if import_scope == "boss":
		return filename.begins_with("boss_") or filename.begins_with("intro_boss") or filename.begins_with("intro_sound_boss") or filename.begins_with("audio_boss")
	return false

func _import() -> void:
	var reader := ZIPReader.new()
	if reader.open(pending_import) != OK:
		status.text = "Import failed: cannot open ZIP."
		return
	var root := ProjectSettings.globalize_path("user://")
	var entries: Array[String] = []
	for entry in reader.get_files():
		if not entry.begins_with("data/") or entry.ends_with("/"):
			continue
		var relative := entry.trim_prefix("data/")
		if relative.is_empty() or relative.begins_with("/") or relative.find("..") != -1 or relative.find("\\") != -1 or relative.find(":") != -1:
			continue
		if _belongs_to_scope(relative):
			entries.append(entry)
	if entries.is_empty():
		reader.close()
		status.text = "No saved files found for this game in the ZIP. Nothing changed."
		return
	# Preserve every existing file that would be replaced BEFORE modifying anything.
	var backup_path := root.path_join("postit_import_backup.zip")
	var backup := ZIPPacker.new()
	if backup.open(backup_path) != OK:
		reader.close()
		status.text = "Import cancelled: unable to create safety backup."
		return
	var backed_up := 0
	for entry in entries:
		var relative := entry.trim_prefix("data/")
		var target := root.path_join(relative)
		if FileAccess.file_exists(target):
			if backup.start_file("data/" + relative) == OK:
				backup.write_file(FileAccess.get_file_as_bytes(target))
				backup.close_file()
				backed_up += 1
	backup.close()
	var count := 0
	for entry in entries:
		var relative := entry.trim_prefix("data/")
		var target := root.path_join(relative)
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var file := FileAccess.open(target,FileAccess.WRITE)
		if file != null:
			file.store_buffer(reader.read_file(entry))
			file.close()
			count += 1
	reader.close()
	status.text = "Imported " + str(count) + " files (" + import_scope + "). Backed up " + str(backed_up) + " existing files. Restart F5 to reload."
