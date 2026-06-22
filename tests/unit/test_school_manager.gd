extends GutTest


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	SchoolManager.reset()
	TechSystem.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao", "chu"], "qin")


func test_school_state_initialized_from_default_school() -> void:
	assert_eq(SchoolManager.get_current_school("qin"), "legalism", "秦国开局应按 default_school 初始化运行时学派")
	assert_eq(SchoolManager.get_school_level("qin"), 1, "初始化时应为 1 级")
	assert_eq(SchoolManager.get_school_exp("qin"), 0, "初始化时经验应为 0")
	assert_eq(SchoolManager.get_transition_turns("qin"), 0, "初始化时不应处于过渡期")
	assert_eq(SchoolManager.get_active_policies("qin").size(), 0, "初始化时不应有激活政策")


func test_school_exp_levels_up_runtime_school() -> void:
	watch_signals(SignalBus)
	SchoolManager.add_school_exp("qin", 60)
	assert_eq(SchoolManager.get_school_level("qin"), 2, "经验达到阈值后应升到 2 级")
	assert_signal_emitted(SignalBus, "school_level_changed", "升级时应广播 school_level_changed")


func test_activate_policy_consumes_exp_and_tracks_duration() -> void:
	SchoolManager.add_school_exp("qin", 60)
	var result: Dictionary = SchoolManager.activate_policy("qin", "leg_surveillance")
	assert_true(bool(result.get("success", false)), "等级与经验足够时应能激活政策")
	assert_eq(SchoolManager.get_school_exp("qin"), 40, "激活政策应扣除对应经验")
	var policies: Array = SchoolManager.get_active_policies("qin")
	assert_eq(policies.size(), 1, "激活后应记录到运行时政策列表")
	assert_eq(int((policies[0] as Dictionary).get("turns_remaining", -1)), 5, "政策应记录持续回合")


func test_activate_policy_rejects_when_no_slot_without_spending_exp() -> void:
	SchoolManager.add_school_exp("qin", 130)
	assert_true(SchoolManager.activate_policy("qin", "leg_surveillance").get("success", false), "首个政策应可激活")
	assert_true(SchoolManager.activate_policy("qin", "gp_research").get("success", false), "第二个政策应可激活")
	assert_true(SchoolManager.activate_policy("qin", "gp_trade").get("success", false), "第三个政策应可激活")
	var exp_before: int = SchoolManager.get_school_exp("qin")
	var result: Dictionary = SchoolManager.activate_policy("qin", "gp_build")
	assert_false(bool(result.get("success", true)), "满槽时不应允许继续激活新政策")
	assert_eq(str(result.get("reason", "")), "NO_POLICY_SLOT", "满槽失败原因应明确")
	assert_eq(SchoolManager.get_school_exp("qin"), exp_before, "槽位不足时不应扣除经验")


func test_permanent_policy_counts_toward_policy_slots() -> void:
	SchoolManager.set_current_school("chu", "daoism")
	SchoolManager.add_school_exp("chu", 20)
	assert_true(SchoolManager.activate_policy("chu", "dao_hermit").get("success", false), "道家永久政策应可激活")
	assert_eq(SchoolManager.get_active_policies("chu").size(), 1, "永久政策应被记录到运行时列表")
	assert_eq(int((SchoolManager.get_active_policies("chu")[0] as Dictionary).get("turns_remaining", -1)), 0, "永久政策持续回合应为 0")
	assert_eq(SchoolManager.get_policy_slot_limit("chu"), 1, "1 级时槽位上限应为 1")
	var blocked: Dictionary = SchoolManager.activate_policy("chu", "gp_trade")
	assert_false(bool(blocked.get("success", true)), "永久政策应占用政策槽位")
	assert_eq(str(blocked.get("reason", "")), "NO_POLICY_SLOT", "满槽失败原因应明确")


func test_policy_duration_ticks_on_player_turn_start() -> void:
	SchoolManager.add_school_exp("qin", 60)
	SchoolManager.activate_policy("qin", "leg_surveillance")
	GameManager.end_current_turn()
	GameManager.end_current_turn()
	var policies: Array = SchoolManager.get_active_policies("qin")
	assert_eq(int((policies[0] as Dictionary).get("turns_remaining", -1)), 4, "轮到玩家新回合时应递减政策持续回合")


