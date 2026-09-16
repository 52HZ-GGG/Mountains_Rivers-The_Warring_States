extends CanvasLayer

## 大地图面板：100x70 六角地图的轻量渲染版。
## 分层：地形静态缓存 + 势力/部队覆盖层；视口裁剪，避免无变化时全图重绘。

const _HEX_RADIUS_BASE_PX: float = 120.0
const _HEX_BOARD_PAD_PX: float = 8.0
const _HEX_BOARD_LAYOUT_VERSION: int = 2
const _ZOOM_STEP: float = 0.15
const _ZOOM_MIN: float = 0.5
const _ZOOM_MAX: float = 3.0
const _BOTTOM_ACTION_PAD_PX: float = 86.0
const _HEX_FILL_BLEED_PX: float = 2.6
const _TERRAIN_UV_CROP: Rect2 = Rect2(0.04, 0.09, 0.92, 0.83)
const _DRAG_THRESHOLD_PX: float = 6.0
const _HexAxial := preload("res://scripts/systems/hex_axial.gd")
const _BigMapPoliticalControl := preload("res://scripts/systems/big_map_political_control.gd")
signal city_clicked(city_id: String)
signal map_closed
signal hub_action_requested(action: String)
signal building_placed(city_id: String, building_id: String, hex_q: int, hex_r: int)
signal building_placement_cancelled

var _city_at_axial: Dictionary = {}
var _terrain_at_axial: Dictionary = {}
var _terrain_cfg: Dictionary = {}
var _political_control_grid: Dictionary = {}
var _hex_refit_pending: bool = false
var _zoom_level: float = 1.0
var _political_mode: bool = false
var _culture_mode: bool = false
var _cell_radius_px: float = 0.0
var _cell_size: Vector2 = Vector2.ZERO
var _board_origin_shift: Vector2 = Vector2.ZERO
var _board_base_size: Vector2 = Vector2.ZERO
var _cell_payload_by_axial: Dictionary = {}
var _terrain_payload_cells: Array = []
var _terrain_layout_dirty: bool = true
var _overlay_dirty: bool = true
var _minimap_cells: Array = []
var _minimap_colors: PackedColorArray = PackedColorArray()
var _drag_armed: bool = false
var _drag_active: bool = false
var _drag_press_pos: Vector2 = Vector2.ZERO
var _city_hit_rects: Array = []
var _placement_city_id: String = ""
var _placement_building_id: String = ""
var _placement_flash_hex: Vector2i = Vector2i(-9999, -9999)
var _placement_flash_until_ms: int = 0

@onready var _hex_board: Control = %HexBoard
@onready var _hover_info: Label = %HoverInfo
@onready var _scroll: ScrollContainer = $MarginContainer/MainVBox/Scroll as ScrollContainer
@onready var _minimap: Control = $MiniMapPanel/Margin/MiniMapVBox/MiniMap as Control


func _debug_log(message: String) -> void:
	if OS.has_feature("debug"):
		print(message)


func _ready() -> void:
	SkirmishTileTextures.style_scene_button($MarginContainer/MainVBox/TitleBar/ZoomOutBtn)
	SkirmishTileTextures.style_scene_button($MarginContainer/MainVBox/TitleBar/ZoomInBtn)
	SkirmishTileTextures.style_scene_button($MarginContainer/MainVBox/TitleBar/ZoomResetBtn)
	SkirmishTileTextures.style_scene_button($MarginContainer/MainVBox/TitleBar/PoliticalBtn)
	SkirmishTileTextures.style_scene_button($MarginContainer/MainVBox/TitleBar/CultureBtn)
	SkirmishTileTextures.style_scene_button($MarginContainer/MainVBox/TitleBar/HubTechBtn)
	SkirmishTileTextures.style_scene_button($MarginContainer/MainVBox/TitleBar/HubDiplomacyBtn)
	SkirmishTileTextures.style_scene_button($MarginContainer/MainVBox/TitleBar/HubMinisterBtn)
	SkirmishTileTextures.style_scene_button($MarginContainer/MainVBox/TitleBar/HubSchoolBtn)
	SkirmishTileTextures.style_scene_button($MarginContainer/MainVBox/TitleBar/HubSaveBtn)
	SkirmishTileTextures.style_scene_button($MarginContainer/MainVBox/TitleBar/CloseBtn)
	$MarginContainer/MainVBox/TitleBar/CloseBtn.pressed.connect(_on_close_pressed)
	$MarginContainer/MainVBox/TitleBar/ZoomInBtn.pressed.connect(_on_zoom_in_pressed)
	$MarginContainer/MainVBox/TitleBar/ZoomOutBtn.pressed.connect(_on_zoom_out_pressed)
	$MarginContainer/MainVBox/TitleBar/ZoomResetBtn.pressed.connect(_on_zoom_reset_pressed)
	$MarginContainer/MainVBox/TitleBar/PoliticalBtn.pressed.connect(_on_political_toggle)
	$MarginContainer/MainVBox/TitleBar/CultureBtn.pressed.connect(_on_culture_toggle)
	$MarginContainer/MainVBox/TitleBar/HubTechBtn.pressed.connect(func() -> void: hub_action_requested.emit("tech"))
	$MarginContainer/MainVBox/TitleBar/HubDiplomacyBtn.pressed.connect(func() -> void: hub_action_requested.emit("diplomacy"))
	$MarginContainer/MainVBox/TitleBar/HubMinisterBtn.pressed.connect(func() -> void: hub_action_requested.emit("ministers"))
	$MarginContainer/MainVBox/TitleBar/HubSchoolBtn.pressed.connect(func() -> void: hub_action_requested.emit("schools"))
	$MarginContainer/MainVBox/TitleBar/HubSaveBtn.pressed.connect(func() -> void: hub_action_requested.emit("save"))
	SignalBus.city_occupied.connect(_on_city_control_changed)
	SignalBus.city_revolted.connect(_on_city_revolted)
	SignalBus.capital_relocated.connect(_on_capital_relocated)
	_minimap.connect("navigate_requested", Callable(self, "_on_minimap_navigate_requested"))
	var h_scroll: ScrollBar = _scroll.get_h_scroll_bar()
	if h_scroll != null:
		h_scroll.value_changed.connect(_on_scroll_value_changed)
	var v_scroll: ScrollBar = _scroll.get_v_scroll_bar()
	if v_scroll != null:
		v_scroll.value_changed.connect(_on_scroll_value_changed)
	_scroll.resized.connect(_on_scroll_view_resized)


func open() -> void:
	show()
	_build_terrain_lookup()
	_build_city_lookup()
	_build_political_control_grid()
	_ensure_hex_buttons()
	_ensure_board_backdrop()
	_terrain_layout_dirty = true
	_overlay_dirty = true
	_refresh_display()
	_build_city_hit_rects()
	_refresh_minimap_viewport()
	_hex_refit_pending = true
	call_deferred("_deferred_refit_hex_radius_if_needed")
	call_deferred("_update_draw_cull_rect")



func is_building_placement_mode() -> bool:
	return _placement_city_id != ""


func begin_building_placement(city_id: String, building_id: String) -> void:
	_placement_city_id = city_id
	_placement_building_id = building_id
	_overlay_dirty = true
	_refresh_overlay_display()
	focus_city(city_id)
	var bname: String = str(DataManager.get_building(building_id).get("name", building_id))
	_hover_info.text = "放置模式：点击绿色辖区格建造「%s」（右键取消）" % bname


