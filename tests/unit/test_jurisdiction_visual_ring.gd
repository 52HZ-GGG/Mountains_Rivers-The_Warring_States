extends GutTest

## 防回归：决策 #123 辖区必须跟大地图「奇数列下移」视觉邻格一致
## 不能对轴向直接取 6 邻格，否则环会偏一格。

const HexAxial := preload("res://scripts/systems/hex_axial.gd")


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func _first_qin_city() -> Dictionary:
	return CityManager.get_faction_cities("qin")[0] as Dictionary


func test_visual_neighbors_helper_exists() -> void:
	var n: Array[Vector2i] = HexAxial.offset_visual_neighbors(10, 10)
	assert_eq(n.size(), 6, "视觉邻格应为 6 个")
	assert_true(n.has(Vector2i(11, 10)))
	assert_true(n.has(Vector2i(10, 9)))
	assert_true(n.has(Vector2i(10, 11)))


func test_jurisdiction_excludes_city_cell_and_has_six_ring() -> void:
	var city: Dictionary = _first_qin_city()
	var city_id: String = str(city.get("id", ""))
	var col: int = int(city.get("hex_q", 0))
	var row: int = int(city.get("hex_r", 0))
	var city_axial: Vector2i = HexAxial.offset_odd_r_to_axial(col, row)
	var hexes: Array[Vector2i] = CityManager.get_jurisdiction_hexes(city_id)
	assert_eq(hexes.size(), 6, "radius=1 辖区应为城周 6 格，got=%s" % hexes)
	assert_false(hexes.has(city_axial), "城市本体格不能在建筑辖区内 axial=%s" % city_axial)
	assert_false(CityManager.is_jurisdiction_hex(city_id, city_axial))


func test_jurisdiction_matches_visual_neighbors_not_axial_ring() -> void:
	var city: Dictionary = _first_qin_city()
	var city_id: String = str(city.get("id", ""))
	var col: int = int(city.get("hex_q", 0))
	var row: int = int(city.get("hex_r", 0))
	var city_axial: Vector2i = HexAxial.offset_odd_r_to_axial(col, row)
	var expected: Dictionary = {}
	for nb: Vector2i in HexAxial.offset_visual_neighbors(col, row):
		expected[HexAxial.offset_odd_r_to_axial(nb.x, nb.y)] = true
	var actual: Dictionary = {}
	for cell: Vector2i in CityManager.get_jurisdiction_hexes(city_id):
		actual[cell] = true
	assert_eq(actual.size(), expected.size())
	for k in expected:
		assert_true(actual.has(k), "辖区必须包含视觉邻格 %s" % k)
	for k in actual:
		assert_true(expected.has(k), "辖区不得包含非视觉邻格 %s" % k)
	# 当视觉环 ≠ 轴向环时，必须以视觉环为准（决策 #123）
	var axial_ring: Dictionary = {}
	for d: Vector2i in HexAxial.DIRECTIONS:
		axial_ring[city_axial + d] = true
	var differs: bool = false
	for k in axial_ring:
		if not expected.has(k):
			differs = true
	if differs:
		for k in expected:
			assert_true(actual.has(k), "视觉环优先于轴向环：%s" % k)


func test_can_build_rejects_city_center_and_accepts_ring() -> void:
	var city: Dictionary = _first_qin_city()
	var city_id: String = str(city.get("id", ""))
	var city_axial: Vector2i = CityManager.get_city_center_axial(city_id)
	var check_center: Dictionary = CityManager.can_build(city_id, "farm", city_axial)
	assert_eq(str(check_center.get("reason", "")), CityManager.REASON_HEX_OUT_OF_JURISDICTION)
	var allowed: Array[Vector2i] = []
	for cell: Vector2i in CityManager.get_jurisdiction_hexes(city_id):
		if bool(CityManager.can_build(city_id, "farm", cell).get("allowed", false)):
			allowed.append(cell)
	if allowed.is_empty():
		pass_test("环上暂无空闲/可建格（槽位或资源），跳过")
		return
	assert_true(CityManager.start_build(city_id, "farm", allowed[0]))
	var queue: Array = CityManager.get_city_state(city_id).get("build_queue", []) as Array
	assert_false(queue.is_empty())
	assert_eq(int((queue[queue.size() - 1] as Dictionary).get("hex_q", -1)), allowed[0].x)
	assert_eq(int((queue[queue.size() - 1] as Dictionary).get("hex_r", -1)), allowed[0].y)