func test_policy_duration_ticks_on_ai_turn_start() -> void:
	SchoolManager.add_school_exp("zhao", 60)
	SchoolManager.activate_policy("zhao", "gp_research")
	GameManager.end_current_turn()
	var policies: Array = SchoolManager.get_active_policies("zhao")
	assert_eq(int((policies[0] as Dictionary).get("turns_remaining", -1)), 4, "AI 势力新回合开始时也应递减政策持续回合")


func test_school_switch_keeps_exp_and_clears_policies() -> void:
	SchoolManager.add_school_exp("qin", 60)
	SchoolManager.activate_policy("qin", "leg_surveillance")
	var before_exp: int = SchoolManager.get_school_exp("qin")
	var switched: bool = SchoolManager.set_current_school("qin", "confucianism")
	assert_true(switched, "切换学派应成功")
	assert_eq(SchoolManager.get_current_school("qin"), "confucianism", "切换后当前学派应更新")
	assert_eq(SchoolManager.get_school_exp("qin"), before_exp, "切换学派不应清空经验")
	assert_eq(SchoolManager.get_active_policies("qin").size(), 0, "切换学派应清空原有政策")
	assert_gt(SchoolManager.get_transition_turns("qin"), 0, "切换学派后应进入过渡期")


func test_school_state_exposed_as_runtime_snapshot() -> void:
	SchoolManager.add_school_exp("qin", 60)
	var state: Dictionary = SchoolManager.get_school_state("qin")
	assert_eq(str(state.get("current_school", "")), "legalism", "运行时快照应包含当前学派")
	assert_eq(int(state.get("level", 0)), SchoolManager.get_school_level("qin"), "快照应包含等级")
	assert_eq(int(state.get("exp", -1)), SchoolManager.get_school_exp("qin"), "快照应包含经验")
	assert_eq(int(state.get("transition_turns", -1)), SchoolManager.get_transition_turns("qin"), "快照应包含过渡回合")


func test_runtime_effects_include_level_and_policy() -> void:
	SchoolManager.add_school_exp("qin", 130)
	SchoolManager.activate_policy("qin", "leg_reform")
	assert_almost_eq(SchoolManager.get_effect_float("qin", "research_speed_bonus"), 0.60, 0.001, "法家 1~3 级科研加成应递进叠加")
	assert_almost_eq(SchoolManager.get_effect_float("qin", "all_output_bonus"), 0.20, 0.001, "激活中的变法图强应计入运行时效果")


func test_runtime_policy_effects_feed_city_economy_and_building_costs() -> void:
	var city_id: String = "xianyang"
	var city: Dictionary = CityManager.get_city_state(city_id)
	city["current_population"] = 10
	var before_build: Dictionary = CityManager.can_build(city_id, "farm")
	SchoolManager.add_school_exp("qin", 60)
	SchoolManager.activate_policy("qin", "gp_build")
	var after_build: Dictionary = CityManager.can_build(city_id, "farm")
	var before_production: Dictionary = CityManager.get_city_production(city_id)
	var after_production: Dictionary = CityManager.get_city_production(city_id)
	assert_lt(int(after_build.get("cost_gold", 0)), int(before_build.get("cost_gold", 0)), "学派建造减免应实时反映到建造成本")
	assert_gt(int(after_production.get("food", 0)), int(before_production.get("food", 0)), "学派全产出加成应实时反映到城市产出")


func test_school_state_can_round_trip_through_save_data() -> void:
	SchoolManager.add_school_exp("qin", 130)
	SchoolManager.activate_policy("qin", "leg_reform")
	var save_data: Dictionary = SchoolManager.get_save_data()
	SchoolManager.reset()
	SchoolManager.load_save_data(save_data)
	assert_eq(SchoolManager.get_current_school("qin"), "legalism", "读回后应恢复当前学派")
	assert_eq(SchoolManager.get_school_level("qin"), 3, "读回后应恢复学派等级")
	assert_eq(SchoolManager.get_school_exp("qin"), 70, "读回后应恢复学派经验")
	assert_eq(SchoolManager.get_active_policies("qin").size(), 1, "读回后应恢复激活政策")
