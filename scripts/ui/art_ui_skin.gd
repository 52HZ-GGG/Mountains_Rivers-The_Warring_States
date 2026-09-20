extends RefCounted
class_name ArtUiSkin

## UI 场景皮肤：把 ai_art 面板底图/按钮样式打到任意 Control。
## 场景 _ready 里调用 ArtUiSkin.apply_panel(self, "tech") 等。


static func _tex(panel_key: String) -> Texture2D:
	if ClassDB.class_exists("ArtCatalog"):
		return ArtCatalog.panel_texture(panel_key)
	return null


static func apply_panel(control: Control, panel_key: String) -> void:
	if control == null:
		return
	var tex := _tex(panel_key)
	if tex == null:
		# 面板键别名
		var alias := ""
		match panel_key:
			"tech_tree", "technology":
				alias = "tech"
			"diplomacy_panel", "diplo":
				alias = "diplomacy"
			"school_panel", "schools":
				alias = "school"
			"save_load", "saveload":
				alias = "save"
			"event":
				alias = "event"
		if alias != "":
			tex = _tex(alias)
	if tex == null:
		return
	# 若已有 TextureRect 背景则换图；否则挂 StyleBoxTexture
	var bg := control.get_node_or_null("Background") as TextureRect
	if bg == null:
		bg = control.get_node_or_null("PanelBg") as TextureRect
	if bg != null:
		bg.texture = tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		return
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = 24.0
	sb.texture_margin_right = 24.0
	sb.texture_margin_top = 20.0
	sb.texture_margin_bottom = 20.0
	control.add_theme_stylebox_override("panel", sb)


static func style_buttons(node: Node) -> void:
	if node == null or not ClassDB.class_exists("SkirmishTileTextures"):
		return
	if node is Button:
		SkirmishTileTextures.style_scene_button(node as Button)
		if ClassDB.class_exists("ArtAudio") or Engine.has_singleton("ArtAudio"):
			pass
	for child in node.get_children():
		style_buttons(child)


static func bind_click_sounds(node: Node) -> void:
	var audio := node.get_node_or_null("/root/ArtAudio")
	if audio == null:
		return
	if audio.has_method("attach_clicks_in"):
		audio.attach_clicks_in(node)


static func apply_full_skin(control: Control, panel_key: String) -> void:
	apply_panel(control, panel_key)
	style_buttons(control)
	bind_click_sounds(control)
