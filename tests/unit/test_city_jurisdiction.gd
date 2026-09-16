extends GutTest

## 辖区必须是「地图视觉」上的城周一圈（奇数列下移布局）


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	GameManager.start_game(["qin"], "qin")


func test_jurisdiction_is_visual_ring() -> void:
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes("xianyang")
	assert_eq(hexes.size(), 6, "应为 6 邻格，实际 %d" % hexes.size())
	var city: Dictionary = CityManager.get_city_state("xianyang")
	var col: int = int(city.get("hex_q", 0))
	var row: int = int(city.get("hex_r", 0))
	var expected: Dictionary = {}
	for nb: Vector2i in HexAxial.offset_visual_neighbors(col, row):
		expected[HexAxial.offset_odd_r_to_axial(nb.x, nb.y)] = true
	for cell: Vector2i in hexes:
		assert_true(expected.has(cell), "格子 %s 应是城 (%d,%d) 的视觉邻格" % [cell, col, row])
	# 不能包含城心
	var center: Vector2i = CityManager.get_city_center_axial("xianyang")
	assert_false(hexes.has(center), "辖区不应包含城心")


func test_xianyang_specific_ring() -> void:
	# 咸阳 offset (22,44) 偶数列：视觉邻格固定
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes("xianyang")
	var offs: Array[Vector2i] = CityManager.get_jurisdiction_offset_hexes("xianyang")
	assert_eq(offs.size(), 6)
	for o: Vector2i in offs:
		assert_false(o == Vector2i(22, 44), "不应包含城心")
		# 必须是城的 6 个视觉邻格之一
		var ok: bool = false
		for nb: Vector2i in HexAxial.offset_visual_neighbors(22, 44):
			if o == nb:
				ok = true
		assert_true(ok, "offset %s 应是 (22,44) 视觉邻格" % o)
