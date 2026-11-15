extends Control
var optional_audio: Node
var game_intro: Node
const SAVE_PATH := "user://boss_fight_settings_v2.json"
const ARENA := Vector2(850, 560)
const STATES := ["full", "half", "near", "dead"]
const ROLES := ["boss", "player"]
const POWER_TYPES := ["Health", "Shield", "Rapid Fire", "Damage Boost", "Speed Boost"]
var cfg := {"power_health_enabled":true, "power_health_weight":1, "power_health_restore":25, "power_shield_enabled":true, "power_shield_weight":1, "power_shield_duration":8.0, "power_shield_protection":100, "power_rapid_enabled":true, "power_rapid_weight":1, "power_rapid_duration":8.0, "power_rapid_multiplier":2.0, "power_damage_enabled":true, "power_damage_weight":1, "power_damage_duration":8.0, "power_damage_multiplier":2.0, "power_speed_enabled":true, "power_speed_weight":1, "power_speed_duration":8.0, "power_speed_multiplier":1.5, "player_hp":100, "boss_hp":500, "bullet_speed":160.0, "bullet_damage":10, "player_speed":280.0, "shot_damage":15, "shot_interval":0.24, "power_interval":9.0, "power_duration":8.0, "power_enabled":true, "boss_size":80.0, "player_size":44.0, "full_threshold":50.0, "near_threshold":20.0, "win_message":"YOU WON!", "lose_message":"TRY AGAIN!"}
var waves: Array[Dictionary] = []
var active_wave := 0
var wave_elapsed := 0.0
var wave_fire_timer := 0.0
var playing := false
var ended := false
var result_text := ""
var player_pos := Vector2(425,480)
var boss_pos := Vector2(425,90)
var hp := 100
var boss_hp := 500
var bullets: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var powerups: Array[Dictionary] = []
var invulnerable := 0.0
var shield_timer := 0.0
var shield_protection := 100.0
var rapid_timer := 0.0
var damage_timer := 0.0
var speed_timer := 0.0
var shoot_timer := 0.0
var power_timer := 0.0
var elapsed := 0.0
var arena: Control
var status: Label
var hud: Label
var message: Label
var wave_list: ItemList
var power_type: OptionButton
var file_dialog: FileDialog
var import_kind := ""
var sprites: Dictionary = {}
var patterns: Dictionary = {}
var background_texture: Texture2D
var wave_name: LineEdit
var wave_duration: SpinBox
var wave_angle: SpinBox
var wave_x: SpinBox
var wave_y: SpinBox
var wave_speed: SpinBox
var wave_lifetime: SpinBox
var wave_fade: SpinBox
var wave_interval: SpinBox
var wave_move_speed: SpinBox
var movement_canvas: Control
var movement_mode: OptionButton
var movement_drag_point := 0
var movement_returning := false
var selected_wave := 0
var wave_canvas: Control
var tooltip_mode := false
var tooltip_targets: Dictionary = {}
var tooltip_defaults: Dictionary = {}
var tooltip_custom: Dictionary = {}
var tooltip_dialog: ConfirmationDialog
var tooltip_edit: TextEdit
var tooltip_target_id := ""
var preview_mode := false
var wave_vx: SpinBox
var wave_vy: SpinBox
var wave_accel: SpinBox
var wave_spread: SpinBox
var wave_rotation: SpinBox
var wave_max_speed: SpinBox

func _ready() -> void:
	_load()
	_load_tooltips()
	_load_images()
	_build()
	_install_optional_audio()
	_install_game_intro()
	_reset()
	set_process(true)

