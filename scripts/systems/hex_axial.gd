extends RefCounted
class_name HexAxial

## 轴坐标六角格工具（对齐 docs/六角网格规范.md）

## 点状顶六角（外接圆半径 R）：轴向 (q,r) → 包住六角形的轴对齐矩形左上角（像素）。
## 行间水平错位来自公式中的 `r/2`：相邻两行的同一「竖向索引」格不会在一条垂直线上对齐。
static func axial_pointy_top_cell_top_left(q: int, r: int, circumradius_px: float) -> Vector2:
	var sqrt3: float = sqrt(3.0)
	var cx: float = circumradius_px * sqrt3 * (float(q) + float(r) * 0.5)
	var cy: float = circumradius_px * 1.5 * float(r)
	var bw: float = circumradius_px * sqrt3
	var bh: float = circumradius_px * 2.0
	return Vector2(cx - bw * 0.5, cy - bh * 0.5)


## odd-R 偏移（列 col、行 row）：与战术 JSON `rows[row][col]`、据点/单位的 q,r **同一套索引**。
## 盘面呈矩形砖砌蜂巢；运行时用下面函数转为轴向 (q,r) 再做邻居与距离。
static func offset_odd_r_to_axial(col: int, row: int) -> Vector2i:
	var q: int = col - int((row - (row & 1)) / 2)
	var r: int = row
	return Vector2i(q, r)


static func axial_to_offset_odd_r(q: int, r: int) -> Vector2i:
	var col: int = q + int((r - (r & 1)) / 2)
	var row: int = r
	return Vector2i(col, row)


## odd-R + 点状顶：列/行 → 六角控件左上角（像素）。保留供校验；战术 UI 已改用平顶摆放。
static func offset_odd_r_cell_top_left(col: int, row: int, circumradius_px: float) -> Vector2:
	var sqrt3: float = sqrt(3.0)
	var cx: float = circumradius_px * sqrt3 * (float(col) + 0.5 * float(row & 1))
	var cy: float = circumradius_px * 1.5 * float(row)
	var bw: float = circumradius_px * sqrt3
	var bh: float = circumradius_px * 2.0
	return Vector2(cx - bw * 0.5, cy - bh * 0.5)


## 平顶六角 + 轴向 (q,r)：Red Blob axial hex-to-pixel（flat top），R 为外接圆半径（中心到顶点）。
## 与 odd-R 表转换得到的轴向坐标配套；控件外包矩形宽 2R、高 √3·R。
static func axial_flat_top_cell_top_left(q: int, r: int, circumradius_px: float) -> Vector2:
	var sqrt3: float = sqrt(3.0)
	var cx: float = circumradius_px * 1.5 * float(q)
	var cy: float = circumradius_px * sqrt3 * (float(r) + float(q) * 0.5)
	var bw: float = circumradius_px * 2.0
	var bh: float = circumradius_px * sqrt3
	return Vector2(cx - bw * 0.5, cy - bh * 0.5)


## 平顶六角 + 轴向：像素中心坐标 -> 轴向坐标（cube rounding）。
static func pixel_flat_top_to_axial(point: Vector2, circumradius_px: float) -> Vector2i:
	if circumradius_px <= 0.0:
		return Vector2i.ZERO
	var qf: float = (2.0 / 3.0 * point.x) / circumradius_px
	var rf: float = ((-1.0 / 3.0) * point.x + (sqrt(3.0) / 3.0) * point.y) / circumradius_px
	return _round_axial(qf, rf)


## 战术盘面摆放：JSON 列/行 → 轴向 → 平顶像素左上角（与蜂窝朝向一致）
static func offset_odd_r_flat_top_cell_top_left(col: int, row: int, circumradius_px: float) -> Vector2:
	var ax: Vector2i = offset_odd_r_to_axial(col, row)
	return axial_flat_top_cell_top_left(ax.x, ax.y, circumradius_px)


const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(1, -1),
]


static func hex_distance_hex(a: Vector2i, b: Vector2i) -> int:
	return hex_distance_axial(a.x, a.y, b.x, b.y)


static func hex_distance_axial(q1: int, r1: int, q2: int, r2: int) -> int:
	var dq: int = absi(q1 - q2)
	var dr: int = absi(r1 - r2)
	var ds: int = absi((q1 + r1) - (q2 + r2))
	return maxi(dq, maxi(dr, ds))


static func neighbors_hex(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in DIRECTIONS:
		out.append(Vector2i(cell.x + d.x, cell.y + d.y))
	return out


## 轴向矩形范围：给定 q,r 边界内所有轴向坐标（与策划案小节地图填充方式一致）
static func iter_rect(q_min: int, q_max: int, r_min: int, r_max: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var q: int = q_min
	while q <= q_max:
		var r: int = r_min
		while r <= r_max:
			cells.append(Vector2i(q, r))
			r += 1
		q += 1
	return cells


static func _round_axial(qf: float, rf: float) -> Vector2i:
	var sf: float = -qf - rf
	var q: int = int(round(qf))
	var r: int = int(round(rf))
	var s: int = int(round(sf))
	var q_diff: float = absf(float(q) - qf)
	var r_diff: float = absf(float(r) - rf)
	var s_diff: float = absf(float(s) - sf)
	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s
	return Vector2i(q, r)
