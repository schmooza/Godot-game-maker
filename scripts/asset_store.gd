extends Node
## Student asset slots are saved per Windows user. Imported images are copied locally.
const SLOTS := ["background", "desk", "painting", "drawer", "door", "key"]
const ROOT := "user://adventure_images"

func import_image(slot: String, source: String) -> String:
	if not SLOTS.has(slot):
		return "Unknown image slot."
	var image := Image.new()
	var result := image.load(source)
	if result != OK:
		return "Could not read image. Choose PNG, JPG or WebP."
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT)) != OK:
		return "Could not create the image folder."
	var destination := ROOT + "/" + slot + ".png"
	if image.save_png(destination) != OK:
		return "Could not save image to your user folder."
	return "Saved " + slot + " image."

func get_texture(slot: String) -> Texture2D:
	if not SLOTS.has(slot):
		return null
	var path := ROOT + "/" + slot + ".png"
	if not FileAccess.file_exists(path):
		return load("res://assets/placeholders/" + slot + ".png") as Texture2D
	var image := Image.new()
	if image.load(path) != OK:
		return load("res://assets/placeholders/" + slot + ".png") as Texture2D
	return ImageTexture.create_from_image(image)

func clear_image(slot: String) -> String:
	if not SLOTS.has(slot):
		return "Unknown image slot."
	var path := ROOT + "/" + slot + ".png"
	if FileAccess.file_exists(path):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
			return "Could not remove the image. Check folder permissions."
	return "Reset " + slot + " to its placeholder."
