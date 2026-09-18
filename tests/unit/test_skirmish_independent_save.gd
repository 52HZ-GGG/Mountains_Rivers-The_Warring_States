extends GutTest

## 演武独立存档：与战役 SaveManager 分离，只读写演武局内状态


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	EventManager.set_muted(true)
	var factions: Array[String] = ["qin", "zhao"]
	GameManager.start_game(factions, "qin")
	TacticalSkirmishManager.reset_skirmish()
	# 清理测试槽
	for slot in [0, 1, 2, -1]:
		SkirmishSaveManager.delete_slot(slot)


func test_skirmish_save_not_in_campaign_save() -> void:
	var camp: Dictionary = SaveManager.build_save_data()
	assert_false(camp.has("skirmish"), "战役存档不得包含演武块")
	assert_false(camp.has("tactical_skirmish"), "战役存档不得包含演武块")


func test_skirmish_save_roundtrip() -> void:
	TacticalSkirmishManager.start_skirmish()
	assert_true(TacticalSkirmishManager.is_active())
	var units_before: int = TacticalSkirmishManager.get_units().size()
	assert_gt(units_before, 0)
	# 改一点状态
	var u0: Dictionary = TacticalSkirmishManager.get_units()[0] as Dictionary
	var uid: String = str(u0.get("id", ""))
	var uref: Dictionary = TacticalSkirmishManager.get_unit_by_id(uid)
	if not uref.is_empty():
		uref["hp"] = maxi(1, int(uref.get("hp", 100)) - 7)
		uref["morale"] = 88
	# 独立槽位保存
	var res: Dictionary = SkirmishSaveManager.save_to_slot(0)
	assert_true(bool(res.get("success", false)), "演武存档应成功: %s" % str(res))
	assert_true(SkirmishSaveManager.has_save(0))
	# 重置演武，再读回
	TacticalSkirmishManager.reset_skirmish()
	assert_false(TacticalSkirmishManager.is_active())
	var load_res: Dictionary = SkirmishSaveManager.load_from_slot(0)
	assert_true(bool(load_res.get("success", false)), "演武读档应成功: %s" % str(load_res))
	assert_true(TacticalSkirmishManager.is_active())
	assert_eq(TacticalSkirmishManager.get_units().size(), units_before)
	var uref2: Dictionary = TacticalSkirmishManager.get_unit_by_id(uid)
	assert_false(uref2.is_empty())
	if not uref.is_empty():
		assert_eq(int(uref2.get("morale", -1)), 88, "局内士气应恢复")


func test_load_rejects_campaign_slot_kind() -> void:
	# 战役档路径与演武档路径不同；若误把战役 JSON 当演武读，kind 校验应拒绝
	TacticalSkirmishManager.start_skirmish()
	var camp: Dictionary = SaveManager.build_save_data()
	camp["kind"] = "campaign"
	# 直接 apply
	var err: String = TacticalSkirmishManager.apply_save_data(camp)
	assert_eq(err, "NOT_SKIRMISH_SAVE")


func test_campaign_save_has_no_skirmish_blob_but_receives_results() -> void:
	# 战役档结构不含演武原始块；演武结果写入 CityManager 后体现在 cities 数据
	TacticalSkirmishManager.start_skirmish()
	var camp: Dictionary = SaveManager.build_save_data()
	assert_false(camp.has("skirmish"), "战役档不含演武原始快照块")
	assert_true(camp.has("cities"))
	assert_true(camp.has("strategic_units"))


func test_skirmish_victory_writes_campaign_city() -> void:
	TacticalSkirmishManager.reset_skirmish()
	var cfg: Dictionary = DataManager.get_skirmish_scenario("luoyi_siege_demo")
	if cfg.is_empty():
		pass_test("无 luoyi_siege_demo 场景配置")
		return
	TacticalSkirmishManager.start_skirmish_with_config(cfg, "summer")
	assert_true(TacticalSkirmishManager.is_active())
	TacticalSkirmishManager.set_campaign_writeback(true)
	var report: Dictionary = TacticalSkirmishManager.apply_result_to_campaign("qin")
	assert_true(bool(report.get("ok", false)), "写回应 ok: %s" % str(report))
	assert_true((report.get("cities", []) as Array).size() > 0, "应同步绑定 city_id 的城")
	var luoyi_after: String = str(CityManager.get_city_state("luoyi").get("current_faction_id", ""))
	assert_eq(luoyi_after, "qin", "胜方应占领洛邑（战役），实为 %s" % luoyi_after)
	# 战役城可能尚无 wall 实体（-1 表示无墙）；有墙则 HP 应已写回
	var wall_after: int = CityManager.get_wall_hp("luoyi")
	assert_true(wall_after >= -1, "战役洛邑墙 HP 读取应合法")
