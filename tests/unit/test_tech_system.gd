extends GutTest


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	WonderManager.reset()
	TechSystem.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func _force_researched(tech_id: String) -> void:
	TechSystem._researched_techs[tech_id] = true


func _give_resource(resource: String, amount: int) -> void:
	GameManager.apply_faction_resource_delta("qin", resource, amount)


func test_start_research_consumes_cost_resources_when_enough() -> void:
	_force_researched("sericulture")
	_give_resource("silk_books", 20)
	_give_resource("gold", 200)
	var silk_before: int = GameManager.get_player_silk_books()
	var gold_before: int = GameManager.get_player_gold()
	var result: Dictionary = TechSystem.start_research("private_academy")
	assert_true(bool(result.get("success", false)), "资源足够且前置满足时应能开始研究，reason=%s" % str(result.get("reason", "")))
	assert_eq(GameManager.get_player_silk_books(), silk_before - 8, "开始研究时应立即扣除帛书")
	assert_eq(GameManager.get_player_gold(), gold_before - 80, "开始研究时应扣除 cost_resources.gold")


func test_start_research_rejects_when_silk_books_insufficient() -> void:
	_force_researched("sericulture")
	_give_resource("gold", 500)
	var result: Dictionary = TechSystem.start_research("private_academy")
	assert_false(bool(result.get("success", false)), "帛书不足时不应开始研究")
	assert_eq(str(result.get("reason", "")), "研究资源不足")
	var missing_resources: Dictionary = result.get("missing_resources", {})
	assert_eq(int(missing_resources.get("silk_books", 0)), 8, "应返回缺少的帛书数量")


func test_city_control_special_condition_uses_real_city_ownership() -> void:
	CityManager.change_ownership("handan", "qin")
	assert_true(TechUnlockContext.check_tech("qin", DataManager.get_tech("hu_cavalry_reform")), "控制邯郸后应满足 city_control 条件")
	CityManager.change_ownership("handan", "zhao")
	assert_false(TechUnlockContext.check_tech("qin", DataManager.get_tech("hu_cavalry_reform")), "失去邯郸后不应满足 city_control 条件")


func test_region_control_special_condition_uses_border_cities() -> void:
	CityManager.change_ownership("daijun", "qin")
	CityManager.change_ownership("yunzhong", "qin")
	CityManager.change_ownership("yanmen", "qin")
	CityManager.change_ownership("shanggu", "qin")
	assert_true(TechUnlockContext.check_tech("qin", DataManager.get_tech("great_wall")), "控制北疆四城后应满足 region_control 条件")


func test_requires_wonder_special_condition_checks_real_ownership() -> void:
	assert_false(TechUnlockContext.check_tech("qin", DataManager.get_tech("hundred_schools")), "未拥有稷下学宫时不应满足 requires_wonder")
	WonderManager.set_wonder_owner("jixia_academy", "qin")
	assert_true(TechUnlockContext.check_tech("qin", DataManager.get_tech("hundred_schools")), "拥有稷下学宫后应满足 requires_wonder")


func test_mutual_exclusion_hard_lock_blocks_peer() -> void:
	TechSystem._researched_techs["agriculture_priority"] = true
	var check: Dictionary = TechSystem.can_research("commerce_priority")
	assert_false(bool(check.get("can_research", true)), "互斥科技不可同时研究")
	assert_eq(str(check.get("locked_by_mutual_exclusion", "")), "agriculture_priority", "应标记互斥对象")
	var start: Dictionary = TechSystem.start_research("commerce_priority")
	assert_false(bool(start.get("success", false)), "互斥科技开始研究应失败")


func test_cost_gold_fallback_consumes_gold_when_no_cost_resources() -> void:
	_give_resource("gold", 200)
	var gold_before: int = GameManager.get_player_gold()
	var result: Dictionary = TechSystem.start_research("formation_tactics")
	assert_true(bool(result.get("success", false)), "金币足够时应能开始研究无资源成本科技，reason=%s" % str(result.get("reason", "")))
	assert_eq(GameManager.get_player_gold(), gold_before - 100, "应回退扣除 cost_gold")


func test_attack_modifier_all_target_not_doubled() -> void:
	TechEffects.apply_tech("qin", DataManager.get_tech("iron_forging"))  # all +0.05
	assert_almost_eq(TechEffects.attack_modifier("qin", "all"), 0.05, 0.001, "target=all 不应双计")
	assert_almost_eq(TechEffects.attack_modifier("qin", "infantry"), 0.05, 0.001, "分类查询应含 all 且仅一次")
	TechEffects.apply_tech("qin", DataManager.get_tech("crossbow_improved"))  # 需前置，直接写效果
	TechEffects.accumulate_effect("qin", {"type": "attack_bonus", "target": "crossbow", "value": 0.15})
	assert_almost_eq(TechEffects.attack_modifier("qin", "crossbow"), 0.20, 0.001, "分类=分类+all")


