extends GutTest

const HexLib := preload("res://scripts/systems/hex_axial.gd")

func test_neighbor_count_is_six() -> void:
	var nbs: Array[Vector2i] = HexLib.neighbors_hex(Vector2i(0, 0))
	assert_eq(nbs.size(), 6, "轴向格应有 6 邻")


func test_axial_distance_adjacent_one() -> void:
	assert_eq(HexLib.hex_distance_axial(0, 0, 1, 0), 1)


func test_axial_distance_diagonal_three() -> void:
	assert_eq(HexLib.hex_distance_axial(0, 0, 2, 1), 3)


## UI 点状顶六角像素摆放：必须行间错位，禁止「矩形棋盘」式 (q×cell_w, r×cell_h)
func test_pointy_top_same_row_neighbor_horizontal_pitch() -> void:
	var r_px: float = 40.0
	var a: Vector2 = HexLib.axial_pointy_top_cell_top_left(0, 0, r_px)
	var b: Vector2 = HexLib.axial_pointy_top_cell_top_left(1, 0, r_px)
	var dx: float = b.x - a.x
	var pitch: float = sqrt(3.0) * r_px
	assert_almost_eq(dx, pitch, 0.02, "同行相邻格水平节距应为 √3·R")


func test_pointy_top_adjacent_rows_stagger_half_pitch() -> void:
	var r_px: float = 40.0
	var a: Vector2 = HexLib.axial_pointy_top_cell_top_left(0, 0, r_px)
	var b: Vector2 = HexLib.axial_pointy_top_cell_top_left(0, 1, r_px)
	var dx: float = b.x - a.x
	var half_pitch: float = sqrt(3.0) * r_px * 0.5
	assert_almost_eq(dx, half_pitch, 0.02, "相邻行须水平错开 √3·R/2，否则视觉上会像方格阵")


func test_pointy_top_fixed_q_not_vertical_column() -> void:
	var r_px: float = 40.0
	var x0: float = HexLib.axial_pointy_top_cell_top_left(2, 0, r_px).x
	var x1: float = HexLib.axial_pointy_top_cell_top_left(2, 1, r_px).x
	assert_ne(x0, x1, "轴向格固定 q 随 r 变化时 x 须变化，不应竖直对齐成矩形列")


func test_offset_odd_r_roundtrip_matches_rectangular_map() -> void:
	for col in range(7):
		for row in range(7):
			var ax: Vector2i = HexLib.offset_odd_r_to_axial(col, row)
			var back: Vector2i = HexLib.axial_to_offset_odd_r(ax.x, ax.y)
			assert_eq(back.x, col, "odd-R 偏移 ↔ 轴向须可逆（列）")
			assert_eq(back.y, row, "odd-R 偏移 ↔ 轴向须可逆（行）")


func test_flat_top_axial_adjacent_center_distance() -> void:
	var R: float = 40.0
	var tl0: Vector2 = HexLib.axial_flat_top_cell_top_left(0, 0, R)
	var tl1: Vector2 = HexLib.axial_flat_top_cell_top_left(1, 0, R)
	var c0: Vector2 = tl0 + Vector2(R, sqrt(3.0) * R * 0.5)
	var c1: Vector2 = tl1 + Vector2(R, sqrt(3.0) * R * 0.5)
	assert_almost_eq(c0.distance_to(c1), sqrt(3.0) * R, 0.05, "平顶轴向相邻格中心距应为 √3·R")


func test_offset_odd_r_flat_top_chain_matches_axial() -> void:
	var R: float = 40.0
	var tl_via_offset: Vector2 = HexLib.offset_odd_r_flat_top_cell_top_left(2, 3, R)
	var ax: Vector2i = HexLib.offset_odd_r_to_axial(2, 3)
	var tl_direct: Vector2 = HexLib.axial_flat_top_cell_top_left(ax.x, ax.y, R)
	assert_eq(tl_via_offset, tl_direct, "odd-R→轴向→平顶像素 须与直接轴向一致")
