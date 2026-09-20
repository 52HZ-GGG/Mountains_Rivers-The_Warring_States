extends Control
class_name HexMapCanvas

## 六角地图画布。
## 支持分层绘制（地形 / 覆盖层）与视口裁剪：大地图把地形当静态缓存，只在脏标记时重绘。

const _EXTRA_BLEED_SCALE: float = 1.2
const _CAPTION_COLOR: Color = Color(1, 1, 1, 1)
const _CAPTION_SHADOW_COLOR: Color = Color(0.05, 0.05, 0.10, 0.9)

const LAYER_TERRAIN: int = 1
const LAYER_OVERLAY: int = 2
const LAYER_ALL: int = LAYER_TERRAIN | LAYER_OVERLAY

## 大地图 payload 是静态缓存：拖拽只改视口；_draw 用 cull 过滤。
## 视口 col/row 窗口索引默认关闭（曾导致空图），保留实现供后续安全开启。
const _USE_RC_WINDOW_INDEX: bool = false

var _payload_cells: Array = []
var _payload_board_size: Vector2 = Vector2.ZERO
var _use_payload: bool = false
var _draw_layers: int = LAYER_ALL
var _cull_rect: Rect2 = Rect2()
var _cull_enabled: bool = false
var _content_dirty: bool = true
## 视口窗口索引：col/row → payload
var _payload_by_rc: Dictionary = {}
var _hex_radius: float = 0.0
var _board_origin_shift: Vector2 = Vector2.ZERO
var _board_pad: float = 0.0
var _rc_index_ready: bool = false
## 大地图地形层烘焙：非空时直接画整张纹理，取代逐格 draw_polygon（缩放只处理一张图）
var _baked_texture: Texture2D
var _baked_draw_size: Vector2 = Vector2.ZERO


