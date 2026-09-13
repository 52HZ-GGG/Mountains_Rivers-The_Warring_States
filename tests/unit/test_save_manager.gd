extends GutTest

## SaveManager 完整单槽存档往返测试


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	SchoolManager.reset()
	WonderManager.reset()
	TechSystem.reset()
	DiplomacySystem.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_quick_save_and_load_restores_core_state() -> void:
	# 造一段可识别状态
	CityManager.get_city_state("xianyang")["conscription_pool"] = 7
	CityManager.get_city_state("handan")["current_faction_id"] = "qin"
	CityManager._build_faction_index()
	GameManager.apply_gold_delta(123)
	GameManager.set_tax_rate(0.4)
	SchoolManager.add_school_exp("qin", 60)
	TechSystem._researched_techs["sericulture"] = true
	TechSystem._apply_tech_effects("sericulture")
	var result: Dictionary = SaveManager.quick_save()
	assert_true(bool(result.get("success", false)), "快速存档应成功")

	# 打乱状态
	CityManager.get_city_state("xianyang")["conscription_pool"] = 0
	GameManager.apply_gold_delta(-GameManager.get_player_gold())
	SchoolManager.reset()
	TechSystem.reset()

	var load_result: Dictionary = SaveManager.quick_load()
	assert_true(bool(load_result.get("success", false)), "读档应成功，reason=%s" % str(load_result.get("reason", "")))
	assert_eq(CityManager.get_conscription_pool("xianyang"), 7, "读档应恢复征兵池")
	assert_eq(str(CityManager.get_city_state("handan").get("current_faction_id", "")), "qin", "读档应恢复城市归属")
	assert_eq(GameManager.get_tax_rate(), 0.4, "读档应恢复税率")
	assert_eq(SchoolManager.get_school_exp("qin"), 60, "读档应恢复学派经验")
	assert_true(TechSystem.is_researched("sericulture"), "读档应恢复已研究科技")


func test_save_summary_not_empty() -> void:
	SaveManager.quick_save()
	var summary: String = SaveManager.get_summary()
	assert_true(summary != "无存档", "有存档时摘要应非空")
	assert_true(SaveManager.format_slots_text().length() > 0, "槽位列表文本应非空")


func test_multi_slot_save_and_auto_slot() -> void:
	GameManager.apply_gold_delta(50)
	var r0: Dictionary = SaveManager.save_to_slot(0)
	assert_true(bool(r0.get("success", false)), "槽位 1 应可保存")
	GameManager.apply_gold_delta(50)
	var r1: Dictionary = SaveManager.save_to_slot(1)
	assert_true(bool(r1.get("success", false)), "槽位 2 应可保存")
	var gold_mid: int = GameManager.get_player_gold()
	SaveManager.load_from_slot(0)
	var gold_slot0: int = GameManager.get_player_gold()
	assert_true(gold_slot0 < gold_mid, "读槽位 1 应回到较早金钱状态")
	SaveManager.save_to_slot(SaveManager.AUTO_SLOT)
	assert_true(SaveManager.has_save(SaveManager.AUTO_SLOT), "自动槽应存在")
	var slots: Array = SaveManager.list_slots()
	assert_true(slots.size() >= 4, "应包含 3 手动槽 + 自动槽")
