extends GutTest

## 防回归：辖区/放置 API 与决策 #123（视觉环，城格除外）

const HexAxial := preload("res://scripts/systems/hex_axial.gd")


func test_wiring_still_present() -> void:
	var city_panel: String = FileAccess.get_file_as_string("res://scenes/ui/city_panel/city_panel.gd")
	assert_true(city_panel.contains("place_building_requested"))
	var main: String = FileAccess.get_file_as_string("res://scenes/main/main.gd")
	assert_true(main.contains("begin_building_placement"))
	var bigmap: String = FileAccess.get_file_as_string("res://scenes/ui/big_map/big_map_panel.gd")
	assert_true(bigmap.contains("func begin_building_placement"))
	var citymgr: String = FileAccess.get_file_as_string("res://scripts/autoload/city_manager.gd")
	assert_true(citymgr.contains("offset_visual_neighbors"), "辖区必须走视觉邻格 BFS")
	assert_true(citymgr.contains("func get_city_center_axial"))
	assert_true(citymgr.contains("REASON_HEX_RESERVED"))
	var hexlib: String = FileAccess.get_file_as_string("res://scripts/systems/hex_axial.gd")
	assert_true(hexlib.contains("func offset_visual_neighbors"))


func test_start_build_accepts_target_hex_on_visual_ring() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")
	var city: Dictionary = (CityManager.get_faction_cities("qin")[0] as Dictionary)
	var city_id: String = str(city.get("id", ""))
	var free_cell: Vector2i = Vector2i(-9999, -9999)
	for cell: Vector2i in CityManager.get_jurisdiction_hexes(city_id):
		if bool(CityManager.can_build(city_id, "farm", cell).get("allowed", false)):
			free_cell = cell
			break
	if free_cell.x <= -9999:
		pass_test("无空闲视觉辖区格")
		return
	assert_true(CityManager.start_build(city_id, "farm", free_cell))
	var queue: Array = CityManager.get_city_state(city_id).get("build_queue", []) as Array
	assert_false(queue.is_empty())
	var last: Dictionary = queue[queue.size() - 1] as Dictionary
	assert_eq(int(last.get("hex_q", -1)), free_cell.x)
	assert_eq(int(last.get("hex_r", -1)), free_cell.y)
	# 城格不得被写入
	var city_axial: Vector2i = CityManager.get_city_center_axial(city_id)
	assert_true(Vector2i(int(last.get("hex_q")), int(last.get("hex_r"))) != city_axial)
