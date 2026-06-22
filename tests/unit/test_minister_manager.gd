extends GutTest


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	TechSystem.reset()
	EventManager.set_muted(true)


func test_initialize_factions_assigns_civil_minister_to_capital() -> void:
	GameManager.start_game(["qin", "zhao"], "qin")
	var capital_id: String = str(CityManager.get_capital_state("qin").get("id", ""))
	var minister: Dictionary = MinisterManager.get_city_civil_minister(capital_id)
	assert_false(minister.is_empty(), "开局应给势力初始化并派驻一名文大夫")
	assert_eq(str(minister.get("faction_id", "")), "qin")


func test_city_minister_increases_gold_or_stability_effects() -> void:
	GameManager.start_game(["qin", "zhao"], "qin")
	var capital_id: String = str(CityManager.get_capital_state("qin").get("id", ""))
	assert_gt(MinisterManager.get_city_gold_bonus(capital_id), 0.0, "文大夫应提供理财加成")
	assert_gt(MinisterManager.get_city_stability_bonus(capital_id), 0, "文大夫应提供安民加成")


func test_minister_corruption_reduction_applies_for_assigned_city() -> void:
	GameManager.start_game(["qin", "zhao"], "qin")
	var reduction: float = MinisterManager.get_faction_corruption_reduction("qin")
	assert_gte(reduction, 0.0, "已派驻文大夫时应能统计肃贪减腐")


func test_city_lost_clears_assignment() -> void:
	GameManager.start_game(["qin", "zhao"], "qin")
	var capital_id: String = str(CityManager.get_capital_state("qin").get("id", ""))
	assert_false(MinisterManager.get_city_civil_minister(capital_id).is_empty(), "城破前应有驻城文大夫")
	CityManager.change_ownership(capital_id, "zhao")
	assert_true(MinisterManager.get_city_civil_minister(capital_id).is_empty(), "城破后不应残留原驻城文大夫绑定")