func cancel_building_placement() -> void:
	if _placement_city_id == "":
		return
	_placement_city_id = ""
	_placement_building_id = ""
	_overlay_dirty = true
	_refresh_overlay_display()
	_hover_info.text = I18n.t("big_map.hover_hint")
	building_placement_cancelled.emit()


func _try_place_building_at(axial: Vector2i) -> void:
	if _placement_city_id == "" or _placement_building_id == "":
		print("[BigMap] place inactive")
		return
	print("[BigMap] place try city=", _placement_city_id, " bid=", _placement_building_id, " hex=", axial)
	if CityManager.start_build(_placement_city_id, _placement_building_id, axial):
		var cid: String = _placement_city_id
		var bid: String = _placement_building_id
		_placement_flash_hex = axial
		_placement_flash_until_ms = Time.get_ticks_msec() + 900
		_placement_city_id = ""
		_placement_building_id = ""
		_overlay_dirty = true
		_refresh_overlay_display()
		get_tree().create_timer(0.95).timeout.connect(func() -> void:
			_overlay_dirty = true
			_refresh_overlay_display()
		)
		building_placed.emit(cid, bid, axial.x, axial.y)
		_hover_info.text = "已在 (%d,%d) 放置建筑" % [axial.x, axial.y]
	else:
		var check: Dictionary = CityManager.can_build(_placement_city_id, _placement_building_id, axial)
		_hover_info.text = "无法放置：%s" % str(check.get("reason", ""))


func _placement_highlight_map() -> Dictionary:
	var out: Dictionary = {}
	if _placement_city_id == "":
		return out
	for cell: Vector2i in CityManager.get_jurisdiction_hexes(_placement_city_id):
		var check: Dictionary = CityManager.can_build(_placement_city_id, _placement_building_id, cell)
		if bool(check.get("allowed", false)):
			out[cell] = Color(0.25, 0.95, 0.35, 0.55)
		else:
			var reason: String = str(check.get("reason", ""))
			if reason == "HEX_OCCUPIED" or reason == "HEX_RESERVED":
				out[cell] = Color(0.9, 0.55, 0.15, 0.5)
			else:
				out[cell] = Color(0.9, 0.2, 0.2, 0.4)
	return out


func _building_category_color(category: String, disabled: bool) -> Color:
	if disabled:
		return Color(0.45, 0.45, 0.45, 0.55)
	match category:
		"defense":
			return Color(0.85, 0.25, 0.2, 0.55)
		"military":
			return Color(0.25, 0.45, 0.9, 0.5)
		"economy":
			return Color(0.25, 0.7, 0.3, 0.5)
		"politics":
			return Color(0.85, 0.7, 0.2, 0.5)
		"special":
			return Color(0.7, 0.35, 0.85, 0.5)
	return Color(0.6, 0.6, 0.5, 0.45)


func _building_mark_map() -> Dictionary:
	var out: Dictionary = {}
	for city in CityManager.get_all_city_states():
		for entry: Variant in city.get("buildings", []):
			var e: Dictionary = entry as Dictionary
			if not e.has("hex_q") or not e.has("hex_r"):
				continue
			var axial: Vector2i = Vector2i(int(e["hex_q"]), int(e["hex_r"]))
			var bid: String = str(e.get("building_id", ""))
			var bdata: Dictionary = DataManager.get_building(bid)
			var name: String = str(bdata.get("name", bid))
			var letter: String = name.substr(0, 1) if name.length() > 0 else "?"
			if bool(e.get("disabled", false)):
				letter = "×"
			out[axial] = {
				"letter": letter,
				"color": _building_category_color(str(bdata.get("category", "")), bool(e.get("disabled", false))),
				"building_id": bid,
				"category": str(bdata.get("category", "")),
			}
	return out


func focus_city(city_id: String) -> void:
	if city_id.is_empty():
		return
	call_deferred("_focus_city_deferred", city_id)


func close() -> void:
	if _placement_city_id != "":
		cancel_building_placement()
	queue_free()


func get_resource_bar_slot() -> VBoxContainer:
	return $MarginContainer/MainVBox as VBoxContainer


func _on_close_pressed() -> void:
	map_closed.emit()


func _on_zoom_in_pressed() -> void:
	_apply_zoom(_zoom_level + _ZOOM_STEP, _scroll.size * 0.5)


func _on_zoom_out_pressed() -> void:
	_apply_zoom(_zoom_level - _ZOOM_STEP, _scroll.size * 0.5)


func _on_zoom_reset_pressed() -> void:
	_apply_zoom(1.0, _scroll.size * 0.5)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _drag_active:
			# 拖拽中在覆盖层外松开：结束拖拽，避免卡死
			_end_drag()
			return
		if not mb.pressed:
			return
		var scroll_rect: Rect2 = _scroll.get_global_rect()
		if not scroll_rect.has_point(mb.position):
			return
		var local_anchor: Vector2 = mb.position - scroll_rect.position
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(_zoom_level + _ZOOM_STEP * 0.5, local_anchor)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(_zoom_level - _ZOOM_STEP * 0.5, local_anchor)
			get_viewport().set_input_as_handled()


func _apply_zoom(new_zoom: float, anchor_in_view: Vector2) -> void:
	new_zoom = clampf(new_zoom, _ZOOM_MIN, _ZOOM_MAX)
	if absf(new_zoom - _zoom_level) < 0.01:
		return
	if _hex_board == null or _board_base_size == Vector2.ZERO:
		_zoom_level = new_zoom
		_update_zoom_label()
		_apply_board_zoom_transform()
		_refresh_minimap_viewport()
		return
	var view_size: Vector2 = _scroll.size
	var clamped_anchor: Vector2 = Vector2(
		clampf(anchor_in_view.x, 0.0, maxf(view_size.x, 0.0)),
		clampf(anchor_in_view.y, 0.0, maxf(view_size.y, 0.0))
	)
	var content_anchor_before: Vector2 = Vector2(
		float(_scroll.scroll_horizontal),
		float(_scroll.scroll_vertical)
	) + clamped_anchor
	var logical_anchor_before: Vector2 = content_anchor_before / maxf(_zoom_level, 0.001)
	_zoom_level = new_zoom
	_update_zoom_label()
	_apply_board_zoom_transform()
	var board_size_after: Vector2 = _board_base_size * _zoom_level
	var target_scroll: Vector2 = logical_anchor_before * _zoom_level - clamped_anchor
	var max_scroll: Vector2 = Vector2(
		maxf(board_size_after.x - view_size.x, 0.0),
		maxf(board_size_after.y - view_size.y, 0.0)
	)
	_scroll.scroll_horizontal = int(round(clampf(target_scroll.x, 0.0, max_scroll.x)))
	_scroll.scroll_vertical = int(round(clampf(target_scroll.y, 0.0, max_scroll.y)))
	_refresh_minimap_viewport()

func _apply_board_zoom_transform() -> void:
	if _hex_board == null or _board_base_size == Vector2.ZERO:
		return
	_hex_board.custom_minimum_size = _board_base_size * _zoom_level
	for canvas_name: String in ["HexMapTerrainCanvas", "HexMapOverlayCanvas", "HexMapCanvas"]:
		var map_canvas: HexMapCanvas = _hex_board.get_node_or_null(canvas_name) as HexMapCanvas
		if map_canvas != null:
			map_canvas.scale = Vector2(_zoom_level, _zoom_level)
			map_canvas.position = Vector2.ZERO
	var overlay: Control = _hex_board.get_node_or_null("HexInputOverlay") as Control
	if overlay != null:
		overlay.scale = Vector2.ONE
		overlay.position = Vector2.ZERO
		overlay.custom_minimum_size = _board_base_size * _zoom_level
		overlay.size = _board_base_size * _zoom_level
	call_deferred("_update_draw_cull_rect")


