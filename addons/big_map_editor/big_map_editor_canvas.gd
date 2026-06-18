@tool
extends Control
class_name BigMapEditorCanvas

const DocumentScript := preload("res://addons/big_map_editor/big_map_document.gd")
const HexAxial := preload("res://scripts/systems/hex_axial.gd")
const TileTextures := preload("res://scripts/ui/skirmish_tile_textures.gd")

signal cell_clicked(col: int, row: int, axial_q: int, axial_r: int)
signal cell_hovered(col: int, row: int, axial_q: int, axial_r: int)
signal hover_exited

const _BASE_RADIUS: float = 20.0
const _PADDING: Vector2 = Vector2(24.0, 24.0)

var _document: BigMapDocument = null
var _selected_cell: Vector2i = Vector2i(-1, -1)
var _selected_city_index: int = -1
var _mode: String = "terrain"
var _zoom_level: float = 1.0
var _show_grid: bool = true
var _show_political: bool = true
var _terrain_cache: Dictionary = {}
var _panning: bool = false
var _pan_anchor: Vector2 = Vector2.ZERO
var _scroll_anchor: Vector2i = Vector2i.ZERO
var _origin_shift: Vector2 = Vector2.ZERO
var _last_hovered_cell: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(1200, 900)
	mouse_exited.connect(func() -> void:
		_last_hovered_cell = Vector2i(-1, -1)
		hover_exited.emit()
	)


func set_view(
	document: BigMapDocument,
	selected_cell: Vector2i,
	selected_city_index: int,
	mode: String,
	zoom_level: float,
	show_grid: bool,
	show_political: bool
) -> void:
	_document = document
	_selected_cell = selected_cell
	_selected_city_index = selected_city_index
	_mode = mode
	_zoom_level = zoom_level
	_show_grid = show_grid
	_show_political = show_political
	custom_minimum_size = _compute_canvas_size()
	queue_redraw()


func _compute_canvas_size() -> Vector2:
	if _document == null:
		_origin_shift = Vector2.ZERO
		return Vector2(1200, 900)
	var radius: float = _radius()
	var min_x: float = INF
	var min_y: float = INF
	var max_x: float = 0.0
	var max_y: float = 0.0
	for row: int in range(_document.get_map_height()):
		for col: int in range(_document.get_map_width()):
			var raw_top_left: Vector2 = _raw_cell_top_left(col, row, radius)
			min_x = minf(min_x, raw_top_left.x)
			min_y = minf(min_y, raw_top_left.y)
			var top_left: Vector2 = raw_top_left
			max_x = maxf(max_x, top_left.x + radius * 2.0)
			max_y = maxf(max_y, top_left.y + sqrt(3.0) * radius)
	if min_x == INF or min_y == INF:
		_origin_shift = Vector2.ZERO
		return Vector2(1200, 900)
	_origin_shift = Vector2(min_x, min_y)
	return Vector2(max_x - min_x + _PADDING.x * 2.0, max_y - min_y + _PADDING.y * 2.0)


func _draw() -> void:
	if _document == null:
		_draw_empty_state()
		return
	var rows: Array = _document.get_rows()
	for row: int in range(_document.get_map_height()):
		var row_data: Array = rows[row] as Array
		for col: int in range(_document.get_map_width()):
			var top_left: Vector2 = _cell_top_left(col, row)
			var polygon: PackedVector2Array = _build_hex_polygon(top_left)
			var terrain_id: String = str(row_data[col])
			_draw_terrain_cell(polygon, terrain_id)
			if _show_political:
				var owner_id: String = _document.get_resolved_owner_at_offset(col, row)
				if not owner_id.is_empty():
					draw_colored_polygon(polygon, _overlay_color(owner_id, 0.26))
				elif _mode == "control":
					draw_colored_polygon(polygon, Color(0.17, 0.19, 0.22, 0.12))
			if _show_grid:
				_draw_outline(polygon, Color(0.16, 0.14, 0.12, 0.50), 1.0)
			var axial: Vector2i = HexAxial.offset_odd_r_to_axial(col, row)
			if _document.has_override_at_axial(axial.x, axial.y):
				_draw_override_marker(top_left, axial)
			if _selected_cell == Vector2i(col, row):
				_draw_outline(polygon, Color(0.96, 0.84, 0.29, 1.0), 2.4)
	_draw_cities()


func _draw_empty_state() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, Vector2(24, 40), "未加载大地图文档", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.85, 0.85, 1.0))


func _draw_terrain_cell(polygon: PackedVector2Array, terrain_id: String) -> void:
	var tex: Texture2D = _get_terrain_texture(terrain_id)
	if tex != null:
		var rect: Rect2 = Rect2(polygon[0], Vector2.ZERO)
		for point: Vector2 in polygon:
			rect = rect.expand(point)
		var uvs: PackedVector2Array = PackedVector2Array()
		for point2: Vector2 in polygon:
			uvs.append(Vector2(
				(point2.x - rect.position.x) / maxf(rect.size.x, 1.0),
				(point2.y - rect.position.y) / maxf(rect.size.y, 1.0)
			))
		var colors: PackedColorArray = PackedColorArray()
		for _i: int in range(polygon.size()):
			colors.append(Color.WHITE)
		draw_polygon(polygon, colors, uvs, tex)
		return
	draw_colored_polygon(polygon, TileTextures.terrain_fallback_color(terrain_id))


