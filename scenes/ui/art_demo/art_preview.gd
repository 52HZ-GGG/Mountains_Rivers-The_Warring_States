extends Control

## 美术预览演示：地形瓦片 + 城市图标 + UI 面板/资源栏（不依赖完整开局）。
## 用法：Godot 打开本场景 F5，或 main 菜单临时指向 res://scenes/ui/art_demo/art_preview.tscn
## 数据：big_map_terrain.json + cities.json（autoload DataManager）

const VIEW_W := 18
const VIEW_H := 12
const HEX_R := 42.0

var _terrain_at: Dictionary = {}
var _cities: Array = []
var _hover_axial: Vector2i = Vector2i(-999, -999)
var _selected_city: Dictionary = {}
var _map_origin := Vector2(40, 72)
var _highlight_tex: Texture2D
var _bgm: AudioStreamPlayer

@onready var _map_layer: Control = $MapLayer
@onready var _hud: Control = $HUD
@onready var _hover_label: Label = $HUD/HoverLabel
@onready var _resource_flow: HBoxContainer = $HUD/TopBar/ResourceFlow
@onready var _city_panel: PanelContainer = $HUD/CityPanel
@onready var _city_panel_tex: TextureRect = $HUD/CityPanel/PanelBg
@onready var _city_title: Label = $HUD/CityPanel/Margin/VBox/Title
@onready var _city_body: Label = $HUD/CityPanel/Margin/VBox/Body
@onready var _legend: Label = $HUD/Legend


func _ready() -> void:
	_highlight_tex = ArtCatalog.highlight_texture("selected")
	_build_resource_bar()
	_load_map_data()
	_map_layer.draw.connect(_on_map_draw)
	_map_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_layer.gui_input.connect(_on_map_input)
	_build_city_panel_style()
	_build_buttons()
	_try_play_bgm()
	_legend.text = "地形演示：六边形瓦片 + 城市｜鼠标悬停看地形名｜点击城市｜Esc 退出"
	_map_layer.queue_redraw()


func _build_buttons() -> void:
	var bar := $HUD/TopBar/ButtonRow as HBoxContainer
	if bar == null:
		return
	var btn_close := SkirmishTileTextures.styled_button("关闭演示")
	btn_close.pressed.connect(func() -> void: get_tree().quit())
	bar.add_child(btn_close)
	var btn_bgm := SkirmishTileTextures.styled_button("BGM")
	btn_bgm.pressed.connect(_try_play_bgm)
	bar.add_child(btn_bgm)
	var btn_panel := SkirmishTileTextures.styled_button("切换面板图")
	btn_panel.pressed.connect(_cycle_panel_skin)
	bar.add_child(btn_panel)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()


func _load_map_data() -> void:
	_terrain_at.clear()
	_cities = []
	var terrain_cfg: Dictionary = DataManager.get_big_map_terrain_config()
	if terrain_cfg.is_empty():
		terrain_cfg = {"map_width": 100, "map_height": 70, "rows": []}
	var rows: Array = terrain_cfg.get("rows", [])
	var all_cities: Array = DataManager.get_all_cities()
	# 取地图中心附近窗口（默认咸阳附近）
	var focus := Vector2i(22, 44)
	for c in all_cities:
		if str(c.get("id", "")) == "xianyang":
			focus = Vector2i(int(c.get("hex_q", 22)), int(c.get("hex_r", 44)))
	var q0: int = clampi(focus.x - VIEW_W / 2, 0, maxi(0, int(terrain_cfg.get("map_width", 100)) - VIEW_W))
	var r0: int = clampi(focus.y - VIEW_H / 2, 0, maxi(0, int(terrain_cfg.get("map_height", 70)) - VIEW_H))
	for r in range(r0, r0 + VIEW_H):
		for q in range(q0, q0 + VIEW_W):
			var tid := "plains"
			if r < rows.size() and q < (rows[r] as Array).size():
				tid = str((rows[r] as Array)[q])
			_terrain_at[Vector2i(q, r)] = tid
	for c in all_cities:
		var cq := int(c.get("hex_q", 0))
		var cr := int(c.get("hex_r", 0))
		if _terrain_at.has(Vector2i(cq, cr)):
			_cities.append(c)