func _button(parent: Node, title: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = title
	# Space is reserved for shooting; focused buttons must not consume it.
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	_register_tooltip(b,title,"Click to use " + title + ".")
	return b

func _label(parent: Node, title: String) -> void:
	var l := Label.new()
	l.text = title
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	_register_tooltip(l,title,"Information about " + title + ".")

func _section(parent: Node, title: String, colour: Color) -> void:
	# Strong colour-coded header separates each group in the scrolling editor.
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = colour.darkened(0.70)
	style.border_color = colour
	style.border_width_left = 5
	style.content_margin_left = 10.0
	style.content_margin_right = 8.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_color_override("font_color", Color.WHITE)
	heading.add_theme_font_size_override("font_size", 16)
	panel.add_child(heading)
	parent.add_child(panel)

func _spin(parent: Node, title: String, initial: float, low: float, high: float, step: float, action: Callable) -> SpinBox:
	_label(parent, title)
	var b := SpinBox.new()
	b.min_value = low
	b.max_value = high
	b.step = step
	b.value = initial
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.value_changed.connect(action)
	parent.add_child(b)
	_register_tooltip(b,title,"Adjust " + title + ".")
	return b

func _setting(parent: Node, title: String, key: String, low: float, high: float, step: float) -> void:
	_spin(parent, title, float(cfg[key]), low, high, step, func(v: float):
		cfg[key] = v
		_save()
		if not playing:
			_reset()
	)

func _text_setting(parent: Node, title: String, key: String) -> void:
	_label(parent, title)
	var e := LineEdit.new()
	e.text = str(cfg[key])
	e.text_changed.connect(func(v: String): cfg[key] = v; _save())
	parent.add_child(e)
	_register_tooltip(e,title,"Edit " + title + ".")

func _power_controls(parent: Node, title: String, key: String, effect_label: String, effect_key: String, low: float, high: float, step: float, timed: bool) -> void:
	_label(parent, "— " + title + " —")
	var enabled := CheckBox.new()
	enabled.text = "Enable " + title
	enabled.button_pressed = bool(cfg["power_"+key+"_enabled"])
	enabled.toggled.connect(func(value: bool): cfg["power_"+key+"_enabled"] = value; _save())
	parent.add_child(enabled)
	_register_tooltip(enabled, "Enable " + title, "Allow this power-up to spawn during play.")
	_setting(parent, title + " spawn weight (0–10)", "power_"+key+"_weight", 0, 10, 1)
	_setting(parent, effect_label, "power_"+key+"_"+effect_key, low, high, step)
	if timed:
		_setting(parent, title + " duration (seconds)", "power_"+key+"_duration", 1, 60, 0.5)

func _install_optional_audio() -> void:
	var sidebar: Node = find_child("SoundSidebar",true,false)
	if sidebar == null:
		return
	optional_audio = load("res://scripts/optional_audio.gd").new()
	add_child(optional_audio)
	var sound_events: Array[String] = ["Background Music", "Player Shooting", "Boss Shooting", "Damage", "Power-up Collected", "Victory", "Defeat"]
	optional_audio.setup(self,sidebar,"boss",sound_events)

func _install_game_intro() -> void:
	var sidebar: Node = find_child("SoundSidebar",true,false)
	if sidebar == null:
		return
	if sidebar is ScrollContainer and sidebar.get_child_count() > 0:
		sidebar = sidebar.get_child(0)
	game_intro = load("res://scripts/game_intro.gd").new()
	add_child(game_intro)
	game_intro.setup(self,sidebar,"boss","Bullet Hell Boss","Dodge incoming bullets, collect power-ups and defeat the boss!")

func _sound(event_name: String) -> void:
	if optional_audio != null:
		optional_audio.play(event_name)

func _build() -> void:
	var root := VBoxContainer.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bar := HBoxContainer.new()
	root.add_child(bar)
	_button(bar, "← Games", func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	_button(bar, "Edit Boss", _edit)
	_button(bar, "Play / Test", _start)
	_button(bar, "Restart", _start)
	var tip_toggle := CheckButton.new()
	tip_toggle.text = "Edit Tooltips"
	tip_toggle.focus_mode = Control.FOCUS_NONE
	tip_toggle.toggled.connect(_toggle_tooltips)
	bar.add_child(tip_toggle)
	# Keep this switch operable in tooltip-edit mode; do not register its click as an editable item.
	tip_toggle.tooltip_text = "Turn tooltip editing on or off. Hover over menu items to read saved tooltips."
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 330
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var left := VBoxContainer.new()
	left.name = "SoundSidebar"
	left.custom_minimum_size.x = 308
	scroll.add_child(left)
	_section(left, "BOSS & PLAYER SETTINGS", Color("#268bd2"))
	_setting(left, "Player maximum HP", "player_hp", 10, 1000, 10)
	_setting(left, "Boss maximum HP", "boss_hp", 10, 5000, 10)
	_setting(left, "Player movement speed", "player_speed", 50, 600, 10)
	_setting(left, "Player shot damage", "shot_damage", 1, 100, 1)
	_setting(left, "Player shot interval (seconds)", "shot_interval", 0.08, 2, 0.02)
	_setting(left, "Bullet damage", "bullet_damage", 1, 100, 1)
	_setting(left, "Boss sprite size", "boss_size", 20, 220, 5)
	_setting(left, "Player sprite size", "player_size", 16, 120, 4)
	_setting(left, "Full health above (%)", "full_threshold", 25, 90, 5)
	_setting(left, "Near death at or below (%)", "near_threshold", 5, 45, 5)
	_section(left, "CUSTOM CHARACTER SPRITES", Color("#9b70d8"))
	for role in ROLES:
		for state in STATES:
			_button(left, "Import %s — %s PNG" % [role.capitalize(), state.capitalize()], _choose.bind("sprite:%s:%s" % [role,state]))
	_button(left, "Import arena background PNG", _choose.bind("background"))
	_section(left, "BULLET WAVE SEQUENCE", Color("#e7a23a"))
	wave_list = ItemList.new()
	wave_list.custom_minimum_size.y = 120
	wave_list.item_selected.connect(_select_wave)
	left.add_child(wave_list)
	_register_tooltip(wave_list,"Wave sequence","Select a wave to edit its bullet layout, movement, and timing.")
	var wave_bar := HBoxContainer.new()
	left.add_child(wave_bar)
	_button(wave_bar, "+ Add wave", _add_wave)
	_button(wave_bar, "Remove", _remove_wave)
	_button(wave_bar, "↑", _wave_up)
	_button(wave_bar, "↓", _wave_down)
	_label(left, "Wave name")
	wave_name = LineEdit.new()
	wave_name.text_changed.connect(func(v: String): _wave_set("name",v))
	left.add_child(wave_name)
	_section(left, "BULLET PATTERN DESIGNER", Color("#d77a36"))
	_label(left, "Click grid squares to add or remove bullets. Each dot is one bullet. The centre cross marks the boss origin.")
	wave_canvas = Control.new()
	wave_canvas.set_script(load("res://scripts/boss_wave_canvas.gd"))
	wave_canvas.set("editor", self)
	wave_canvas.custom_minimum_size = Vector2(300, 220)
	left.add_child(wave_canvas)
	var pattern_buttons := HBoxContainer.new()
	left.add_child(pattern_buttons)
	_button(pattern_buttons, "Clear", _clear_pattern)
	_button(pattern_buttons, "Ring", _ring_pattern)
	_button(pattern_buttons, "Line", _line_pattern)
	_button(pattern_buttons, "Arrow", _arrow_pattern)
	_label(left, "Each wave has its own clickable bullet layout. Set direction and spawn offset below.")
	wave_duration = _wave_spin(left,"Wave duration (seconds)","duration",1,40,0.5)
	wave_angle = _wave_spin(left,"Bullet direction (degrees: 0 right, 90 down)","angle",0,359,1)
	wave_x = _wave_spin(left,"Spawn offset X from boss centre","offset_x",-300,300,5)
	wave_y = _wave_spin(left,"Spawn offset Y from boss centre","offset_y",-300,300,5)
	wave_speed = _wave_spin(left,"Bullet speed","speed",20,600,10)
	wave_lifetime = _wave_spin(left,"Bullet lifetime (seconds)","lifetime",0.5,20,0.5)
	wave_fade = _wave_spin(left,"Fade duration (seconds)","fade",0,5,0.1)
	wave_interval = _wave_spin(left,"Time between volleys (seconds)","interval",0.2,10,0.1)
	_section(left,"BULLET VELOCITY & MOTION",Color("#8e79d6"))
	wave_vx = _wave_spin(left,"Extra horizontal velocity X","velocity_x",-500,500,10)
	wave_vy = _wave_spin(left,"Extra vertical velocity Y","velocity_y",-500,500,10)
	wave_accel = _wave_spin(left,"Acceleration along direction","acceleration",-500,500,10)
	wave_spread = _wave_spin(left,"Spread outward (pixels/sec)","spread",-300,300,10)
	wave_rotation = _wave_spin(left,"Formation rotation (degrees/sec)","rotation",-360,360,10)
	wave_max_speed = _wave_spin(left,"Maximum bullet speed (0 = unlimited)","max_speed",0,1200,20)
	_button(left,"Preview Selected Wave",_preview_wave)
	_section(left, "BOSS MOVEMENT: POINT A → POINT B", Color("#4eae9c"))
	_label(left, "Drag A and B on the arena map. Boss moves between them while continuously firing this wave.")
	movement_canvas = Control.new()
	movement_canvas.set_script(load("res://scripts/boss_movement_canvas.gd"))
	movement_canvas.set("editor", self)
	movement_canvas.custom_minimum_size = Vector2(300, 200)
	left.add_child(movement_canvas)
	wave_move_speed = _wave_spin(left,"Boss travel speed (pixels/second)","move_speed",0,400,5)
	_label(left, "When boss reaches B")
	movement_mode = OptionButton.new()
	for choice in ["Stop at B", "Return to A (repeat)", "Restart at A (repeat)"]:
		movement_mode.add_item(choice)
	movement_mode.item_selected.connect(func(index: int): _wave_set("move_mode",index))
	left.add_child(movement_mode)
	_register_tooltip(movement_mode,"Movement end behaviour","Choose whether the boss stops, returns to A, or teleports to A at the end of its path.")
	_label(left, "Movement is independent of firing. Wave duration determines when the next wave starts.")
	_section(left, "POWER-UPS", Color("#62a857"))
	var enable := CheckBox.new()
	enable.text = "Enable power-ups"
	enable.button_pressed = bool(cfg["power_enabled"])
	enable.toggled.connect(func(v: bool): cfg["power_enabled"] = v; _save())
	left.add_child(enable)
	_register_tooltip(enable,"Enable power-ups","Choose whether collectible power-ups appear during the boss fight.")
	_setting(left,"Power-up spawn interval (seconds)","power_interval",1,60,1)
	_label(left,"Each power-up has its own enable switch, spawn weight, strength and duration.")
	_power_controls(left,"Health","health","HP restored (% of max HP)","restore",1,100,5,false)
	_power_controls(left,"Shield","shield","Damage blocked (%)","protection",0,100,5,true)
	_power_controls(left,"Rapid Fire","rapid","Fire rate multiplier","multiplier",1,6,0.25,true)
	_power_controls(left,"Damage Boost","damage","Damage multiplier","multiplier",1,6,0.25,true)
	_power_controls(left,"Speed Boost","speed","Movement multiplier","multiplier",1,4,0.25,true)
	power_type = OptionButton.new()
	for t in POWER_TYPES:
		power_type.add_item(t)
	left.add_child(power_type)
	_register_tooltip(power_type,"Power-up type","Select the power-up whose image you want to import.")
	_button(left,"Import selected power-up PNG",_import_power)
	_section(left, "END GAME MESSAGES", Color("#d36b91"))
	_text_setting(left,"Victory message","win_message")
	_text_setting(left,"Defeat message","lose_message")
	_label(left,"CONTROLS: WASD move, SPACE shoots. Touch power-ups to collect.")
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(right)
	hud = Label.new()
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(hud)
	var holder := AspectRatioContainer.new()
	holder.ratio = ARENA.x / ARENA.y
	holder.stretch_mode = AspectRatioContainer.STRETCH_FIT
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(holder)
	arena = Control.new()
	arena.set_script(load("res://scripts/boss_arena.gd"))
	arena.set("controller", self)
	holder.add_child(arena)
	message = Label.new()
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 26)
	right.add_child(message)
	status = Label.new()
	root.add_child(status)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.png", "PNG images")
	file_dialog.file_selected.connect(_import_image)
	add_child(file_dialog)
	tooltip_dialog = ConfirmationDialog.new()
	tooltip_dialog.title = "Edit Menu Tooltip"
	tooltip_dialog.min_size = Vector2i(480,250)
	var tip_box := VBoxContainer.new()
	tooltip_dialog.add_child(tip_box)
	tooltip_edit = TextEdit.new()
	tooltip_edit.custom_minimum_size.y = 120
	tip_box.add_child(tooltip_edit)
	var reset_tip := Button.new()
	reset_tip.text = "Reset this tooltip to default"
	reset_tip.focus_mode = Control.FOCUS_NONE
	reset_tip.pressed.connect(_reset_tooltip)
	tip_box.add_child(reset_tip)
	tooltip_dialog.confirmed.connect(_save_current_tooltip)
	add_child(tooltip_dialog)
	_refresh_waves()

func _set_pattern(points: Array) -> void:
	if selected_wave < 0 or selected_wave >= waves.size():
		return
	waves[selected_wave]["points"] = points
	_save()
	if wave_canvas != null:
		wave_canvas.queue_redraw()

func _clear_pattern() -> void:
	_set_pattern([])

func _ring_pattern() -> void:
	var pts: Array = []
	for i in range(16):
		var angle: float = TAU * float(i) / 16.0
		var p := [roundi(cos(angle)*5.0), roundi(sin(angle)*4.0)]
		if not pts.has(p):
			pts.append(p)
	_set_pattern(pts)

func _line_pattern() -> void:
	var pts: Array = []
	for x in range(-6,7):
		pts.append([x,0])
	_set_pattern(pts)

func _arrow_pattern() -> void:
	var pts: Array = []
	for y in range(-4,5):
		pts.append([0,y])
	for x in range(-4,5):
		pts.append([x,abs(x)-4])
	_set_pattern(pts)

func _wave_spin(parent: Node, title: String, key: String, low: float, high: float, step: float) -> SpinBox:
	return _spin(parent,title,0,low,high,step,func(v: float): _wave_set(key,v))

func _default_wave() -> Dictionary:
	return {"name":"Radial wave", "duration":6.0, "angle":90.0, "offset_x":0.0, "offset_y":0.0, "speed":160.0, "lifetime":5.0, "fade":0.5, "interval":1.0, "move_speed":100.0, "move_mode":1, "velocity_x":0.0, "velocity_y":0.0, "acceleration":0.0, "spread":0.0, "rotation":0.0, "max_speed":0.0, "start_x":200.0, "start_y":100.0, "end_x":650.0, "end_y":100.0, "points":[[0,-3],[-2,-1],[0,-1],[2,-1],[-4,1],[-2,1],[0,1],[2,1],[4,1]]}

func _refresh_waves() -> void:
	if wave_list == null:
		return
	wave_list.clear()
	for i in range(waves.size()):
		wave_list.add_item("%d. %s" % [i+1,str(waves[i].get("name","Wave"))])
	if waves.is_empty():
		return
	if wave_canvas != null:
		wave_canvas.queue_redraw()
	selected_wave = clampi(selected_wave,0,waves.size()-1)
	wave_list.select(selected_wave)
	var w: Dictionary = waves[selected_wave]
	wave_name.text = str(w.get("name","Wave"))
	if wave_canvas != null:
		wave_canvas.queue_redraw()
	if movement_canvas != null:
		movement_canvas.queue_redraw()
	if movement_mode != null:
		movement_mode.select(clampi(int(w.get("move_mode",1)),0,2))
	for entry in [["duration",wave_duration],["angle",wave_angle],["offset_x",wave_x],["offset_y",wave_y],["speed",wave_speed],["lifetime",wave_lifetime],["fade",wave_fade],["interval",wave_interval],["velocity_x",wave_vx],["velocity_y",wave_vy],["acceleration",wave_accel],["spread",wave_spread],["rotation",wave_rotation],["max_speed",wave_max_speed],["move_speed",wave_move_speed]]:
		(entry[1] as SpinBox).set_value_no_signal(float(w.get(entry[0],0)))

func _select_wave(index: int) -> void:
	selected_wave = index
	_refresh_waves()

func _wave_set(key: String, value: Variant) -> void:
	if selected_wave < 0 or selected_wave >= waves.size():
		return
	waves[selected_wave][key] = value
	_save()
	if movement_canvas != null:
		movement_canvas.queue_redraw()
	if key == "name":
		wave_list.set_item_text(selected_wave,"%d. %s" % [selected_wave+1,str(value)])

func _add_wave() -> void:
	var w := _default_wave()
	w["name"] = "Wave %d" % (waves.size()+1)
	waves.append(w)
	selected_wave = waves.size()-1
	_save()
	_refresh_waves()

func _remove_wave() -> void:
	if waves.size() <= 1:
		return
	waves.remove_at(selected_wave)
	selected_wave = mini(selected_wave,waves.size()-1)
	_save()
	_refresh_waves()

func _wave_up() -> void:
	if selected_wave > 0:
		var w := waves[selected_wave]
		waves[selected_wave] = waves[selected_wave-1]
		waves[selected_wave-1] = w
		selected_wave -= 1
		_save()
		_refresh_waves()

func _wave_down() -> void:
	if selected_wave < waves.size()-1:
		var w := waves[selected_wave]
		waves[selected_wave] = waves[selected_wave+1]
		waves[selected_wave+1] = w
		selected_wave += 1
		_save()
		_refresh_waves()

func _choose(kind: String) -> void:
	import_kind = kind
	file_dialog.popup_centered_ratio(0.7)

func _import_power() -> void:
	_choose("power:"+POWER_TYPES[power_type.selected].to_lower().replace(" ","_"))

func _image_path(kind: String) -> String:
	return "user://boss_asset_" + kind.replace(":","_") + ".png"

func _import_image(path: String) -> void:
	var img := Image.new()
	if img.load(path) != OK:
		status.text = "Could not open PNG."
		return
	img.convert(Image.FORMAT_RGBA8)
	if img.save_png(_image_path(import_kind)) != OK:
		status.text = "Could not save sprite."
		return
	_load_images()
	status.text = "Imported %s" % import_kind
	arena.queue_redraw()

func _load_images() -> void:
	sprites.clear()
	for role in ROLES:
		for state in STATES:
			var key := "sprite:%s:%s" % [role,state]
			sprites[key] = _read_texture(key)
	for power in POWER_TYPES:
		var key: String = "power:" + str(power).to_lower().replace(" ", "_")
		sprites[key] = _read_texture(key)
	background_texture = _read_texture("background")

func _read_texture(kind: String) -> Texture2D:
	if not FileAccess.file_exists(_image_path(kind)):
		return null
	var img := Image.new()
	if img.load(_image_path(kind)) == OK:
		return ImageTexture.create_from_image(img)
	return null

func _load() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if parsed is Dictionary:
			var saved: Dictionary = parsed
			if saved.get("settings",{}) is Dictionary:
				for key in cfg:
					if saved["settings"].has(key):
						cfg[key] = saved["settings"][key]
			if saved.get("waves",[]) is Array:
				for item in saved["waves"]:
					if item is Dictionary:
						var w := _default_wave()
						w.merge(item,true)
						waves.append(w)
	if waves.is_empty():
		waves.append(_default_wave())

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"settings":cfg,"waves":waves}))
		f.close()

