extends GutTest

const DocumentScript := preload("res://addons/skirmish_scenario_editor/scenario_document.gd")

var _temp_path: String = "user://test_skirmish_scenario_document.json"


func before_each() -> void:
	if FileAccess.file_exists(_temp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_temp_path))


func after_each() -> void:
	if FileAccess.file_exists(_temp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_temp_path))


func _load_doc() -> SkirmishScenarioDocument:
	var doc: SkirmishScenarioDocument = DocumentScript.new()
	assert_true(doc.load_from_path(), "应能加载 skirmish_scenarios.json")
	return doc


func test_existing_skirmish_scenarios_validate_successfully() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	var errors: Array[String] = doc.validate_document()
	assert_eq(errors.size(), 0, "现有演武场景应通过插件校验。errors=%s" % str(errors))


func test_create_new_scenario_has_valid_defaults() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	var new_index: int = doc.create_new_scenario()
	var scenario: Dictionary = doc.get_scenario(new_index)
	assert_eq(str(scenario.get("name", "")), "新演武场景")
	assert_eq(int(scenario.get("map_width", 0)), 7)
	assert_eq(int(scenario.get("map_height", 0)), 7)
	assert_eq((scenario.get("rows", []) as Array).size(), 7)
	assert_eq(str((scenario.get("rows", []) as Array)[0][0]), "plains")


func test_duplicate_scenario_generates_unique_id() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	var copy_index: int = doc.duplicate_scenario(0)
	var original_id: String = str(doc.get_scenario(0).get("id", ""))
	var copy_id: String = str(doc.get_scenario(copy_index).get("id", ""))
	assert_ne(copy_id, original_id, "复制后的场景 id 必须唯一")
	assert_true(copy_id.begins_with(original_id + "_copy"), "复制后的 id 应带 _copy 前缀")


func test_resize_expansion_fills_new_cells_with_plains() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	var result: Dictionary = doc.resize_scenario(0, 9, 8)
	assert_true(bool(result.get("ok", false)), "扩大地图应成功")
	assert_eq(doc.get_cell_terrain(0, 8, 7), "plains")


func test_resize_rejects_when_city_would_be_clipped() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	var result: Dictionary = doc.resize_scenario(0, 6, 7)
	assert_false(bool(result.get("ok", true)), "裁掉城池时应拒绝缩图")


func test_resize_rejects_when_unit_would_be_clipped() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	var result: Dictionary = doc.resize_scenario(3, 8, 9)
	assert_false(bool(result.get("ok", true)), "裁掉单位时应拒绝缩图")


func test_duplicate_scenario_ids_fail_validation() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	doc.create_new_scenario()
	doc.set_scenario_id(doc.get_scenario_count() - 1, str(doc.get_scenario(0).get("id", "")))
	var errors: Array[String] = doc.validate_document()
	assert_true(_contains_text(errors, "场景 id 重复"), "重复场景 id 应校验失败")


func test_duplicate_unit_ids_fail_validation() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	var scenario: Dictionary = doc.get_scenario(0)
	var units: Array = scenario.get("initial_units", [])
	(units[1] as Dictionary)["id"] = str((units[0] as Dictionary).get("id", ""))
	doc.mark_dirty()
	var errors: Array[String] = doc.validate_document()
	assert_true(_contains_text(errors, "单位 id 重复"), "重复单位 id 应校验失败")


func test_unknown_terrain_fails_validation() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	doc.set_cell_terrain(0, 0, 0, "lava")
	var errors: Array[String] = doc.validate_document()
	assert_true(_contains_text(errors, "地形未知"), "未知地形应校验失败")


func test_unknown_unit_type_fails_validation() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	var scenario: Dictionary = doc.get_scenario(0)
	var units: Array = scenario.get("initial_units", [])
	(units[0] as Dictionary)["unit_type_id"] = "unknown_unit"
	doc.mark_dirty()
	var errors: Array[String] = doc.validate_document()
	assert_true(_contains_text(errors, "兵种未知"), "未知兵种应校验失败")


