extends Control
class_name BigMapMiniMap

signal navigate_requested(normalized: Vector2)

const _BG_COLOR: Color = Color(0.08, 0.09, 0.08, 0.88)
const _BORDER_COLOR: Color = Color(0.72, 0.66, 0.48, 0.95)
const _NEUTRAL_COLOR: Color = Color(0.46, 0.46, 0.46, 1.0)
const _VIEW_COLOR: Color = Color(1.0, 0.95, 0.70, 0.18)
const _VIEW_BORDER_COLOR: Color = Color(1.0, 0.92, 0.55, 1.0)

var _map_size: Vector2i = Vector2i.ONE
var _viewport_rect: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
var _markers: Array = []
var _surface_texture: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(220, 160)
	queue_redraw()


func set_cells(_cell_rects: Array, cell_colors: PackedColorArray, map_size: Vector2i) -> void:
	_map_size = map_size
	_surface_texture = _build_surface_texture(cell_colors, map_size)
	queue_redraw()


func set_markers(markers: Array) -> void:
	_markers = markers
	queue_redraw()


func set_viewport_rect(normalized_rect: Rect2) -> void:
	_viewport_rect = Rect2(
		Vector2(clampf(normalized_rect.position.x, 0.0, 1.0), clampf(normalized_rect.position.y, 0.0, 1.0)),
		Vector2(clampf(normalized_rect.size.x, 0.0, 1.0), clampf(normalized_rect.size.y, 0.0, 1.0))
	)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var content_rect: Rect2 = _content_rect()
			if content_rect.has_point(mb.position):
				var normalized: Vector2 = Vector2(
					clampf((mb.position.x - content_rect.position.x) / maxf(content_rect.size.x, 1.0), 0.0, 1.0),
					clampf((mb.position.y - content_rect.position.y) / maxf(content_rect.size.y, 1.0), 0.0, 1.0)
				)
				navigate_requested.emit(normalized)
				accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _BG_COLOR, true)
	var content_rect: Rect2 = _content_rect()
	draw_rect(content_rect, Color(0.16, 0.17, 0.14, 1.0), true)
	if _surface_texture != null:
		draw_texture_rect(_surface_texture, content_rect, false)
	for marker_v: Variant in _markers:
		if marker_v is not Dictionary:
			continue
		var marker: Dictionary = marker_v as Dictionary
		var pos_n: Vector2 = marker.get("pos", Vector2.ZERO) as Vector2
		var marker_pos: Vector2 = content_rect.position + Vector2(pos_n.x * content_rect.size.x, pos_n.y * content_rect.size.y)
		var color: Color = marker.get("color", _NEUTRAL_COLOR) as Color
		var radius: float = float(marker.get("radius", 2.5))
		draw_circle(marker_pos, radius, color)
		if bool(marker.get("is_capital", false)):
			draw_arc(marker_pos, radius + 2.0, 0.0, TAU, 20, Color(1.0, 0.92, 0.65, 1.0), 1.6)
	var view_rect: Rect2 = Rect2(
		content_rect.position + Vector2(_viewport_rect.position.x * content_rect.size.x, _viewport_rect.position.y * content_rect.size.y),
		Vector2(_viewport_rect.size.x * content_rect.size.x, _viewport_rect.size.y * content_rect.size.y)
	)
	draw_rect(view_rect, _VIEW_COLOR, true)
	draw_rect(view_rect, _VIEW_BORDER_COLOR, false, 2.0)
	draw_rect(content_rect, _BORDER_COLOR, false, 2.0)


func neutral_color() -> Color:
	return _NEUTRAL_COLOR


func _build_surface_texture(cell_colors: PackedColorArray, map_size: Vector2i) -> Texture2D:
	if map_size.x <= 0 or map_size.y <= 0:
		return null
	var img: Image = Image.create(map_size.x, map_size.y, false, Image.FORMAT_RGBA8)
	img.fill(_NEUTRAL_COLOR)
	var idx: int = 0
	for row: int in range(map_size.y):
		for col: int in range(map_size.x):
			if idx < cell_colors.size():
				img.set_pixel(col, row, cell_colors[idx])
			idx += 1
	return ImageTexture.create_from_image(img)


func _content_rect() -> Rect2:
	var pad: float = 10.0
	var target_ratio: float = float(_map_size.x) / maxf(float(_map_size.y), 1.0)
	var avail_size: Vector2 = Vector2(maxf(size.x - pad * 2.0, 1.0), maxf(size.y - pad * 2.0, 1.0))
	var draw_size: Vector2 = avail_size
	var avail_ratio: float = avail_size.x / maxf(avail_size.y, 1.0)
	if avail_ratio > target_ratio:
		draw_size.x = avail_size.y * target_ratio
	else:
		draw_size.y = avail_size.x / maxf(target_ratio, 0.001)
	var pos: Vector2 = Vector2((size.x - draw_size.x) * 0.5, (size.y - draw_size.y) * 0.5)
	return Rect2(pos, draw_size)
