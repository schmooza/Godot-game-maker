extends Control
# Clickable 15x11 bullet-formation editor, saved per wave as integer grid coordinates.
var editor: Control
const COLS := 15
const ROWS := 11
const CELL := 19.0
const ORIGIN := Vector2(150, 110)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(300,220)), Color("#162334"))
	for col in range(COLS):
		for row in range(ROWS):
			var centre := ORIGIN + Vector2(float(col-7),float(row-5))*CELL
			draw_rect(Rect2(centre-Vector2(8,8),Vector2(16,16)),Color("#293a50"),false,1.0)
	draw_line(ORIGIN+Vector2(-8,0),ORIGIN+Vector2(8,0),Color("#75d6ff"),2)
	draw_line(ORIGIN+Vector2(0,-8),ORIGIN+Vector2(0,8),Color("#75d6ff"),2)
	if editor == null or editor.waves.is_empty():
		return
	var wave: Dictionary = editor.waves[editor.selected_wave]
	for point in wave.get("points",[]):
		if point is Array and point.size()>=2:
			var centre := ORIGIN + Vector2(float(point[0]),float(point[1]))*CELL
			draw_circle(centre,6,Color("#ffcf60"))

func _gui_input(event: InputEvent) -> void:
	if editor == null or editor.waves.is_empty():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local: Vector2 = event.position
		var x := roundi((local.x-ORIGIN.x)/CELL)
		var y := roundi((local.y-ORIGIN.y)/CELL)
		if abs(x)>7 or abs(y)>5:
			return
		var points: Array = editor.waves[editor.selected_wave].get("points",[]).duplicate(true)
		var cell := [x,y]
		if points.has(cell):
			points.erase(cell)
		elif points.size()<80:
			points.append(cell)
		editor._set_pattern(points)
		accept_event()