func _scale_poly_outward(poly: PackedVector2Array, cell_pos: Vector2, cell: SkirmishHexCell) -> PackedVector2Array:
	var half_w: float = cell.custom_minimum_size.x * 0.5
	var half_h: float = cell.custom_minimum_size.y * 0.5
	var lc: Vector2 = Vector2(half_w, half_h)
	var cc: Vector2 = Vector2(cell_pos.x + half_w, cell_pos.y + half_h)
	var out: PackedVector2Array = PackedVector2Array()
	var i: int = 0
	while i < poly.size():
		var d: Vector2 = poly[i] - lc
		out.append(cc + d * _EXTRA_BLEED_SCALE)
		i += 1
	return out


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = -40
	set_anchors_preset(PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0


func _notification(what: int) -> void:
	# 仅在内容脏时响应尺寸变化；缩放走 Control.scale，不应触发全图重绘
	if what == NOTIFICATION_RESIZED and _content_dirty:
		queue_redraw()


func set_draw_layers(layers: int) -> void:
	if _draw_layers == layers:
		return
	_draw_layers = layers
	_content_dirty = true
	queue_redraw()


func set_cull_enabled(enabled: bool) -> void:
	_cull_enabled = enabled
	if not enabled:
		_content_dirty = true
		queue_redraw()


func set_cull_rect(rect: Rect2) -> void:
	if not _cull_enabled:
		return
	# 边缘预留：不要按整图尺寸百分比撑得过大，否则窗口索引会退化成全图
	var grow: float = clampf(maxf(_payload_board_size.x, _payload_board_size.y) * 0.01 + 40.0, 24.0, 96.0)
	var padded: Rect2 = rect.grow(grow)
	if _cull_rect == padded:
		return
	_cull_rect = padded
	_content_dirty = true
	queue_redraw()


func _white_vertex_colors(n: int) -> PackedColorArray:
	var colors: PackedColorArray = PackedColorArray()
	var i: int = 0
	while i < n:
		colors.append(Color.WHITE)
		i += 1
	return colors


func set_payload_cells(cells: Array, board_size: Vector2) -> void:
	_payload_cells = cells
	_payload_board_size = board_size
	_use_payload = true
	_content_dirty = true
	_rebuild_rc_index()
	queue_redraw()


## 大地图矩形 odd-R 布局元数据，供视口窗口裁剪
func set_spatial_meta(hex_radius: float, origin_shift: Vector2, pad: float) -> void:
	_hex_radius = hex_radius
	_board_origin_shift = origin_shift
	_board_pad = pad
	_rebuild_rc_index()
	queue_redraw()


func request_overlay_redraw() -> void:
	_content_dirty = true
	queue_redraw()


func _rebuild_rc_index() -> void:
	_payload_by_rc.clear()
	_rc_index_ready = false
	if _payload_cells.is_empty() or _hex_radius <= 0.01:
		return
	var has_rc: bool = false
	for payload_v: Variant in _payload_cells:
		if payload_v is not Dictionary:
			continue
		var payload: Dictionary = payload_v as Dictionary
		if not payload.has("col") or not payload.has("row"):
			continue
		_payload_by_rc[Vector2i(int(payload["col"]), int(payload["row"]))] = payload
		has_rc = true
	_rc_index_ready = has_rc


func _visible_payloads() -> Array:
	# 静态 payload + cull：始终扫列表、用 polygon AABB 过滤（稳定）
	if _USE_RC_WINDOW_INDEX and _rc_index_ready and _cull_enabled and _cull_rect.size != Vector2.ZERO and _hex_radius > 0.01:
		var windowed: Array = _payloads_in_cull_window()
		if not windowed.is_empty():
			return windowed
	return _payload_cells


## cull 矩形（棋盘逻辑坐标）→ col/row 窗口，只取视口附近格
func _payloads_in_cull_window() -> Array:
	var r: float = _hex_radius
	var sqrt3: float = sqrt(3.0)
	var pad: float = _board_pad
	var origin: Vector2 = _board_origin_shift
	# 逻辑坐标 → 未 shift 的布局像素（与 offset_odd_r_flat_top_cell_top_left_rect 一致）
	var p0: Vector2 = _cull_rect.position - Vector2(pad, pad) + origin
	var p1: Vector2 = _cull_rect.end - Vector2(pad, pad) + origin
	var col_min: int = int(floor(minf(p0.x, p1.x) / (1.5 * r))) - 2
	var col_max: int = int(ceil(maxf(p0.x, p1.x) / (1.5 * r))) + 2
	var y0: float = minf(p0.y, p1.y) / (sqrt3 * r)
	var y1: float = maxf(p0.y, p1.y) / (sqrt3 * r)
	var row_min: int = int(floor(y0 - 1.0)) - 2
	var row_max: int = int(ceil(y1 + 1.0)) + 2
	col_min = maxi(col_min, 0)
	row_min = maxi(row_min, 0)
	var out: Array = []
	for col: int in range(col_min, col_max + 1):
		for row: int in range(row_min, row_max + 1):
			var payload: Variant = _payload_by_rc.get(Vector2i(col, row), null)
			if payload != null:
				out.append(payload)
	if out.is_empty():
		return _payload_cells
	return out


func _draw_payload_cells() -> void:
	if _payload_board_size != Vector2.ZERO and size != _payload_board_size:
		size = _payload_board_size
	var font: Font = get_theme_default_font()
	var font_size_default: int = get_theme_default_font_size()
	var draw_terrain: bool = (_draw_layers & LAYER_TERRAIN) != 0
	var draw_overlay: bool = (_draw_layers & LAYER_OVERLAY) != 0
	var source: Array = _visible_payloads()
	var use_window: bool = _USE_RC_WINDOW_INDEX and source != _payload_cells
	for payload_v: Variant in source:
		if payload_v is not Dictionary:
			continue
		var payload: Dictionary = payload_v as Dictionary
		if not use_window and not _payload_visible(payload):
			continue
		var polygon: PackedVector2Array = payload.get("polygon", PackedVector2Array()) as PackedVector2Array
		if polygon.size() < 3:
			continue
		if draw_terrain:
			var tex: Texture2D = payload.get("texture", null) as Texture2D
			var uvs: PackedVector2Array = payload.get("uvs", PackedVector2Array()) as PackedVector2Array
			if tex != null and polygon.size() == uvs.size():
				draw_polygon(polygon, _white_vertex_colors(polygon.size()), uvs, tex)
				_draw_terrain_edge_blends(polygon, uvs, payload.get("edge_blends", []) as Array)
			else:
				draw_colored_polygon(polygon, payload.get("fallback_color", SkirmishHexCell.fallback_terrain_color()) as Color)
		if not draw_overlay:
			continue
		var tint: Color = payload.get("tint", Color(0, 0, 0, 0)) as Color
		if tint.a > 0.001:
			draw_colored_polygon(polygon, tint)
		var capital_rect: Rect2 = payload.get("capital_rect", Rect2()) as Rect2
		var capital_tex: Texture2D = payload.get("capital_texture", null) as Texture2D
		if capital_tex != null and capital_rect.size.x > 0.0 and capital_rect.size.y > 0.0:
			draw_texture_rect(capital_tex, capital_rect, false)
		var unit_rect: Rect2 = payload.get("unit_rect", Rect2()) as Rect2
		var unit_tex: Texture2D = payload.get("unit_texture", null) as Texture2D
		if unit_tex != null and unit_rect.size.x > 0.0 and unit_rect.size.y > 0.0:
			draw_texture_rect(unit_tex, unit_rect, false)
		elif str(payload.get("unit_caption", "")) != "":
			# 贴图缺失时仍显示编制标记，便于排查大地图单位
			var uc: Vector2 = payload.get("caption_center", Vector2.ZERO) as Vector2
			draw_circle(uc, 5.0, Color(0.92, 0.78, 0.22, 0.85))
		var building_rect: Rect2 = payload.get("building_rect", Rect2()) as Rect2
		var building_tex: Texture2D = payload.get("building_texture", null) as Texture2D
		if building_tex != null and building_rect.size.x > 0.0 and building_rect.size.y > 0.0:
			draw_texture_rect(building_tex, building_rect, false)
		var caption_text: String = str(payload.get("caption", ""))
		if caption_text.is_empty() or font == null:
			continue
		var font_size: int = int(payload.get("caption_font_size", font_size_default))
		var caption_center: Vector2 = payload.get("caption_center", Vector2.ZERO) as Vector2
		_draw_multiline_centered_caption(font, font_size, caption_center, caption_text)
	# payload 模式必须保持 _use_payload=true；绘制完成后不要 queue_redraw，避免每帧死循环重绘
	_content_dirty = false


func _draw_terrain_edge_blends(polygon: PackedVector2Array, uvs: PackedVector2Array, blends: Array) -> void:
	if blends.is_empty() or polygon.size() != 6 or uvs.size() != 6:
		return
	var center: Vector2 = Vector2.ZERO
	var uv_center: Vector2 = Vector2.ZERO
	for i: int in range(6):
		center += polygon[i]
		uv_center += uvs[i]
	center /= 6.0
	uv_center /= 6.0
	for blend_v: Variant in blends:
		var blend: Dictionary = blend_v as Dictionary
		var texture: Texture2D = blend.get("texture", null) as Texture2D
		if texture == null:
			continue
		var side: int = int(blend.get("side", 0))
		var alpha: float = float(blend.get("alpha", 0.5))
		var next_side: int = (side + 1) % 6
		var points := PackedVector2Array([
			polygon[side], polygon[next_side],
			polygon[next_side].lerp(center, 0.22), polygon[side].lerp(center, 0.22),
		])
		var edge_uvs := PackedVector2Array([
			uvs[side], uvs[next_side],
			uvs[next_side].lerp(uv_center, 0.22), uvs[side].lerp(uv_center, 0.22),
		])
		var colors := PackedColorArray([
			Color(1, 1, 1, alpha), Color(1, 1, 1, alpha),
			Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0),
		])
		draw_polygon(points, colors, edge_uvs, texture)