func _build_resource_bar() -> void:
	for child in _resource_flow.get_children():
		child.queue_free()
	var samples := [
		{"key": "food", "label": "粮食", "value": 330},
		{"key": "gold", "label": "金钱", "value": 1200},
		{"key": "wood", "label": "木材", "value": 260},
		{"key": "iron", "label": "精铁", "value": 40},
		{"key": "horse", "label": "马匹", "value": 12},
		{"key": "craftsmen", "label": "工匠", "value": 8},
		{"key": "building_materials", "label": "建材", "value": 15},
		{"key": "troops", "label": "兵力", "value": 48},
		{"key": "population", "label": "人口", "value": 110},
		{"key": "morale", "label": "民心", "value": 62},
	]
	for s in samples:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		var tex: Texture2D = ArtCatalog.icon_texture(str(s["key"]))
		if tex != null:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.custom_minimum_size = Vector2(28, 28)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cell.add_child(tr)
		var lbl := Label.new()
		lbl.text = "%s  %d" % [str(s["label"]), int(s["value"])]
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
		cell.add_child(lbl)
		_resource_flow.add_child(cell)


var _panel_skins := ["city", "main", "event", "battle", "settings"]
var _panel_skin_i := 0


func _build_city_panel_style() -> void:
	_apply_panel_skin("city")
	_city_panel.visible = false


func _cycle_panel_skin() -> void:
	_panel_skin_i = (_panel_skin_i + 1) % _panel_skins.size()
	_apply_panel_skin(_panel_skins[_panel_skin_i])
	_city_panel.visible = true
	_city_title.text = "面板皮肤：%s" % _panel_skins[_panel_skin_i]
	_city_body.text = "使用 assets/ai_art/ui/panels/panel_*.png"


func _apply_panel_skin(key: String) -> void:
	var tex: Texture2D = ArtCatalog.panel_texture(key)
	if tex != null:
		_city_panel_tex.texture = tex
		_city_panel_tex.visible = true
	else:
		_city_panel_tex.visible = false


func _try_play_bgm() -> void:
	var path := ArtCatalog.bgm_path()
	if not ResourceLoader.exists(path):
		return
	if _bgm == null:
		_bgm = AudioStreamPlayer.new()
		_bgm.bus = "Master"
		add_child(_bgm)
	if _bgm.playing:
		return
	var stream: AudioStream = load(path)
	if stream != null:
		_bgm.stream = stream
		_bgm.volume_db = -6.0
		_bgm.play()


func _hex_center(q: int, r: int) -> Vector2:
	# flat-top 布局，与 big_map 一致的 odd-r 近似
	var x: float = _map_origin.x + HEX_R * 1.5 * float(q)
	var y: float = _map_origin.y + HEX_R * 1.7320508 * (float(r) + 0.5 * float(q & 1))
	return Vector2(x, y)


