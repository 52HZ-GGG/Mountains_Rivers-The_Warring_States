extends GutTest

## 防回归：禁止 InputEvent.accept_event()（会卡退大地图点击）
## 禁止编辑器缓冲覆盖后静默丢失修复。


func test_big_map_panel_has_no_inputevent_accept_event() -> void:
	var path: String = "res://scenes/ui/big_map/big_map_panel.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "big_map_panel.gd should exist")
	var text: String = file.get_as_text()
	file.close()
	assert_false(text.contains("mb.accept_event()"), "must not call InputEventMouseButton.accept_event()")
	assert_false(text.contains("motion.accept_event()"), "must not call InputEventMouseMotion.accept_event()")


func test_big_map_panel_uses_safe_input_consume() -> void:
	var path: String = "res://scenes/ui/big_map/big_map_panel.gd"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file)
	var text: String = file.get_as_text()
	file.close()
	assert_true(
		text.contains("_BigMapInput.consume()")
		or text.contains("BigMapInput.consume()")
		or text.contains("set_input_as_handled"),
		"input must be consumed safely via viewport"
	)


func test_big_map_input_helper_exists() -> void:
	var lib: Script = load("res://scripts/ui/big_map_input.gd")
	assert_not_null(lib)
	assert_true(lib.can_instantiate())


func test_city_caption_includes_hp() -> void:
	var src: String = FileAccess.get_file_as_string("res://scripts/ui/big_map_input.gd")
	assert_true(src.contains("func city_caption"), "helper must define city_caption")
	assert_true(src.contains("HP"), "caption format includes HP")
	GameManager.reset()
	CityManager.reset()
	var factions: Array[String] = ["qin", "zhao"]
	GameManager.start_game(factions, "qin")
	var cities: Array = CityManager.get_faction_cities("qin")
	assert_false(cities.is_empty())
	var city_id: String = str((cities[0] as Dictionary).get("id", ""))
	var state: Dictionary = CityManager.get_city_state(city_id)
	assert_false(state.is_empty(), "city state should exist after start_game")
	assert_true(state.has("current_hp") or CityManager.has_method("get_city_max_hp"),
		"CityManager must expose city HP for map captions")