func test_existing_alias_unit_type_is_accepted() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	var scenario: Dictionary = doc.get_scenario(2)
	var units: Array = scenario.get("initial_units", [])
	assert_eq(str((units[3] as Dictionary).get("unit_type_id", "")), "dayi")
	var errors: Array[String] = doc.validate_document()
	assert_false(_contains_text(errors, "兵种未知"), "现有演武别名兵种 ID 应被兼容")


func test_unknown_faction_fails_validation() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	doc.set_scenario_field(0, "player_faction_id", "ghost")
	var errors: Array[String] = doc.validate_document()
	assert_true(_contains_text(errors, "玩家势力未知"), "未知势力应校验失败")


func test_out_of_bounds_unit_fails_validation() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	var scenario: Dictionary = doc.get_scenario(0)
	var units: Array = scenario.get("initial_units", [])
	(units[0] as Dictionary)["q"] = 999
	doc.mark_dirty()
	var errors: Array[String] = doc.validate_document()
	assert_true(_contains_text(errors, "坐标越界"), "越界单位应校验失败")


func test_overlapping_units_fail_validation() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	var scenario: Dictionary = doc.get_scenario(0)
	var units: Array = scenario.get("initial_units", [])
	var first: Dictionary = units[0] as Dictionary
	var second: Dictionary = units[1] as Dictionary
	second["q"] = int(first.get("q", 0))
	second["r"] = int(first.get("r", 0))
	doc.mark_dirty()
	var errors: Array[String] = doc.validate_document()
	assert_true(_contains_text(errors, "单位不能重叠"), "重叠单位应校验失败")


func test_unit_on_city_fails_validation() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	var player_city: Dictionary = doc.get_city(0, "player")
	var scenario: Dictionary = doc.get_scenario(0)
	var units: Array = scenario.get("initial_units", [])
	(units[0] as Dictionary)["q"] = int(player_city.get("q", 0))
	(units[0] as Dictionary)["r"] = int(player_city.get("r", 0))
	doc.mark_dirty()
	var errors: Array[String] = doc.validate_document()
	assert_true(_contains_text(errors, "不能与城池重叠"), "压城单位应校验失败")


func test_overlapping_cities_fail_validation() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	var player_city: Dictionary = doc.get_city(0, "player")
	var scenario: Dictionary = doc.get_scenario(0)
	var enemy_city: Dictionary = scenario.get("enemy_city", {})
	enemy_city["q"] = int(player_city.get("q", 0))
	enemy_city["r"] = int(player_city.get("r", 0))
	doc.mark_dirty()
	var errors: Array[String] = doc.validate_document()
	assert_true(_contains_text(errors, "不能重叠"), "重叠城池应校验失败")


func test_mechanics_text_round_trip() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	doc.set_scenario_mechanics_from_text(0, "火攻\n伏击\n\n补给")
	assert_eq(doc.get_scenario_mechanics_text(0), "火攻\n伏击\n补给")


func test_save_and_reload_round_trip() -> void:
	var doc: SkirmishScenarioDocument = _load_doc()
	var new_index: int = doc.create_new_scenario()
	doc.set_scenario_field(new_index, "name", "回写测试")
	var save_result: Dictionary = doc.save_to_path(_temp_path)
	assert_true(bool(save_result.get("ok", false)), "临时保存应成功")
	var reloaded: SkirmishScenarioDocument = DocumentScript.new()
	assert_true(reloaded.load_from_path(_temp_path), "应能重新读取保存结果")
	assert_eq(reloaded.get_scenario_count(), doc.get_scenario_count())
	assert_eq(str(reloaded.get_scenario(new_index).get("name", "")), "回写测试")


func _contains_text(lines: Array[String], needle: String) -> bool:
	for line: String in lines:
		if line.contains(needle):
			return true
	return false
