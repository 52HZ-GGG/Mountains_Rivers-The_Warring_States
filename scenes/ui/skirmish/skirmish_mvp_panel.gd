extends CanvasLayer

## 阶段1战术演武 UI：odd-R 矩形蜂巢密铺（JSON 列/行 → 轴向寻路）+ 地形/兵种贴图 + 悬停信息栏
## 选中己方单位后：可走格移动，或直接点击射程内敌军攻击（无需切换模式）

## 六角外接圆半径基准（像素）；实际半径按战术区可用尺寸换算，使蜂巢棋盘尽量大、看得清
const _HEX_RADIUS_BASE_PX: float = 60.0
## 棋盘外沿留白（像素）；过小易导致裁切，过大浪费可视面积
const _HEX_BOARD_PAD_PX: float = 8.0
## 递增后下次打开面板会重建六角格（修正布局/绘制逻辑后避免沿用旧节点）
const _HEX_BOARD_LAYOUT_VERSION: int = 11

const _HexAxial := preload("res://scripts/systems/hex_axial.gd")

const _CLR_EMPTY_REACH: Color = Color(0.72, 1.0, 0.90)
const _CLR_PLAYER_UNIT: Color = Color(0.88, 0.93, 1.0)
const _CLR_ENEMY_UNIT: Color = Color(1.0, 0.88, 0.88)
const _CLR_ATTACKABLE: Color = Color(1.0, 0.78, 0.58)
const _CLR_SELECTED: Color = Color(1.0, 0.96, 0.62)
const _CLR_PLAYER_CITY: Color = Color(0.9, 0.93, 1.0)
const _CLR_ENEMY_CITY: Color = Color(1.0, 0.9, 0.9)

@onready var _hex_board: Control = %HexBoard
@onready var _log_view: RichTextLabel = %SkirmishLog
@onready var _hint: Label = %HintLabel
@onready var _hover_info: Label = %HexHoverInfo
@onready var _retreat_btn: Button = %RetreatBtn
@onready var _season_label: Label = %SeasonLabel

var _selected_unit_id: String = ""
var _reachable: Dictionary = {}
var _hex_refit_pending: bool = false


func _ready() -> void:
	visible = false
	$MarginContainer/MainVBox/ButtonRow/EndTurnBtn.pressed.connect(_on_end_turn_pressed)
	$MarginContainer/MainVBox/ButtonRow/RestartBtn.pressed.connect(_on_restart_pressed)
	_retreat_btn.pressed.connect(_on_retreat_pressed)
	$MarginContainer/MainVBox/ButtonRow/CloseBtn.pressed.connect(_on_close_pressed)
	TacticalSkirmishManager.skirmish_ended.connect(_on_skirmish_ended_unified)
	TacticalSkirmishManager.state_changed.connect(_refresh_display)
	TacticalSkirmishManager.log_appended.connect(_on_mgr_log)


func open_panel() -> void:
	print("[SkirmishPanel] open_panel 开始")
	show()
	_hex_board.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ensure_hex_buttons()
	print("[SkirmishPanel] hex buttons 创建完成")
	_ensure_board_backdrop()
	if not TacticalSkirmishManager.is_active():
		TacticalSkirmishManager.start_skirmish()
	_selected_unit_id = ""
	_reachable.clear()
	_log_view.clear()
	var atk_hint: int = TacticalSkirmishManager.get_attack_move_cost()
	_hint.text = "点选己方单位：绿格可移动；攻击需额外移动力 %d。移动后若仍可攻击会保持选中，再点本单位可待命结束。" % atk_hint
	_update_season_label()
	_hover_info.text = _default_hover_text()
	_refresh_display()
	print("[SkirmishPanel] open_panel 完成")
	_hex_refit_pending = true
	call_deferred("_deferred_refit_hex_radius_if_needed")


func close_panel() -> void:
	TacticalSkirmishManager.reset_skirmish()
	visible = false


func _default_hover_text() -> String:
	return "将鼠标移到格子上：显示地形效果、据点归属与单位信息。"