func _hex_poly(center: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(6):
		var ang := deg_to_rad(60.0 * float(i))
		pts.append(center + Vector2(cos(ang), sin(ang)) * HEX_R * 0.96)
	return pts


func _on_map_draw() -> void:
	# 先画地形（六边形裁剪贴图，与 HexMapCanvas 同思路）
	for axial in _terrain_at:
		var tid: String = _terrain_at[axial]
		var c := _hex_center(axial.x, axial.y)
		var poly := _hex_poly(c)
		var tex: Texture2D = ArtCatalog.terrain_texture(tid)
		if tex != null:
			var uvs := _hex_uvs(poly)
			var colors := PackedColorArray()
			colors.resize(poly.size())
			colors.fill(Color.WHITE)
			_map_layer.draw_polygon(poly, colors, uvs, tex)
		else:
			_map_layer.draw_colored_polygon(poly, SkirmishTileTextures.terrain_fallback_color(tid))
		_map_layer.draw_polyline(poly, Color(0.05, 0.04, 0.03, 0.45), 1.2)
		if axial == _hover_axial:
			_map_layer.draw_colored_polygon(poly, Color(1.0, 0.92, 0.35, 0.35))
			if _highlight_tex != null:
				var hb := _poly_bounds(poly)
				_map_layer.draw_texture_rect(_highlight_tex, hb.grow(1), false, Color(1, 1, 1, 0.55))
	# 城市图标叠在地形上
	for city in _cities:
		var cq := int(city.get("hex_q", 0))
		var cr := int(city.get("hex_r", 0))
		var ax := Vector2i(cq, cr)
		if not _terrain_at.has(ax):
			continue
		var center := _hex_center(cq, cr)
		var fid := str(city.get("faction_id", "neutral"))
		var is_cap := bool(city.get("is_capital", false))
		var ctex: Texture2D = ArtCatalog.city_texture(str(city.get("id", "")), fid, is_cap)
		var size := HEX_R * (1.45 if is_cap else 1.05)
		if ctex != null:
			var rect := Rect2(center.x - size, center.y - size * 0.95, size * 2.0, size * 1.75)
			_map_layer.draw_texture_rect(ctex, rect, false)
		else:
			_map_layer.draw_circle(center, size * 0.32, _faction_color(fid))
		var font := ThemeDB.fallback_font
		var label_pos := center + Vector2(0, size * 0.78)
		_map_layer.draw_string_outline(font, label_pos, str(city.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, -1, 13, 3, Color(0, 0, 0, 0.85))
		_map_layer.draw_string(font, label_pos, str(city.get("name", "")), HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(1, 0.95, 0.8))


func _hex_uvs(poly: PackedVector2Array) -> PackedVector2Array:
	# 用多边形 AABB 映射到 0..1，贴图填满六边形
	var bounds := _poly_bounds(poly)
	var uvs := PackedVector2Array()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		for i in range(poly.size()):
			uvs.append(Vector2.ZERO)
		return uvs
	for p in poly:
		uvs.append(Vector2(
			(p.x - bounds.position.x) / bounds.size.x,
			(p.y - bounds.position.y) / bounds.size.y
		))
	return uvs


func _poly_bounds(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var min_v := poly[0]
	var max_v := poly[0]
	for p in poly:
		min_v = Vector2(minf(min_v.x, p.x), minf(min_v.y, p.y))
		max_v = Vector2(maxf(max_v.x, p.x), maxf(max_v.y, p.y))
	return Rect2(min_v, max_v - min_v)


func _faction_color(fid: String) -> Color:
	var f: Dictionary = DataManager.get_faction(fid) if DataManager.has_method("get_faction") else {}
	if not f.is_empty() and f.has("color"):
		return Color.html(str(f["color"]))
	return Color(0.6, 0.55, 0.4)


func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var local: Vector2 = _map_layer.get_local_mouse_position()
		var ax := _pick_axial(local)
		if ax != _hover_axial:
			_hover_axial = ax
			_hover_label.text = _hover_text(ax)
			_map_layer.queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local2: Vector2 = _map_layer.get_local_mouse_position()
		var ax2 := _pick_axial(local2)
		var city := _city_at(ax2)
		if not city.is_empty():
			_selected_city = city
			_show_city_panel(city)
			_map_layer.queue_redraw()


func _pick_axial(local: Vector2) -> Vector2i:
	var best := Vector2i(-999, -999)
	var best_d := 1e9
	for axial in _terrain_at:
		var d: float = local.distance_to(_hex_center(axial.x, axial.y))
		if d < best_d:
			best_d = d
			best = axial
	if best_d > HEX_R * 1.2:
		return Vector2i(-999, -999)
	return best


func _city_at(axial: Vector2i) -> Dictionary:
	for city in _cities:
		if int(city.get("hex_q", -1)) == axial.x and int(city.get("hex_r", -1)) == axial.y:
			return city
	return {}


func _hover_text(axial: Vector2i) -> String:
	if axial.x < -1000:
		return "悬停六边形查看地形 / 城市"
	var tid: String = _terrain_at.get(axial, "")
	var tdata: Dictionary = DataManager.get_terrain(tid) if DataManager.has_method("get_terrain") else {}
	var city := _city_at(axial)
	var tname := str(tdata.get("name", tid)) if not tdata.is_empty() else tid
	if city.is_empty():
		return "格 (%d,%d)  地形：%s  移耗：%s" % [axial.x, axial.y, tname, str(tdata.get("move_cost", "-"))]
	return "城市：%s（%s）  地形：%s  点击查看详情" % [
		str(city.get("name", "")),
		str(city.get("faction_id", "")),
		tname,
	]


func _show_city_panel(city: Dictionary) -> void:
	_apply_panel_skin("city")
	_city_panel.visible = true
	var fid := str(city.get("faction_id", "neutral"))
	_city_title.text = "%s  ·  %s" % [str(city.get("name", "")), fid]
	var lines: PackedStringArray = []
	lines.append("ID: %s" % str(city.get("id", "")))
	lines.append("坐标: (%s, %s)" % [str(city.get("hex_q", "")), str(city.get("hex_r", ""))])
	lines.append("等级: %s  人口: %s" % [str(city.get("city_level", "")), str(city.get("initial_population", city.get("base_population", "")))])
	if bool(city.get("is_capital", false)):
		lines.append("【首都】")
	var art: Texture2D = ArtCatalog.city_texture(str(city.get("id", "")), fid, bool(city.get("is_capital", false)))
	lines.append("图标: %s" % ("ai_art 已加载" if art != null else "缺图，使用色块"))
	_city_body.text = "\n".join(lines)
