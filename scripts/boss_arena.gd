extends Control
var controller: Control

func _draw() -> void:
	if controller == null:
		return
	var c = controller
	var factor: float = minf(size.x/850.0,size.y/560.0)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*factor)
	draw_rect(Rect2(Vector2.ZERO,Vector2(850,560)),Color("#172134"))
	if c.background_texture != null:
		draw_texture_rect(c.background_texture,Rect2(Vector2.ZERO,Vector2(850,560)),false)
	_draw_character(c,"boss",c.boss_pos,float(c.cfg["boss_size"]),Color("#b63e69"))
	_draw_character(c,"player",c.player_pos,float(c.cfg["player_size"]),Color("#55d8ed"))
	for b in c.bullets:
		var fade: float = float(b["fade"])
		var remaining: float = float(b["life"])-float(b["age"])
		var alpha: float = clampf(remaining/fade,0,1) if fade>0 else 1.0
		draw_circle(b["pos"],6,Color(1,0.8,0.3,alpha))
	for shot in c.shots:
		draw_rect(Rect2(shot["pos"]-Vector2(3,11),Vector2(6,17)),Color("#9bffcf"))
	for p in c.powerups:
		var kind: String = str(p["kind"])
		var col := Color("#50c88a") if kind=="Health" else Color("#8aa7ff")
		var key := "power:"+kind.to_lower().replace(" ","_")
		var tex: Texture2D = c.sprites.get(key)
		if tex != null:
			draw_texture_rect(tex,Rect2(p["pos"]-Vector2(14,14),Vector2(28,28)),false)
		else:
			draw_circle(p["pos"],13,col)
	if c.shield_timer>0:
		draw_arc(c.player_pos,30,0,TAU,32,Color("#8ac6ff"),3)
	_draw_bar(Vector2(25,14),Vector2(800,14),float(c.boss_hp)/maxf(1,float(c.cfg["boss_hp"])),Color("#ee6686"))
	_draw_bar(Vector2(25,538),Vector2(800,12),float(c.hp)/maxf(1,float(c.cfg["player_hp"])),Color("#52d6a0"))
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func _draw_character(c: Control,role: String,pos: Vector2,diameter: float,fallback: Color) -> void:
	var tex: Texture2D = c._character_texture(role)
	if tex != null:
		var original := tex.get_size()
		var scale_factor: float = diameter/maxf(original.x,original.y)
		var dims := original*scale_factor
		draw_texture_rect(tex,Rect2(pos-dims*0.5,dims),false)
	else:
		draw_circle(pos,diameter*0.5,fallback)

func _draw_bar(pos: Vector2,dim: Vector2,fraction: float,fill_color: Color) -> void:
	draw_rect(Rect2(pos,dim),Color("#303847"))
	draw_rect(Rect2(pos,Vector2(dim.x*clampf(fraction,0,1),dim.y)),fill_color)
