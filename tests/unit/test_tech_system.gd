extends GutTest


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	TechSystem.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_start_research_consumes_cost_resources_when_enough() -> void:
	var city_id: String = str(CityManager.get_capital_state("qin")["id"])
	var city: Dictionary = CityManager.get_city_state(city_id)
	(city["buildings"] as Array).append({"building_id": "scriptorium", "level": 1})
	GameManager._process_production("qin")
	GameManager.apply_gold_delta(200)
	var silk_before: int = GameManager.get_player_silk_books()
	var gold_before: int = GameManager.get_player_gold()
	var result: Dictionary = TechSystem.start_research("private_academy")
	assert_true(bool(result.get("success", false)), "资源足够时应能开始研究")
	assert_eq(GameManager.get_player_silk_books(), silk_before - 8, "开始研究时应立即扣除帛书")
	assert_eq(GameManager.get_player_gold(), gold_before - 80, "开始研究时应扣除 cost_resources.gold")


func test_start_research_rejects_when_silk_books_insufficient() -> void:
	GameManager.apply_gold_delta(500)
	var result: Dictionary = TechSystem.start_research("private_academy")
	assert_false(bool(result.get("success", false)), "帛书不足时不应开始研究")
	assert_eq(str(result.get("reason", "")), "研究资源不足")
	var missing_resources: Dictionary = result.get("missing_resources", {})
	assert_eq(int(missing_resources.get("silk_books", 0)), 8, "应返回缺少的帛书数量")


func test_city_control_special_condition_uses_real_city_ownership() -> void:
	CityManager.change_ownership("handan", "qin")
	assert_true(TechSystem._check_special_conditions(DataManager.get_tech("horse_archery")), "控制邯郸后应满足 city_control 条件")
	CityManager.change_ownership("handan", "zhao")
	assert_false(TechSystem._check_special_conditions(DataManager.get_tech("horse_archery")), "失去邯郸后不应满足 city_control 条件")


func test_region_control_special_condition_uses_border_cities() -> void:
	CityManager.change_ownership("daijun", "qin")
	CityManager.change_ownership("yunzhong", "qin")
	CityManager.change_ownership("yanmen", "qin")
	CityManager.change_ownership("shanggu", "qin")
	assert_true(TechSystem._check_special_conditions(DataManager.get_tech("great_wall")), "控制北疆四城后应满足 region_control 条件")


func test_requires_wonder_special_condition_checks_real_ownership() -> void:
	var tech: Dictionary = DataManager.get_tech("hundred_schools")
	assert_false(TechSystem._check_special_conditions(tech), "未拥有稷下学宫时不应满足 requires_wonder")
	WonderManager.set_wonder_owner("jixia_academy", "qin")
	assert_true(TechSystem._check_special_conditions(tech), "拥有稷下学宫后应满足 requires_wonder")