func _reset() -> void:
	playing = false
	preview_mode = false
	ended = false
	result_text = ""
	hp = int(cfg["player_hp"])
	boss_hp = int(cfg["boss_hp"])
	player_pos = Vector2(ARENA.x*0.5,ARENA.y*0.85)
	boss_pos = _wave_point(waves[0], "start") if not waves.is_empty() else Vector2(ARENA.x*0.5,ARENA.y*0.17)
	movement_returning = false
	bullets.clear()
	shots.clear()
	powerups.clear()
	active_wave = 0
	wave_elapsed = 0
	wave_fire_timer = 0
	shoot_timer = 0
	power_timer = float(cfg["power_interval"])
	invulnerable = 0
	shield_timer = 0
	rapid_timer = 0
	damage_timer = 0
	speed_timer = 0
	elapsed = 0
	if message != null:
		message.text = ""
	_update_hud()
	if arena != null:
		arena.queue_redraw()

func _edit() -> void:
	_reset()
	status.text = "EDIT BOSS: configure wave sequence, sprites and power-ups."

func _start() -> void:
	if game_intro != null:
		game_intro.show_intro(Callable(self,"_start_actual"))
	else:
		_start_actual()

func _start_actual() -> void:
	get_viewport().gui_release_focus()
	_reset()
	playing = true
	status.text = "BOSS FIGHT: WASD to move; SPACE to shoot."
	_sound("Background Music")

