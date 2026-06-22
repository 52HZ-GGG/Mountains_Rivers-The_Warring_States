extends GutTest


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	TechSystem.reset()
	SchoolManager.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_send_hostage_updates_runtime_state() -> void:
	SchoolManager.add_school_exp("qin", 60)
	var minister_id: String = str(MinisterManager.get_faction_civil_ministers("qin")[0].get("id", ""))
	assert_ne(minister_id, "", "开局应存在可送出的文大夫")
	var result: Dictionary = DiplomacySystem.send_hostage("qin", "zhao", minister_id)
	assert_true(bool(result.get("success", false)), "送质子应成功")
	assert_true(DiplomacySystem.has_hostage("qin"), "送质子后应记录质子状态")
	var hostage: Dictionary = DiplomacySystem.get_hostage("qin")
	assert_eq(str(hostage.get("minister_id", "")), minister_id, "质子状态应记录对应大夫")
	assert_eq(str(MinisterManager.get_minister(minister_id).get("status", "")), "hostage", "大夫状态应切换为 hostage")


func test_release_prisoners_clears_runtime_state() -> void:
	DiplomacySystem.add_prisoner("zhao", "prisoner_1")
	var result: Dictionary = DiplomacySystem.release_prisoners("qin", "zhao")
	assert_true(bool(result.get("success", false)), "释放俘虏应成功")
	assert_true(result.get("prisoners", []).size() == 1, "应返回被释放俘虏列表")
	assert_eq(DiplomacySystem.get_prisoners("zhao").size(), 0, "释放后俘虏应清空")


func test_vassal_tribute_ticks_on_turn_end() -> void:
	GameManager.apply_gold_delta(200)
	GameManager.apply_food_delta(200)
	DiplomacySystem._establish_vassal("zhao", "qin")
	var master_gold_before: int = GameManager.get_faction_resource("qin", "gold")
	var vassal_gold_before: int = GameManager.get_faction_resource("zhao", "gold")
	DiplomacySystem._settle_vassal_tribute()
	assert_lt(GameManager.get_faction_resource("zhao", "gold"), vassal_gold_before, "附庸朝贡应减少宗主国的金钱池")
	assert_gt(GameManager.get_faction_resource("qin", "gold"), master_gold_before, "附庸朝贡应增加宗主国的金钱池")


func test_diplomacy_state_can_round_trip_through_save_data() -> void:
	SchoolManager.add_school_exp("qin", 60)
	var minister_id: String = str(MinisterManager.get_faction_civil_ministers("qin")[0].get("id", ""))
	DiplomacySystem.send_hostage("qin", "zhao", minister_id)
	DiplomacySystem.add_prisoner("qin", minister_id)
	DiplomacySystem.set_tribute("qin", 42)
	DiplomacySystem.set_intelligence_points("qin", "zhao", 55, 3)
	var save_data: Dictionary = DiplomacySystem.get_save_data()
	DiplomacySystem.reset()
	DiplomacySystem.load_save_data(save_data)
	assert_true(DiplomacySystem.has_hostage("qin"), "读回后应恢复质子状态")
	assert_eq(DiplomacySystem.get_prisoners("qin").size(), 1, "读回后应恢复俘虏状态")
	assert_eq(DiplomacySystem.get_tribute("qin"), 42, "读回后应恢复朝贡状态")
	assert_eq(DiplomacySystem.get_intelligence_points("qin", "zhao"), 55, "读回后应恢复情报点数")
	assert_eq(DiplomacySystem.get_intelligence_level("qin", "zhao"), 2, "读回后应恢复情报等级")


func test_intelligence_points_recover_after_ceasefire() -> void:
	DiplomacySystem.set_intelligence_points("qin", "zhao", 55, 2)
	DiplomacySystem.declare_war("qin", "zhao")
	assert_eq(DiplomacySystem.get_intelligence_points("qin", "zhao"), 0, "宣战后情报力应归零")
	DiplomacySystem.accept_ceasefire("qin", "zhao", {})
	GameManager.end_current_turn()
	GameManager.end_current_turn()
	assert_gt(DiplomacySystem.get_intelligence_points("qin", "zhao"), 0, "停战后情报力应逐步恢复")


func test_intelligence_points_reduce_to_zero_during_war_and_recover_after_ceasefire() -> void:
	DiplomacySystem.set_intelligence_points("qin", "zhao", 55, 2)
	DiplomacySystem.declare_war("qin", "zhao")
	assert_eq(DiplomacySystem.get_intelligence_points("qin", "zhao"), 0, "宣战后情报力应归零")
	GameManager.end_current_turn()
	GameManager.end_current_turn()
	DiplomacySystem.accept_ceasefire("qin", "zhao", {})
	assert_gt(DiplomacySystem.get_intelligence_points("qin", "zhao"), 0, "停战后情报力应逐步恢复")
