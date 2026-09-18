extends GutTest

## 防回归：禁止引用未注册的 MapGateway（解析错误会卡死演武面板）


func test_no_map_gateway_identifier() -> void:
	var paths: Array[String] = [
		"res://scenes/ui/skirmish/skirmish_mvp_panel.gd",
		"res://scenes/ui/big_map/big_map_panel.gd",
		"res://scenes/ui/big_map/big_map_scene.gd",
		"res://scenes/main/main.gd",
	]
	for p: String in paths:
		if not FileAccess.file_exists(p):
			continue
		var text: String = FileAccess.get_file_as_string(p)
		assert_false(text.contains("MapGateway."), "%s 不得调用 MapGateway" % p)


func test_season_apis_exist() -> void:
	assert_true(CityManager.has_method("get_current_season"))
	assert_true(TacticalSkirmishManager.has_method("get_current_season"))
	assert_true(TacticalSkirmishManager.has_method("set_season"))
