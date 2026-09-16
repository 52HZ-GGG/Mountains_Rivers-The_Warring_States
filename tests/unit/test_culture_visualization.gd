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


func test_culture_coverage_ratio_exists() -> void:
	var ratio: float = CityManager.get_culture_coverage_ratio("qin")
	assert_true(ratio >= 0.0 and ratio <= 1.0, "覆盖率应在 0~1")


func test_mainstream_and_mismatch() -> void:
	var cities: Array = CityManager.get_faction_cities("qin")
	assert_false(cities.is_empty())
	var city_id: String = str(cities[0].get("id", ""))
	var state: Dictionary = CityManager.get_city_state(city_id)
	# 强制赵国主流
	var cult: Dictionary = CityManager.get_city_culture(city_id)
	cult["zhao"] = 100.0
	cult["qin"] = 1.0
	state["culture"] = cult
	state["mainstream_culture"] = CityManager._get_mainstream_culture(cult)
	assert_eq(CityManager.get_mainstream_culture(city_id), "zhao")
	assert_true(CityManager.has_culture_mismatch(city_id), "主流≠归属应冲突")


func test_culture_mainstream_changed_signal() -> void:
	var cities: Array = CityManager.get_faction_cities("zhao")
	assert_false(cities.is_empty())
	var city_id: String = str(cities[0].get("id", ""))
	var state: Dictionary = CityManager.get_city_state(city_id)
	var cult: Dictionary = CityManager.get_city_culture(city_id)
	cult["qin"] = 200.0
	state["culture"] = cult
	var got: Array = []
	var cb := func(cid: String, old_f: String, new_f: String) -> void:
		got.append([cid, old_f, new_f])
	SignalBus.culture_mainstream_changed.connect(cb)
	CityManager._apply_culture_flip(state, "qin", cult)
	SignalBus.culture_mainstream_changed.disconnect(cb)
	assert_eq(got.size(), 1, "倒戈应发出信号")
	assert_eq(str(got[0][0]), city_id)
	assert_eq(str(got[0][2]), "qin")


func test_cultural_victory_hold_turns_accessor() -> void:
	assert_eq(GameManager.get_cultural_victory_hold_turns("qin"), 0)


func test_culture_i18n_keys() -> void:
	assert_true(I18n.has_key("big_map.culture_on"))
	assert_true(I18n.has_key("city.culture_title"))
	assert_true(I18n.has_key("hud.culture_progress"))
