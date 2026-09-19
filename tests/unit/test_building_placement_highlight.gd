extends GutTest

## BuildingPlacementHighlight：与大地图同一套辖区高亮配色/判定

const Highlight := preload("res://scripts/ui/building_placement_highlight.gd")


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_highlight_matches_jurisdiction_ring() -> void:
	var city: Dictionary = (CityManager.get_faction_cities("qin")[0] as Dictionary)
	var city_id: String = str(city.get("id", ""))
	var map: Dictionary = Highlight.highlight_for_jurisdiction(city_id, "farm")
	var juris: Array[Vector2i] = CityManager.get_jurisdiction_hexes(city_id)
	assert_eq(map.size(), juris.size(), "高亮键应与辖区环一致")
	for cell: Vector2i in juris:
		assert_true(map.has(cell), "辖区格必须在高亮中: %s" % str(cell))
		var check: Dictionary = CityManager.can_build(city_id, "farm", cell)
		if bool(check.get("allowed", false)):
			assert_eq(map[cell], Highlight.CLR_OK)
		else:
			assert_ne(map[cell], Highlight.CLR_OK)


func test_empty_ids_return_empty() -> void:
	assert_true(Highlight.highlight_for_jurisdiction("", "farm").is_empty())
	assert_true(Highlight.highlight_for_jurisdiction("xianyang", "").is_empty())
