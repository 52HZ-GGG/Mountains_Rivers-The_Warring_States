extends Control
class_name SkirmishHexCell

const _HexAxial := preload("res://scripts/systems/hex_axial.gd")

## 单格六角：平顶朝向（相对点状顶旋转 90°），外包 2R×√3·R；轴向逻辑不变。
## 内部邻格之间不描边、不外投影，避免缝看起来像「黑线」；仅地图外轮廓可描边。
## 使用 Control._draw 绘制（避免 Node2D 在 ScrollContainer 下不显示）
## 拾取：_has_point 六边形内

signal hex_clicked(q: int, r: int)

const _OUTLINE_COLOR: Color = Color(0.28, 0.24, 0.20, 0.55)
const _OUTLINE_WIDTH: float = 1.0
const _FALLBACK_TERRAIN: Color = Color(0.42, 0.52, 0.36, 1.0)


static func fallback_terrain_color() -> Color:
	return _FALLBACK_TERRAIN
## 沿顶点外扩，使相邻格地形层互相压住，盖住采样/抗锯齿造成的细缝（几何仍为密铺）
const _FILL_BLEED_PX: float = 2.6


var cell_q: int = 0
var cell_r: int = 0
var circumradius: float = 40.0
var _board_w: int = 1
var _board_h: int = 1

