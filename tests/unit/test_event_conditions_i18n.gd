extends GutTest


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	TechSystem.reset()
	SchoolManager.reset()
	DiplomacySystem.reset()
	DisasterManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao", "qi", "chu", "wei"], "qin")


func test_tribute_min_blocks_low_tribute() -> void:
	var ok: bool = EventManager._check_conditions({"tribute_min": 80}, 1, "qin")
	assert_false(ok, "朝贡度不足时 tribute_min 应失败")
	DiplomacySystem.set_tribute("qin", 85)
	ok = EventManager._check_conditions({"tribute_min": 80}, 1, "qin")
	assert_true(ok, "朝贡度达标后应通过")


func test_reputation_min_blocks_low_rep() -> void:
	var ok: bool = EventManager._check_conditions({"reputation_min": 80}, 1, "qin")
	assert_false(ok, "声望不足时 reputation_min 应失败")
	DiplomacySystem._change_reputation("qin", 50)
	ok = EventManager._check_conditions({"reputation_min": 80}, 1, "qin")
	assert_true(ok, "声望达标后应通过")


func test_reputation_min_any_faction() -> void:
	var ok: bool = EventManager._check_conditions({"reputation_min_any_faction": 90}, 1, "qin")
	assert_false(ok, "无人达标时应失败")
	DiplomacySystem._change_reputation("zhao", 50)
	ok = EventManager._check_conditions({"reputation_min_any_faction": 90}, 1, "qin")
	assert_true(ok, "任意国家达标即通过")


func test_faction_exists_blocks_eliminated() -> void:
	assert_true(EventManager._check_conditions({"faction_exists": "zhao"}, 1, "qin"))
	for city in CityManager.get_faction_cities("zhao").duplicate():
		CityManager.occupy_city(str(city.get("id", "")), "qin")
	assert_false(EventManager._check_conditions({"faction_exists": "zhao"}, 1, "qin"), "已灭国应失败")


func test_hezong_active_flag_condition() -> void:
	assert_false(EventManager._check_conditions({"hezong_active": true}, 1, "qin"))
	DiplomacySystem.set_event_chain_flag("hezong_active", true)
	assert_true(EventManager._check_conditions({"hezong_active": true}, 1, "qin"))


func test_guest_house_grants_intelligence() -> void:
	DiplomacySystem.change_opinion("qin", "zhao", 40)
	var cities: Array = CityManager.get_faction_cities("qin")
	assert_false(cities.is_empty())
	var city_id: String = str(cities[0].get("id", ""))
	var state: Dictionary = CityManager.get_city_state(city_id)
	state["buildings"] = [{"building_id": "guest_house", "level": 1}]
	var before: int = DiplomacySystem.get_intelligence_points("qin", "zhao")
	DiplomacySystem._apply_building_diplomacy_effects()
	var after: int = DiplomacySystem.get_intelligence_points("qin", "zhao")
	assert_gt(after, before, "驿馆应提升情报力 before=%d after=%d" % [before, after])


func test_city_i18n_keys_exist() -> void:
	assert_true(I18n.has_key("city.back_to_map"))
	assert_true(I18n.has_key("city.upgrade"))
	assert_true(I18n.has_key("city.recruit_one"))
	assert_eq(I18n.t("city.upgrade"), "升级")
