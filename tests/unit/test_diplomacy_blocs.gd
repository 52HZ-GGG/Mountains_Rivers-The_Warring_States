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


func test_casus_belli_grant_and_consume() -> void:
	DiplomacySystem.grant_casus_belli("qin", "zhao", "border_conflict")
	assert_true(DiplomacySystem.has_casus_belli("qin", "zhao"), "应记录战争借口")
	assert_eq(DiplomacySystem.get_casus_belli("qin", "zhao"), "border_conflict")
	var source: String = DiplomacySystem.consume_casus_belli("qin", "zhao")
	assert_eq(source, "border_conflict", "宣战应消耗借口")
	assert_false(DiplomacySystem.has_casus_belli("qin", "zhao"), "消耗后不应再有借口")


func test_declare_war_with_cb_reduces_reputation_penalty() -> void:
	var rep_before: int = DiplomacySystem.get_reputation("qin")
	var war_no_cb: Dictionary = DiplomacySystem.declare_war("qin", "zhao")
	assert_true(bool(war_no_cb.get("success", false)))
	var rep_after_no_cb: int = DiplomacySystem.get_reputation("qin")
	assert_lt(rep_after_no_cb, rep_before, "无借口宣战应降声望")

	# 重置战争状态后用借口再测
	DiplomacySystem.reset()
	DiplomacySystem.initialize(["qin", "zhao", "qi", "chu", "wei"] as Array[String])
	rep_before = DiplomacySystem.get_reputation("qin")
	DiplomacySystem.grant_casus_belli("qin", "zhao", "revenge")
	var war_cb: Dictionary = DiplomacySystem.declare_war("qin", "zhao")
	assert_true(bool(war_cb.get("success", false)))
	assert_eq(str(war_cb.get("casus_belli", "")), "revenge")
	var rep_after_cb: int = DiplomacySystem.get_reputation("qin")
	assert_gt(rep_after_cb, rep_after_no_cb, "有借口宣战声望损失应更小")


func test_form_hezong_requires_members_and_declares_war() -> void:
	var result: Dictionary = DiplomacySystem.form_hezong("qi", "qin", ["zhao"])
	assert_false(bool(result.get("success", false)), "3国合纵需2个盟友，1个应失败")

	result = DiplomacySystem.form_hezong("qi", "qin", ["zhao", "chu"])
	assert_true(bool(result.get("success", false)), "reason=%s" % str(result.get("reason", "")))
	assert_true(DiplomacySystem.is_in_hezong("qi"))
	assert_true(DiplomacySystem.is_in_hezong("zhao"))
	assert_true(DiplomacySystem.are_at_war("qi", "qin"), "合纵应对目标宣战")
	assert_true(DiplomacySystem.are_at_war("zhao", "qin"))
	assert_true(DiplomacySystem.are_allied("qi", "zhao"), "成员间应强制同盟")


func test_hezong_dissolves_after_duration() -> void:
	var params: Dictionary = DataManager.get_diplomacy_param("hezong_lianheng")
	var duration: int = int(params.get("hezong_duration", 10))
	DiplomacySystem.form_hezong("qi", "qin", ["zhao", "chu"])
	for i in range(duration):
		DiplomacySystem._tick_hezong_lianheng()
	assert_false(DiplomacySystem.is_in_hezong("qi"), "到期后合纵应解散")
	assert_false(DiplomacySystem.are_allied("qi", "zhao"), "强制同盟应随合纵解除")


func test_form_lianheng_joins_two_against_target() -> void:
	var result: Dictionary = DiplomacySystem.form_lianheng("qin", "qi", "zhao")
	assert_true(bool(result.get("success", false)), "reason=%s" % str(result.get("reason", "")))
	assert_true(DiplomacySystem.is_in_lianheng("qin"))
	assert_true(DiplomacySystem.is_in_lianheng("zhao"))
	assert_true(DiplomacySystem.are_at_war("qin", "qi"))
	assert_true(DiplomacySystem.are_at_war("zhao", "qi"))
	assert_true(DiplomacySystem.are_allied("qin", "zhao"))


func test_strategist_ability_consumes_gold_and_once() -> void:
	GameManager.apply_gold_delta(500)
	var result: Dictionary = DiplomacySystem.activate_lianheng_ability("qin", "qi", "zhao")
	assert_true(bool(result.get("success", false)), "reason=%s" % str(result.get("reason", "")))
	var again: Dictionary = DiplomacySystem.activate_lianheng_ability("qin", "qi", "chu")
	assert_false(bool(again.get("success", false)), "每局仅限一次")
	assert_eq(str(again.get("reason", "")), "already_used")


func test_restoration_eligible_and_force_success() -> void:
	# 模拟灭国：先复制列表，避免 occupy 过程中改 faction 索引导致漏城
	var zhao_cities: Array = CityManager.get_faction_cities("zhao").duplicate()
	for city in zhao_cities:
		CityManager.occupy_city(str(city.get("id", "")), "qin")
	assert_true(CityManager.is_faction_eliminated("zhao"), "应已清空赵国城池")
	DisasterManager._on_faction_eliminated("zhao")
	assert_true(DisasterManager._eliminated_memory.has("zhao"), "灭国应写入记忆")

	# 强制成功（force_rng 跳过 min_turn）
	var result: Dictionary = DisasterManager.attempt_restoration("zhao", 0.0)
	assert_true(bool(result.get("success", false)), "reason=%s" % str(result.get("reason", "")))
	assert_false(CityManager.is_faction_eliminated("zhao"), "复国后应持有城池")
	assert_true(DisasterManager.get_restored_factions().has("zhao"))


func test_restoration_fails_without_memory() -> void:
	var result: Dictionary = DisasterManager.attempt_restoration("chu", 0.0)
	assert_false(bool(result.get("success", false)))
	assert_eq(str(result.get("reason", "")), "not_eligible")


func test_disaster_save_round_trip() -> void:
	DiplomacySystem.grant_casus_belli("qin", "zhao", "border_conflict")
	DiplomacySystem.form_lianheng("qin", "qi", "zhao")
	var save: Dictionary = DiplomacySystem.get_save_data()
	DiplomacySystem.reset()
	DiplomacySystem.load_save_data(save)
	assert_true(DiplomacySystem.has_casus_belli("qin", "zhao"), "存档应恢复战争借口")
	assert_true(DiplomacySystem.is_in_lianheng("qin"), "存档应恢复连横")