func _update_zoom_label() -> void:
	var lbl: Label = $MarginContainer/MainVBox/TitleBar/ZoomLabel as Label
	if lbl != null:
		lbl.text = "%d%%" % int(_zoom_level * 100.0)


func _rebuild_hex_grid() -> void:
	_hex_board.set_meta("_hex_layout_v", 0)
	_ensure_hex_buttons()
	_ensure_board_backdrop()
	_terrain_layout_dirty = true
	_overlay_dirty = true
	_refresh_display()
	_build_city_hit_rects()
	_refresh_minimap_viewport()


func _on_political_toggle() -> void:
	_political_mode = not _political_mode
	if _political_mode:
		_culture_mode = false
		_refresh_runtime_political_control(false)
	_sync_map_mode_buttons()
	_update_political_legend()
	_overlay_dirty = true
	_refresh_overlay_display()


func _on_culture_toggle() -> void:
	_culture_mode = not _culture_mode
	if _culture_mode:
		_political_mode = false
	_sync_map_mode_buttons()
	_update_political_legend()
	_overlay_dirty = true
	_refresh_overlay_display()


func _sync_map_mode_buttons() -> void:
	var pbtn: Button = $MarginContainer/MainVBox/TitleBar/PoliticalBtn as Button
	if pbtn != null:
		pbtn.text = I18n.t("big_map.political_on") if _political_mode else I18n.t("big_map.political_off")
	var cbtn: Button = $MarginContainer/MainVBox/TitleBar/CultureBtn as Button
	if cbtn != null:
		cbtn.text = I18n.t("big_map.culture_on") if _culture_mode else I18n.t("big_map.culture_off")


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
	var cities: Array = CityManager.get_all_city_states()
	for city_v: Variant in cities:
		if city_v is not Dictionary:
			continue
		var city: Dictionary = city_v as Dictionary
		var axial: Vector2i = _HexAxial.offset_odd_r_to_axial(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
		_city_at_axial[axial] = city


func _build_political_control_grid() -> void:
	_political_control_grid = _BigMapPoliticalControl.build_resolved_control_grid(
		CityManager.get_all_city_states(),
		DataManager.get_big_map_control_overrides(),
		DataManager.get_big_map_size(),
		DataManager.get_big_map_political_radius_rules()
	)


func _refresh_runtime_political_control(refresh_view: bool = true) -> void:
	_build_city_lookup()
	_build_political_control_grid()
	_overlay_dirty = true
	if refresh_view and visible:
		_refresh_overlay_display()
		_update_political_legend()


func _on_city_control_changed(_city_id: String, _old_faction: String, _new_faction: String) -> void:
	_refresh_runtime_political_control()


func _on_city_revolted(_city_id: String, _old_faction: String) -> void:
	_refresh_runtime_political_control()


func _on_capital_relocated(_faction_id: String, _new_capital_id: String) -> void:
	_refresh_runtime_political_control()


func _ensure_hex_buttons() -> void:
	var w: int = int(_terrain_cfg.get("map_width", 30))
	var h: int = int(_terrain_cfg.get("map_height", 20))
	var overlay: Control = _hex_board.get_node_or_null("HexInputOverlay") as Control
	if overlay != null and int(_hex_board.get_meta("_hex_layout_v", 0)) == _HEX_BOARD_LAYOUT_VERSION:
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
	for row: int in range(h):
		for col: int in range(w):
			var tl: Vector2 = _HexAxial.offset_odd_r_flat_top_cell_top_left_rect(col, row, radius_px)
			min_tl_x = minf(min_tl_x, tl.x)
			min_tl_y = minf(min_tl_y, tl.y)
			max_br_x = maxf(max_br_x, tl.x + cell_w)
			max_br_y = maxf(max_br_y, tl.y + cell_h)
	_board_origin_shift = Vector2(min_tl_x, min_tl_y)
	_cell_radius_px = radius_px
	_cell_size = Vector2(cell_w, cell_h)
	var board_size: Vector2 = Vector2(max_br_x - min_tl_x + pad * 2.0, max_br_y - min_tl_y + pad * 2.0)
	_board_base_size = board_size
	_hex_board.custom_minimum_size = board_size * _zoom_level
	_hex_board.set_meta("_hex_layout_v", _HEX_BOARD_LAYOUT_VERSION)
	_hex_board.set_meta("_hex_radius_applied", radius_px)
	_create_hex_input_overlay(board_size)


func _create_hex_input_overlay(board_size: Vector2) -> void:
	var overlay: Control = Control.new()
	overlay.name = "HexInputOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.position = Vector2.ZERO
	overlay.custom_minimum_size = board_size * _zoom_level
	overlay.size = board_size * _zoom_level
	overlay.gui_input.connect(_on_overlay_gui_input)
	overlay.mouse_exited.connect(_on_overlay_mouse_exited)
	_hex_board.add_child(overlay)


func _hex_play_area_avail_px() -> Vector2:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var sc: Control = $MarginContainer/MainVBox/Scroll as Control
	var ss: Vector2 = sc.size
	var from_vp: Vector2 = Vector2(
		clampf(vp.x * 0.92 - 48.0, 560.0, 1920.0),
		clampf(vp.y * 0.70 - 100.0 - _BOTTOM_ACTION_PAD_PX, 340.0, 980.0)
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
		_terrain_layout_dirty = true
		_overlay_dirty = true
		_refresh_display()
		_build_city_hit_rects()
		_refresh_minimap_viewport()


func _map_bbox_unit(w: int, h: int, pad: float, radius: float) -> Vector2:
	var sqrt3: float = sqrt(3.0)
	var cell_w: float = radius * 2.0
	var cell_h: float = radius * sqrt3
	var min_tl_x: float = INF
	var min_tl_y: float = INF
	var max_br_x: float = -INF
	var max_br_y: float = -INF
	for row: int in range(h):
		for col: int in range(w):
			var tl: Vector2 = _HexAxial.offset_odd_r_flat_top_cell_top_left_rect(col, row, radius)
			min_tl_x = minf(min_tl_x, tl.x)
			min_tl_y = minf(min_tl_y, tl.y)
			max_br_x = maxf(max_br_x, tl.x + cell_w)
			max_br_y = maxf(max_br_y, tl.y + cell_h)
	return Vector2(max_br_x - min_tl_x + pad * 2.0, max_br_y - min_tl_y + pad * 2.0)


func _compute_hex_radius_px(w: int, h: int, pad: float) -> float:
	var bb_unit: Vector2 = _map_bbox_unit(w, h, pad, 1.0)
	if bb_unit.x < 1.0 or bb_unit.y < 1.0:
		return _HEX_RADIUS_BASE_PX
	var avail: Vector2 = _hex_play_area_avail_px()
	var scale: float = minf(avail.x / bb_unit.x, avail.y / bb_unit.y) * 0.99
	scale = clampf(scale, 60.0, 220.0)
	return scale


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
	bg.color = Color(0.50, 0.55, 0.45, 1.0)
	# 兼容旧节点名：若仍是单画布则移除，改建分层画布
	var legacy: Node = _hex_board.get_node_or_null("HexMapCanvas")
	if legacy != null:
		legacy.free()
	_ensure_hex_layer_canvas("HexMapTerrainCanvas", HexMapCanvas.LAYER_TERRAIN, -40)
	_ensure_hex_layer_canvas("HexMapOverlayCanvas", HexMapCanvas.LAYER_OVERLAY, -30)


func _ensure_hex_layer_canvas(canvas_name: String, layers: int, z: int) -> void:
	var cv: HexMapCanvas = _hex_board.get_node_or_null(canvas_name) as HexMapCanvas
	if cv == null:
		cv = HexMapCanvas.new()
		cv.name = canvas_name
		_hex_board.add_child(cv)
	cv.z_index = z
	cv.set_draw_layers(layers)
	cv.set_cull_enabled(true)
	var backdrop: Node = _hex_board.get_node_or_null("BoardBackdrop")
	if backdrop != null:
		var backdrop_index: int = backdrop.get_index()
		if cv.get_index() < backdrop_index:
			_hex_board.move_child(cv, backdrop_index + 1)
	cv.scale = Vector2(_zoom_level, _zoom_level)
	cv.queue_redraw()


func _iter_map_cells() -> Array:
	var w: int = int(_terrain_cfg.get("map_width", 30))
	var h: int = int(_terrain_cfg.get("map_height", 20))
	var caption_font_size: int = clampi(int(_cell_radius_px * 0.35), 8, 14)
	var cells: Array = []
	for row: int in range(h):
		var axial_col_shift: int = (row - (row & 1)) / 2
		for col: int in range(w):
			var cell_axial: Vector2i = Vector2i(col - axial_col_shift, row)
			var cell_pos: Vector2 = _cell_top_left(cell_axial)
			cells.append({
				"axial": cell_axial,
				"pos": cell_pos,
				"polygon": _world_hex_polygon(cell_pos),
				"caption_font_size": caption_font_size,
			})
	return cells


func _build_terrain_payload_cells(layout_cells: Array) -> Array:
	var payload_cells: Array = []
	_cell_payload_by_axial.clear()
	for entry: Dictionary in layout_cells:
		var cell_axial: Vector2i = entry["axial"] as Vector2i
		var cell_pos: Vector2 = entry["pos"] as Vector2
		payload_cells.append({
			"polygon": entry["polygon"],
			"uvs": _world_hex_uvs(),
			"texture": SkirmishTileTextures.terrain_texture(str(_terrain_at_axial.get(cell_axial, "plains"))),
			"fallback_color": SkirmishTileTextures.terrain_fallback_color(str(_terrain_at_axial.get(cell_axial, "plains"))),
			"tint": Color(0, 0, 0, 0),
			"caption": "",
			"caption_center": cell_pos + _cell_size * 0.5,
			"caption_font_size": entry["caption_font_size"],
			"capital_texture": null,
			"capital_rect": Rect2(),
			"unit_texture": null,
			"unit_rect": Rect2(),
		})
		_cell_payload_by_axial[cell_axial] = {
			"polygon": entry["polygon"],
		}
	return payload_cells


func _apply_overlay_to_terrain_payload() -> void:
	var selected_id: String = StrategicMapManager.get_selected_unit_id()
	var reachable: Dictionary = {}
	if selected_id != "":
		reachable = StrategicMapManager.get_reachable_cells(selected_id)
	var placement_cells: Dictionary = _placement_highlight_map()
	var building_marks: Dictionary = _building_mark_map()
	for i: int in range(_terrain_payload_cells.size()):
		var payload: Dictionary = _terrain_payload_cells[i] as Dictionary
		# 用 caption_center 反推 axial 不可靠；按顺序与 _iter_map_cells 一致
		# 通过 polygon 中心匹配太慢，改为在 build 时缓存 axial
		var cell_axial: Vector2i = payload.get("_axial", Vector2i(-99999, -99999)) as Vector2i
		if cell_axial.x <= -99999:
			continue
		var city: Dictionary = _city_at_axial.get(cell_axial, {}) as Dictionary
		var unit: Dictionary = StrategicMapManager.get_unit_at_axial(cell_axial)
		var caption: String = str(city.get("name", "")) if not city.is_empty() else ""
		if not city.is_empty():
			var built_count: int = (city.get("buildings", []) as Array).size()
			var queue_count: int = (city.get("build_queue", []) as Array).size()
			if built_count > 0 or queue_count > 0:
				var b_tag: String = I18n.t("big_map.build_tag") % built_count
				if queue_count > 0:
					b_tag += "+%d" % queue_count
				caption = "%s\n%s" % [caption, b_tag]
		if not unit.is_empty():
			var unit_name: String = str(DataManager.get_unit_type(str(unit.get("unit_type_id", ""))).get("name", unit.get("unit_type_id", "")))
			var unit_tag: String = "%s×%s" % [unit_name, str(unit.get("count", 1))]
			caption = unit_tag if caption.is_empty() else "%s\n%s" % [caption, unit_tag]
		if building_marks.has(cell_axial):
			var letter: String = str((building_marks[cell_axial] as Dictionary).get("letter", ""))
			if letter != "":
				caption = letter if caption.is_empty() else "%s\n%s" % [caption, letter]
		var tint: Color = _cell_tint(cell_axial, city)
		if building_marks.has(cell_axial):
			tint = (building_marks[cell_axial] as Dictionary).get("color", tint) as Color
		if reachable.has(cell_axial):
			tint = Color(0.35, 0.75, 1.0, 0.35)
		if placement_cells.has(cell_axial):
			tint = placement_cells[cell_axial] as Color
		if _placement_flash_hex == cell_axial and Time.get_ticks_msec() < _placement_flash_until_ms:
			tint = Color(0.3, 1.0, 0.4, 0.7)
		payload["tint"] = tint
		payload["caption"] = caption
		payload["capital_texture"] = _capital_texture(city)
		payload["capital_rect"] = _capital_rect(payload.get("caption_center", Vector2.ZERO) as Vector2 - _cell_size * 0.5)
		payload["unit_texture"] = _unit_texture(unit)
		payload["unit_rect"] = _unit_rect(payload.get("caption_center", Vector2.ZERO) as Vector2 - _cell_size * 0.5)
		if building_marks.has(cell_axial):
			var bmark: Dictionary = building_marks[cell_axial] as Dictionary
			payload["building_texture"] = SkirmishTileTextures.building_texture(
				str(bmark.get("building_id", "")), str(bmark.get("category", "")))
			payload["building_rect"] = _building_rect(payload.get("caption_center", Vector2.ZERO) as Vector2 - _cell_size * 0.5)
		else:
			payload["building_texture"] = null
			payload["building_rect"] = Rect2()
		_terrain_payload_cells[i] = payload


func _refresh_display() -> void:
	var w: int = int(_terrain_cfg.get("map_width", 30))
	var h: int = int(_terrain_cfg.get("map_height", 20))
	var map_size: Vector2i = Vector2i(w, h)
	var layout_rebuilt: bool = false
	if _terrain_layout_dirty or _terrain_payload_cells.is_empty():
		var layout_cells: Array = _iter_map_cells()
		_terrain_payload_cells = _build_terrain_payload_cells(layout_cells)
		for i: int in range(layout_cells.size()):
			var payload: Dictionary = _terrain_payload_cells[i] as Dictionary
			payload["_axial"] = layout_cells[i]["axial"]
			_terrain_payload_cells[i] = payload
		_terrain_layout_dirty = false
		_overlay_dirty = true
		layout_rebuilt = true
	if _overlay_dirty:
		_apply_overlay_to_terrain_payload()
		_overlay_dirty = false
	var board_size: Vector2 = _hex_board.custom_minimum_size
	if layout_rebuilt:
		var terrain_cv: HexMapCanvas = _hex_board.get_node_or_null("HexMapTerrainCanvas") as HexMapCanvas
		if terrain_cv != null:
			terrain_cv.set_payload_cells(_terrain_payload_cells, board_size)
	var overlay_cv: HexMapCanvas = _hex_board.get_node_or_null("HexMapOverlayCanvas") as HexMapCanvas
	if overlay_cv != null:
		overlay_cv.set_payload_cells(_terrain_payload_cells, board_size)
	_rebuild_minimap_data(map_size)
	_refresh_minimap_viewport()
	call_deferred("_update_draw_cull_rect")


func _refresh_overlay_display() -> void:
	if _terrain_payload_cells.is_empty():
		_terrain_layout_dirty = true
		_refresh_display()
		return
	_apply_overlay_to_terrain_payload()
	_overlay_dirty = false
	var board_size: Vector2 = _hex_board.custom_minimum_size
	var overlay_cv: HexMapCanvas = _hex_board.get_node_or_null("HexMapOverlayCanvas") as HexMapCanvas
	if overlay_cv != null:
		overlay_cv.set_payload_cells(_terrain_payload_cells, board_size)
	var map_size: Vector2i = Vector2i(int(_terrain_cfg.get("map_width", 30)), int(_terrain_cfg.get("map_height", 20)))
	_rebuild_minimap_data(map_size)
	_refresh_minimap_viewport()
	call_deferred("_update_draw_cull_rect")


func _update_draw_cull_rect() -> void:
	if _scroll == null or _board_base_size == Vector2.ZERO:
		return
	var view_size: Vector2 = _scroll.size
	if view_size.x < 1.0 or view_size.y < 1.0:
		return
	# 裁剪矩形使用未缩放逻辑坐标
	var origin: Vector2 = Vector2(float(_scroll.scroll_horizontal), float(_scroll.scroll_vertical)) / maxf(_zoom_level, 0.001)
	var size_logical: Vector2 = view_size / maxf(_zoom_level, 0.001)
	var rect: Rect2 = Rect2(origin, size_logical)
	for canvas_name: String in ["HexMapTerrainCanvas", "HexMapOverlayCanvas"]:
		var cv: HexMapCanvas = _hex_board.get_node_or_null(canvas_name) as HexMapCanvas
		if cv != null:
			cv.set_cull_rect(rect)


func _cell_top_left(cell_axial: Vector2i) -> Vector2:
	var offset: Vector2i = _HexAxial.axial_to_offset_odd_r(cell_axial.x, cell_axial.y)
	var tl: Vector2 = _HexAxial.offset_odd_r_flat_top_cell_top_left_rect(offset.x, offset.y, _cell_radius_px)
	return tl - _board_origin_shift + Vector2(_HEX_BOARD_PAD_PX, _HEX_BOARD_PAD_PX)


func _local_hex_polygon() -> PackedVector2Array:
	var cx: float = _cell_size.x * 0.5
	var cy: float = _cell_size.y * 0.5
	var polygon: PackedVector2Array = PackedVector2Array()
	for i: int in range(6):
		var angle: float = float(i) * TAU / 6.0
		polygon.append(Vector2(cx + cos(angle) * _cell_radius_px, cy + sin(angle) * _cell_radius_px))
	return polygon


func _world_hex_polygon(cell_pos: Vector2) -> PackedVector2Array:
	var local_poly: PackedVector2Array = _local_hex_polygon()
	var center: Vector2 = _cell_size * 0.5
	var out: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in local_poly:
		var dir: Vector2 = point - center
		var dir_len: float = dir.length()
		var bleed_point: Vector2 = point
		if dir_len > 0.001:
			bleed_point += dir * (_HEX_FILL_BLEED_PX / dir_len)
		out.append(cell_pos + bleed_point)
	return out


func _world_hex_uvs() -> PackedVector2Array:
	var local_poly: PackedVector2Array = _local_hex_polygon()
	var uvs: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in local_poly:
		var uv: Vector2 = Vector2(point.x / _cell_size.x, point.y / _cell_size.y)
		uvs.append(Vector2(
			_TERRAIN_UV_CROP.position.x + uv.x * _TERRAIN_UV_CROP.size.x,
			_TERRAIN_UV_CROP.position.y + uv.y * _TERRAIN_UV_CROP.size.y
		))
	return uvs


func _cell_tint(cell: Vector2i, city: Dictionary) -> Color:
	if _political_mode:
		return _political_tint(cell, city)
	if _culture_mode:
		return _culture_tint(cell, city)
	if city.is_empty():
		return Color(0, 0, 0, 0)
	var fid: String = str(city.get("current_faction_id", city.get("faction_id", "neutral")))
	return _city_tint_color(fid, bool(city.get("is_capital", false)))


func _culture_tint(_cell: Vector2i, city: Dictionary) -> Color:
	if city.is_empty():
		return Color(0, 0, 0, 0)
	var city_id: String = str(city.get("id", ""))
	if city_id.is_empty():
		return Color(0, 0, 0, 0)
	var mainstream: String = CityManager.get_mainstream_culture(city_id)
	if mainstream.is_empty():
		return Color(0.45, 0.45, 0.45, 0.20)
	var owner: String = str(CityManager.get_city_state(city_id).get("current_faction_id", city.get("current_faction_id", "neutral")))
	var mismatch: bool = mainstream != owner
	var fdata: Dictionary = DataManager.get_faction(mainstream)
	if fdata.is_empty():
		return Color(0.45, 0.45, 0.45, 0.25)
	var color: Color = Color.html(str(fdata.get("color", "#888888")))
	color.a = 0.78 if mismatch else 0.48
	return color


func _political_tint(cell: Vector2i, city: Dictionary) -> Color:
	var fid: String = str(_political_control_grid.get(cell, ""))
	if fid == "" and not city.is_empty():
		fid = str(city.get("current_faction_id", city.get("faction_id", "neutral")))
	var is_capital: bool = not city.is_empty() and bool(city.get("is_capital", false))
	var fdata: Dictionary = DataManager.get_faction(fid) if fid != "neutral" else {}
	if fdata.is_empty():
		return Color(0.42, 0.42, 0.42, 0.62)
	var color: Color = Color.html(str(fdata.get("color", "#888888")))
	color.a = 0.85 if is_capital else 0.7
	return color


func _city_tint_color(faction_id: String, is_capital: bool) -> Color:
	if faction_id == "neutral":
		return Color(0.5, 0.5, 0.5, 0.25)
	var fdata: Dictionary = DataManager.get_faction(faction_id)
	if fdata.is_empty():
		return Color(0.5, 0.5, 0.5, 0.25)
	var color: Color = Color.html(str(fdata.get("color", "#888888")))
	color.a = 0.45 if is_capital else 0.30
	return color


func _capital_texture(city: Dictionary) -> Texture2D:
	if city.is_empty() or not bool(city.get("is_capital", false)):
		return null
	var fid: String = str(city.get("current_faction_id", city.get("faction_id", "")))
	return SkirmishTileTextures.capital_texture(fid)


func _capital_rect(cell_pos: Vector2) -> Rect2:
	var size_px: float = minf(_cell_size.x, _cell_size.y) * 0.4
	var center: Vector2 = cell_pos + _cell_size * 0.5
	return Rect2(center.x - size_px, center.y - size_px * 0.88, size_px * 2.0, size_px * 1.76)


func _unit_texture(unit: Dictionary) -> Texture2D:
	if unit.is_empty():
		return null
	return SkirmishTileTextures.unit_texture(str(unit.get("unit_type_id", "")))


func _building_rect(cell_pos: Vector2) -> Rect2:
	var size_px: float = minf(_cell_size.x, _cell_size.y) * 0.55
	var center: Vector2 = cell_pos + _cell_size * 0.5
	return Rect2(center.x - size_px * 0.5, center.y - size_px * 0.35, size_px, size_px)


func _unit_rect(cell_pos: Vector2) -> Rect2:
	var size_px: float = minf(_cell_size.x, _cell_size.y) * 0.42
	var center: Vector2 = cell_pos + _cell_size * 0.5
	return Rect2(center.x - size_px * 0.5, center.y - size_px * 0.5, size_px, size_px)


func _rebuild_minimap_data(map_size: Vector2i) -> void:
	var markers: Array = []
	_minimap_cells.clear()
	_minimap_colors = PackedColorArray()
	var board_size: Vector2 = _board_base_size if _board_base_size != Vector2.ZERO else Vector2(float(map_size.x), float(map_size.y))
	for row: int in range(map_size.y):
		var axial_col_shift: int = (row - (row & 1)) / 2
		for col: int in range(map_size.x):
			var cell_axial: Vector2i = Vector2i(col - axial_col_shift, row)
			var city: Dictionary = _city_at_axial.get(cell_axial, {}) as Dictionary
			var cell_pos: Vector2 = _cell_top_left(cell_axial)
			var cell_rect: Rect2 = Rect2(
				Vector2(
					clampf(cell_pos.x / maxf(board_size.x, 1.0), 0.0, 1.0),
					clampf(cell_pos.y / maxf(board_size.y, 1.0), 0.0, 1.0)
				),
				Vector2(
					clampf(_cell_size.x / maxf(board_size.x, 1.0), 0.0, 1.0),
					clampf(_cell_size.y / maxf(board_size.y, 1.0), 0.0, 1.0)
				)
			)
			_minimap_cells.append(cell_rect)
			_minimap_colors.append(_minimap_color(cell_axial, city))
			if not city.is_empty():
				var fid: String = str(city.get("current_faction_id", city.get("faction_id", "neutral")))
				var marker_color: Color = (_minimap as Object).call("neutral_color") as Color
				if fid != "neutral":
					var fdata: Dictionary = DataManager.get_faction(fid)
					if not fdata.is_empty():
						marker_color = Color.html(str(fdata.get("color", "#888888")))
				var cell_center: Vector2 = cell_pos + _cell_size * 0.5
				markers.append({
					"pos": Vector2(
						clampf(cell_center.x / maxf(board_size.x, 1.0), 0.0, 1.0),
						clampf(cell_center.y / maxf(board_size.y, 1.0), 0.0, 1.0)
					),
					"color": marker_color,
					"radius": 2.3 if bool(city.get("is_capital", false)) else 1.4,
					"is_capital": bool(city.get("is_capital", false)),
				})
	(_minimap as Object).call("set_cells", _minimap_cells, _minimap_colors, map_size)
	(_minimap as Object).call("set_markers", markers)


func _minimap_color(cell: Vector2i, city: Dictionary) -> Color:
	var political: Color = _political_tint(cell, city)
	if political.a > 0.001:
		return Color(political.r, political.g, political.b, 1.0)
	var fid: String = str(_political_control_grid.get(cell, "neutral"))
	if fid == "" or fid == "neutral":
		return (_minimap as Object).call("neutral_color") as Color
	var fdata: Dictionary = DataManager.get_faction(fid)
	if fdata.is_empty():
		return (_minimap as Object).call("neutral_color") as Color
	var color: Color = Color.html(str(fdata.get("color", "#888888")))
	return Color(color.r, color.g, color.b, 1.0)


func _update_political_legend() -> void:
	var legend: VBoxContainer = $MarginContainer/MainVBox/PoliticalLegend as VBoxContainer
	if legend == null:
		return
	for child: Node in legend.get_children():
		child.queue_free()
	if not _political_mode and not _culture_mode:
		legend.visible = false
		return
	legend.visible = true
	var title: Label = Label.new()
	title.text = I18n.t("big_map.culture_legend") if _culture_mode else I18n.t("big_map.political_legend")
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	legend.add_child(title)
	if _culture_mode:
		var hint: Label = Label.new()
		hint.text = I18n.t("big_map.culture_legend_hint")
		hint.add_theme_font_size_override("font_size", 11)
		hint.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
		legend.add_child(hint)
	for faction_id: String in GameManager.FACTION_IDS:
		var fdata: Dictionary = DataManager.get_faction(faction_id)
		if fdata.is_empty():
			continue
		var row: HBoxContainer = HBoxContainer.new()
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(16, 16)
		swatch.color = Color.html(str(fdata.get("color", "#888888")))
		row.add_child(swatch)
		var label: Label = Label.new()
		if _culture_mode:
			var cov: float = CityManager.get_culture_coverage_ratio(faction_id)
			label.text = "%s %d%%" % [str(fdata.get("name", "")), int(round(cov * 100.0))]
		else:
			label.text = str(fdata.get("name", ""))
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		row.add_child(label)
		legend.add_child(row)


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _drag_armed and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if not _drag_active and motion.position.distance_to(_drag_press_pos) >= _DRAG_THRESHOLD_PX:
				_drag_active = true
				_set_map_cursor(Control.CURSOR_MOVE)
			if _drag_active:
				_pan_by(-motion.relative)
				get_viewport().set_input_as_handled()
				return
		var hit_motion: Variant = _axial_at_local_point(motion.position)
		if hit_motion is Vector2i:
			var cell_motion: Vector2i = hit_motion as Vector2i
			_on_hex_mouse_enter(cell_motion.x, cell_motion.y)
		else:
			_on_hex_mouse_exit()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and _placement_city_id != "":
			cancel_building_placement()
			get_viewport().set_input_as_handled()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		# 放置模式：按下左键立即落点
		if mb.pressed and _placement_city_id != "":
			var hit_place: Variant = _axial_at_local_point(mb.position)
			if hit_place == null:
				hit_place = _nearest_axial_at_local_point(mb.position)
			print("[BigMap] click place pos=", mb.position, " hit=", hit_place)
			if hit_place is Vector2i:
				_try_place_building_at(hit_place as Vector2i)
			get_viewport().set_input_as_handled()
			return
		if mb.pressed:
			_drag_armed = true
			_drag_active = false
			_drag_press_pos = mb.position
			get_viewport().set_input_as_handled()
			return
		var was_dragging: bool = _drag_active
		_end_drag()
		get_viewport().set_input_as_handled()
		if was_dragging:
			return
		# 固定城池触发区：优先直接进内政，不依赖六角多边形命中
		var city_id: String = _city_id_at_local_point(mb.position)
		if city_id != "":
			StrategicMapManager.clear_selection()
			city_clicked.emit(city_id)
			return
		var hit_click: Variant = _axial_at_local_point(mb.position)
		if hit_click is Vector2i:
			var cell_click: Vector2i = hit_click as Vector2i
			_on_hex_pressed(cell_click.x, cell_click.y)


func _build_city_hit_rects() -> void:
	_city_hit_rects.clear()
	if _cell_size == Vector2.ZERO:
		return
	for axial: Variant in _city_at_axial.keys():
		var cell_axial: Vector2i = axial as Vector2i
		var city: Dictionary = _city_at_axial.get(cell_axial, {}) as Dictionary
		if city.is_empty():
			continue
		var cell_pos: Vector2 = _cell_top_left(cell_axial)
		# 略大于格子，方便点中城池
		var hit_rect: Rect2 = Rect2(cell_pos, _cell_size).grow(minf(_cell_size.x, _cell_size.y) * 0.08)
		_city_hit_rects.append({
			"rect": hit_rect,
			"city_id": str(city.get("id", "")),
		})


func _city_id_at_local_point(point: Vector2) -> String:
	if _city_hit_rects.is_empty():
		return ""
	var logical_point: Vector2 = point / maxf(_zoom_level, 0.001)
	# 后建的在上层；多城重叠时取面积更小的命中
	var best_id: String = ""
	var best_area: float = INF
	for entry: Dictionary in _city_hit_rects:
		var rect: Rect2 = entry.get("rect", Rect2()) as Rect2
		if not rect.has_point(logical_point):
			continue
		var area: float = rect.size.x * rect.size.y
		if area < best_area:
			best_area = area
			best_id = str(entry.get("city_id", ""))
	return best_id


func _pan_by(delta: Vector2) -> void:
	if _scroll == null:
		return
	var board_size: Vector2 = _hex_board.custom_minimum_size if _hex_board != null else Vector2.ZERO
	var view_size: Vector2 = _scroll.size
	var max_x: float = maxf(board_size.x - view_size.x, 0.0)
	var max_y: float = maxf(board_size.y - view_size.y, 0.0)
	_scroll.scroll_horizontal = int(clampf(float(_scroll.scroll_horizontal) + delta.x, 0.0, max_x))
	_scroll.scroll_vertical = int(clampf(float(_scroll.scroll_vertical) + delta.y, 0.0, max_y))


func _end_drag() -> void:
	_drag_armed = false
	if _drag_active:
		_drag_active = false
		_set_map_cursor(Control.CURSOR_ARROW)


func _set_map_cursor(shape: Control.CursorShape) -> void:
	if _hex_board == null:
		return
	var overlay: Control = _hex_board.get_node_or_null("HexInputOverlay") as Control
	if overlay != null:
		overlay.mouse_default_cursor_shape = shape


func _on_scroll_value_changed(_value: float) -> void:
	_refresh_minimap_viewport()
	call_deferred("_update_draw_cull_rect")


func _on_scroll_view_resized() -> void:
	call_deferred("_update_draw_cull_rect")


func _refresh_minimap_viewport() -> void:
	if _scroll == null or _hex_board == null:
		return
	var board_size: Vector2 = _hex_board.custom_minimum_size
	if board_size.x <= 1.0 or board_size.y <= 1.0:
		return
	var view_size: Vector2 = _scroll.size
	var max_x: float = maxf(board_size.x - view_size.x, 1.0)
	var max_y: float = maxf(board_size.y - view_size.y, 1.0)
	var rect: Rect2 = Rect2(
		Vector2(
			clampf(float(_scroll.scroll_horizontal) / max_x, 0.0, 1.0),
			clampf(float(_scroll.scroll_vertical) / max_y, 0.0, 1.0)
		),
		Vector2(
			clampf(view_size.x / board_size.x, 0.0, 1.0),
			clampf(view_size.y / board_size.y, 0.0, 1.0)
		)
	)
	(_minimap as Object).call("set_viewport_rect", rect)


func _on_minimap_navigate_requested(normalized: Vector2) -> void:
	var board_size: Vector2 = _hex_board.custom_minimum_size
	var view_size: Vector2 = _scroll.size
	var max_x: float = maxf(board_size.x - view_size.x, 0.0)
	var max_y: float = maxf(board_size.y - view_size.y, 0.0)
	var target_x: int = int(clampf(normalized.x * board_size.x - view_size.x * 0.5, 0.0, max_x))
	var target_y: int = int(clampf(normalized.y * board_size.y - view_size.y * 0.5, 0.0, max_y))
	_scroll.scroll_horizontal = target_x
	_scroll.scroll_vertical = target_y
	_refresh_minimap_viewport()


func _focus_city_deferred(city_id: String) -> void:
	if _hex_board == null or _scroll == null:
		return
	var city: Dictionary = CityManager.get_city_state(city_id)
	if city.is_empty():
		return
	if _board_base_size == Vector2.ZERO or _cell_size == Vector2.ZERO:
		call_deferred("_focus_city_deferred", city_id)
		return
	var axial: Vector2i = _HexAxial.offset_odd_r_to_axial(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
	var logical_center: Vector2 = _cell_top_left(axial) + _cell_size * 0.5
	var board_center: Vector2 = logical_center * _zoom_level
	var view_size: Vector2 = _scroll.size
	var board_size: Vector2 = _hex_board.custom_minimum_size
	var max_scroll: Vector2 = Vector2(
		maxf(board_size.x - view_size.x, 0.0),
		maxf(board_size.y - view_size.y, 0.0)
	)
	_scroll.scroll_horizontal = int(round(clampf(board_center.x - view_size.x * 0.5, 0.0, max_scroll.x)))
	_scroll.scroll_vertical = int(round(clampf(board_center.y - view_size.y * 0.5, 0.0, max_scroll.y)))
	_refresh_minimap_viewport()


func _nearest_axial_at_local_point(point: Vector2) -> Variant:
	var logical_point: Vector2 = point / maxf(_zoom_level, 0.001)
	var best: Variant = null
	var best_d: float = INF
	for axial: Variant in _cell_payload_by_axial.keys():
		var payload: Dictionary = _cell_payload_by_axial.get(axial, {}) as Dictionary
		var poly: PackedVector2Array = payload.get("polygon", PackedVector2Array()) as PackedVector2Array
		if poly.size() < 3:
			continue
		var c: Vector2 = Vector2.ZERO
		for pt: Vector2 in poly:
			c += pt
		c /= float(poly.size())
		var d: float = c.distance_squared_to(logical_point)
		if d < best_d:
			best_d = d
			best = axial
	if best_d > pow(_cell_radius_px * 2.0 / maxf(_zoom_level, 0.001), 2.0):
		return null
	return best


func _axial_at_local_point(point: Vector2) -> Variant:
	var logical_point: Vector2 = point / maxf(_zoom_level, 0.001)
	var center_local: Vector2 = logical_point - Vector2(_HEX_BOARD_PAD_PX, _HEX_BOARD_PAD_PX) + _board_origin_shift + _cell_size * 0.5
	var candidate: Vector2i = _HexAxial.pixel_flat_top_to_axial(center_local, _cell_radius_px)
	var candidates: Array[Vector2i] = [candidate]
	for neighbor: Vector2i in _HexAxial.neighbors_hex(candidate):
		candidates.append(neighbor)
	for axial: Vector2i in candidates:
		var payload: Dictionary = _cell_payload_by_axial.get(axial, {}) as Dictionary
		if payload.is_empty():
			continue
		var polygon: PackedVector2Array = payload.get("polygon", PackedVector2Array()) as PackedVector2Array
		if polygon.size() >= 3 and Geometry2D.is_point_in_polygon(logical_point, polygon):
			return axial
	return null


func _on_hex_pressed(q: int, r: int) -> void:
	var axial: Vector2i = Vector2i(q, r)
	if _placement_city_id != "":
		_try_place_building_at(axial)
		return
	# 战略单位交互：选中己方 → 点可达格移动；点邻接敌军/敌城攻击
	var selected_id: String = StrategicMapManager.get_selected_unit_id()
	var unit_here: Dictionary = StrategicMapManager.get_unit_at_axial(axial)
	if selected_id != "":
		var selected: Dictionary = StrategicMapManager.get_unit(selected_id)
		if not selected.is_empty() and str(selected.get("faction_id", "")) == GameManager.get_player_faction():
			if not unit_here.is_empty() and str(unit_here.get("faction_id", "")) != GameManager.get_player_faction():
				StrategicMapManager.try_attack_unit(selected_id, str(unit_here.get("id", "")))
				_overlay_dirty = true
				_refresh_overlay_display()
				return
			var city: Dictionary = _city_at_axial.get(axial, {}) as Dictionary
			if not city.is_empty() and str(city.get("current_faction_id", "")) != GameManager.get_player_faction():
				StrategicMapManager.try_attack_city(selected_id, str(city.get("id", "")))
				_overlay_dirty = true
				_refresh_overlay_display()
				return
			var moved: Dictionary = StrategicMapManager.try_move_unit(selected_id, axial)
			if bool(moved.get("ok", false)):
				StrategicMapManager.clear_selection()
				_overlay_dirty = true
				_refresh_overlay_display()
				return
	# 选中己方单位
	if not unit_here.is_empty() and str(unit_here.get("faction_id", "")) == GameManager.get_player_faction():
		StrategicMapManager.select_unit(str(unit_here.get("id", "")))
		_overlay_dirty = true
		_refresh_overlay_display()
		return
	StrategicMapManager.clear_selection()
	_overlay_dirty = true
	_refresh_overlay_display()
	var city2: Dictionary = _city_at_axial.get(axial, {}) as Dictionary
	if not city2.is_empty():
		city_clicked.emit(str(city2.get("id", "")))


func _on_hex_mouse_enter(q: int, r: int) -> void:
	if _placement_city_id != "":
		var check: Dictionary = CityManager.can_build(_placement_city_id, _placement_building_id, Vector2i(q, r))
		var bname: String = str(DataManager.get_building(_placement_building_id).get("name", _placement_building_id))
		if bool(check.get("allowed", false)):
			_hover_info.text = "点击放置「%s」于 (%d,%d)" % [bname, q, r]
		else:
			_hover_info.text = "(%d,%d) 不可放置：%s" % [q, r, str(check.get("reason", ""))]
		return
	_hover_info.text = _build_hover_text(Vector2i(q, r))


func _on_overlay_mouse_exited() -> void:
	_on_hex_mouse_exit()
	if _drag_armed and not _drag_active:
		_end_drag()


func _on_hex_mouse_exit() -> void:
	_hover_info.text = I18n.t("big_map.hover_hint")


func _build_hover_text(cell: Vector2i) -> String:
	var lines: PackedStringArray = []
	var terrain_id: String = str(_terrain_at_axial.get(cell, "plains"))
	var terrain_data: Dictionary = DataManager.get_terrain(terrain_id)
	var terrain_name: String = str(terrain_data.get("name", terrain_id))
	var move_cost: Variant = terrain_data.get("move_cost", 1)
	var move_text: String = I18n.t("big_map.impassable") if int(move_cost) < 0 else str(move_cost)
	lines.append("地形：%s（%s）｜ 移耗：%s ｜ 攻×%.2f ｜ 守×%.2f" % [
		terrain_name,
		terrain_id,
		move_text,
		float(terrain_data.get("atk_mod", 1.0)),
		float(terrain_data.get("def_mod", 1.0))
	])
	var city: Dictionary = _city_at_axial.get(cell, {}) as Dictionary
	if not city.is_empty():
		var city_id: String = str(city.get("id", ""))
		var state: Dictionary = CityManager.get_city_state(city_id)
		var fid: String = str(state.get("current_faction_id", city.get("current_faction_id", city.get("faction_id", "neutral"))))
		var cap_tag: String = "（首都）" if bool(state.get("is_capital", city.get("is_capital", false))) else ""
		var special_resource: Variant = state.get("special_resource", city.get("special_resource", null))
		var special_text: String = " ｜ 特产：%s" % str(special_resource) if special_resource != null else ""
		var built_names: Array = []
		for b in state.get("buildings", []):
			var bdata: Dictionary = DataManager.get_building(str(b.get("building_id", "")))
			if not bdata.is_empty():
				built_names.append(str(bdata.get("name", b.get("building_id", ""))))
		var build_text: String = ""
		if not built_names.is_empty():
			build_text = " ｜ 建筑：%s" % "、".join(PackedStringArray(built_names))
		lines.append("城市：%s%s ｜ 势力：%s ｜ 人口：%d ｜ 城防 HP：%d%s%s" % [
			str(state.get("name", city.get("name", ""))),
			cap_tag,
			_faction_display_name(fid),
			int(state.get("current_population", city.get("base_population", 0))),
			int(state.get("current_hp", city.get("current_hp", 0))),
			special_text,
			build_text
		])
		lines.append(I18n.t("big_map.click_city"))
		var cult: Dictionary = CityManager.get_city_culture(city_id)
		if not cult.is_empty():
			var ranked: Array = []
			for fid_key in cult:
				ranked.append({"id": str(fid_key), "v": float(cult[fid_key])})
			ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a["v"]) > float(b["v"])
			)
			var total: float = 0.0
			for item in ranked:
				total += float(item["v"])
			if total > 0.0:
				var parts: PackedStringArray = PackedStringArray()
				for i in range(mini(2, ranked.size())):
					var item: Dictionary = ranked[i]
					var pct: int = int(round(float(item["v"]) / total * 100.0))
					parts.append("%s %d%%" % [_faction_display_name(str(item["id"])), pct])
				var mainstream: String = CityManager.get_mainstream_culture(city_id)
				var mismatch_tag: String = ""
				if mainstream != "" and mainstream != fid:
					mismatch_tag = " ｜ " + I18n.t("big_map.culture_mismatch")
				lines.append(I18n.t("big_map.culture_line") % [
					"、".join(parts),
					_faction_display_name(mainstream) if mainstream != "" else "-",
					mismatch_tag
				])
	var unit: Dictionary = StrategicMapManager.get_unit_at_axial(cell)
	if not unit.is_empty():
		var u_type: Dictionary = DataManager.get_unit_type(str(unit.get("unit_type_id", "")))
		lines.append("单位：%s ｜ 势力：%s ｜ HP %d/%d ｜ 移力 %d" % [
			str(u_type.get("name", unit.get("unit_type_id", ""))),
			_faction_display_name(str(unit.get("faction_id", ""))),
			int(unit.get("hp", 0)),
			int(unit.get("max_hp", 0)),
			int(unit.get("mp", 0)),
		])
	var selected_id: String = StrategicMapManager.get_selected_unit_id()
	if selected_id != "":
		var reach: Dictionary = StrategicMapManager.get_reachable_cells(selected_id)
		if reach.has(cell):
			lines.append(I18n.t("big_map.reachable") % int(reach[cell]))
	return "\n".join(lines)


func _faction_display_name(faction_id: String) -> String:
	if faction_id == "neutral":
		return I18n.t("big_map.neutral")
	var faction: Dictionary = DataManager.get_faction(faction_id)
	if not faction.is_empty():
		return str(faction.get("name", faction_id))
	return faction_id
