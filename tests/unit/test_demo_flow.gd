extends GutTest


func before_each() -> void:
	CityManager.reset()
	DemoFlow.reset()
	DemoFlow.set_enabled(true)
	DemoFlow.set_full_demo_enabled(true)


func test_demo_target_is_luoyi() -> void:
	assert_eq(DemoFlow.get_player_faction_id(), "qin")
	assert_eq(DemoFlow.get_target_city_id(), "luoyi")
	assert_eq(DemoFlow.get_target_city_name(), "洛邑")


func test_demo_first_step_is_big_map_for_full_strategy_demo() -> void:
	assert_eq(
		DemoFlow.get_current_step(),
		DemoFlow.STEP_OPEN_BIG_MAP,
		"完整 Demo 应先让玩家确认七国与中立城市都在战略层"
	)


func test_strategy_preparation_requires_map_and_capital() -> void:
	DemoFlow.mark_step_completed(DemoFlow.STEP_OPEN_BIG_MAP)
	DemoFlow.mark_strategy_prepared_if_ready()

	assert_false(DemoFlow.is_step_completed(DemoFlow.STEP_PREPARE_QIN), "只看大地图还不算完成经营准备")

	DemoFlow.mark_step_completed(DemoFlow.STEP_MANAGE_CAPITAL)
	DemoFlow.mark_strategy_prepared_if_ready()

	assert_true(DemoFlow.is_step_completed(DemoFlow.STEP_PREPARE_QIN), "看过版图和首都经营后才完成经营准备")


func test_strategy_snapshot_contains_seven_factions_and_neutral_cities() -> void:
	var snapshot: Dictionary = DemoFlow.get_strategy_snapshot()
	var city_counts: Dictionary = snapshot.get("faction_city_counts", {}) as Dictionary

	assert_eq(int(snapshot.get("active_faction_count", 0)), 7, "Demo 战略层应以完整七国为主控范围")
	assert_eq(int(snapshot.get("total_cities", 0)), 50, "Demo 战略层应加载完整 50 城")
	assert_eq(city_counts.keys().size(), 7, "七国都应持有初始城市")
	assert_gt(int(snapshot.get("neutral_city_count", 0)), 0, "Demo 应保留中立城市")
	assert_gt(int(snapshot.get("independent_city_count", 0)), 0, "洛邑等周室城市应作为非七国城市存在")


func test_demo_uses_luoyi_siege_scenario() -> void:
	var scenario_id: String = DemoFlow.get_recommended_scenario_id()
	var scenario: Dictionary = DataManager.get_skirmish_scenario(scenario_id)
	var enemy_city: Dictionary = scenario.get("enemy_city", {})
	var has_siege_unit: bool = false
	for raw_unit: Variant in scenario.get("initial_units", []):
		var unit: Dictionary = raw_unit as Dictionary
		var unit_type_id: String = str(unit.get("unit_type_id", ""))
		if unit_type_id == "battering_ram" or unit_type_id == "siege":
			has_siege_unit = true
			break

	assert_eq(scenario_id, "luoyi_siege_demo", "Demo 主线应进入洛邑攻城战，而不是基础平原战")
	assert_false(scenario.is_empty(), "洛邑攻城 Demo 场景必须存在")
	assert_eq(int(scenario.get("map_width", 0)), 9, "洛邑攻城 Demo 应使用更完整的 9x9 战场")
	assert_eq(int(enemy_city.get("level", 0)), 3, "洛邑 Demo 敌城应有城墙但不要过度拖长测试")
	assert_true(has_siege_unit, "洛邑攻城 Demo 应提供攻城器械，形成实质攻城玩法")


func test_qin_skirmish_victory_captures_luoyi() -> void:
	var changed: bool = DemoFlow.apply_skirmish_victory("qin")
	var luoyi: Dictionary = CityManager.get_city_state("luoyi")

	assert_true(changed, "秦国演武胜利应推进 Demo")
	assert_eq(luoyi.get("current_faction_id", ""), "qin", "洛邑应归秦")
	assert_true(DemoFlow.is_step_completed(DemoFlow.STEP_WIN_SKIRMISH))
	assert_true(DemoFlow.is_step_completed(DemoFlow.STEP_CAPTURE_LUOYI))
	assert_false(DemoFlow.is_demo_complete(), "战斗胜利后还需回到经营层查看结果")

	DemoFlow.mark_result_reviewed()

	assert_true(DemoFlow.is_step_completed(DemoFlow.STEP_REVIEW_RESULT))
	assert_true(DemoFlow.is_demo_complete())


func test_non_qin_skirmish_victory_does_not_complete_demo() -> void:
	var changed: bool = DemoFlow.apply_skirmish_victory("zhao")
	var luoyi: Dictionary = CityManager.get_city_state("luoyi")

	assert_false(changed, "非秦国胜利不应推进 Demo")
	assert_ne(luoyi.get("current_faction_id", ""), "qin", "洛邑不应归秦")
	assert_false(DemoFlow.is_demo_complete())


func test_disabled_demo_flow_ignores_skirmish_victory() -> void:
	DemoFlow.set_enabled(false)

	var changed: bool = DemoFlow.apply_skirmish_victory("qin")
	var luoyi: Dictionary = CityManager.get_city_state("luoyi")

	assert_false(changed, "Demo 未启用时不应推进")
	assert_ne(luoyi.get("current_faction_id", ""), "qin", "Demo 未启用时洛邑不应归秦")
	assert_false(DemoFlow.is_demo_complete())


func test_tutorial_skirmish_victory_completes_short_flow() -> void:
	DemoFlow.reset()
	DemoFlow.set_enabled(true)
	DemoFlow.set_tutorial_enabled(true)

	var changed: bool = DemoFlow.apply_skirmish_victory("qin")

	assert_true(changed, "新手教程战斗胜利应推进")
	assert_true(DemoFlow.is_step_completed(DemoFlow.STEP_CAPTURE_LUOYI), "新手教程战斗胜利后洛邑应归秦")
	assert_true(DemoFlow.is_demo_complete(), "新手教程是短流程小地图，胜利后即可完成")
