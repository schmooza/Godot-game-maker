extends Control
func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("#d5b58b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	var title := Label.new()
	title.text = "The Post-it Note Game Engine"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Choose a game. The same scene editor works for all three."
	box.add_child(subtitle)
	for mode in SharedData.MODES:
		var button := Button.new()
		button.text = {"adventure":"Point-and-click Adventure","racing":"2D Car Racing","boss":"Bullet Hell Boss"}[mode] + " — Open Shared Editor"
		button.custom_minimum_size.y = 65
		button.pressed.connect(_open.bind(mode))
		box.add_child(button)
	var legacy := Button.new()
	legacy.text = "Advanced adventure GDScript / Post-it note editor"
	legacy.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/adventure_editor.tscn"))
	box.add_child(legacy)

func _open(mode: String) -> void:
	SharedData.mode = mode
	get_tree().change_scene_to_file("res://scenes/shared_editor.tscn")
