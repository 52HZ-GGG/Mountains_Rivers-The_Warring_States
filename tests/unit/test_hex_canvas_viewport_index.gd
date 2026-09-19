extends GutTest

## HexMapCanvas 视口窗口索引：payload 含 col/row 时可按 cull 窗口取子集

const Canvas := preload("res://scripts/ui/skirmish_hex_map_canvas.gd")


func test_window_index_returns_subset_when_meta_ready() -> void:
	var cv: HexMapCanvas = Canvas.new()
	add_child_autofree(cv)
	var cells: Array = []
	var cols: int = 30
	var rows: int = 20
	var r: float = 20.0
	for row: int in range(rows):
		for col: int in range(cols):
			cells.append({
				"col": col,
				"row": row,
				"polygon": PackedVector2Array([Vector2(0, 0), Vector2(40, 0), Vector2(40, 30)]),
				"caption_center": Vector2(1.5 * r * col, sqrt(3.0) * r * (row + 0.5 * float(col & 1))),
				"tint": Color(0, 0, 0, 0),
			})
	var board: Vector2 = Vector2(cols * 1.5 * r + 40.0, rows * sqrt(3.0) * r + 40.0)
	cv.set_spatial_meta(r, Vector2.ZERO, 8.0)
	cv.set_payload_cells(cells, board)
	cv.set_cull_enabled(true)
	cv.set_cull_rect(Rect2(board.x * 0.4, board.y * 0.4, 120.0, 90.0))
	# 默认关闭窗口索引：可见列表应仍是全量 payload（靠 _payload_visible 过滤绘制）
	var visible: Array = cv._visible_payloads()
	assert_eq(visible.size(), cells.size(), "默认应返回全量 payload，保证静态大地图可绘制")
	# 直接测窗口函数：有元数据时应能取到子集
	var windowed: Array = cv._payloads_in_cull_window()
	assert_gt(windowed.size(), 0)
	assert_lt(windowed.size(), cells.size(), "窗口函数应少于全图 visible=%d total=%d" % [windowed.size(), cells.size()])

func test_without_meta_fallback_full_scan() -> void:
	var cv: HexMapCanvas = Canvas.new()
	add_child_autofree(cv)
	var cells: Array = [{"polygon": PackedVector2Array([Vector2(0,0), Vector2(1,0), Vector2(1,1)])}]
	cv.set_payload_cells(cells, Vector2(100, 100))
	cv.set_cull_enabled(true)
	cv.set_cull_rect(Rect2(0, 0, 10, 10))
	assert_eq(cv._visible_payloads().size(), cells.size(), "无 col/row 时应回退全量")