func _preview_wave() -> void:
	_reset()
	active_wave = selected_wave
	boss_pos = _wave_point(waves[active_wave],"start")
	preview_mode = true
	playing = true
	status.text = "WAVE PREVIEW: bullets and boss movement only. Select Play / Test for full game."

func _register_tooltip(control: Control, title: String, default_text: String) -> void:
	var key := title.strip_edges()
	tooltip_defaults[key] = default_text
	tooltip_targets[control] = key
	control.tooltip_text = str(tooltip_custom.get(key,default_text))
	control.gui_input.connect(_tooltip_click.bind(control))

func _tooltip_click(event: InputEvent, control: Control) -> void:
	if control is BaseButton and (control as BaseButton).text == "Edit Tooltips":
		return
	if not tooltip_mode or not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	tooltip_target_id = str(tooltip_targets.get(control,""))
	if tooltip_target_id.is_empty():
		return
	tooltip_edit.text = str(tooltip_custom.get(tooltip_target_id,tooltip_defaults.get(tooltip_target_id,"")))
	tooltip_dialog.popup_centered()
	control.accept_event()

func _toggle_tooltips(enabled: bool) -> void:
	tooltip_mode = enabled
	status.text = "TOOLTIP EDIT MODE: click a menu item to edit its help text." if enabled else "Tooltips saved. Hover over menu items to read them."

