extends CanvasLayer

## 大地图面板：30×20 六角密铺，复用 SkirmishHexCell + HexMapCanvas 渲染栈。
## 显示 50 座城市及其势力归属，悬停查看地形/城市详情，点击城市发射信号。

const _HEX_RADIUS_BASE_PX: float = 20.0
const _HEX_BOARD_PAD_PX: float = 8.0
const _HEX_BOARD_LAYOUT_VERSION: int = 1
const _ZOOM_STEP: float = 0.15
const _ZOOM_MIN: float = 0.5
const _ZOOM_MAX: float = 3.0
const _HexAxial := preload("res://scripts/systems/hex_axial.gd")

signal city_clicked(city_id: String)

var _city_at_axial: Dictionary = {}   # Vector2i -> city Dictionary
var _terrain_at_axial: Dictionary = {} # Vector2i -> terrain_id String
var _terrain_cfg: Dictionary = {}     # big_map_terrain.json 原始数据
var _hex_refit_pending: bool = false
var _zoom_level: float = 1.0
var _political_mode: bool = false


func _ready() -> void:
	$MarginContainer/MainVBox/TitleBar/CloseBtn.pressed.connect(_on_close_pressed)
	$MarginContainer/MainVBox/TitleBar/ZoomInBtn.pressed.connect(_on_zoom_in_pressed)
	$MarginContainer/MainVBox/TitleBar/ZoomOutBtn.pressed.connect(_on_zoom_out_pressed)
	$MarginContainer/MainVBox/TitleBar/ZoomResetBtn.pressed.connect(_on_zoom_reset_pressed)
	$MarginContainer/MainVBox/TitleBar/PoliticalBtn.pressed.connect(_on_political_toggle)


func open() -> void:
	show()
	print("[BigMap] open() 开始")
	_build_terrain_lookup()
	print("[BigMap] terrain_cfg keys: %d, terrain_at_axial size: %d" % [_terrain_cfg.size(), _terrain_at_axial.size()])
	_build_city_lookup()
	print("[BigMap] city_at_axial size: %d" % [_city_at_axial.size()])
	_ensure_hex_buttons()
	print("[BigMap] hex buttons 创建完成, child count: %d" % [_hex_board.get_child_count()])
	_ensure_board_backdrop()
	_refresh_display()
	print("[BigMap] open() 完成, HexBoard size: %s, HexBoard min_size: %s" % [str(_hex_board.size), str(_hex_board.custom_minimum_size)])
	print("[BigMap] Scroll size: %s, MarginContainer size: %s" % [str($MarginContainer/MainVBox/Scroll.size), str($MarginContainer.size)])
	# 检查第一个六角格
	for ch: Node in _hex_board.get_children():
		if ch is SkirmishHexCell:
			var fc: SkirmishHexCell = ch as SkirmishHexCell
			print("[BigMap] 首个六角格: pos=%s size=%s min_size=%s q=%d r=%d" % [str(fc.position), str(fc.size), str(fc.custom_minimum_size), fc.cell_q, fc.cell_r])
			break
	_hex_refit_pending = true
	call_deferred("_deferred_refit_hex_radius_if_needed")


func close() -> void:
	queue_free()


func _on_close_pressed() -> void:
	close()


func _on_zoom_in_pressed() -> void:
	_apply_zoom(_zoom_level + _ZOOM_STEP)


func _on_zoom_out_pressed() -> void:
	_apply_zoom(_zoom_level - _ZOOM_STEP)