func _on_close_pressed() -> void:
	close_panel()


func _on_retreat_pressed() -> void:
	if not TacticalSkirmishManager.is_active():
		return
	if _selected_unit_id.is_empty():
		_hint.text = "请先选中一个己方单位再撤退。"
		return
	var res: Dictionary = TacticalSkirmishManager.try_retreat(_selected_unit_id)
	if bool(res.get("ok", false)):
		_hint.text = "%s 已撤退。" % _selected_unit_id
	else:
		_hint.text = "撤退失败：%s" % str(res.get("reason", "未知原因"))
	_selected_unit_id = ""
	_reachable.clear()
	_refresh_display()


func _update_season_label() -> void:
	var season: String = TacticalSkirmishManager.get_current_season()
	var names: Dictionary = {"spring": "春", "summer": "夏", "autumn": "秋", "winter": "冬"}
	_season_label.text = "季节：%s" % names.get(season, season)


func _on_restart_pressed() -> void:
	TacticalSkirmishManager.reset_skirmish()
	TacticalSkirmishManager.start_skirmish()
	_selected_unit_id = ""
	_reachable.clear()
	_log_view.clear()
	_hover_info.text = _default_hover_text()
	_refresh_display()


func _on_end_turn_pressed() -> void:
	if TacticalSkirmishManager.is_active():
		TacticalSkirmishManager.end_player_turn()
	_refresh_display()


func _ensure_hex_buttons() -> void:
	var cfg: Dictionary = TacticalSkirmishManager.get_active_config()
	var w: int = int(cfg.get("map_width", 7))
	var h: int = int(cfg.get("map_height", 7))
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
	## 尖顶六角外包：宽 √3·R、高 2R
	var cell_w: float = radius_px * sqrt3
	var cell_h: float = radius_px * 2.0
	var min_tl_x: float = INF
	var min_tl_y: float = INF
	var max_br_x: float = -INF
	var max_br_y: float = -INF
	var row_scan: int = 0
	while row_scan < h:
		var axial_col_shift_s: int = (row_scan - (row_scan & 1)) / 2
		var col_scan: int = 0
		while col_scan < w:
			var ax_s: Vector2i = Vector2i(col_scan - axial_col_shift_s, row_scan)
			var tl_s: Vector2 = _HexAxial.axial_flat_top_cell_top_left(ax_s.x, ax_s.y, radius_px)
			min_tl_x = minf(min_tl_x, tl_s.x)
			min_tl_y = minf(min_tl_y, tl_s.y)
			max_br_x = maxf(max_br_x, tl_s.x + cell_w)
			max_br_y = maxf(max_br_y, tl_s.y + cell_h)
			col_scan += 1
		row_scan += 1
	var origin_shift: Vector2 = Vector2(min_tl_x, min_tl_y)
	var row_var: int = 0
	while row_var < h:
		var axial_col_shift: int = (row_var - (row_var & 1)) / 2
		var col_var: int = 0
		while col_var < w:
			var axial_pos: Vector2i = Vector2i(col_var - axial_col_shift, row_var)
			var tl: Vector2 = _HexAxial.axial_flat_top_cell_top_left(axial_pos.x, axial_pos.y, radius_px)
			var cell: SkirmishHexCell = SkirmishHexCell.new()
			cell.configure(axial_pos.x, axial_pos.y, radius_px, cell_w, cell_h)
			cell.set_board_bounds(w, h)
			var pos: Vector2 = tl - origin_shift + Vector2(pad, pad)
			cell.position = pos.snapped(Vector2(0.5, 0.5))
			var cap: Label = Label.new()
			cap.name = "CellCaption"
			cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cap.set_anchors_preset(Control.PRESET_FULL_RECT)
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cap.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			cap.add_theme_font_size_override("font_size", clampi(int(radius_px * 0.26), 11, 19))
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
		clampf(vp.x * 0.90 - 72.0, 560.0, 1680.0),
		clampf(vp.y * 0.62 - 140.0, 380.0, 960.0)
	)
	if ss.x >= 100.0 and ss.y >= 100.0:
		return Vector2(maxf(ss.x, from_vp.x), maxf(ss.y, from_vp.y))
	return from_vp


