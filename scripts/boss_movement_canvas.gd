extends Control
# Interactive scaled arena showing the boss's start A and destination B.
var editor: Control
const ARENA := Vector2(850,560)
const VIEW := Vector2(300,198)
var dragging := ""
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,VIEW),Color("#172134"))
	for i in range(1,5):
		var x: float = VIEW.x*float(i)/5.0
		draw_line(Vector2(x,0),Vector2(x,VIEW.y),Color("#344357"),1)
	for i in range(1,4):
		var y: float = VIEW.y*float(i)/4.0
		draw_line(Vector2(0,y),Vector2(VIEW.x,y),Color("#344357"),1)
	if editor == null or editor.waves.is_empty():
		return
	var w: Dictionary = editor.waves[editor.selected_wave]
	var a: Vector2 = editor._wave_point(w,"start")*VIEW/ARENA
	var b: Vector2 = editor._wave_point(w,"end")*VIEW/ARENA
	draw_line(a,b,Color("#ffbf69"),3)
	_draw_pin(a,"A",Color("#69d5ff"))
	_draw_pin(b,"B",Color("#ffad69"))
func _draw_pin(p: Vector2, letter: String, color: Color) -> void:
	draw_circle(p,11,color)
	var font: Font = ThemeDB.fallback_font
	draw_string(font,p+Vector2(-5,5),letter,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#10202d"))
func _gui_input(event: InputEvent) -> void:
	if editor == null or editor.waves.is_empty() or editor.playing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var w: Dictionary = editor.waves[editor.selected_wave]
			var a: Vector2 = editor._wave_point(w,"start")*VIEW/ARENA
			var b: Vector2 = editor._wave_point(w,"end")*VIEW/ARENA
			dragging = "start" if event.position.distance_to(a) <= event.position.distance_to(b) else "end"
			_update_position(event.position)
		else:
			dragging = ""
		accept_event()
	elif event is InputEventMouseMotion and not dragging.is_empty():
		_update_position(event.position)
		accept_event()
func _update_position(p: Vector2) -> void:
	if dragging.is_empty():
		return
	editor._set_movement_point(dragging,p.clamp(Vector2.ZERO,VIEW)*ARENA/VIEW)
