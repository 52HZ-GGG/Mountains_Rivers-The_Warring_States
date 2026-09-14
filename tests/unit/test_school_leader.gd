extends GutTest

## 学派领袖技能


func before_each() -> void:
	GameManager.reset()
	CityManager.reset()
	MinisterManager.reset()
	SchoolManager.reset()
	TechSystem.reset()
	EventManager.set_muted(true)
	GameManager.start_game(["qin", "zhao"], "qin")


func test_leader_skill_inactive_at_level_one() -> void:
	var effects: Dictionary = SchoolManager.get_leader_skill_effects("qin")
	assert_true(effects.is_empty() or SchoolManager.get_school_level("qin") >= 2,
		"1 级不应激活领袖技能")


func test_leader_skill_unlocks_at_level_two() -> void:
	SchoolManager.add_school_exp("qin", 80)
	assert_true(SchoolManager.get_school_level("qin") >= 2, "经验应升到 2 级")
	var effects: Dictionary = SchoolManager.get_leader_skill_effects("qin")
	assert_false(effects.is_empty(), "2 级应暴露领袖技能效果")
	if effects.has("stability_bonus"):
		assert_gt(float(effects["stability_bonus"]), 0.0, "领袖安定度加成应为正")