func _draw_cities() -> void:
	var font: Font = ThemeDB.fallback_font
	var radius: float = _radius()
	for city_index: int in range(_document.get_city_count()):
		var city: Dictionary = _document.get_city(city_index)
		var offset: Vector2i = Vector2i(int(city.get("hex_q", 0)), int(city.get("hex_r", 0)))
		var top_left: Vector2 = _cell_top_left(offset.x, offset.y)
		var center: Vector2 = top_left + Vector2(radius, sqrt(3.0) * radius * 0.5)
		var faction_id: String = str(city.get("faction_id", "neutral"))
		var fill: Color = _document.get_faction_color(faction_id)
		fill.a = 0.95
		var city_radius: float = radius * (0.30 if not bool(city.get("is_capital", false)) else 0.38)
		draw_circle(center, city_radius, fill)
		draw_arc(center, city_radius + 1.5, 0.0, TAU, 24, Color(0.08, 0.07, 0.06, 0.95), 2.0)
		if bool(city.get("is_capital", false)):
			draw_arc(center, city_radius + 4.0, 0.0, TAU, 24, Color(0.98, 0.85, 0.31, 0.95), 2.0)
		if city_index == _selected_city_index:
			draw_arc(center, city_radius + 7.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.95), 2.0)
		if font != null and _zoom_level >= 0.85:
			var label: String = str(city.get("name", "")).left(2)
			draw_string(font, center + Vector2(-radius * 0.28, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, clampi(int(radius * 0.62), 10, 16), Color(1, 1, 1, 0.95))


func _draw_override_marker(top_left: Vector2, axial: Vector2i) -> void:
	var radius: float = _radius()
	var center: Vector2 = top_left + Vector2(radius, sqrt(3.0) * radius * 0.5)
	var owner: Variant = _document.get_override_owner_at_axial(axial.x, axial.y)
	if owner == null:
		draw_line(center + Vector2(-4, -4), center + Vector2(4, 4), Color(1, 1, 1, 0.95), 2.0)
		draw_line(center + Vector2(-4, 4), center + Vector2(4, -4), Color(1, 1, 1, 0.95), 2.0)
	else:
		draw_arc(center + Vector2(radius * 0.42, -radius * 0.32), radius * 0.12, 0.0, TAU, 16, Color(1, 1, 1, 0.95), 2.0)


func _overlay_color(owner_id: String, alpha: float) -> Color:
	var base: Color = _document.get_faction_color(owner_id)
	return Color(base.r, base.g, base.b, alpha)


func _draw_outline(polygon: PackedVector2Array, color: Color, width: float) -> void:
	for i: int in range(polygon.size()):
		draw_line(polygon[i], polygon[(i + 1) % polygon.size()], color, width)


func _build_hex_polygon(top_left: Vector2) -> PackedVector2Array:
	var radius: float = _radius()
	var center: Vector2 = top_left + Vector2(radius, sqrt(3.0) * radius * 0.5)
	var polygon: PackedVector2Array = PackedVector2Array()
	for i: int in range(6):
		var angle: float = float(i) * TAU / 6.0
		polygon.append(Vector2(center.x + cos(angle) * radius, center.y + sin(angle) * radius))
	return polygon


func _cell_top_left(col: int, row: int) -> Vector2:
	var radius: float = _radius()
	return _PADDING + _raw_cell_top_left(col, row, radius) - _origin_shift


func _raw_cell_top_left(col: int, row: int, radius: float) -> Vector2:
	return HexAxial.offset_odd_r_flat_top_cell_top_left(col, row, radius)


func _radius() -> float:
	return _BASE_RADIUS * _zoom_level


func _get_terrain_texture(terrain_id: String) -> Texture2D:
	if _terrain_cache.has(terrain_id):
		return _terrain_cache[terrain_id] as Texture2D
	var tex: Texture2D = TileTextures.terrain_texture(terrain_id)
	_terrain_cache[terrain_id] = tex
	return tex


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_panning = mb.pressed
			if _panning:
				_pan_anchor = mb.position
				var scroll: ScrollContainer = _find_scroll_parent()
				if scroll != null:
					_scroll_anchor = Vector2i(scroll.scroll_horizontal, scroll.scroll_vertical)
				accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var cell: Vector2i = _find_cell_at_point(mb.position)
			if cell.x >= 0 and cell.y >= 0:
				var axial: Vector2i = HexAxial.offset_odd_r_to_axial(cell.x, cell.y)
				cell_clicked.emit(cell.x, cell.y, axial.x, axial.y)
				accept_event()
			return
	if event is InputEventMouseMotion and _panning:
		var scroll: ScrollContainer = _find_scroll_parent()
		if scroll != null:
			var delta: Vector2 = event.position - _pan_anchor
			scroll.scroll_horizontal = _scroll_anchor.x - int(delta.x)
			scroll.scroll_vertical = _scroll_anchor.y - int(delta.y)
			accept_event()
			return
	if event is InputEventMouseMotion:
		var hover_cell: Vector2i = _find_cell_at_point(event.position)
		if hover_cell == _last_hovered_cell:
			return
		_last_hovered_cell = hover_cell
		if hover_cell.x >= 0 and hover_cell.y >= 0:
			var hover_axial: Vector2i = HexAxial.offset_odd_r_to_axial(hover_cell.x, hover_cell.y)
			cell_hovered.emit(hover_cell.x, hover_cell.y, hover_axial.x, hover_axial.y)
		else:
			hover_exited.emit()


func _find_scroll_parent() -> ScrollContainer:
	var node: Node = get_parent()
	while node != null:
		if node is ScrollContainer:
			return node as ScrollContainer
		node = node.get_parent()
	return null


func _find_cell_at_point(point: Vector2) -> Vector2i:
	if _document == null:
		return Vector2i(-1, -1)
	for row: int in range(_document.get_map_height()):
		for col: int in range(_document.get_map_width()):
			if Geometry2D.is_point_in_polygon(point, _build_hex_polygon(_cell_top_left(col, row))):
				return Vector2i(col, row)
	return Vector2i(-1, -1)
