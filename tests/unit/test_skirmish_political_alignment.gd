extends GutTest

## 演武政治疆域：与大地图同一套 BigMapPoliticalControl 影响力算法（战术坐标）

const Political := preload("res://scripts/systems/big_map_political_control.gd")


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_influence_prefers_stronger_capital_on_tactical_map() -> void:
	var rules: Dictionary = DataManager.get_big_map_political_control()
	var map_size: Vector2i = Vector2i(9, 9)
	var cities: Array = [
		{
			"hex_q": 0, "hex_r": 4,
			"current_faction_id": "qin",
			"city_level": 3, "is_capital": true, "development": 20,
		},
		{
			"hex_q": 8, "hex_r": 4,
			"current_faction_id": "zhao",
			"city_level": 3, "is_capital": true, "development": 20,
		},
	]
	var terrain_rows: Array = []
	for r: int in range(9):
		var row: Array = []
		for c: int in range(9):
			row.append("plains")
		terrain_rows.append(row)
	var grid: Dictionary = Political.build_resolved_control_grid(cities, [], map_size, rules, terrain_rows)
	# odd-R (0,4) / (8,4) → axial
	var left_axial: Vector2i = Vector2i(0 - ((4 - (4 & 1)) / 2), 4)
	var right_axial: Vector2i = Vector2i(8 - ((4 - (4 & 1)) / 2), 4)
	assert_eq(str(grid.get(left_axial, "")), "qin", "秦都附近应归秦 %s" % str(left_axial))
	assert_eq(str(grid.get(right_axial, "")), "zhao", "赵都附近应归赵 %s" % str(right_axial))
	assert_false(str(grid.get(left_axial, "")).is_empty())
	assert_false(str(grid.get(right_axial, "")).is_empty())