func _save_current_tooltip() -> void:
	if tooltip_target_id.is_empty():
		return
	tooltip_custom[tooltip_target_id] = tooltip_edit.text
	_save_tooltips()
	_apply_tooltips()

func _reset_tooltip() -> void:
	tooltip_edit.text = str(tooltip_defaults.get(tooltip_target_id,""))
	tooltip_custom.erase(tooltip_target_id)
	_save_tooltips()
	_apply_tooltips()
	tooltip_dialog.hide()

func _apply_tooltips() -> void:
	for control in tooltip_targets:
		if is_instance_valid(control):
			var key: String = str(tooltip_targets[control])
			(control as Control).tooltip_text = str(tooltip_custom.get(key,tooltip_defaults.get(key,"")))

func _load_tooltips() -> void:
	if FileAccess.file_exists("user://boss_tooltips.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://boss_tooltips.json"))
		if parsed is Dictionary:
			tooltip_custom = parsed

func _save_tooltips() -> void:
	var file := FileAccess.open("user://boss_tooltips.json",FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(tooltip_custom))
		file.close()

func _health_state(current: int, maximum: int) -> String:
	if current <= 0:
		return "dead"
	var pct := 100.0 * float(current) / float(maxi(1,maximum))
	if pct <= float(cfg["near_threshold"]):
		return "near"
	if pct <= float(cfg["full_threshold"]):
		return "half"
	return "full"

