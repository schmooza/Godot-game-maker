extends Control
## Post-it grid home screen. Game editors remain independent.
const MODES := [
	{"id":"adventure","name":"Adventure","colour":"#f7dc78"},
	{"id":"racing","name":"2D Car Racing","colour":"#a9d8f2"},
	{"id":"boss","name":"Boss Fight","colour":"#f1b0bc"}
]
var transfer: Node

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#e7dfcf")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var layout := VBoxContainer.new()
	layout.custom_minimum_size = Vector2(760,580)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation",26)
	scroll.add_child(layout)
	var heading := Label.new()
	heading.text = "THE POST-IT NOTE GAME ENGINE"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",32)
	heading.add_theme_color_override("font_color",Color("#35332f"))
	layout.add_child(heading)
	var intro := Label.new()
	intro.text = "Choose a game to create"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.add_theme_color_override("font_color",Color("#504b45"))
	layout.add_child(intro)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",24)
	grid.add_theme_constant_override("v_separation",24)
	center.add_child(grid)
	for entry in MODES:
		var note := Button.new()
		note.text = str(entry["name"])
		note.custom_minimum_size = Vector2(205,205)
		note.add_theme_font_size_override("font_size",22)
		note.add_theme_color_override("font_color",Color("#2f3033"))
		note.add_theme_color_override("font_hover_color",Color("#171717"))
		note.add_theme_color_override("font_pressed_color",Color("#171717"))
		for state in ["normal","hover","pressed","focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(str(entry["colour"])).lightened(0.08 if state=="hover" else 0.0)
			style.shadow_color = Color(0,0,0,0.17)
			style.shadow_size = 5
			style.content_margin_left = 12
			style.content_margin_right = 12
			style.content_margin_top = 12
			style.content_margin_bottom = 12
			note.add_theme_stylebox_override(state,style)
		note.pressed.connect(_open.bind(str(entry["id"])))
		grid.add_child(note)
	var capstone_button := Button.new()
	capstone_button.text = "CAPSTONE - Game Flow Editor"
	capstone_button.custom_minimum_size = Vector2(340, 55)
	layout.add_child(capstone_button)
	capstone_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/capstone_flow.tscn"))
	var transfer_row := HBoxContainer.new()
	transfer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	transfer_row.add_theme_constant_override("separation",16)
	layout.add_child(transfer_row)
	var export_button := Button.new()
	export_button.text = "Export Project"
	export_button.custom_minimum_size = Vector2(165,45)
	transfer_row.add_child(export_button)
	var import_button := Button.new()
	import_button.text = "Import Project"
	import_button.custom_minimum_size = Vector2(165,45)
	transfer_row.add_child(import_button)
	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status)
	transfer = load("res://scripts/project_transfer.gd").new()
	add_child(transfer)
	transfer.setup(self,status)
	export_button.pressed.connect(transfer.choose_export)
	import_button.pressed.connect(transfer.choose_import)

func _open(mode: String) -> void:
	SharedData.mode = mode
	get_tree().change_scene_to_file("res://scenes/racing_editor.tscn" if mode == "racing" else ("res://scenes/boss_editor.tscn" if mode == "boss" else "res://scenes/shared_editor.tscn"))