var _poly: PackedVector2Array = PackedVector2Array()
var _uvs: PackedVector2Array = PackedVector2Array()
var _terrain_tex: Texture2D
var _tint_color: Color = Color(0, 0, 0, 0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	size = custom_minimum_size
	_refresh_polygon_geometry()


func configure(q: int, r: int, radius: float, box_w: float, box_h: float) -> void:
	cell_q = q
	cell_r = r
	circumradius = radius
	custom_minimum_size = Vector2(box_w, box_h)


func set_board_bounds(map_w: int, map_h: int) -> void:
	_board_w = maxi(1, map_w)
	_board_h = maxi(1, map_h)


func _refresh_polygon_geometry() -> void:
	if custom_minimum_size.x <= 0.0 or custom_minimum_size.y <= 0.0:
		_poly = PackedVector2Array()
		_uvs = PackedVector2Array()
		queue_redraw()
		return
	_poly = _hex_polygon_vertices()
	_uvs = _hex_uvs(_poly)
	queue_redraw()


func _hex_polygon_vertices() -> PackedVector2Array:
	## 平顶六角（常用「盘面」朝向）：外包矩形宽 2R×高 √3·R，首顶点朝右
	var bw: float = custom_minimum_size.x
	var bh: float = custom_minimum_size.y
	var cx: float = bw * 0.5
	var cy: float = bh * 0.5
	var pts: PackedVector2Array = PackedVector2Array()
	var i: int = 0
	while i < 6:
		var a: float = float(i) * TAU / 6.0
		pts.append(Vector2(cx + cos(a) * circumradius, cy + sin(a) * circumradius))
		i += 1
	return pts


func _hex_uvs(poly: PackedVector2Array) -> PackedVector2Array:
	var uvs: PackedVector2Array = PackedVector2Array()
	var bw: float = custom_minimum_size.x
	var bh: float = custom_minimum_size.y
	var i: int = 0
	while i < poly.size():
		var p: Vector2 = poly[i]
		uvs.append(Vector2(p.x / bw, p.y / bh))
		i += 1
	return uvs


func _poly_bleed_outward(poly: PackedVector2Array) -> PackedVector2Array:
	if poly.size() < 3 or _FILL_BLEED_PX <= 0.0:
		return poly
	var bw: float = custom_minimum_size.x
	var bh: float = custom_minimum_size.y
	var cx: float = bw * 0.5
	var cy: float = bh * 0.5
	var c: Vector2 = Vector2(cx, cy)
	var out: PackedVector2Array = PackedVector2Array()
	var i: int = 0
	while i < poly.size():
		var d: Vector2 = poly[i] - c
		var len: float = d.length()
		if len > 0.001:
			out.append(poly[i] + d * (_FILL_BLEED_PX / len))
		else:
			out.append(poly[i])
		i += 1
	return out


func _pixel_delta_axial(dq: int, dr: int) -> Vector2:
	## 矩形布局下平顶轴向邻格像素位移
	return _HexAxial.rect_neighbor_pixel_delta(cell_q, cell_r, dq, dr, circumradius)


func _neighbor_axial_for_edge(edge_i: int) -> Vector2i:
	var bw: float = custom_minimum_size.x
	var bh: float = custom_minimum_size.y
	var c: Vector2 = Vector2(bw * 0.5, bh * 0.5)
	var p0: Vector2 = _poly[edge_i]
	var p1: Vector2 = _poly[(edge_i + 1) % _poly.size()]
	var mid: Vector2 = (p0 + p1) * 0.5
	var outward: Vector2 = (mid - c).normalized()
	var best_dot: float = -10.0
	var best_dir: Vector2i = _HexAxial.DIRECTIONS[0]
	var ni: int = 0
	while ni < _HexAxial.DIRECTIONS.size():
		var dir: Vector2i = _HexAxial.DIRECTIONS[ni]
		var pd: Vector2 = _pixel_delta_axial(dir.x, dir.y).normalized()
		var dot: float = pd.dot(outward)
		if dot > best_dot:
			best_dot = dot
			best_dir = dir
		ni += 1
	return best_dir


## 战术盘为 odd-R 矩形列×行；邻格是否在盘上以偏移坐标判定（轴向 q 可为负）
func _hex_neighbor_on_board(nq: int, nr: int) -> bool:
	var o: Vector2i = _HexAxial.axial_to_offset_odd_r(nq, nr)
	return o.x >= 0 and o.x < _board_w and o.y >= 0 and o.y < _board_h


func get_bleed_polygon_local() -> PackedVector2Array:
	if _poly.size() < 3:
		return PackedVector2Array()
	return _poly_bleed_outward(_poly)


func get_uvs_for_bleed_polygon(draw_poly: PackedVector2Array) -> PackedVector2Array:
	return _hex_uvs(draw_poly)


func get_terrain_texture_for_map() -> Texture2D:
	return _terrain_tex


func get_overlay_tint_color() -> Color:
	return _tint_color


func _draw() -> void:
	if _poly.size() < 3:
		return
	## 地形与可走格染色均在 HexMapCanvas 绘制，避免与 Control 叠层错位
	var n: int = _poly.size()
	var i2: int = 0
	while i2 < n:
		var nd: Vector2i = _neighbor_axial_for_edge(i2)
		var nq: int = cell_q + nd.x
		var nr: int = cell_r + nd.y
		if _hex_neighbor_on_board(nq, nr):
			i2 += 1
			continue
		var a: Vector2 = _poly[i2]
		var b: Vector2 = _poly[(i2 + 1) % n]
		draw_line(a, b, _OUTLINE_COLOR, _OUTLINE_WIDTH, false)
		i2 += 1


func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _hex_polygon_vertices())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _has_point(mb.position):
				hex_clicked.emit(cell_q, cell_r)
				accept_event()


func set_terrain_texture(tex: Texture2D) -> void:
	_terrain_tex = tex


func set_tint_color(c: Color) -> void:
	_tint_color = Color(c.r, c.g, c.b, c.a)
	queue_redraw()
	_queue_parent_hex_map_canvas_redraw()


func notify_size_changed() -> void:
	size = custom_minimum_size
	_refresh_polygon_geometry()
	_queue_parent_hex_map_canvas_redraw()


func _queue_parent_hex_map_canvas_redraw() -> void:
	var board: Control = get_parent() as Control
	if board == null:
		return
	var cv: Node = board.get_node_or_null("HexMapCanvas")
	if cv is CanvasItem:
		(cv as CanvasItem).queue_redraw()
