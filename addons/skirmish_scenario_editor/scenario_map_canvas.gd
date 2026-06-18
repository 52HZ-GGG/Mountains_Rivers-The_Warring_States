@tool
extends Control
class_name SkirmishScenarioMapCanvas

signal cell_clicked(col: int, row: int)

const HexLib := preload("res://scripts/systems/hex_axial.gd")
const TileTextures := preload("res://scripts/ui/skirmish_tile_textures.gd")
const _RADIUS: float = 28.0
const _PADDING: Vector2 = Vector2(20.0, 20.0)

var _scenario: Dictionary = {}
var _selected_cell: Vector2i = Vector2i(-1, -1)
var _selected_unit_index: int = -1
var _selected_city_key: String = ""
var _terrain_cache: Dictionary = {}
var _capital_cache: Dictionary = {}
var _unit_cache: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(640, 480)


func set_scenario_data(scenario: Dictionary, selected_cell: Vector2i, selected_unit_index: int, selected_city_key: String) -> void:
	_scenario = scenario
	_selected_cell = selected_cell
	_selected_unit_index = selected_unit_index
	_selected_city_key = selected_city_key
	custom_minimum_size = _compute_canvas_size()
	queue_redraw()


func clear_scene() -> void:
	_scenario = {}
	_selected_cell = Vector2i(-1, -1)
	_selected_unit_index = -1
	_selected_city_key = ""
	queue_redraw()


func _compute_canvas_size() -> Vector2:
	var width: int = int(_scenario.get("map_width", 7))
	var height: int = int(_scenario.get("map_height", 7))
	var max_x: float = 0.0
	var max_y: float = 0.0
	for row: int in range(height):
		for col: int in range(width):
			var top_left: Vector2 = _cell_top_left(col, row)
			max_x = maxf(max_x, top_left.x + _RADIUS * 2.0)
			max_y = maxf(max_y, top_left.y + sqrt(3.0) * _RADIUS)
	return Vector2(max_x + _PADDING.x, max_y + _PADDING.y)


func _draw() -> void:
	if _scenario.is_empty():
		_draw_empty_state()
		return
	var rows: Array = _scenario.get("rows", [])
	var width: int = int(_scenario.get("map_width", 0))
	var height: int = int(_scenario.get("map_height", 0))
	for row: int in range(height):
		for col: int in range(width):
			var top_left: Vector2 = _cell_top_left(col, row)
			var polygon: PackedVector2Array = _build_hex_polygon(top_left)
			var terrain_id: String = ""
			if row < rows.size():
				var row_data: Variant = rows[row]
				if row_data is Array and col < (row_data as Array).size():
					terrain_id = str((row_data as Array)[col])
			_draw_cell(polygon, terrain_id)
			_draw_grid_outline(polygon, Color(0.17, 0.15, 0.13, 0.9), 1.0)
			if _selected_cell == Vector2i(col, row):
				_draw_grid_outline(polygon, Color(0.94, 0.82, 0.31, 1.0), 3.0)
			_draw_cell_label(top_left, terrain_id, col, row)
	_draw_city("player", Color(0.74, 0.28, 0.22, 0.92))
	_draw_city("enemy", Color(0.22, 0.41, 0.76, 0.92))
	_draw_units()


func _draw_empty_state() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, Vector2(24, 40), "未加载演武场景", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.85, 0.85, 0.85, 1.0))


func _draw_cell(polygon: PackedVector2Array, terrain_id: String) -> void:
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
	draw_colored_polygon(polygon, _fallback_terrain_color(terrain_id))


func _draw_grid_outline(polygon: PackedVector2Array, color: Color, width: float) -> void:
	for i: int in range(polygon.size()):
		draw_line(polygon[i], polygon[(i + 1) % polygon.size()], color, width)


func _draw_cell_label(top_left: Vector2, terrain_id: String, col: int, row: int) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var center: Vector2 = top_left + Vector2(_RADIUS, sqrt(3.0) * _RADIUS * 0.5)
	var label: String = "%d,%d" % [col, row]
	draw_string(font, center + Vector2(-18, 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.1, 0.1, 0.1, 0.85))
	draw_string(font, center + Vector2(-20, -10), terrain_id.left(4), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.1, 0.1, 0.1, 0.7))


func _draw_city(city_key: String, fallback_color: Color) -> void:
	var dict_key: String = "player_city" if city_key == "player" else "enemy_city"
	var city_v: Variant = _scenario.get(dict_key, {})
	if not (city_v is Dictionary):
		return
	var city: Dictionary = city_v as Dictionary
	var col: int = int(city.get("q", -1))
	var row: int = int(city.get("r", -1))
	if col < 0 or row < 0:
		return
	var top_left: Vector2 = _cell_top_left(col, row)
	var rect: Rect2 = Rect2(top_left + Vector2(12, 10), Vector2(_RADIUS * 1.1, _RADIUS * 1.0))
	var faction_id: String = str(_scenario.get("player_faction_id", "qin")) if city_key == "player" else str(_scenario.get("enemy_faction_id", "zhao"))
	var capital_texture: Texture2D = _get_capital_texture(faction_id)
	if capital_texture != null:
		draw_texture_rect(capital_texture, rect, false)
	else:
		draw_rect(rect, fallback_color, true)
	var is_selected: bool = _selected_city_key == city_key
	if is_selected:
		draw_rect(rect.grow(3.0), Color(1.0, 0.87, 0.34, 0.9), false, 2.0)
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var short_text: String = "我城" if city_key == "player" else "敌城"
		draw_string(font, rect.position + Vector2(-2, rect.size.y + 14), short_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.95, 0.95, 1.0))