func _deferred_refit_hex_radius_if_needed() -> void:
	if not visible or not _hex_refit_pending:
		return
	_hex_refit_pending = false
	var cfg: Dictionary = TacticalSkirmishManager.get_active_config()
	var w: int = int(cfg.get("map_width", 7))
	var h: int = int(cfg.get("map_height", 7))
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
	var cell_w: float = radius * sqrt3
	var cell_h: float = radius * 2.0
	var min_tl_x: float = INF
	var min_tl_y: float = INF
	var max_br_x: float = -INF
	var max_br_y: float = -INF
	var row_scan: int = 0
	while row_scan < h:
		var col_scan: int = 0
		while col_scan < w:
			var tl_scan: Vector2 = _HexAxial.offset_odd_r_cell_top_left(col_scan, row_scan, radius)
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
		return _HEX_RADIUS_BASE_PX
	var avail: Vector2 = _hex_play_area_avail_px()
	var s: float = minf(avail.x / bb_unit.x, avail.y / bb_unit.y) * 0.99
	s = clampf(s, 48.0, 144.0)
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
	bg.color = Color(0.35, 0.38, 0.32, 1.0)
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


func _on_hex_mouse_enter(q: int, r: int) -> void:
	_hover_info.text = _build_hover_text(Vector2i(q, r))


func _on_hex_mouse_exit() -> void:
	_hover_info.text = _default_hover_text()


func _build_hover_text(cell: Vector2i) -> String:
	var t_id: String = TacticalSkirmishManager.terrain_at(cell)
	var tdata: Dictionary = DataManager.get_terrain(t_id)
	var t_name: String = str(tdata.get("name", t_id))
	var mc: Variant = tdata.get("move_cost", 1)
	var mc_str: String = "不可通行" if int(mc) < 0 else str(mc)
	var atk_m: float = float(tdata.get("atk_mod", 1.0))
	var def_m: float = float(tdata.get("def_mod", 1.0))
	var amb: float = float(tdata.get("ambush_chance", 0.0))
	var amb_str: String = ("伏击概率+%d%%" % int(round(amb * 100.0))) if amb > 0.001 else "无额外伏击"
	var lines: PackedStringArray = []
	lines.append("地形：%s（%s）" % [t_name, t_id])
	lines.append("移耗：%s ｜ 攻方伤害×%.2f ｜ 守方防御×%.2f ｜ %s" % [mc_str, atk_m, def_m, amb_str])
	var pc: Vector2i = TacticalSkirmishManager.get_player_city()
	var ec: Vector2i = TacticalSkirmishManager.get_enemy_city()
	if cell == pc:
		lines.append("据点：秦国目标城格（占领赵城格获胜）")
	elif cell == ec:
		lines.append("据点：赵国目标城格（占领秦城格赵方获胜）")
	var uu: Dictionary = _unit_at_cell(cell)
	if not uu.is_empty():
		var fid: String = str(uu["faction_id"])
		var fac_name: String = _faction_display_name(fid)
		var ut: Dictionary = DataManager.get_unit_type(str(uu["unit_type_id"]))
		var ut_name: String = str(ut.get("name", uu["unit_type_id"]))
		var rng: int = int(ut.get("range", 1))
		var acted: bool = bool(uu.get("acted", false))
		var act_str: String = "本回合已行动" if acted else "尚未行动"
		var spd: int = int(uu.get("speed", 3))
		var rem: int = int(uu.get("mp_remaining", spd))
		var atk_mp: int = TacticalSkirmishManager.get_attack_move_cost()
		lines.append("单位：%s · %s ｜ HP %d/%d ｜ 射程%d ｜ 移动力 %d/%d（攻击额外 %d）｜ %s" % [
			fac_name, ut_name, int(uu["hp"]), int(uu["max_hp"]), rng, rem, spd, atk_mp, act_str
		])
		var uid: String = str(uu["id"])
		var morale_val: int = TacticalSkirmishManager.get_unit_morale(uid)
		var burn_val: int = TacticalSkirmishManager.get_unit_burn(uid)
		var supplied: bool = TacticalSkirmishManager.get_unit_supply(uid)
		var status_parts: PackedStringArray = []
		status_parts.append("士气 %d" % morale_val)
		if not supplied:
			status_parts.append("断粮")
		if burn_val > 0:
			status_parts.append("烧伤(%d回合)" % burn_val)
		lines.append("状态：%s" % " | ".join(status_parts))
		if _selected_unit_id != "" and fid == TacticalSkirmishManager.get_enemy_faction():
			var can_atk: bool = TacticalSkirmishManager.list_attack_targets(_selected_unit_id).has(str(uu["id"]))
			lines.append("（当前选中己方单位）%s" % ("可攻击此目标" if can_atk else "不可攻击（射程或移动力不足）"))
	return "\n".join(lines)