func _poly_aabb(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var min_v: Vector2 = poly[0]
	var max_v: Vector2 = poly[0]
	for p: Vector2 in poly:
		min_v = Vector2(minf(min_v.x, p.x), minf(min_v.y, p.y))
		max_v = Vector2(maxf(max_v.x, p.x), maxf(max_v.y, p.y))
	return Rect2(min_v, max_v - min_v)


func _payload_visible(payload: Dictionary) -> bool:
	if not _cull_enabled or _cull_rect.size == Vector2.ZERO:
		return true
	# 缓存 AABB：polygon 与 caption_center 在 payload 构建后固定不变，滚动时无需每帧重扫 6 顶点
	if not payload.has("_aabb"):
		var poly: PackedVector2Array = payload.get("polygon", PackedVector2Array()) as PackedVector2Array
		if poly.size() < 3:
			return false
		var aabb: Rect2 = _poly_aabb(poly)
		var caption_center: Vector2 = payload.get("caption_center", Vector2.ZERO) as Vector2
		if caption_center != Vector2.ZERO:
			aabb = aabb.expand(caption_center)
		payload["_aabb"] = aabb
	var aabb2: Rect2 = payload["_aabb"] as Rect2
	# cull 矩形完全在棋盘外时不要滤空
	if _payload_board_size != Vector2.ZERO:
		var board: Rect2 = Rect2(Vector2.ZERO, _payload_board_size)
		if not board.intersects(_cull_rect):
			return true
	return aabb2.intersects(_cull_rect)


func _draw() -> void:
	_content_dirty = false
	# 烘焙纹理必须有有效绘制尺寸，否则退回 payload，避免整层空白/灰底
	if _baked_texture != null and _baked_draw_size.x > 1.0 and _baked_draw_size.y > 1.0:
		# 控件尺寸对齐烘焙逻辑尺寸，否则地图边缘会被裁切掉
		if size != _baked_draw_size:
			size = _baked_draw_size
		draw_texture_rect(_baked_texture, Rect2(Vector2.ZERO, _baked_draw_size), false)
		return
	if _use_payload:
		_draw_payload_cells()
		return
	var board: Control = get_parent() as Control
	if board == null:
		return
	if size != board.size:
		size = board.size
	var list: Array[SkirmishHexCell] = []
	for ch: Node in board.get_children():
		if ch is SkirmishHexCell:
			list.append(ch as SkirmishHexCell)
	list.sort_custom(func(a: SkirmishHexCell, b: SkirmishHexCell) -> bool:
		if a.cell_r != b.cell_r:
			return a.cell_r < b.cell_r
		return a.cell_q < b.cell_q
	)
	for cell: SkirmishHexCell in list:
		var lp: PackedVector2Array = cell.get_bleed_polygon_local()
		if lp.size() < 3:
			continue
		var bp: PackedVector2Array = _scale_poly_outward(lp, cell.position, cell)
		var tex: Texture2D = cell.get_terrain_texture_for_map()
		var uvs: PackedVector2Array = cell.get_uvs_for_bleed_polygon(lp)
		if tex != null and bp.size() == uvs.size():
			draw_polygon(bp, _white_vertex_colors(bp.size()), uvs, tex)
		else:
			draw_colored_polygon(bp, cell.get_terrain_fallback_color())
	for cell2: SkirmishHexCell in list:
		var tc: Color = cell2.get_overlay_tint_color()
		if tc.a <= 0.001:
			continue
		var lp2: PackedVector2Array = cell2.get_bleed_polygon_local()
		if lp2.size() < 3:
			continue
		var bp2: PackedVector2Array = _scale_poly_outward(lp2, cell2.position, cell2)
		draw_colored_polygon(bp2, tc)


func clear_payload_cells() -> void:
	_payload_cells = []
	_payload_board_size = Vector2.ZERO
	_use_payload = false
	_payload_by_rc.clear()
	_rc_index_ready = false
	_content_dirty = true
	queue_redraw()


## 设置烘焙纹理后，_draw 直接绘制整张纹理（地形层静态化）；传 null 则回退逐格绘制
func set_baked_texture(tex: Texture2D, draw_size: Vector2) -> void:
	_baked_texture = tex
	_baked_draw_size = draw_size
	if draw_size.x > 1.0 and draw_size.y > 1.0:
		# 与 payload 绘制一致：控件逻辑尺寸 = 棋盘尺寸，避免边缘裁切
		if size != draw_size:
			size = draw_size
		if custom_minimum_size != draw_size:
			custom_minimum_size = draw_size
	_content_dirty = true
	queue_redraw()


func clear_baked_texture() -> void:
	_baked_texture = null
	_baked_draw_size = Vector2.ZERO
	_content_dirty = true
	queue_redraw()


func _draw_multiline_centered_caption(font: Font, font_size: int, center: Vector2, text: String) -> void:
	var lines: PackedStringArray = text.split("\n")
	if lines.is_empty():
		return
	var line_height: float = float(font_size) + 2.0
	var total_height: float = line_height * float(lines.size())
	var baseline_y: float = center.y - total_height * 0.5 + float(font_size)
	for line: String in lines:
		if line.is_empty():
			baseline_y += line_height
			continue
		var line_width: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var pos: Vector2 = Vector2(center.x - line_width * 0.5, baseline_y)
		draw_string(font, pos + Vector2(1, 1), line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, _CAPTION_SHADOW_COLOR)
		draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, _CAPTION_COLOR)
		baseline_y += line_height
