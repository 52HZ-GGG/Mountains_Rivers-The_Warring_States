extends GutTest

const CombatCtxLib := preload("res://scripts/systems/combat_ctx_builder.gd")


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


func test_demo_victory_writeback() -> void:
	DemoFlow.reset()
	DemoFlow.set_enabled(true)
	var target: String = str(DemoFlow.get_target_city_id())
	assert_eq(target, "luoyi")
	var ok: bool = DemoFlow.apply_skirmish_victory("qin")
	assert_true(ok, "demo victory should apply")
	var city: Dictionary = CityManager.get_city_state("luoyi")
	assert_eq(str(city.get("current_faction_id", "")), "qin", "luoyi owner should be qin")
	assert_true(DiplomacySystem.get_save_data() is Dictionary)


func test_culture_mismatch_def_ctx_readonly() -> void:
	var cities: Array = CityManager.get_faction_cities("qin")
	assert_false(cities.is_empty())
	var city_id: String = str((cities[0] as Dictionary).get("id", ""))
	var ctx_ok: Dictionary = CombatCtxLib.build_defense_ctx("qin", "infantry", city_id)
	assert_true(ctx_ok is Dictionary)
	var state: Dictionary = CityManager.get_city_state(city_id)
	var cult: Dictionary = CityManager.get_city_culture(city_id)
	cult["zhao"] = 200.0
	cult["qin"] = 1.0
	state["culture"] = cult
	state["mainstream_culture"] = CityManager._get_mainstream_culture(cult)
	assert_true(CityManager.has_culture_mismatch(city_id))
	var ctx_mis: Dictionary = CombatCtxLib.build_defense_ctx("qin", "infantry", city_id)
	var pen_v: Variant = DataManager.get_balance_param("culture.culture_mismatch_garrison_def_penalty")
	if pen_v != null:
		assert_lt(float(ctx_mis.get("faction_def", 0.0)), 0.0, "mismatch should lower def")
	var ctx_nocity: Dictionary = CombatCtxLib.build_defense_ctx("qin", "infantry", "")
	assert_true(ctx_nocity is Dictionary)


func test_demo_disables_after_reset() -> void:
	DemoFlow.reset()
	assert_false(DemoFlow.is_enabled())