func _character_texture(role: String) -> Texture2D:
	var state := _health_state(boss_hp if role=="boss" else hp,int(cfg["boss_hp"] if role=="boss" else cfg["player_hp"]))
	var tex: Texture2D = sprites.get("sprite:%s:%s" % [role,state])
	if tex == null:
		tex = sprites.get("sprite:%s:full" % role)
	return tex

func _update_hud() -> void:
	if hud != null:
		hud.text = "BOSS HP: %d / %d     PLAYER HP: %d / %d     WAVE: %d / %d" % [boss_hp,int(cfg["boss_hp"]),hp,int(cfg["player_hp"]),active_wave+1,waves.size()]

func _finish(win: bool) -> void:
	playing = false
	ended = true
	result_text = str(cfg["win_message"] if win else cfg["lose_message"])
	message.text = result_text
	status.text = "Boss defeated. Restart or return to Games." if win else "Player defeated. Restart to try again."
	if optional_audio != null:
		optional_audio.stop_all()
	_sound("Victory" if win else "Defeat")
	bullets.clear()
	shots.clear()

func _spawn_wave() -> void:
	if waves.is_empty():
		return
	var w: Dictionary = waves[active_wave]
	var origins: Array[Vector2] = []
	for point in w.get("points", []):
		if point is Array and point.size() >= 2:
			origins.append(Vector2(float(point[0]),float(point[1])) * 14.0)
			if origins.size() >= 80:
				break
	if origins.is_empty():
		return
	var angle := deg_to_rad(float(w["angle"]))
	var velocity := Vector2.RIGHT.rotated(angle)*float(w["speed"])+Vector2(float(w.get("velocity_x",0)),float(w.get("velocity_y",0)))
	var spawn := boss_pos+Vector2(float(w["offset_x"]),float(w["offset_y"]))
	_sound("Boss Shooting")
	for offset in origins:
		var spread_vector: Vector2 = offset.normalized()*float(w.get("spread",0))
		bullets.append({"pos":spawn+offset,"vel":velocity+spread_vector,"age":0.0,"life":float(w["lifetime"]),"fade":float(w["fade"]),"acceleration":float(w.get("acceleration",0)),"rotation":deg_to_rad(float(w.get("rotation",0))),"max_speed":float(w.get("max_speed",0)),"origin":spawn,"radial":offset})
	# Cap total active bullets to avoid slowing school computers.
	if bullets.size() > 700:
		bullets = bullets.slice(bullets.size()-700)

