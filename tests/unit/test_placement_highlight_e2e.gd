extends GutTest

## 端到端：放置高亮键 = 视觉辖区环（决策 #123），且绿格可 start_build

const HexAxial := preload("res://scripts/systems/hex_axial.gd")


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func _placement_highlight(city_id: String, building_id: String) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector2i in CityManager.get_jurisdiction_hexes(city_id):
		var check: Dictionary = CityManager.can_build(city_id, building_id, cell)
		if bool(check.get("allowed", false)):
			out[cell] = "green"
		else:
			out[cell] = str(check.get("reason", ""))
	return out


func test_highlight_keys_are_visual_ring_and_place_works() -> void:
	var city: Dictionary = (CityManager.get_faction_cities("qin")[0] as Dictionary)
	var city_id: String = str(city.get("id", ""))
	var col: int = int(city.get("hex_q", 0))
	var row: int = int(city.get("hex_r", 0))
	var highlight: Dictionary = _placement_highlight(city_id, "farm")
	assert_false(highlight.is_empty())
	# 高亮键 = 视觉邻格 → axial，不得包含城格
	var city_axial: Vector2i = HexAxial.offset_odd_r_to_axial(col, row)
	assert_false(highlight.has(city_axial), "高亮不应包含城市本体格")
	for nb: Vector2i in HexAxial.offset_visual_neighbors(col, row):
		var ax: Vector2i = HexAxial.offset_odd_r_to_axial(nb.x, nb.y)
		assert_true(highlight.has(ax), "高亮必须覆盖视觉邻格 %s (axial %s)" % [nb, ax])

	var greens: Array = []
	for k in highlight:
		if str(highlight[k]) == "green":
			greens.append(k)
	if greens.is_empty():
		pass_test("环上无绿格（资源/槽位），跳过落点")
		return
	var target: Vector2i = greens[0] as Vector2i
	assert_true(CityManager.start_build(city_id, "farm", target), "绿格应可放置")
	var queue: Array = CityManager.get_city_state(city_id).get("build_queue", []) as Array
	assert_eq(int((queue[queue.size() - 1] as Dictionary).get("hex_q", -1)), target.x)
	assert_eq(int((queue[queue.size() - 1] as Dictionary).get("hex_r", -1)), target.y)


func test_hex_axial_dirents_visual_neighborhood_differs_when_needed() -> void:
	# 锁定：even col 时视觉环与轴向环确实不同，防止再被“简化”回去
	var n: Array[Vector2i] = HexAxial.offset_visual_neighbors(10, 10)
	var axial: Vector2i = HexAxial.offset_odd_r_to_axial(10, 10)
	var visual_axial: Dictionary = {}
	for nb in n:
		visual_axial[HexAxial.offset_odd_r_to_axial(nb.x, nb.y)] = true
	var axial_ring: Dictionary = {}
	for d in HexAxial.DIRECTIONS:
		axial_ring[axial + d] = true
	var same: bool = true
	for k in visual_axial:
		if not axial_ring.has(k):
			same = false
	for k in axial_ring:
		if not visual_axial.has(k):
			same = false
	assert_false(same, "odd-Q 视觉环应与 odd-R 轴向环不同，否则说明坐标约定被改乱 visual=%s axial=%s" % [visual_axial.keys(), axial_ring.keys()])
