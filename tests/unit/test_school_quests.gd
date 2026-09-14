extends GutTest

## 学派任务最小闭环


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	SchoolManager.reset()
	TechSystem.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_gold_quest_completes_and_grants_exp() -> void:
	var exp_before: int = SchoolManager.get_school_exp("qin")
	GameManager.apply_faction_resource_delta("qin", "gold", 5000)
	SchoolManager.check_quests("qin")
	var completed: Array = SchoolManager.get_completed_quests("qin")
	assert_true(completed.has("leg_q3"), "金钱达标应完成富国强兵任务，got=%s" % str(completed))
	assert_gt(SchoolManager.get_school_exp("qin"), exp_before, "任务应发放学派经验")


func test_quest_not_repeatable() -> void:
	GameManager.apply_faction_resource_delta("qin", "gold", 5000)
	SchoolManager.check_quests("qin")
	var exp1: int = SchoolManager.get_school_exp("qin")
	SchoolManager.check_quests("qin")
	assert_eq(SchoolManager.get_school_exp("qin"), exp1, "同一任务不应重复发经验")


func test_recruit_quest_completes_with_troops() -> void:
	GameManager.add_units("qin", "infantry", 12)
	SchoolManager.check_quests("qin")
	assert_true(SchoolManager.get_completed_quests("qin").has("leg_q1"), "兵力达标应完成奖励耕战")