func _spawn_powerup() -> void:
	var weighted: Array[String] = []
	for entry in [["Health","health"],["Shield","shield"],["Rapid Fire","rapid"],["Damage Boost","damage"],["Speed Boost","speed"]]:
		var title: String = str(entry[0])
		var key: String = str(entry[1])
		if bool(cfg["power_"+key+"_enabled"]):
			for i in range(clampi(int(cfg["power_"+key+"_weight"]),0,10)):
				weighted.append(title)
	if weighted.is_empty():
		return
	var kind: String = weighted[randi_range(0,weighted.size()-1)]
	powerups.append({"pos":Vector2(randf_range(40,ARENA.x-40),randf_range(ARENA.y*0.35,ARENA.y-45)),"kind":kind,"age":0.0})

func _collect_powerup(kind: String) -> void:
	_sound("Power-up Collected")
	match kind:
		"Health":
			hp = mini(int(cfg["player_hp"]),hp+maxi(1,roundi(float(cfg["player_hp"])*float(cfg["power_health_restore"])/100.0)))
		"Shield":
			shield_timer = float(cfg["power_shield_duration"])
			shield_protection = float(cfg["power_shield_protection"])
		"Rapid Fire": rapid_timer = float(cfg["power_rapid_duration"])
		"Damage Boost": damage_timer = float(cfg["power_damage_duration"])
		"Speed Boost": speed_timer = float(cfg["power_speed_duration"])

func _boss_movement_min() -> Vector2:
	# Keep the entire boss sprite visible, regardless of its configured size.
	var margin: float = maxf(8.0, float(cfg["boss_size"]) * 0.5)
	return Vector2(margin, margin)

func _boss_movement_max() -> Vector2:
	var margin: float = maxf(8.0, float(cfg["boss_size"]) * 0.5)
	return ARENA - Vector2(margin, margin)

func _wave_point(wave: Dictionary, which: String) -> Vector2:
	var x: float = float(wave.get(which+"_x",200.0 if which=="start" else 650.0))
	var y: float = float(wave.get(which+"_y",100.0))
	return Vector2(x,y).clamp(_boss_movement_min(), _boss_movement_max())

func _move_boss(wave: Dictionary, delta: float) -> void:
	var speed: float = float(wave.get("move_speed",100.0))
	if speed <= 0:
		return
	var target: Vector2 = _wave_point(wave,"start" if movement_returning else "end")
	boss_pos = boss_pos.move_toward(target,speed*delta)
	if boss_pos.distance_to(target) < 0.5:
		match int(wave.get("move_mode",1)):
			1:
				movement_returning = not movement_returning
			2:
				boss_pos = _wave_point(wave,"start")
				movement_returning = false
			_:
				pass

func _set_movement_point(which: String, position: Vector2) -> void:
	if selected_wave < 0 or selected_wave >= waves.size():
		return
	var p: Vector2 = position.clamp(_boss_movement_min(), _boss_movement_max())
	waves[selected_wave][which+"_x"] = p.x
	waves[selected_wave][which+"_y"] = p.y
	_save()
	if movement_canvas != null:
		movement_canvas.queue_redraw()
	if not playing and selected_wave == 0:
		boss_pos = _wave_point(waves[0],"start")
		arena.queue_redraw()

