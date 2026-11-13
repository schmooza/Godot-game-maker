extends Control
## Phase 1 foundation. This is a placeholder board, not the finished student UI.

const BOARD_NAMES: Array[String] = [
	"Point-and-Click Adventure",
	"2D Racing",
	"Bullet Hell Boss Fight",
]

var board_picker: OptionButton
var board_heading: Label


func _ready() -> void:
	_build_foundation_ui()
	_select_board(0)


func _build_foundation_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("#d5b58b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)

	var title := Label.new()
	title.text = "The Post-it Note Game Engine"
	title.add_theme_font_size_override("font_size", 30)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Phase 1: portable project foundation"
	content.add_child(subtitle)

	board_picker = OptionButton.new()
	for name in BOARD_NAMES:
		board_picker.add_item(name)
	board_picker.item_selected.connect(_select_board)
	content.add_child(board_picker)

	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 24)
	panel_margin.add_theme_constant_override("margin_top", 24)
	panel.add_child(panel_margin)

	var panel_content := VBoxContainer.new()
	panel_margin.add_child(panel_content)

	board_heading = Label.new()
	board_heading.add_theme_font_size_override("font_size", 24)
	panel_content.add_child(board_heading)

	var notice := Label.new()
	notice.text = "The three complete games and editable Post-it notes will be added in later phases."
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel_content.add_child(notice)


func _select_board(index: int) -> void:
	if index < 0 or index >= BOARD_NAMES.size():
		return
	if board_heading:
		board_heading.text = BOARD_NAMES[index]