func _on_zoom_reset_pressed() -> void:
	_apply_zoom(1.0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.ctrl_pressed and mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_apply_zoom(_zoom_level + _ZOOM_STEP * 0.5)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_apply_zoom(_zoom_level - _ZOOM_STEP * 0.5)


func _apply_zoom(new_zoom: float) -> void:
	new_zoom = clampf(new_zoom, _ZOOM_MIN, _ZOOM_MAX)
	if absf(new_zoom - _zoom_level) < 0.01:
		return
	_zoom_level = new_zoom
	_update_zoom_label()
	_rebuild_hex_grid()


func _update_zoom_label() -> void:
	var lbl: Label = $MarginContainer/MainVBox/TitleBar/ZoomLabel as Label
	if lbl != null:
		lbl.text = "%d%%" % int(_zoom_level * 100.0)


func _rebuild_hex_grid() -> void:
	_hex_board.set_meta("_hex_layout_v", 0)
	_ensure_hex_buttons()
	_ensure_board_backdrop()
	_refresh_display()


func _on_political_toggle() -> void:
	_political_mode = not _political_mode
	var btn: Button = $MarginContainer/MainVBox/TitleBar/PoliticalBtn as Button
	if btn != null:
		btn.text = "势力图：开" if _political_mode else "势力图：关"
	_update_political_legend()
	_refresh_display()
	print("[BigMap] 政治地图: %s, 城市数量: %d" % ["开" if _political_mode else "关", _city_at_axial.size()])


# ── 数据构建 ──────────────────────────────────────────────

func _build_terrain_lookup() -> void:
	_terrain_at_axial.clear()
	var fa: FileAccess = FileAccess.open("res://data/big_map_terrain.json", FileAccess.READ)
	if fa == null:
		push_error("BigMapPanel: 无法加载 big_map_terrain.json")
		return
	var parsed: Variant = JSON.parse_string(fa.get_as_text())
	if parsed is not Dictionary:
		push_error("BigMapPanel: big_map_terrain.json 解析失败")
		return
	_terrain_cfg = parsed as Dictionary
	var rows: Array = _terrain_cfg.get("rows", []) as Array
	var map_w: int = int(_terrain_cfg.get("map_width", 30))
	var map_h: int = int(_terrain_cfg.get("map_height", 20))
	var row_i: int = 0
	while row_i < rows.size() and row_i < map_h:
		var row: Array = rows[row_i] as Array
		var col_i: int = 0
		while col_i < row.size() and col_i < map_w:
			var axial: Vector2i = _HexAxial.offset_odd_r_to_axial(col_i, row_i)
			_terrain_at_axial[axial] = str(row[col_i])
			col_i += 1
		row_i += 1


func _build_city_lookup() -> void:
	_city_at_axial.clear()
	var cities: Array = DataManager.get_all_cities()
	for c: Dictionary in cities:
		var axial: Vector2i = Vector2i(int(c["hex_q"]), int(c["hex_r"]))
		_city_at_axial[axial] = c


# ── 六角格构建（复用 skirmish 模式）────────────────────────

@onready var _hex_board: Control = %HexBoard
@onready var _hover_info: Label = %HoverInfo


func _ensure_hex_buttons() -> void:
	var w: int = int(_terrain_cfg.get("map_width", 30))
	var h: int = int(_terrain_cfg.get("map_height", 20))
	var expected_cells: int = w * h
	var existing_hex_cells: int = 0
	for ch: Node in _hex_board.get_children():
		if ch is SkirmishHexCell:
			existing_hex_cells += 1
	if (
		existing_hex_cells == expected_cells
		and int(_hex_board.get_meta("_hex_layout_v", 0)) == _HEX_BOARD_LAYOUT_VERSION
	):
		return
	while _hex_board.get_child_count() > 0:
		_hex_board.get_child(0).free()
	var pad: float = _HEX_BOARD_PAD_PX
	var radius_px: float = _compute_hex_radius_px(w, h, pad)
	var sqrt3: float = sqrt(3.0)
	var cell_w: float = radius_px * 2.0
	var cell_h: float = radius_px * sqrt3
	var min_tl_x: float = INF
	var min_tl_y: float = INF
	var max_br_x: float = -INF
	var max_br_y: float = -INF
	var row_scan: int = 0
	while row_scan < h:
		var col_scan: int = 0
		while col_scan < w:
			var tl_scan: Vector2 = _HexAxial.offset_odd_r_flat_top_cell_top_left(col_scan, row_scan, radius_px)
			min_tl_x = minf(min_tl_x, tl_scan.x)
			min_tl_y = minf(min_tl_y, tl_scan.y)
			max_br_x = maxf(max_br_x, tl_scan.x + cell_w)
			max_br_y = maxf(max_br_y, tl_scan.y + cell_h)
			col_scan += 1
		row_scan += 1
	var origin_shift: Vector2 = Vector2(min_tl_x, min_tl_y)
	var row_var: int = 0
	while row_var < h:
		var col_var: int = 0
		while col_var < w:
			var axial_pos: Vector2i = _HexAxial.offset_odd_r_to_axial(col_var, row_var)
			var top_left: Vector2 = _HexAxial.offset_odd_r_flat_top_cell_top_left(col_var, row_var, radius_px)
			var cell: SkirmishHexCell = SkirmishHexCell.new()
			cell.configure(axial_pos.x, axial_pos.y, radius_px, cell_w, cell_h)
			cell.set_board_bounds(w, h)
			var pos: Vector2 = top_left - origin_shift + Vector2(pad, pad)
			cell.position = pos.snapped(Vector2(0.5, 0.5))
			var cap: Label = Label.new()
			cap.name = "CellCaption"
			cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cap.set_anchors_preset(Control.PRESET_FULL_RECT)
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cap.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			cap.add_theme_font_size_override("font_size", clampi(int(radius_px * 0.35), 8, 14))
			cap.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			cap.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1, 1))
			cap.add_theme_constant_override("outline_size", 2)
			cap.z_index = 5
			cell.add_child(cap)
			var aq: int = axial_pos.x
			var ar: int = axial_pos.y
			cell.hex_clicked.connect(_on_hex_pressed)
			cell.mouse_entered.connect(func() -> void:
				_on_hex_mouse_enter(aq, ar)
			)
			cell.mouse_exited.connect(_on_hex_mouse_exit)
			_hex_board.add_child(cell)
			cell.notify_size_changed()
			col_var += 1
		row_var += 1
	var bb_w: float = max_br_x - min_tl_x + pad * 2.0
	var bb_h: float = max_br_y - min_tl_y + pad * 2.0
	_hex_board.custom_minimum_size = Vector2(bb_w, bb_h)
	_hex_board.set_meta("_hex_layout_v", _HEX_BOARD_LAYOUT_VERSION)
	_hex_board.set_meta("_hex_radius_applied", radius_px)


