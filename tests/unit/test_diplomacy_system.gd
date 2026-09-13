extends GutTest


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	TechSystem.reset()
	SchoolManager.reset()
	DiplomacySystem.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func _raise_opinion(sender: String, receiver: String, target_min: int) -> void:
	var current: int = DiplomacySystem.get_opinion(sender, receiver)
	if current < target_min:
		DiplomacySystem.change_opinion(sender, receiver, target_min - current + 5)


func test_send_hostage_updates_runtime_state() -> void:
	_raise_opinion("qin", "zhao", int(DataManager.get_hostage_params().get("min_opinion_to_send", 20)))
	var minister_id: String = str(MinisterManager.get_faction_civil_ministers("qin")[0].get("id", ""))
	assert_ne(minister_id, "", "开局应存在可送出的文大夫")
	var result: Dictionary = DiplomacySystem.send_hostage("qin", "zhao", minister_id)
	assert_true(bool(result.get("success", false)), "送质子应成功，reason=%s" % str(result.get("reason", "")))
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
	assert_lt(GameManager.get_faction_resource("zhao", "gold"), vassal_gold_before, "附庸朝贡应减少附庸金钱池")
	assert_gt(GameManager.get_faction_resource("qin", "gold"), master_gold_before, "附庸朝贡应增加宗主国金钱池")


func test_diplomacy_state_can_round_trip_through_save_data() -> void:
	# 机制：情报力 = 好感 + 修正。本用例不送质子，避免 hostage +10 干扰
	var minister_id: String = str(MinisterManager.get_faction_civil_ministers("qin")[0].get("id", ""))
	DiplomacySystem.add_prisoner("qin", minister_id)
	DiplomacySystem.set_tribute("qin", 42)
	DiplomacySystem.set_intelligence_points("qin", "zhao", 55, 3)
	var expected_points: int = DiplomacySystem.get_intelligence_points("qin", "zhao")
	var expected_level: int = DiplomacySystem.get_intelligence_level("qin", "zhao")
	var save_data: Dictionary = DiplomacySystem.get_save_data()
	DiplomacySystem.reset()
	DiplomacySystem.load_save_data(save_data)
	assert_eq(DiplomacySystem.get_prisoners("qin").size(), 1, "读回后应恢复俘虏状态")
	assert_eq(DiplomacySystem.get_tribute("qin"), 42, "读回后应恢复朝贡状态")
	assert_eq(DiplomacySystem.get_intelligence_points("qin", "zhao"), expected_points, "读回后应恢复情报点数")
	assert_eq(DiplomacySystem.get_intelligence_level("qin", "zhao"), expected_level, "读回后应恢复情报等级")


func test_intelligence_zero_on_war_and_follows_opinion_after_ceasefire() -> void:
	# 机制：宣战归零；停战后跟随好感度恢复（情报力系统.md §9）
	DiplomacySystem.set_intelligence_points("qin", "zhao", 55, 2)
	DiplomacySystem.declare_war("qin", "zhao")
	assert_eq(DiplomacySystem.get_intelligence_points("qin", "zhao"), 0, "宣战后情报力应归零")
	var accepted: Dictionary = DiplomacySystem.accept_ceasefire("qin", "zhao", {})
	assert_true(bool(accepted.get("success", false)), "停战应成功，reason=%s" % str(accepted.get("reason", "")))
	assert_false(DiplomacySystem.are_at_war("qin", "zhao"), "停战后不应仍处于战争")
	# 宣战大幅降低好感；恢复好感后情报力应重新大于 0
	_raise_opinion("qin", "zhao", 40)
	assert_gt(DiplomacySystem.get_intelligence_points("qin", "zhao"), 0, "停战且好感恢复后情报力应大于 0")


func test_intelligence_stays_zero_while_at_war() -> void:
	DiplomacySystem.set_intelligence_points("qin", "zhao", 55, 2)
	DiplomacySystem.declare_war("qin", "zhao")
	assert_eq(DiplomacySystem.get_intelligence_points("qin", "zhao"), 0, "宣战后情报力应归零")
	GameManager.end_current_turn()
	GameManager.end_current_turn()
	assert_eq(DiplomacySystem.get_intelligence_points("qin", "zhao"), 0, "战争期间情报力保持 0")
	assert_true(DiplomacySystem.are_at_war("qin", "zhao"), "应仍处于战争")
