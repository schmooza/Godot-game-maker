extends Node
const PATH := "user://shared_scenes.json"
const MODES := ["adventure", "racing", "boss"]
var mode := "adventure"
var scenes: Dictionary = {}
var active_room := "Room 1"

func _ready() -> void:
	reset_defaults()
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for key in MODES:
				if parsed.has(key) and parsed[key] is Dictionary:
					scenes[key] = parsed[key]
	ensure_rooms()

func reset_defaults() -> void:
	scenes = {
		"adventure": {"objects": [
			{"id":"desk","label":"Desk","x":0.19,"y":0.61,"w":120,"h":100,"action":"inspect","message":"The desk has a small drawer."},
			{"id":"drawer","label":"Drawer","x":0.36,"y":0.72,"w":75,"h":60,"action":"reveal","target":"key","message":"The drawer opens. A key is inside."},
			{"id":"painting","label":"Painting","x":0.49,"y":0.24,"w":105,"h":105,"action":"swap","message":"Behind the painting: Check the desk drawer."},
			{"id":"door","label":"Door","x":0.80,"y":0.44,"w":115,"h":210,"action":"unlock","required":"Brass key","message":"The door opens. You escaped!"},
			{"id":"key","label":"Brass key","x":0.37,"y":0.70,"w":40,"h":35,"action":"collect","item":"Brass key","hidden":true,"message":"You picked up the brass key."}]},
		"racing": {"objects": [
			{"id":"car","label":"Player car","x":0.49,"y":0.79,"w":55,"h":90},
			{"id":"obstacle","label":"Obstacle","x":0.53,"y":0.30,"w":55,"h":65}]},
		"boss": {"objects": [
			{"id":"player","label":"Player","x":0.50,"y":0.84,"w":65,"h":65},
			{"id":"enemy","label":"Boss","x":0.50,"y":0.19,"w":115,"h":100}]}
	}

func ensure_rooms() -> void:
	var adventure: Dictionary = scenes["adventure"]
	if not adventure.has("rooms"):
		var original: Dictionary = adventure.duplicate(true)
		adventure["rooms"] = {"Room 1": original}
		adventure.erase("objects")
		adventure.erase("appearance")
		adventure.erase("starting_hp")
	if not adventure["rooms"].has(active_room):
		active_room = "Room 1"

func room_names() -> Array:
	ensure_rooms()
	return scenes["adventure"]["rooms"].keys()

func current_scene() -> Dictionary:
	if mode == "adventure":
		ensure_rooms()
		return scenes["adventure"]["rooms"][active_room]
	return scenes[mode]

func add_room(name: String) -> bool:
	ensure_rooms()
	name = name.strip_edges()
	if name.is_empty() or scenes["adventure"]["rooms"].has(name):
		return false
	scenes["adventure"]["rooms"][name] = {"objects": [], "appearance": {}}
	active_room = name
	return true

func room_slot(slot: String) -> String:
	if mode != "adventure" or active_room == "Room 1":
		return slot
	return "room_" + active_room.sha256_text().substr(0, 12) + "_" + slot

func save() -> bool:
	var f := FileAccess.open(PATH,FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(scenes, "\t"))
	f.close()
	return true

func image_path(slot: String) -> String:
	return "user://shared_" + mode + "_" + room_slot(slot) + ".png"

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

func reset_mode() -> void:
	var current := mode
	var saved := scenes.duplicate(true)
	reset_defaults()
	var default_scene: Dictionary = scenes[current].duplicate(true)
	scenes = saved
	scenes[current] = default_scene
	if current == "adventure":
		active_room = "Room 1"
		ensure_rooms()