func _hex_play_area_avail_px() -> Vector2:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sc: Control = $MarginContainer/MainVBox/Scroll as Control
	var ss: Vector2 = sc.size
	var from_vp: Vector2 = Vector2(
		clampf(vp.x * 0.92 - 48.0, 560.0, 1920.0),
		clampf(vp.y * 0.70 - 100.0, 400.0, 1080.0)
	)
	if ss.x >= 100.0 and ss.y >= 100.0:
		return Vector2(maxf(ss.x, from_vp.x), maxf(ss.y, from_vp.y))
	return from_vp


func _deferred_refit_hex_radius_if_needed() -> void:
	if not visible or not _hex_refit_pending:
		return
	_hex_refit_pending = false
	var w: int = int(_terrain_cfg.get("map_width", 30))
	var h: int = int(_terrain_cfg.get("map_height", 20))
	var pad: float = _HEX_BOARD_PAD_PX
	var r_new: float = _compute_hex_radius_px(w, h, pad)
	var r_old: float = float(_hex_board.get_meta("_hex_radius_applied", -1.0))
	if r_old < 0.0 or absf(r_new - r_old) >= 1.5:
		_hex_board.set_meta("_hex_layout_v", 0)
		_ensure_hex_buttons()
		_ensure_board_backdrop()
		_refresh_display()


func _map_bbox_unit(w: int, h: int, pad: float, radius: float) -> Vector2:
	var sqrt3: float = sqrt(3.0)
	var cell_w: float = radius * 2.0
	var cell_h: float = radius * sqrt3
	var min_tl_x: float = INF
	var min_tl_y: float = INF
	var max_br_x: float = -INF
	var max_br_y: float = -INF
	var row_scan: int = 0
	while row_scan < h:
		var col_scan: int = 0
		while col_scan < w:
			var tl_scan: Vector2 = _HexAxial.offset_odd_r_flat_top_cell_top_left(col_scan, row_scan, radius)
			min_tl_x = minf(min_tl_x, tl_scan.x)
			min_tl_y = minf(min_tl_y, tl_scan.y)
			max_br_x = maxf(max_br_x, tl_scan.x + cell_w)
			max_br_y = maxf(max_br_y, tl_scan.y + cell_h)
			col_scan += 1
		row_scan += 1
	return Vector2(max_br_x - min_tl_x + pad * 2.0, max_br_y - min_tl_y + pad * 2.0)


func _compute_hex_radius_px(w: int, h: int, pad: float) -> float:
	var bb_unit: Vector2 = _map_bbox_unit(w, h, pad, 1.0)
	if bb_unit.x < 1.0 or bb_unit.y < 1.0:
		return _HEX_RADIUS_BASE_PX * _zoom_level
	var avail: Vector2 = _hex_play_area_avail_px()
	var s: float = minf(avail.x / bb_unit.x, avail.y / bb_unit.y) * 0.99
	s = clampf(s, 12.0, 60.0) * _zoom_level
	return s


func _ensure_board_backdrop() -> void:
	var bg: ColorRect = _hex_board.get_node_or_null("BoardBackdrop") as ColorRect
	if bg == null:
		bg = ColorRect.new()
		bg.name = "BoardBackdrop"
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.z_index = -100
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.offset_left = 0.0
		bg.offset_top = 0.0
		bg.offset_right = 0.0
		bg.offset_bottom = 0.0
		_hex_board.add_child(bg)
		_hex_board.move_child(bg, 0)
	bg.color = Color(0.19, 0.21, 0.18, 1.0)
	_ensure_hex_map_canvas()


