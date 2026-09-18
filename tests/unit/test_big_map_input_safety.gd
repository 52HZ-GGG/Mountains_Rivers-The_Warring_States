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
	assert_true(text.contains("_BigMapInput.consume()") or text.contains("set_input_as_handled"), "input must be consumed safely")
	assert_true(text.contains("preload(\"res://scripts/ui/big_map_input.gd\")"), "must preload BigMapInput (class_name cache may be stale)")


func test_big_map_input_helper_exists() -> void:
	var lib: Script = load("res://scripts/ui/big_map_input.gd")
	assert_not_null(lib)
	assert_true(lib.can_instantiate())


func test_city_caption_includes_hp() -> void:
	var city_lib: Script = load("res://scripts/ui/big_map_input.gd")
	assert_not_null(city_lib)
	GameManager.reset()
	CityManager.reset()
	GameManager.start_game(["qin", "zhao"], "qin")
	var cities: Array = CityManager.get_faction_cities("qin")
	assert_false(cities.is_empty())
	var city_id: String = str((cities[0] as Dictionary).get("id", ""))
	# 静态函数通过脚本调用
	var caption: String = city_lib.call("city_caption", city_id, "TestCity")
	assert_true(caption.contains("TestCity"), "caption keeps city name")
	assert_true(caption.contains("HP"), "caption includes HP")
