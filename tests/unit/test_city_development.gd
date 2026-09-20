extends GutTest

## 发展度公式（定稿）与政治 power=发展度


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_development_formula_levels_and_building_levels() -> void:
	var city: Dictionary = {
		"city_level": 2,
		"is_capital": false,
		"current_faction_id": "qin",
		"current_population": 8,
		"stability": 50,
		"buildings": [
			{"building_id": "farm", "level": 2},
			{"building_id": "market", "level": 1},
		],
	}
	# raw = 2×10 + (2+1)×4 + 8×0.5 + 50×0.15 = 20+12+4+7.5 → 43
	# medium 18~50 → 43
	var dev: int = CityManager.compute_city_development(city)
	assert_eq(dev, 43, "发展度=城级×10+Σ建筑等级×4+人口×0.5+安定×0.15")
	assert_true(CityManager.get_city_development_type(city) == "medium")


func test_development_capital_clamped() -> void:
	var city: Dictionary = {
		"city_level": 5,
		"is_capital": true,
		"current_faction_id": "qin",
		"current_population": 30,
		"stability": 80,
		"buildings": [
			{"building_id": "a", "level": 3},
			{"building_id": "b", "level": 3},
			{"building_id": "c", "level": 2},
		],
	}
	# raw = 50 + 8×4 + 15 + 12 = 50+32+15+12=109 → capital max 100
	assert_eq(CityManager.compute_city_development(city), 100)


func test_runtime_development_written_and_power_is_development() -> void:
	CityManager.refresh_all_city_development()
	var xianyang: Dictionary = CityManager.get_city_state("xianyang")
	assert_false(xianyang.is_empty())
	var expected: int = CityManager.compute_city_development(xianyang)
	assert_eq(int(xianyang.get("development", -1)), expected, "发展度应与公式一致")
	var cfg: Dictionary = DataManager.get_big_map_political_control()
	var power_cfg: Dictionary = cfg.get("city_power", {}) as Dictionary
	var scale: float = float(power_cfg.get("development_scale", 1.0))
	# 直接调用政治模块内部口径：power = development × scale
	var PoliticalControl := preload("res://scripts/systems/big_map_political_control.gd")
	var p: float = PoliticalControl._city_power(xianyang, power_cfg)
	assert_almost_eq(p, float(expected) * scale, 0.01, "政治 power 应等于发展度×scale")


func test_political_radius_from_development() -> void:
	var PoliticalControl := preload("res://scripts/systems/big_map_political_control.gd")
	var radius_cfg: Dictionary = DataManager.get_big_map_political_control().get("radius", {}) as Dictionary
	var city: Dictionary = {"development": 0}
	assert_eq(PoliticalControl._influence_radius(city, radius_cfg), int(radius_cfg.get("min", 2)))
	city["development"] = 40
	var r40: int = PoliticalControl._influence_radius(city, radius_cfg)
	assert_eq(r40, int(radius_cfg.get("min", 2)) + 2, "40 发展度 → min+2（per=20）")
	city["development"] = 999
	assert_eq(PoliticalControl._influence_radius(city, radius_cfg), int(radius_cfg.get("max", 7)), "不应超过 max")


func test_cities_json_has_no_static_development() -> void:
	var f: FileAccess = FileAccess.open("res://data/cities.json", FileAccess.READ)
	assert_not_null(f, "应能读 cities.json")
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	assert_true(parsed is Dictionary)
	for c in (parsed as Dictionary).get("cities", []):
		assert_false((c as Dictionary).has("development"), "cities.json 不应再含静态 development： %s" % str((c as Dictionary).get("id", "")))


func test_skirmish_and_big_map_share_political_rules() -> void:
	var rules: Dictionary = DataManager.get_big_map_political_control()
	assert_eq(str(rules.get("mode", "")), "influence")
	assert_true((rules.get("city_power", {}) as Dictionary).has("development_scale"), "应配置 development_scale")
	assert_true((rules.get("radius", {}) as Dictionary).has("per_development"), "半径应按发展度")
	var script: Script = load("res://scenes/ui/skirmish/skirmish_mvp_panel.gd")
	assert_not_null(script)
	var src: String = script.source_code
	assert_true(src.contains("BigMapPoliticalControl"), "演武政治图应共用 BigMapPoliticalControl")
	assert_true(src.contains("get_pass_ownership_list"), "演武政治图关隘源应读 TSM 盘面状态")
	assert_false(src.contains("PassManager.get_all_passes") and src.contains("_collect_skirmish_political_passes"), "不应再用战役全图 PassManager 坐标当演武关隘源")