func _process(delta: float) -> void:
	if not playing or arena == null:
		return
	delta = minf(delta,0.05)
	elapsed += delta
	invulnerable = maxf(0,invulnerable-delta)
	shield_timer = maxf(0,shield_timer-delta)
	rapid_timer = maxf(0,rapid_timer-delta)
	damage_timer = maxf(0,damage_timer-delta)
	speed_timer = maxf(0,speed_timer-delta)
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))).normalized()
	var multiplier: float = float(cfg["power_speed_multiplier"]) if speed_timer>0 else 1.0
	player_pos = (player_pos+direction*float(cfg["player_speed"])*multiplier*delta).clamp(Vector2(24,35),ARENA-Vector2(24,24))
	shoot_timer -= delta
	if not preview_mode and Input.is_physical_key_pressed(KEY_SPACE) and shoot_timer<=0:
		shoot_timer = float(cfg["shot_interval"])/(float(cfg["power_rapid_multiplier"]) if rapid_timer>0 else 1.0)
		_sound("Player Shooting")
		shots.append({"pos":player_pos+Vector2(0,-24),"damage":maxi(1,roundi(float(cfg["shot_damage"])*(float(cfg["power_damage_multiplier"]) if damage_timer>0 else 1.0)))})
	if not waves.is_empty():
		var wave: Dictionary = waves[active_wave]
		_move_boss(wave, delta)
		wave_elapsed += delta
		wave_fire_timer -= delta
		if wave_fire_timer <= 0:
			_spawn_wave()
			wave_fire_timer = float(wave["interval"])
		if wave_elapsed >= float(wave["duration"]):
			active_wave = (active_wave+1)%waves.size()
			boss_pos = _wave_point(waves[active_wave], "start")
			movement_returning = false
			wave_elapsed = 0
			wave_fire_timer = 0
	if preview_mode:
		shots.clear()
	for i in range(shots.size()-1,-1,-1):
		var shot: Dictionary = shots[i]
		var pos: Vector2 = shot["pos"]+Vector2(0,-500)*delta
		if pos.y<0:
			shots.remove_at(i)
		elif pos.distance_to(boss_pos)<float(cfg["boss_size"])*0.42:
			boss_hp = maxi(0,boss_hp-int(shot["damage"]))
			shots.remove_at(i)
			if boss_hp==0:
				_finish(true)
				break
		else:
			shot["pos"] = pos
			shots[i] = shot
	if not playing:
		_update_hud()
		arena.queue_redraw()
		return
	for i in range(bullets.size()-1,-1,-1):
		var b: Dictionary = bullets[i]
		var vel: Vector2 = b["vel"]
		var acceleration: float = float(b.get("acceleration",0.0))
		if vel.length_squared()>0.001:
			vel += vel.normalized()*acceleration*delta
		var rotation: float = float(b.get("rotation",0.0))
		vel = vel.rotated(rotation*delta)
		var maximum: float = float(b.get("max_speed",0.0))
		if maximum>0 and vel.length()>maximum:
			vel = vel.normalized()*maximum
		b["vel"] = vel
		b["pos"] = (b["pos"] as Vector2)+vel*delta
		b["age"] = float(b["age"])+delta
		var pos: Vector2 = b["pos"]
		if float(b["age"])>=float(b["life"]) or pos.x< -20 or pos.y< -20 or pos.x>ARENA.x+20 or pos.y>ARENA.y+20:
			bullets.remove_at(i)
		elif pos.distance_to(player_pos)<float(cfg["player_size"])*0.32+6 and invulnerable<=0 and not preview_mode:
			bullets.remove_at(i)
			var damage: int = int(cfg["bullet_damage"])
			if shield_timer > 0:
				damage = maxi(0,roundi(float(damage)*(1.0-shield_protection/100.0)))
			hp = maxi(0,hp-damage)
			if damage > 0:
				_sound("Damage")
			invulnerable = 0.65
			if hp==0:
				_finish(false)
				break
		else:
			bullets[i] = b
	if bool(cfg["power_enabled"]) and playing and not preview_mode:
		power_timer -= delta
		if power_timer<=0:
			_spawn_powerup()
			power_timer = float(cfg["power_interval"])
		for i in range(powerups.size()-1,-1,-1):
			var p: Dictionary = powerups[i]
			p["age"] = float(p["age"])+delta
			if float(p["age"])>10:
				powerups.remove_at(i)
			elif (p["pos"] as Vector2).distance_to(player_pos)<30:
				_collect_powerup(str(p["kind"]))
				powerups.remove_at(i)
			else:
				powerups[i] = p
	_update_hud()
	arena.queue_redraw()
