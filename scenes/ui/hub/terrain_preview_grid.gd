extends Control

## 中枢里的混合地形试排。素材由画布裁成六角格。
const COLUMNS: int = 6
const ROWS: int = 4
const UV_CROP: Rect2 = Rect2(0.10, 0.10, 0.80, 0.80)
const TERRAIN_ROWS: Array = [
	["tundra", "tundra", "mountain", "mountain", "desert", "desert"],
	["forest", "forest", "mountain", "pass", "plains", "desert"],
	["plains", "forest", "plains", "plains", "marsh", "shallow_ocean"],
	["plains", "plains", "marsh", "shallow_ocean", "shallow_ocean", "deep_ocean"],
]
const VARIANT_ROWS: Array = [
	["plains", "plains", "plains", "plains", "plains", "plains"],
	["plains", "plains", "forest", "forest", "forest", "mountain"],
	["forest", "forest", "forest", "mountain", "mountain", "mountain"],
	["mountain", "mountain", "mountain", "plains", "forest", "plains"],
]
## 每种素材恰好出现一次，按寒地、山林、湿地、海岸方向试排。
const FULL_VARIANT_ROWS: Array = [
	["tundra", "tundra", "tundra", "mountain", "mountain", "mountain"],
	["forest", "forest", "forest", "pass", "pass", "desert"],
	["plains", "plains", "plains", "marsh", "desert", "desert"],
	["marsh", "marsh", "shallow_ocean", "shallow_ocean", "deep_ocean", "deep_ocean"],
]
const FULL_VARIANT_INDICES: Array = [
	[0, 1, 2, 0, 1, 2],
	[0, 1, 2, 0, 1, 0],
	[0, 1, 2, 0, 1, 2],
	[1, 2, 0, 1, 0, 1],
]

var _preview_mode: int = 0


func _ready() -> void:
	resized.connect(queue_redraw)


func set_preview_mode(mode: int) -> void:
	_preview_mode = mode
	queue_redraw()


func get_terrain_texture(terrain_id: String, column: int = 0, row: int = 0) -> Texture2D:
	if _preview_mode == 2 and column >= 0 and column < COLUMNS and row >= 0 and row < ROWS:
		return SkirmishTileTextures.terrain_texture_by_variant(terrain_id, int(FULL_VARIANT_INDICES[row][column]))
	return SkirmishTileTextures.terrain_variant_texture(terrain_id, column, row)


func _draw() -> void:
	var hex_width: float = minf(166.0, minf((size.x - 40.0) / 4.9, (size.y - 40.0) / 3.9))
	if hex_width <= 0.0:
		return
	var hex_height: float = hex_width * sqrt(3.0) * 0.5
	var board_width: float = hex_width * (1.0 + float(COLUMNS - 1) * 0.75)
	var board_height: float = hex_height * (float(ROWS) + 0.5)
	var start := Vector2((size.x - board_width) * 0.5 + hex_width * 0.5,
		(size.y - board_height) * 0.5 + hex_height * 0.5)
	for row in range(ROWS):
		for column in range(COLUMNS):
			var center := _cell_center(start, column, row, hex_width, hex_height)
			_draw_hex(center, hex_width, hex_height,
				get_terrain_texture(_terrain_at(column, row), column, row))
	# 两侧各在共享边缘渐入 50% 邻格纹理，避免直接碰接的色块断层。
	for row in range(ROWS):
		for column in range(COLUMNS):
			var terrain_id: String = _terrain_at(column, row)
			var center := _cell_center(start, column, row, hex_width, hex_height)
			var offsets := _hex_offsets(hex_width, hex_height)
			for side in range(6):
				var neighbor: Vector2i = _neighbor_cell(column, row, side)
				var neighbor_id: String = _terrain_at(neighbor.x, neighbor.y)
				var alpha: float = SkirmishTileTextures.terrain_edge_blend_alpha(terrain_id, neighbor_id)
				if alpha > 0.0:
					_draw_edge_blend(center, offsets[side], offsets[(side + 1) % 6],
						hex_width, hex_height, get_terrain_texture(neighbor_id, neighbor.x, neighbor.y), alpha)


func _terrain_at(column: int, row: int) -> String:
	if column < 0 or column >= COLUMNS or row < 0 or row >= ROWS:
		return ""
	var rows: Array = FULL_VARIANT_ROWS if _preview_mode == 2 else (VARIANT_ROWS if _preview_mode == 1 else TERRAIN_ROWS)
	return str(rows[row][column])


func _cell_center(start: Vector2, column: int, row: int, width: float, height: float) -> Vector2:
	return start + Vector2(float(column) * width * 0.75,
		(float(row) + float(column % 2) * 0.5) * height)


func _neighbor_cell(column: int, row: int, side: int) -> Vector2i:
	var even: bool = column % 2 == 0
	match side:
		0: return Vector2i(column, row - 1)
		1: return Vector2i(column + 1, row - 1 if even else row)
		2: return Vector2i(column + 1, row if even else row + 1)
		3: return Vector2i(column, row + 1)
		4: return Vector2i(column - 1, row if even else row + 1)
		_: return Vector2i(column - 1, row - 1 if even else row)


func _hex_offsets(width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-width * 0.25, -height * 0.5),
		Vector2(width * 0.25, -height * 0.5),
		Vector2(width * 0.5, 0.0),
		Vector2(width * 0.25, height * 0.5),
		Vector2(-width * 0.25, height * 0.5),
		Vector2(-width * 0.5, 0.0),
	])


func _draw_hex(center: Vector2, width: float, height: float, texture: Texture2D) -> void:
	if texture == null:
		return
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	for offset in _hex_offsets(width, height):
		points.append(center + offset)
		uvs.append(_uv_for_offset(offset, width, height))
		colors.append(Color.WHITE)
	draw_polygon(points, colors, uvs, texture)


func _draw_edge_blend(center: Vector2, a: Vector2, b: Vector2,
		width: float, height: float, texture: Texture2D, alpha: float) -> void:
	if texture == null:
		return
	var inset: float = width * 0.13
	var inner_a: Vector2 = a - a.normalized() * inset
	var inner_b: Vector2 = b - b.normalized() * inset
	var offsets := PackedVector2Array([a, b, inner_b, inner_a])
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for offset in offsets:
		points.append(center + offset)
		uvs.append(_uv_for_offset(offset, width, height))
	var colors := PackedColorArray([
		Color(1, 1, 1, alpha), Color(1, 1, 1, alpha),
		Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0),
	])
	draw_polygon(points, colors, uvs, texture)


func _uv_for_offset(offset: Vector2, width: float, height: float) -> Vector2:
	return UV_CROP.position + Vector2(0.5 + offset.x / width,
		0.5 + offset.y / height) * UV_CROP.size