func _draw_units() -> void:
	var units_v: Variant = _scenario.get("initial_units", [])
	if not (units_v is Array):
		return
	var units: Array = units_v as Array
	var font: Font = ThemeDB.fallback_font
	for unit_index: int in range(units.size()):
		var unit: Dictionary = units[unit_index] as Dictionary
		var col: int = int(unit.get("q", -1))
		var row: int = int(unit.get("r", -1))
		if col < 0 or row < 0:
			continue
		var top_left: Vector2 = _cell_top_left(col, row)
		var center: Vector2 = top_left + Vector2(_RADIUS, sqrt(3.0) * _RADIUS * 0.5)
		var faction_id: String = str(unit.get("faction_id", ""))
		var bg_color: Color = Color(0.72, 0.28, 0.23, 0.95) if faction_id == str(_scenario.get("player_faction_id", "")) else Color(0.22, 0.45, 0.77, 0.95)
		draw_circle(center + Vector2(0, 4), 14.0, bg_color)
		var unit_tex: Texture2D = _get_unit_texture(str(unit.get("unit_type_id", "")))
		if unit_tex != null:
			draw_texture_rect(unit_tex, Rect2(center + Vector2(-11, -8), Vector2(22, 22)), false)
		elif font != null:
			draw_string(font, center + Vector2(-10, 8), str(unit.get("unit_type_id", "")).left(3), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		if unit_index == _selected_unit_index:
			draw_arc(center + Vector2(0, 4), 17.0, 0.0, TAU, 24, Color(1.0, 0.87, 0.34, 1.0), 3.0)


func _build_hex_polygon(top_left: Vector2) -> PackedVector2Array:
	var center: Vector2 = top_left + Vector2(_RADIUS, sqrt(3.0) * _RADIUS * 0.5)
	var polygon: PackedVector2Array = PackedVector2Array()
	for i: int in range(6):
		var angle: float = float(i) * TAU / 6.0
		polygon.append(Vector2(center.x + cos(angle) * _RADIUS, center.y + sin(angle) * _RADIUS))
	return polygon


func _cell_top_left(col: int, row: int) -> Vector2:
	return _PADDING + HexLib.offset_odd_r_flat_top_cell_top_left(col, row, _RADIUS)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var cell: Vector2i = _find_cell_at_point(mb.position)
			if cell.x >= 0 and cell.y >= 0:
				cell_clicked.emit(cell.x, cell.y)
				accept_event()


func _find_cell_at_point(point: Vector2) -> Vector2i:
	if _scenario.is_empty():
		return Vector2i(-1, -1)
	var width: int = int(_scenario.get("map_width", 0))
	var height: int = int(_scenario.get("map_height", 0))
	for row: int in range(height):
		for col: int in range(width):
			var polygon: PackedVector2Array = _build_hex_polygon(_cell_top_left(col, row))
			if Geometry2D.is_point_in_polygon(point, polygon):
				return Vector2i(col, row)
	return Vector2i(-1, -1)


func _get_terrain_texture(terrain_id: String) -> Texture2D:
	if _terrain_cache.has(terrain_id):
		return _terrain_cache[terrain_id] as Texture2D
	var tex: Texture2D = TileTextures.terrain_texture(terrain_id)
	_terrain_cache[terrain_id] = tex
	return tex


func _get_capital_texture(faction_id: String) -> Texture2D:
	if _capital_cache.has(faction_id):
		return _capital_cache[faction_id] as Texture2D
	var tex: Texture2D = TileTextures.capital_texture(faction_id)
	_capital_cache[faction_id] = tex
	return tex


func _get_unit_texture(unit_type_id: String) -> Texture2D:
	var normalized_id: String = unit_type_id
	match unit_type_id:
		"catapult":
			normalized_id = "siege"
		"dayi":
			normalized_id = "great_wing"
		"louchuan":
			normalized_id = "tower_ship"
	if _unit_cache.has(normalized_id):
		return _unit_cache[normalized_id] as Texture2D
	var tex: Texture2D = TileTextures.unit_texture(normalized_id)
	_unit_cache[normalized_id] = tex
	return tex


func _fallback_terrain_color(terrain_id: String) -> Color:
	match terrain_id:
		"forest":
			return Color(0.36, 0.51, 0.29, 1.0)
		"mountain":
			return Color(0.45, 0.44, 0.46, 1.0)
		"river":
			return Color(0.28, 0.51, 0.72, 1.0)
		"marsh":
			return Color(0.42, 0.50, 0.36, 1.0)
		"pass":
			return Color(0.61, 0.49, 0.31, 1.0)
		"ford":
			return Color(0.43, 0.62, 0.72, 1.0)
		"desert":
			return Color(0.76, 0.67, 0.42, 1.0)
		"tundra":
			return Color(0.74, 0.79, 0.82, 1.0)
		_:
			return Color(0.60, 0.69, 0.46, 1.0)
