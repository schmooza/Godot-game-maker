extends Node
const PATH := "user://shared_scenes.json"
const MODES := ["adventure", "racing", "boss"]
var mode := "adventure"
var scenes: Dictionary = {}

func _ready() -> void:
	reset_defaults()
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for key in MODES:
				if parsed.has(key) and parsed[key] is Dictionary:
					scenes[key] = parsed[key]

func reset_defaults() -> void:
	scenes = {
		"adventure": {"objects": [
			{"id":"desk","label":"Desk","x":0.19,"y":0.61,"w":120,"h":100},
			{"id":"drawer","label":"Drawer","x":0.36,"y":0.72,"w":75,"h":60},
			{"id":"painting","label":"Painting","x":0.49,"y":0.24,"w":105,"h":105},
			{"id":"door","label":"Door","x":0.80,"y":0.44,"w":115,"h":210}]},
		"racing": {"objects": [
			{"id":"car","label":"Player car","x":0.49,"y":0.79,"w":55,"h":90},
			{"id":"obstacle","label":"Obstacle","x":0.53,"y":0.30,"w":55,"h":65}]},
		"boss": {"objects": [
			{"id":"player","label":"Player","x":0.50,"y":0.84,"w":65,"h":65},
			{"id":"enemy","label":"Boss","x":0.50,"y":0.19,"w":115,"h":100}]}
	}

func save() -> bool:
	var f := FileAccess.open(PATH,FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(scenes, "\t"))
	f.close()
	return true

func image_path(slot: String) -> String:
	return "user://shared_" + mode + "_" + slot + ".png"

func texture(slot: String) -> Texture2D:
	var image := Image.new()
	if FileAccess.file_exists(image_path(slot)) and image.load(image_path(slot)) == OK:
		return ImageTexture.create_from_image(image)
	if slot == "background":
		return load("res://assets/shared/" + mode + "_background.png") as Texture2D
	if ResourceLoader.exists("res://assets/shared/" + slot + ".png"):
		return load("res://assets/shared/" + slot + ".png") as Texture2D
	if ResourceLoader.exists("res://assets/placeholders/" + slot + ".png"):
		return load("res://assets/placeholders/" + slot + ".png") as Texture2D
	return null

func import_image(slot: String, path: String) -> bool:
	var image := Image.new()
	if image.load(path) != OK: return false
	return image.save_png(image_path(slot)) == OK