func _faction_display_name(faction_id: String) -> String:
	var f: Dictionary = DataManager.get_faction(faction_id)
	if not f.is_empty():
		return str(f.get("name", faction_id))
	match faction_id:
		"qin":
			return "秦国"
		"zhao":
			return "赵国"
		_:
			return faction_id


func _on_hex_pressed(q: int, r: int) -> void:
	if not TacticalSkirmishManager.is_active():
		return
	var cell: Vector2i = Vector2i(q, r)
	var occ: Dictionary = _unit_at_cell(cell)
	# 已选中己方：优先判断攻击（点击敌军）
	if _selected_unit_id != "":
		if not occ.is_empty() and str(occ.get("faction_id", "")) == TacticalSkirmishManager.get_enemy_faction():
			var res: Dictionary = TacticalSkirmishManager.try_player_attack(_selected_unit_id, str(occ["id"]))
			if bool(res.get("ok", false)):
				_selected_unit_id = ""
				_reachable.clear()
			_refresh_display()
			return
	# 点己方单位：再点同一单位＝待命结束；否则切换选中
	if not occ.is_empty() and str(occ.get("faction_id", "")) == TacticalSkirmishManager.get_player_faction():
		if bool(occ.get("acted", false)):
			_hint.text = "该单位本回合已行动。"
			return
		if str(occ["id"]) == _selected_unit_id:
			TacticalSkirmishManager.finalize_player_unit_action(str(occ["id"]))
			_selected_unit_id = ""
			_reachable.clear()
			_hint.text = "已待命（本单位本回合结束）。"
			_refresh_display()
			return
		_selected_unit_id = str(occ["id"])
		_reachable = TacticalSkirmishManager.get_reachable_cells(_selected_unit_id)
		var ac: int = TacticalSkirmishManager.get_attack_move_cost()
		_hint.text = "已选 %s：点绿格移动；攻击需额外移动力 %d；再点本单位可待命。" % [_selected_unit_id, ac]
		_refresh_display()
		return
	# 已选中：可走空格移动；移动后若本回合未结束则保持选中
	if _selected_unit_id != "":
		if occ.is_empty() and _reachable.has(cell):
			var moving_id: String = _selected_unit_id
			var mv: Dictionary = TacticalSkirmishManager.try_move_unit(moving_id, cell)
			if bool(mv.get("ok", false)):
				var u_after: Dictionary = TacticalSkirmishManager.get_unit_by_id(moving_id)
				if not u_after.is_empty() and not bool(u_after.get("acted", false)):
					_selected_unit_id = moving_id
					_reachable = TacticalSkirmishManager.get_reachable_cells(moving_id)
					var ae: int = TacticalSkirmishManager.get_attack_move_cost()
					_hint.text = "移动后仍可行动：点橙格敌军攻击（需额外 %d 移动力）或再点本单位待命。" % ae
				else:
					_selected_unit_id = ""
					_reachable.clear()
			else:
				_selected_unit_id = ""
				_reachable.clear()
		_refresh_display()
		return


func _unit_at_cell(cell: Vector2i) -> Dictionary:
	for u: Dictionary in TacticalSkirmishManager.get_units():
		if Vector2i(int(u["q"]), int(u["r"])) == cell:
			return u
	return {}


