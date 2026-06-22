extends Control
class_name HexMapCanvas

## 在 HexBoard 上一次性绘制全部六角地形贴图，避免逐格 Control._draw 叠加误差造成「假缝隙」。

const _EXTRA_BLEED_SCALE: float = 1.2
const _CAPTION_COLOR: Color = Color(1, 1, 1, 1)
const _CAPTION_SHADOW_COLOR: Color = Color(0.05, 0.05, 0.10, 0.9)

var _payload_cells: Array = []
var _payload_board_size: Vector2 = Vector2.ZERO
var _use_payload: bool = false

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
	if what == NOTIFICATION_RESIZED:
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
	queue_redraw()


func clear_payload_cells() -> void:
	_payload_cells = []
	_payload_board_size = Vector2.ZERO
	_use_payload = false
	queue_redraw()


func _draw() -> void:
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


func _draw_payload_cells() -> void:
	if _payload_board_size != Vector2.ZERO and size != _payload_board_size:
		size = _payload_board_size
	var font: Font = get_theme_default_font()
	var font_size_default: int = get_theme_default_font_size()
	for payload_v: Variant in _payload_cells:
		if payload_v is not Dictionary:
			continue
		var payload: Dictionary = payload_v as Dictionary
		var polygon: PackedVector2Array = payload.get("polygon", PackedVector2Array()) as PackedVector2Array
		if polygon.size() < 3:
			continue
		var tex: Texture2D = payload.get("texture", null) as Texture2D
		var uvs: PackedVector2Array = payload.get("uvs", PackedVector2Array()) as PackedVector2Array
		if tex != null and polygon.size() == uvs.size():
			draw_polygon(polygon, _white_vertex_colors(polygon.size()), uvs, tex)
		else:
			draw_colored_polygon(polygon, payload.get("fallback_color", SkirmishHexCell.fallback_terrain_color()) as Color)
		var tint: Color = payload.get("tint", Color(0, 0, 0, 0)) as Color
		if tint.a > 0.001:
			draw_colored_polygon(polygon, tint)
		var capital_rect: Rect2 = payload.get("capital_rect", Rect2()) as Rect2
		var capital_tex: Texture2D = payload.get("capital_texture", null) as Texture2D
		if capital_tex != null and capital_rect.size.x > 0.0 and capital_rect.size.y > 0.0:
			draw_texture_rect(capital_tex, capital_rect, false)
		var caption_text: String = str(payload.get("caption", ""))
		if caption_text.is_empty() or font == null:
			continue
		var font_size: int = int(payload.get("caption_font_size", font_size_default))
		var caption_center: Vector2 = payload.get("caption_center", Vector2.ZERO) as Vector2
		_draw_multiline_centered_caption(font, font_size, caption_center, caption_text)


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
