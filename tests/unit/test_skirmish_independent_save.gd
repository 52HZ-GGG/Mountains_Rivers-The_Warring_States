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


func test_campaign_save_unaffected_by_skirmish_activity() -> void:
	TacticalSkirmishManager.start_skirmish()
	var camp: Dictionary = SaveManager.build_save_data()
	assert_false(camp.has("skirmish_units"))
	assert_true(camp.has("cities"))
	assert_true(camp.has("strategic_units"))