func _is_attackable_enemy_cell(cell: Vector2i) -> bool:
	if _selected_unit_id == "":
		return false
	var occ: Dictionary = _unit_at_cell(cell)
	if occ.is_empty():
		return false
	if str(occ.get("faction_id", "")) != TacticalSkirmishManager.get_enemy_faction():
		return false
	return TacticalSkirmishManager.list_attack_targets(_selected_unit_id).has(str(occ["id"]))


func _refresh_display() -> void:
	var cfg: Dictionary = TacticalSkirmishManager.get_active_config()
	var w: int = int(cfg.get("map_width", 7))
	var h: int = int(cfg.get("map_height", 7))
	print("[SkirmishPanel] _refresh_display: w=%d h=%d active=%s" % [w, h, str(TacticalSkirmishManager.is_active())])
	var by_axial: Dictionary = {}
	var hex_count: int = 0
	for ch: Node in _hex_board.get_children():
		if ch is SkirmishHexCell:
			var hc: SkirmishHexCell = ch as SkirmishHexCell
			by_axial[Vector2i(hc.cell_q, hc.cell_r)] = hc
			hex_count += 1
	print("[SkirmishPanel] _refresh_display: hex_count=%d expected=%d" % [hex_count, w * h])
	var row_var: int = 0
	while row_var < h:
		var col_var: int = 0
		while col_var < w:
			var cell_axial: Vector2i = _HexAxial.offset_odd_r_to_axial(col_var, row_var)
			var hex_cell: SkirmishHexCell = by_axial.get(cell_axial, null) as SkirmishHexCell
			if hex_cell == null:
				push_error("SkirmishMVP: 缺少轴向格 (%d,%d) col=%d row=%d" % [cell_axial.x, cell_axial.y, col_var, row_var])
				return
			var t_id: String = TacticalSkirmishManager.terrain_at(cell_axial)
			var uu: Dictionary = _unit_at_cell(cell_axial)
			var cap: Label = hex_cell.get_node_or_null("CellCaption") as Label
			var tex: Texture2D = SkirmishTileTextures.terrain_texture(t_id)
			hex_cell.set_terrain_texture(tex)
			hex_cell.set_tint_color(_cell_tint_color(cell_axial, uu))
			var tag: String = ""
			if cell_axial == TacticalSkirmishManager.get_player_city():
				tag = "秦城"
			elif cell_axial == TacticalSkirmishManager.get_enemy_city():
				tag = "赵城"
			var line2: String = ""
			if not uu.is_empty():
				var fn: String = _faction_short(str(uu["faction_id"]))
				line2 = "%s·%s\n%d/%d" % [fn, str(uu["unit_type_id"]), int(uu["hp"]), int(uu["max_hp"])]
			var caption_text: String = ""
			if tag != "":
				caption_text = tag + ("\n" + line2 if line2 != "" else "")
			else:
				caption_text = line2
			if cap != null:
				cap.text = caption_text
			_apply_capital_badge(hex_cell, cell_axial)
			_apply_unit_overlay(hex_cell, uu)
			col_var += 1
		row_var += 1
	var map_cv: HexMapCanvas = _hex_board.get_node_or_null("HexMapCanvas") as HexMapCanvas
	if map_cv != null:
		map_cv.queue_redraw()


func _faction_short(fid: String) -> String:
	match fid:
		"qin":
			return "秦"
		"zhao":
			return "赵"
		_:
			return fid


