extends GutTest

## 武/外交大夫最小闭环


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	SchoolManager.reset()
	DiplomacySystem.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_initialize_creates_military_and_diplomat() -> void:
	var mil: Array = MinisterManager.get_faction_military_ministers("qin")
	var dip: Array = MinisterManager.get_faction_diplomat_ministers("qin")
	assert_gt(mil.size(), 0, "应生成武大夫")
	assert_gt(dip.size(), 0, "应生成外交大夫")
	assert_eq(str((mil[0] as Dictionary).get("type", "")), "military")
	assert_eq(str((dip[0] as Dictionary).get("type", "")), "diplomat")


func test_military_bonus_is_non_negative() -> void:
	var atk: float = MinisterManager.get_faction_military_attack_bonus("qin")
	var def: float = MinisterManager.get_faction_military_defense_bonus("qin")
	assert_true(atk >= 0.0, "勇武加成不应为负")
	assert_true(def >= 0.0, "韬略加成不应为负")


func test_diplomat_assign_and_bonuses() -> void:
	var dip: Array = MinisterManager.get_faction_diplomat_ministers("qin")
	assert_gt(dip.size(), 0)
	var did: String = str((dip[0] as Dictionary).get("id", ""))
	assert_true(MinisterManager.assign_diplomat_to_faction(did, "zhao"), "应能派驻外交大夫到赵")
	assert_true(MinisterManager.get_diplomat_cost_reduction("qin", "zhao") > 0.0, "辩才应降低对赵外交成本")
	assert_true(MinisterManager.get_diplomat_opinion_gain("qin", "zhao") > 0.0, "亲和应提供对赵好感成长")
	assert_eq(MinisterManager.get_diplomat_cost_reduction("qin", "chu"), 0.0, "未派驻目标国无加成")
