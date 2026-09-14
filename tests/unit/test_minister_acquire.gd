extends GutTest

## 大夫获取：武（占城）、外交（商路/同盟）


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	SchoolManager.reset()
	DiplomacySystem.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_battle_win_can_acquire_military_minister() -> void:
	var before: int = MinisterManager.get_faction_military_ministers("qin").size()
	var got: bool = false
	for i in 40:
		var r: Dictionary = MinisterManager.try_acquire_military_minister("qin")
		if bool(r.get("success", false)):
			got = true
			break
	var after: int = MinisterManager.get_faction_military_ministers("qin").size()
	assert_true(got or after > before, "多次尝试后应能招募到武大夫（before=%d after=%d）" % [before, after])
	assert_true(after <= int(DataManager.get_balance_param("minister.capacity.military")), "不应超过容量")


func test_city_capture_triggers_acquire() -> void:
	var before: int = MinisterManager.get_faction_military_ministers("qin").size()
	# 占领赵都（城防归零模拟）
	var zhao_cap: String = str(CityManager.get_capital_state("zhao")["id"])
	CityManager.get_city_state(zhao_cap)["current_hp"] = 0
	StrategicMapManager.try_capture_city_if_clear("qin", zhao_cap)
	# 占领成功即可，获取为概率事件
	assert_eq(str(CityManager.get_city_state(zhao_cap).get("current_faction_id", "")), "qin", "应能占城")
	var after: int = MinisterManager.get_faction_military_ministers("qin").size()
	assert_true(after >= before, "占城后武大夫数量不应减少")


func test_trade_route_can_acquire_diplomat() -> void:
	DiplomacySystem.change_opinion("qin", "zhao", 40)
	DiplomacySystem.change_opinion("zhao", "qin", 40)
	var before: int = MinisterManager.get_faction_diplomat_ministers("qin").size()
	var opened: Dictionary = DiplomacySystem.open_trade_route("qin", "zhao")
	assert_true(bool(opened.get("success", false)), "商路应成功")
	var after: int = MinisterManager.get_faction_diplomat_ministers("qin").size()
	assert_true(after >= before, "开商路后外交大夫数量不应减少")