func _ensure_hex_map_canvas() -> void:
	var cv: HexMapCanvas = _hex_board.get_node_or_null("HexMapCanvas") as HexMapCanvas
	if cv == null:
		cv = HexMapCanvas.new()
		cv.name = "HexMapCanvas"
		_hex_board.add_child(cv)
	var backdrop: Node = _hex_board.get_node_or_null("BoardBackdrop")
	if backdrop != null:
		var bi: int = backdrop.get_index()
		if cv.get_index() != bi + 1:
			_hex_board.move_child(cv, bi + 1)
	elif cv.get_index() != 0:
		_hex_board.move_child(cv, 0)
	cv.queue_redraw()


# ── 显示刷新 ──────────────────────────────────────────────

func _refresh_display() -> void:
	var w: int = int(_terrain_cfg.get("map_width", 30))
	var h: int = int(_terrain_cfg.get("map_height", 20))
	var by_axial: Dictionary = {}
	for ch: Node in _hex_board.get_children():
		if ch is SkirmishHexCell:
			var hc: SkirmishHexCell = ch as SkirmishHexCell
			by_axial[Vector2i(hc.cell_q, hc.cell_r)] = hc
	var row_var: int = 0
	while row_var < h:
		var col_var: int = 0
		while col_var < w:
			var cell_axial: Vector2i = _HexAxial.offset_odd_r_to_axial(col_var, row_var)
			var hex_cell: SkirmishHexCell = by_axial.get(cell_axial, null) as SkirmishHexCell
			if hex_cell == null:
				col_var += 1
				continue
			var t_id: String = str(_terrain_at_axial.get(cell_axial, "plains"))
			var tex: Texture2D = SkirmishTileTextures.terrain_texture(t_id)
			hex_cell.set_terrain_texture(tex)
			var city: Dictionary = _city_at_axial.get(cell_axial, {}) as Dictionary
			var cap: Label = hex_cell.get_node_or_null("CellCaption") as Label
			if _political_mode:
				_apply_political_cell(hex_cell, city, cap)
			elif not city.is_empty():
				var fid: String = str(city.get("faction_id", "neutral"))
				hex_cell.set_tint_color(_city_tint_color(fid, bool(city.get("is_capital", false))))
				if cap != null:
					cap.text = str(city.get("name", ""))
				_apply_capital_badge(hex_cell, city)
			else:
				hex_cell.set_tint_color(Color(0, 0, 0, 0))
				if cap != null:
					cap.text = ""
				_remove_capital_badge(hex_cell)
			col_var += 1
		row_var += 1
	var map_cv: HexMapCanvas = _hex_board.get_node_or_null("HexMapCanvas") as HexMapCanvas
	if map_cv != null:
		map_cv.queue_redraw()


func _city_tint_color(faction_id: String, is_capital: bool) -> Color:
	if faction_id == "neutral":
		return Color(0.5, 0.5, 0.5, 0.25)
	var fdata: Dictionary = DataManager.get_faction(faction_id)
	if fdata.is_empty():
		return Color(0.5, 0.5, 0.5, 0.25)
	var hex_str: String = str(fdata.get("color", "#888888"))
	var c: Color = Color.html(hex_str)
	var alpha: float = 0.45 if is_capital else 0.30
	return Color(c.r, c.g, c.b, alpha)


func _apply_political_cell(hex_cell: SkirmishHexCell, city: Dictionary, cap: Label) -> void:
	if city.is_empty():
		hex_cell.set_tint_color(Color(0.3, 0.3, 0.3, 0.6))
		if cap != null:
			cap.text = ""
		_remove_capital_badge(hex_cell)
		return
	var fid: String = str(city.get("faction_id", "neutral"))
	var is_capital: bool = bool(city.get("is_capital", false))
	var fdata: Dictionary = DataManager.get_faction(fid) if fid != "neutral" else {}
	var base_color: Color
	if fdata.is_empty():
		base_color = Color(0.5, 0.5, 0.5, 0.7)
	else:
		var hex_str: String = str(fdata.get("color", "#888888"))
		base_color = Color.html(hex_str)
		base_color.a = 0.85 if is_capital else 0.7
	hex_cell.set_tint_color(base_color)
	if cap != null:
		cap.text = str(city.get("name", ""))
	if is_capital:
		_apply_capital_badge(hex_cell, city)
	else:
		_remove_capital_badge(hex_cell)