func test_cancel_research_refunds_resources() -> void:
	_force_researched("sericulture")
	_give_resource("silk_books", 20)
	_give_resource("gold", 200)
	var silk_before: int = GameManager.get_player_silk_books()
	var gold_before: int = GameManager.get_player_gold()
	var result: Dictionary = TechSystem.start_research("private_academy")
	assert_true(bool(result.get("success", false)))
	assert_eq(GameManager.get_player_silk_books(), silk_before - 8)
	TechSystem.cancel_research()
	assert_eq(GameManager.get_player_silk_books(), silk_before, "取消研究应退还帛书")
	assert_eq(GameManager.get_player_gold(), gold_before, "取消研究应退还金币")


func test_ai_research_accumulates_into_tech_effects_fascade() -> void:
	TechSystem.start_ai_research("zhao", "iron_forging")
	assert_true(TechSystem.get_ai_researched_techs("zhao").has("iron_forging"), "AI 应完成铁兵锻造")
	assert_almost_eq(TechEffects.attack_modifier("zhao", "all"), 0.05, 0.001, "AI 科技应写入 TechEffects 势力桶")
	assert_almost_eq(TechEffects.attack_modifier("qin", "all"), 0.0, 0.001, "玩家桶不应被 AI 科技污染")


func test_player_research_writes_to_tech_effects() -> void:
	_give_resource("gold", 200)
	var result: Dictionary = TechSystem.start_research("iron_forging")
	assert_true(bool(result.get("success", false)), "应能开始研究铁兵锻造")
	# 强制完成
	TechSystem._research_progress = TechSystem._research_cost_turns
	TechSystem._complete_research()
	assert_true(TechSystem.is_researched("iron_forging"), "研究应完成")
	assert_almost_eq(TechEffects.attack_modifier("qin", "all"), 0.05, 0.001, "玩家研究应写入 TechEffects")


func test_synergy_activates_when_required_techs_researched() -> void:
	TechSystem._researched_techs["formation_tactics"] = true
	TechSystem._researched_techs["iron_armor"] = true
	TechSystem._apply_all_synergies()
	var active: Array = TechSystem.get_active_synergies()
	var found := false
	for s in active:
		if str(s.get("id", "")) == "synergy_infantry_master":
			found = true
	assert_true(found, "步兵协同应在前置科技齐全后激活")
	assert_almost_eq(TechEffects.attack_modifier("qin", "infantry"), 0.1, 0.001, "协同应写入门面并提供步兵攻击")


func test_tech_effects_isolated_from_research_state_machine() -> void:
	TechEffects.apply_tech("qin", DataManager.get_tech("city_defense"))
	assert_almost_eq(TechEffects.city_defense_bonus("qin"), 0.15, 0.001, "门面应独立累加城防科技")
	assert_false(TechSystem.is_researched("city_defense"), "直接写门面不应标记为已研究")


func test_school_research_speed_via_runtime_layer() -> void:
	TechEffects.set_runtime_bonus("qin", "research_speed_modifier", 0.3)
	assert_almost_eq(TechEffects.research_speed_modifier("qin"), 0.3, 0.001, "学派运行时科研速度应叠加到门面")
	TechEffects.apply_tech("qin", DataManager.get_tech("textual_legacy"))  # research_speed +0.15
	assert_almost_eq(TechEffects.research_speed_modifier("qin"), 0.45, 0.001, "科技+学派科研速度应叠加")


func test_mastery_upgrade_after_research() -> void:
	TechSystem._researched_techs["iron_forging"] = true
	_give_resource("gold", 500)
	_give_resource("refined_iron", 10)
	_give_resource("silk_books", 20)
	var before: float = TechEffects.attack_modifier("qin", "all")
	var check: Dictionary = TechSystem.can_upgrade_mastery("iron_forging")
	assert_true(bool(check.get("can_upgrade", false)), "已研究且资源足够时应可升精通，reason=%s" % str(check.get("reason", "")))
	var result: Dictionary = TechSystem.upgrade_mastery("iron_forging")
	assert_true(bool(result.get("success", false)), "精通升级应成功")
	assert_eq(TechSystem.get_mastery_level("iron_forging"), 1, "精通等级应变为1")
	assert_almost_eq(TechEffects.attack_modifier("qin", "all"), before + 0.02, 0.001, "精通应叠加攻击增量")