## 半透明叠色（不乘到地形贴上），优先级：选中 > 可攻击 > 可走 > 空城 > 势力占位
func _cell_tint_color(cell: Vector2i, uu: Dictionary) -> Color:
	if not uu.is_empty() and str(uu["id"]) == _selected_unit_id:
		return Color(_CLR_SELECTED.r, _CLR_SELECTED.g, _CLR_SELECTED.b, 0.45)
	if _is_attackable_enemy_cell(cell):
		return Color(_CLR_ATTACKABLE.r, _CLR_ATTACKABLE.g, _CLR_ATTACKABLE.b, 0.4)
	if _reachable.has(cell) and uu.is_empty():
		return Color(_CLR_EMPTY_REACH.r, _CLR_EMPTY_REACH.g, _CLR_EMPTY_REACH.b, 0.38)
	if uu.is_empty():
		if cell == TacticalSkirmishManager.get_player_city():
			return Color(_CLR_PLAYER_CITY.r, _CLR_PLAYER_CITY.g, _CLR_PLAYER_CITY.b, 0.26)
		if cell == TacticalSkirmishManager.get_enemy_city():
			return Color(_CLR_ENEMY_CITY.r, _CLR_ENEMY_CITY.g, _CLR_ENEMY_CITY.b, 0.26)
	if not uu.is_empty():
		var fid: String = str(uu["faction_id"])
		if fid == TacticalSkirmishManager.get_player_faction():
			return Color(_CLR_PLAYER_UNIT.r, _CLR_PLAYER_UNIT.g, _CLR_PLAYER_UNIT.b, 0.18)
		elif fid == TacticalSkirmishManager.get_enemy_faction():
			return Color(_CLR_ENEMY_UNIT.r, _CLR_ENEMY_UNIT.g, _CLR_ENEMY_UNIT.b, 0.18)
	return Color(0, 0, 0, 0)


## 秦/赵据点亮首都美术（叠在地形与描边之间，兵牌仍压在其上）
func _apply_capital_badge(hex_cell: Control, cell: Vector2i) -> void:
	var badge: TextureRect = hex_cell.get_node_or_null("CapitalBadge") as TextureRect
	var fid: String = ""
	if cell == TacticalSkirmishManager.get_player_city():
		fid = TacticalSkirmishManager.get_player_faction()
	elif cell == TacticalSkirmishManager.get_enemy_city():
		fid = TacticalSkirmishManager.get_enemy_faction()
	if fid == "":
		if badge != null:
			badge.visible = false
		return
	var cap_tex: Texture2D = SkirmishTileTextures.capital_texture(fid)
	if cap_tex == null:
		if badge != null:
			badge.visible = false
		return
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


func _apply_unit_overlay(btn: Control, uu: Dictionary) -> void:
	var overlay: TextureRect = btn.get_node_or_null("UnitOverlay") as TextureRect
	var unit_shadow: TextureRect = btn.get_node_or_null("UnitShadow") as TextureRect
	if uu.is_empty():
		if overlay != null:
			overlay.visible = false
		if unit_shadow != null:
			unit_shadow.visible = false
		return
	if overlay == null:
		var ushadow: TextureRect = TextureRect.new()
		ushadow.name = "UnitShadow"
		ushadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ushadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ushadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ushadow.modulate = Color(0.06, 0.03, 0.02, 0.52)
		ushadow.z_index = 3
		btn.add_child(ushadow)
		overlay = TextureRect.new()
		overlay.name = "UnitOverlay"
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		overlay.z_index = 4
		btn.add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	overlay.offset_left = -42.0
	overlay.offset_top = 2.0
	overlay.offset_right = -2.0
	overlay.offset_bottom = 42.0
	var ut: Texture2D = SkirmishTileTextures.unit_texture(str(uu["unit_type_id"]))
	if ut != null:
		overlay.texture = ut
	overlay.visible = true
	unit_shadow = btn.get_node_or_null("UnitShadow") as TextureRect
	if unit_shadow != null and ut != null:
		unit_shadow.texture = ut
		unit_shadow.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		unit_shadow.offset_left = overlay.offset_left + 5.0
		unit_shadow.offset_top = overlay.offset_top + 7.0
		unit_shadow.offset_right = overlay.offset_right + 5.0
		unit_shadow.offset_bottom = overlay.offset_bottom + 7.0
		unit_shadow.visible = true
	overlay.move_to_front()


func _on_mgr_log(line: String) -> void:
	_log_view.append_text(line + "\n")


func _on_skirmish_ended_unified(_winner: String) -> void:
	pass