func _update_political_legend() -> void:
	var legend: VBoxContainer = $MarginContainer/MainVBox/PoliticalLegend as VBoxContainer
	if legend == null:
		return
	for ch: Node in legend.get_children():
		ch.queue_free()
	if not _political_mode:
		legend.visible = false
		return
	legend.visible = true
	var factions: Array[Dictionary] = []
	for fid: String in GameManager.FACTION_IDS:
		var fdata: Dictionary = DataManager.get_faction(fid)
		if not fdata.is_empty():
			factions.append(fdata)
	var title: Label = Label.new()
	title.text = "势力图例"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	legend.add_child(title)
	for fdata: Dictionary in factions:
		var row: HBoxContainer = HBoxContainer.new()
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(16, 16)
		var hex_str: String = str(fdata.get("color", "#888888"))
		swatch.color = Color.html(hex_str)
		row.add_child(swatch)
		var lbl: Label = Label.new()
		lbl.text = str(fdata.get("name", ""))
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		row.add_child(lbl)
		legend.add_child(row)


# ── 首都标记 ──────────────────────────────────────────────

func _apply_capital_badge(hex_cell: Control, city: Dictionary) -> void:
	if not bool(city.get("is_capital", false)):
		_remove_capital_badge(hex_cell)
		return
	var fid: String = str(city.get("faction_id", ""))
	var cap_tex: Texture2D = SkirmishTileTextures.capital_texture(fid)
	if cap_tex == null:
		_remove_capital_badge(hex_cell)
		return
	var badge: TextureRect = hex_cell.get_node_or_null("CapitalBadge") as TextureRect
	if badge == null:
		badge = TextureRect.new()
		badge.name = "CapitalBadge"
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.z_index = 3
		hex_cell.add_child(badge)
	badge.texture = cap_tex
	badge.set_anchors_preset(Control.PRESET_CENTER)
	var s: float = minf(hex_cell.custom_minimum_size.x, hex_cell.custom_minimum_size.y) * 0.4
	badge.offset_left = -s
	badge.offset_top = -s * 0.88
	badge.offset_right = s
	badge.offset_bottom = s * 0.88
	badge.visible = true


func _remove_capital_badge(hex_cell: Control) -> void:
	var badge: TextureRect = hex_cell.get_node_or_null("CapitalBadge") as TextureRect
	if badge != null:
		badge.visible = false


# ── 交互 ──────────────────────────────────────────────────

func _on_hex_pressed(q: int, r: int) -> void:
	var axial: Vector2i = Vector2i(q, r)
	var city: Dictionary = _city_at_axial.get(axial, {}) as Dictionary
	if not city.is_empty():
		city_clicked.emit(str(city["id"]))


func _on_hex_mouse_enter(q: int, r: int) -> void:
	_hover_info.text = _build_hover_text(Vector2i(q, r))


func _on_hex_mouse_exit() -> void:
	_hover_info.text = "将鼠标移到格子上：显示地形与城市信息。"


func _build_hover_text(cell: Vector2i) -> String:
	var lines: PackedStringArray = []
	var t_id: String = str(_terrain_at_axial.get(cell, "plains"))
	var tdata: Dictionary = DataManager.get_terrain(t_id)
	var t_name: String = str(tdata.get("name", t_id))
	var mc: Variant = tdata.get("move_cost", 1)
	var mc_str: String = "不可通行" if int(mc) < 0 else str(mc)
	var atk_m: float = float(tdata.get("atk_mod", 1.0))
	var def_m: float = float(tdata.get("def_mod", 1.0))
	lines.append("地形：%s（%s）｜ 移耗：%s ｜ 攻×%.2f ｜ 守×%.2f" % [t_name, t_id, mc_str, atk_m, def_m])
	var city: Dictionary = _city_at_axial.get(cell, {}) as Dictionary
	if not city.is_empty():
		var cname: String = str(city.get("name", ""))
		var fid: String = str(city.get("faction_id", "neutral"))
		var fname: String = _faction_display_name(fid)
		var cap_tag: String = "（首都）" if bool(city.get("is_capital", false)) else ""
		var pop: int = int(city.get("base_population", 0))
		var sr: Variant = city.get("special_resource", null)
		var sr_str: String = " ｜ 特产：%s" % str(sr) if sr != null else ""
		lines.append("城市：%s%s ｜ 势力：%s ｜ 人口：%d%s" % [cname, cap_tag, fname, pop, sr_str])
	return "\n".join(lines)


func _faction_display_name(faction_id: String) -> String:
	if faction_id == "neutral":
		return "中立"
	var f: Dictionary = DataManager.get_faction(faction_id)
	if not f.is_empty():
		return str(f.get("name", faction_id))
	return faction_id
