extends GutTest

## 诊断：大地图打开后地形 payload / 画布是否就绪


func test_big_map_terrain_payload_after_open() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")
	var panel_scene: PackedScene = load("res://scenes/ui/big_map/big_map_panel.tscn")
	assert_not_null(panel_scene, "大地图面板场景应存在")
	var panel: CanvasLayer = panel_scene.instantiate() as CanvasLayer
	add_child_autofree(panel)
	# 模拟独立打开
	if panel.has_method("open"):
		panel.call("open")
	await wait_physics_frames(8)
	var hex_board: Control = panel.get_node_or_null("%HexBoard") as Control
	if hex_board == null:
		hex_board = panel.get_node_or_null("MarginContainer/MainVBox/Scroll/HexBoard") as Control
	assert_not_null(hex_board, "应存在 HexBoard")
	var terrain_cv: Control = hex_board.get_node_or_null("HexMapTerrainCanvas") as Control
	assert_not_null(terrain_cv, "应存在地形画布")
	var payload: Array = panel.get("_terrain_payload_cells") as Array
	var board_base: Vector2 = panel.get("_board_base_size") as Vector2
	var radius: float = float(panel.get("_cell_radius_px"))
	var cfg: Dictionary = panel.get("_terrain_cfg") as Dictionary
	print("[diag] payload=", payload.size(), " board_base=", board_base, " radius=", radius)
	print("[diag] cfg map=", cfg.get("map_width"), "x", cfg.get("map_height"))
	print("[diag] terrain visible=", terrain_cv.get("visible"), " z=", terrain_cv.get("z_index"))
	print("[diag] use_payload=", terrain_cv.get("_use_payload"), " baked=", terrain_cv.get("_baked_texture"))
	print("[diag] payload_board_size=", terrain_cv.get("_payload_board_size"))
	assert_gt(payload.size(), 100, "地形 payload 不应为空，实际 %d" % payload.size())
	assert_gt(board_base.x, 10.0, "棋盘逻辑宽度应 >10，实际 %s" % str(board_base))
	assert_gt(radius, 5.0, "六角半径应 >5，实际 %s" % str(radius))
	assert_true(bool(terrain_cv.get("visible")), "地形画布应可见")
	if payload.size() > 0:
		var p0: Dictionary = payload[0] as Dictionary
		var poly: PackedVector2Array = p0.get("polygon", PackedVector2Array()) as PackedVector2Array
		print("[diag] p0 axial=", p0.get("_axial"), " poly_n=", poly.size(), " tex=", p0.get("texture"), " fallback=", p0.get("fallback_color"))
		assert_gte(poly.size(), 3, "首格 polygon 应有效")
	# DataManager 地形配置
	var rows: Array = DataManager.get_big_map_rows()
	print("[diag] data rows=", rows.size(), " map_size=", DataManager.get_big_map_size())
	assert_gt(rows.size(), 5, "big_map_terrain 行数应 >5")
